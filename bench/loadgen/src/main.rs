//! Load generator for the Campfire benchmark (bench/run). Talks plain HTTP/1.1 and Action Cable
//! (WebSocket) to one server and prints one JSON object per command on stdout.
//!
//!   loadgen login  --base URL --email E --password P            -> {"cookie": "..."}
//!   loadgen scrape --base URL --cookie C --room ID              -> csrf token, stream names, assets
//!   loadgen http   --base URL --cookie C --path P --conc N --duration S
//!                  [--post-room ID --csrf T]                     -> latency/throughput
//!   loadgen cable  --base URL --cookie C --room ID --csrf T --clients N [--streams a,b,c]
//!                  [--sources 127.0.0.2,127.0.0.3 --hold-secs 60 --deflate 1]
//!                  [--latency-msgs 30 --interval-ms 200 --tput-secs 15 --posters 4]
//!   loadgen upload --base URL --cookie C --room ID --csrf T --file PATH [--reps 5]
//!   loadgen fetch  --base URL --cookie C --path P --out FILE     -> saves an uncompressed body
//!   loadgen gzip   --file F [--iters 200]                         -> CPU per compression, by backend/level
//!
//! `http` also takes `--gzip 0` (`Accept-Encoding: identity`), `--requests N` (stop after N requests,
//! for allocation counting) and `--trace FILE` (each request's start, latency and status). `cable` prints `PHASE <name> <unix ms>` lines on stderr so memory
//! samples can be attributed to its phases.
//!
//! Every command takes `--user-agent UA`, sent as the `User-Agent` of each request it makes,
//! WebSocket handshakes included; without it there is no `User-Agent` header. For example, a
//! desktop Chrome: `--user-agent 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36
//! (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36'` (one line).

use std::collections::{HashMap, HashSet};
use std::sync::atomic::{AtomicBool, AtomicU64, AtomicUsize, Ordering};
use std::sync::{Arc, Mutex, OnceLock};
use std::time::{Duration, Instant};

use bytes::Bytes;
use futures_util::{SinkExt, StreamExt};
use hdrhistogram::Histogram;
use http_body_util::{BodyExt, Full};
use hyper::client::conn::http1::SendRequest;
use hyper_util::rt::TokioIo;
use serde_json::{Value, json};
use tokio::net::TcpStream;
use tokio_tungstenite::tungstenite::{Message as WsMessage, client::IntoClientRequest};

type Res<T> = Result<T, Box<dyn std::error::Error + Send + Sync>>;

struct Args(HashMap<String, String>);

impl Args {
    fn parse(raw: &[String]) -> Self {
        let mut map = HashMap::new();
        let mut it = raw.iter();
        while let Some(k) = it.next() {
            if let Some(k) = k.strip_prefix("--") {
                map.insert(k.to_string(), it.next().cloned().unwrap_or_default());
            }
        }
        Args(map)
    }
    fn get(&self, k: &str) -> String {
        self.0.get(k).cloned().unwrap_or_else(|| panic!("missing --{k}"))
    }
    fn opt(&self, k: &str) -> Option<String> {
        self.0.get(k).cloned()
    }
    fn num<T: std::str::FromStr>(&self, k: &str, default: T) -> T {
        self.0.get(k).and_then(|v| v.parse().ok()).unwrap_or(default)
    }
}

/// `--user-agent`, set once in `main`.
static USER_AGENT: OnceLock<Option<String>> = OnceLock::new();

fn user_agent() -> Option<&'static str> {
    USER_AGENT.get().and_then(Option::as_deref)
}

fn host_port(base: &str) -> String {
    base.trim_start_matches("http://").trim_end_matches('/').to_string()
}

async fn connect(addr: &str) -> Res<SendRequest<Full<Bytes>>> {
    let stream = TcpStream::connect(addr).await?;
    stream.set_nodelay(true)?;
    let (sender, conn) = hyper::client::conn::http1::handshake(TokioIo::new(stream)).await?;
    tokio::spawn(async move {
        let _ = conn.await;
    });
    Ok(sender)
}

struct Resp {
    status: u16,
    headers: hyper::HeaderMap,
    body: Bytes,
}

async fn send(
    sender: &mut SendRequest<Full<Bytes>>,
    addr: &str,
    method: &str,
    path: &str,
    headers: &[(&str, String)],
    body: Bytes,
) -> Res<Resp> {
    let mut req = hyper::Request::builder().method(method).uri(path).header("host", addr);
    if let Some(user_agent) = user_agent() {
        req = req.header("user-agent", user_agent);
    }
    for (k, v) in headers {
        req = req.header(*k, v.as_str());
    }
    let req = req.body(Full::new(body))?;
    // A request that takes longer than this counts as an error (and drops the connection).
    tokio::time::timeout(Duration::from_secs(30), async {
        sender.ready().await?;
        let resp = sender.send_request(req).await?;
        let status = resp.status().as_u16();
        let headers = resp.headers().clone();
        let body = resp.into_body().collect().await?.to_bytes();
        Ok(Resp { status, headers, body })
    })
    .await
    .map_err(|_| "request timed out after 30s")?
}

async fn one_shot(addr: &str, method: &str, path: &str, headers: &[(&str, String)], body: Bytes) -> Res<Resp> {
    let mut s = connect(addr).await?;
    send(&mut s, addr, method, path, headers, body).await
}

fn urlencode(s: &str) -> String {
    let mut out = String::new();
    for b in s.bytes() {
        match b {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'_' | b'.' | b'~' => out.push(b as char),
            _ => out.push_str(&format!("%{b:02X}")),
        }
    }
    out
}

fn form(pairs: &[(&str, &str)]) -> Bytes {
    Bytes::from(pairs.iter().map(|(k, v)| format!("{}={}", urlencode(k), urlencode(v))).collect::<Vec<_>>().join("&"))
}

fn merge_cookies(jar: &mut Vec<(String, String)>, headers: &hyper::HeaderMap) {
    for v in headers.get_all("set-cookie") {
        let s = v.to_str().unwrap_or("");
        let pair = s.split(';').next().unwrap_or("");
        if let Some((k, v)) = pair.split_once('=') {
            jar.retain(|(n, _)| n != k);
            jar.push((k.to_string(), v.to_string()));
        }
    }
}

fn cookie_header(jar: &[(String, String)]) -> String {
    jar.iter().map(|(k, v)| format!("{k}={v}")).collect::<Vec<_>>().join("; ")
}

/// The page's CSRF token: the Rails app renders one; the Rust app doesn't (it checks `Sec-Fetch-Site`).
fn csrf_from(html: &str) -> Option<String> {
    regex::Regex::new(r#"<meta name="csrf-token" content="([^"]*)""#).unwrap().captures(html).map(|c| c[1].to_string())
}

/// What a browser sends with requests its pages make; the Rust app's forgery protection needs it.
fn same_origin() -> (&'static str, String) {
    ("sec-fetch-site", "same-origin".into())
}

fn unescape(s: &str) -> String {
    s.replace("&amp;", "&").replace("&quot;", "\"").replace("&#39;", "'")
}

async fn login(a: &Args) -> Res<Value> {
    let addr = host_port(&a.get("base"));
    let mut jar = Vec::new();
    let r = one_shot(&addr, "GET", "/session/new", &[], Bytes::new()).await?;
    merge_cookies(&mut jar, &r.headers);
    let token = csrf_from(&String::from_utf8_lossy(&r.body)).unwrap_or_default();
    let body = form(&[("email_address", &a.get("email")), ("password", &a.get("password")), ("authenticity_token", &token)]);
    let r = one_shot(
        &addr,
        "POST",
        "/session",
        &[("cookie", cookie_header(&jar)), ("content-type", "application/x-www-form-urlencoded".into()), same_origin()],
        body,
    )
    .await?;
    merge_cookies(&mut jar, &r.headers);
    if r.status != 302 || !jar.iter().any(|(k, _)| k == "session_token") {
        return Err(format!("login failed: {}", r.status).into());
    }
    Ok(json!({ "cookie": cookie_header(&jar) }))
}

async fn scrape(a: &Args) -> Res<Value> {
    let addr = host_port(&a.get("base"));
    let path = format!("/rooms/{}", a.get("room"));
    let r = one_shot(&addr, "GET", &path, &[("cookie", a.get("cookie"))], Bytes::new()).await?;
    let mut html = String::from_utf8_lossy(&r.body).to_string();
    // The sidebar frame (loaded lazily by the page) carries the rooms/user-rooms stream sources.
    let sidebar = one_shot(&addr, "GET", "/users/me/sidebar", &[("cookie", a.get("cookie"))], Bytes::new()).await?;
    html.push_str(&String::from_utf8_lossy(&sidebar.body));
    let streams: Vec<String> = {
        // "Channel|signed name" for each <turbo-cable-stream-source>.
        let re = regex::Regex::new(r#"<turbo-cable-stream-source channel="([^"]+)" signed-stream-name="([^"]+)""#).unwrap();
        let mut seen = HashSet::new();
        re.captures_iter(&html).map(|c| format!("{}|{}", &c[1], unescape(&c[2]))).filter(|s| seen.insert(s.clone())).collect()
    };
    let css = regex::Regex::new(r#"href="(/assets/[^"]+\.css)""#).unwrap().captures(&html).map(|c| c[1].to_string());
    let js = regex::Regex::new(r#"(/assets/[^"]+\.js)""#).unwrap().captures(&html).map(|c| c[1].to_string());
    Ok(json!({
        "status": r.status,
        "bytes": r.body.len(),
        "csrf": csrf_from(&html),
        "streams": streams,
        "css": css,
        "js": js,
    }))
}

fn hist() -> Histogram<u64> {
    Histogram::new_with_bounds(1, 120_000_000, 3).unwrap()
}

fn ms(us: u64) -> f64 {
    (us as f64 / 1000.0 * 1000.0).round() / 1000.0
}

fn summary(h: &Histogram<u64>) -> Value {
    if h.is_empty() {
        return json!({"n": 0});
    }
    json!({
        "n": h.len(),
        "p50_ms": ms(h.value_at_quantile(0.5)),
        "p90_ms": ms(h.value_at_quantile(0.9)),
        "p99_ms": ms(h.value_at_quantile(0.99)),
        "max_ms": ms(h.max()),
        "mean_ms": (h.mean() / 10.0).round() / 100.0,
    })
}

static SEQ: AtomicU64 = AtomicU64::new(0);

fn nonce() -> String {
    let t = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_nanos();
    format!("{:x}{:x}", t, SEQ.fetch_add(1, Ordering::Relaxed))
}

fn message_request(cookie: &str, csrf: &str, body_text: &str) -> (Vec<(&'static str, String)>, Bytes) {
    let body = form(&[("message[body]", body_text), ("message[client_message_id]", &nonce()), ("authenticity_token", csrf)]);
    (
        vec![
            ("cookie", cookie.to_string()),
            ("content-type", "application/x-www-form-urlencoded".into()),
            ("accept", "text/vnd.turbo-stream.html, text/html, application/xhtml+xml".into()),
            ("x-csrf-token", csrf.to_string()),
            same_origin(),
        ],
        body,
    )
}

async fn http_load(a: &Args) -> Res<Value> {
    let addr = host_port(&a.get("base"));
    let cookie = a.opt("cookie").unwrap_or_default();
    let path = a.opt("path").unwrap_or_else(|| "/".into());
    let conc: usize = a.num("conc", 1);
    let duration = Duration::from_secs_f64(a.num("duration", 10.0));
    let post_room = a.opt("post-room");
    let csrf = a.opt("csrf").unwrap_or_default();
    let gzip = a.num("gzip", 1u8) != 0;
    let accept_encoding = if gzip { "gzip" } else { "identity" };
    let limit: u64 = a.num("requests", u64::MAX);
    let trace_path = a.opt("trace");
    let trace = Arc::new(Mutex::new(Vec::<(u128, u64, u16)>::new()));
    let issued = Arc::new(AtomicU64::new(0));

    let hist_all = Arc::new(Mutex::new(hist()));
    let statuses = Arc::new(Mutex::new(HashMap::<u16, u64>::new()));
    let errors = Arc::new(AtomicU64::new(0));
    let invalid_responses = Arc::new(AtomicU64::new(0));
    let bytes_total = Arc::new(AtomicU64::new(0));
    let start = Instant::now();
    let deadline = start + duration;
    let mut tasks = Vec::new();
    for _ in 0..conc {
        let (addr, cookie, path, post_room, csrf) = (addr.clone(), cookie.clone(), path.clone(), post_room.clone(), csrf.clone());
        let invalid_responses = invalid_responses.clone();
        let (hist_all, statuses, errors, bytes_total, issued, trace) =
            (hist_all.clone(), statuses.clone(), errors.clone(), bytes_total.clone(), issued.clone(), trace.clone());
        let tracing = trace_path.is_some();
        tasks.push(tokio::spawn(async move {
            let mut h = hist();
            let mut local = HashMap::<u16, u64>::new();
            let mut conn: Option<SendRequest<Full<Bytes>>> = None;
            let mut i = 0u64;
            let mut local_trace = Vec::new();
            while Instant::now() < deadline && issued.fetch_add(1, Ordering::Relaxed) < limit {
                if conn.is_none() {
                    match connect(&addr).await {
                        Ok(c) => conn = Some(c),
                        Err(_) => {
                            errors.fetch_add(1, Ordering::Relaxed);
                            tokio::time::sleep(Duration::from_millis(10)).await;
                            continue;
                        }
                    }
                }
                let (method, p, headers, body) = match &post_room {
                    Some(room) => {
                        i += 1;
                        let (mut h, b) = message_request(&cookie, &csrf, &format!("bench write {i}"));
                        h.push(("accept-encoding", accept_encoding.into()));
                        ("POST", format!("/rooms/{room}/messages"), h, b)
                    }
                    None => {
                        let mut h = vec![("cookie", cookie.clone())];
                        h.push(("accept-encoding", accept_encoding.into()));
                        ("GET", path.clone(), h, Bytes::new())
                    }
                };
                let t0 = Instant::now();
                let wall0 =
                    if tracing { std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_micros() } else { 0 };
                match send(conn.as_mut().unwrap(), &addr, method, &p, &headers, body).await {
                    Ok(r) => {
                        if r.status != 200 || r.body.is_empty() { invalid_responses.fetch_add(1, Ordering::Relaxed); }
                        h.record(t0.elapsed().as_micros() as u64).ok();
                        if tracing {
                            local_trace.push((wall0, t0.elapsed().as_micros() as u64, r.status));
                        }
                        *local.entry(r.status).or_default() += 1;
                        bytes_total.fetch_add(r.body.len() as u64, Ordering::Relaxed);
                        if r.headers.get("connection").map(|v| v == "close").unwrap_or(false) {
                            conn = None;
                        }
                    }
                    Err(_) => {
                        errors.fetch_add(1, Ordering::Relaxed);
                        conn = None;
                    }
                }
            }
            hist_all.lock().unwrap().add(&h).unwrap();
            trace.lock().unwrap().extend(local_trace);
            let mut s = statuses.lock().unwrap();
            for (k, v) in local {
                *s.entry(k).or_default() += v;
            }
        }));
    }
    for t in tasks {
        t.await?;
    }
    let elapsed = start.elapsed().as_secs_f64();
    if let Some(path) = &trace_path {
        // One line per request: start (unix µs), latency (µs), status.
        let mut t = trace.lock().unwrap();
        t.sort();
        let lines: String = t.iter().map(|(s, l, st)| format!("{s} {l} {st}\n")).collect();
        std::fs::write(path, lines)?;
    }
    let h = hist_all.lock().unwrap();
    let st = statuses.lock().unwrap();
    let ok: u64 = st.iter().filter(|(k, _)| **k == 200).map(|(_, v)| v).sum();
    Ok(json!({
        "path": if let Some(r) = &post_room { format!("POST /rooms/{r}/messages") } else { path },
        "conc": conc,
        "gzip": gzip,
        "secs": (elapsed * 100.0).round() / 100.0,
        "rps": ((ok as f64 / elapsed) * 10.0).round() / 10.0,
        "ok": ok,
        "statuses": st.iter().map(|(k, v)| (k.to_string(), json!(v))).collect::<serde_json::Map<_, _>>(),
        "errors": errors.load(Ordering::Relaxed),
        "invalid_responses": invalid_responses.load(Ordering::Relaxed),
        "avg_bytes": if !h.is_empty() { bytes_total.load(Ordering::Relaxed) / h.len() } else { 0 },
        "latency": summary(&h),
    }))
}

// ---------------------------------------------------------------------------------------------
// Action Cable fan-out

struct Delivery {
    sent: Mutex<HashMap<u64, Instant>>,
    got: Mutex<HashMap<u64, (usize, Instant)>>, // seq -> (clients received, last receipt)
    per_client: Mutex<Histogram<u64>>,
    receipts: AtomicU64,
    /// Bytes read off the sockets (`--deflate` clients only): what the network carries.
    wire_bytes: AtomicU64,
}

fn markers(text: &str) -> Vec<u64> {
    let mut out = Vec::new();
    let mut rest = text;
    while let Some(i) = rest.find("bmk") {
        rest = &rest[i + 3..];
        let digits: String = rest.chars().take_while(|c| c.is_ascii_digit()).collect();
        if !digits.is_empty()
            && rest[digits.len()..].starts_with('z')
            && let Ok(n) = digits.parse()
        {
            out.push(n);
        }
    }
    out
}

#[allow(clippy::too_many_arguments)]
async fn cable_client(
    addr: String,
    source: Option<std::net::IpAddr>,
    cookie: String,
    subs: Vec<String>,
    confirmed: Arc<AtomicUsize>,
    connected: Arc<AtomicUsize>,
    stop: Arc<AtomicBool>,
    delivery: Arc<Delivery>,
) -> Res<()> {
    let mut req = format!("ws://{addr}/cable").into_client_request()?;
    let h = req.headers_mut();
    h.insert("cookie", cookie.parse()?);
    h.insert("origin", format!("http://{addr}").parse()?);
    h.insert("sec-websocket-protocol", "actioncable-v1-json, actioncable-unsupported".parse()?);
    if let Some(user_agent) = user_agent() {
        h.insert("user-agent", user_agent.parse()?);
    }
    let debug = std::env::var_os("LOADGEN_DEBUG").is_some();
    if debug {
        eprintln!("connecting {:?}", req.headers());
    }
    // One source address has ~28k ephemeral ports towards one server port; many clients connect
    // from several loopback addresses (`--sources`).
    let socket = tokio::net::TcpSocket::new_v4()?;
    if let Some(source) = source {
        socket.bind(std::net::SocketAddr::new(source, 0))?;
    }
    let stream = socket.connect(tokio::net::lookup_host(&addr).await?.next().ok_or("no address")?).await?;
    stream.set_nodelay(true)?;
    let (ws, _) = tokio_tungstenite::client_async(req, stream).await.inspect_err(|e| {
        if debug {
            eprintln!("connect error: {e}")
        }
    })?;
    if debug {
        eprintln!("connected");
    }
    connected.fetch_add(1, Ordering::Relaxed);
    let (mut tx, mut rx) = ws.split();
    for ident in &subs {
        tx.send(WsMessage::text(json!({"command": "subscribe", "identifier": ident}).to_string())).await?;
    }
    let mut seen = HashSet::new();
    let mut confirms = 0;
    while let Some(msg) = rx.next().await {
        if stop.load(Ordering::Relaxed) {
            break;
        }
        let text = match msg? {
            WsMessage::Text(t) => t,
            WsMessage::Close(_) => break,
            _ => continue,
        };
        on_text(&text, subs.len(), &mut confirms, &mut seen, &confirmed, &delivery);
    }
    let _ = tx.send(WsMessage::Close(None)).await;
    Ok(())
}

/// A frame's text: counts subscription confirmations and records each marked message's arrival.
fn on_text(text: &str, subscriptions: usize, confirms: &mut usize, seen: &mut HashSet<u64>, confirmed: &AtomicUsize, delivery: &Delivery) {
    let now = Instant::now();
    if std::env::var_os("LOADGEN_DEBUG").is_some() {
        eprintln!("<< {}", &text[..text.len().min(300)]);
    }
    if text.contains("confirm_subscription") {
        *confirms += 1;
        if *confirms == subscriptions {
            confirmed.fetch_add(1, Ordering::Relaxed);
        }
        return;
    }
    for seq in markers(text) {
        if !seen.insert(seq) {
            continue;
        }
        delivery.receipts.fetch_add(1, Ordering::Relaxed);
        let sent = delivery.sent.lock().unwrap().get(&seq).copied();
        if let Some(t0) = sent {
            delivery.per_client.lock().unwrap().record(now.duration_since(t0).as_micros() as u64).ok();
        }
        let mut got = delivery.got.lock().unwrap();
        let e = got.entry(seq).or_insert((0, now));
        e.0 += 1;
        e.1 = now;
    }
}

/// `--deflate`: a minimal WebSocket client (RFC 6455) that offers `permessage-deflate` as browsers
/// do, since tungstenite has no compression, and counts the bytes read off the socket.
#[allow(clippy::too_many_arguments)]
async fn deflate_cable_client(
    addr: String,
    source: Option<std::net::IpAddr>,
    cookie: String,
    subs: Vec<String>,
    confirmed: Arc<AtomicUsize>,
    connected: Arc<AtomicUsize>,
    stop: Arc<AtomicBool>,
    delivery: Arc<Delivery>,
) -> Res<()> {
    use tokio::io::{AsyncBufReadExt, AsyncReadExt, AsyncWriteExt};
    let socket = tokio::net::TcpSocket::new_v4()?;
    if let Some(source) = source {
        socket.bind(std::net::SocketAddr::new(source, 0))?;
    }
    let stream = socket.connect(tokio::net::lookup_host(&addr).await?.next().ok_or("no address")?).await?;
    stream.set_nodelay(true)?;
    let (read, mut write) = stream.into_split();
    let request = format!(
        "GET /cable HTTP/1.1\r\nHost: {addr}\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n\
         Sec-WebSocket-Version: 13\r\nSec-WebSocket-Protocol: actioncable-v1-json, actioncable-unsupported\r\n\
         Sec-WebSocket-Extensions: permessage-deflate; client_max_window_bits\r\nOrigin: http://{addr}\r\nCookie: {cookie}\r\n\r\n"
    );
    write.write_all(request.as_bytes()).await?;
    let mut reader = tokio::io::BufReader::with_capacity(16 * 1024, read);
    let mut status = String::new();
    reader.read_line(&mut status).await?;
    if !status.starts_with("HTTP/1.1 101") {
        return Err(format!("upgrade failed: {}", status.trim()).into());
    }
    let mut compressed = false;
    loop {
        let mut line = String::new();
        reader.read_line(&mut line).await?;
        if line.trim().is_empty() {
            break;
        }
        compressed |= line.to_ascii_lowercase().starts_with("sec-websocket-extensions:") && line.contains("permessage-deflate");
    }
    connected.fetch_add(1, Ordering::Relaxed);
    for ident in &subs {
        let payload = json!({"command": "subscribe", "identifier": ident}).to_string();
        write.write_all(&masked_text_frame(payload.as_bytes())).await?;
    }
    let mut seen = HashSet::new();
    let mut confirms = 0;
    let mut inflater = flate2::Decompress::new(false);
    let mut payload = Vec::new();
    let mut text = Vec::new();
    loop {
        if stop.load(Ordering::Relaxed) {
            break;
        }
        let mut head = [0u8; 2];
        if reader.read_exact(&mut head).await.is_err() {
            break;
        }
        let len = match head[1] & 0x7f {
            126 => reader.read_u16().await? as usize,
            127 => reader.read_u64().await? as usize,
            len => len as usize,
        };
        payload.resize(len, 0);
        reader.read_exact(&mut payload).await?;
        let header_len = 2 + if len >= 65536 {
            8
        } else if len >= 126 {
            2
        } else {
            0
        };
        delivery.wire_bytes.fetch_add((header_len + len) as u64, Ordering::Relaxed);
        match head[0] & 0x0f {
            0x8 => break,
            0x1 => {}
            _ => continue,
        }
        let message = if head[0] & 0x40 != 0 && compressed {
            inflater.reset(false);
            payload.extend_from_slice(&[0, 0, 0xff, 0xff]);
            text.clear();
            text.reserve(len * 8 + 1024);
            loop {
                let consumed = inflater.total_in() as usize;
                inflater.decompress_vec(&payload[consumed..], &mut text, flate2::FlushDecompress::Sync)?;
                if inflater.total_in() as usize == payload.len() && text.len() < text.capacity() {
                    break;
                }
                text.reserve(text.capacity());
            }
            std::str::from_utf8(&text)?
        } else {
            std::str::from_utf8(&payload)?
        };
        on_text(message, subs.len(), &mut confirms, &mut seen, &confirmed, &delivery);
    }
    Ok(())
}

/// A client's text frame: masked, as RFC 6455 requires of clients.
fn masked_text_frame(payload: &[u8]) -> Vec<u8> {
    let mask = [0x37, 0xfa, 0x21, 0x3d];
    let mut frame = vec![0x81];
    match payload.len() {
        len if len < 126 => frame.push(0x80 | len as u8),
        len => {
            frame.push(0x80 | 126);
            frame.extend_from_slice(&(len as u16).to_be_bytes());
        }
    }
    frame.extend_from_slice(&mask);
    frame.extend(payload.iter().enumerate().map(|(i, b)| b ^ mask[i % 4]));
    frame
}

async fn post_marked(
    sender: &mut Option<SendRequest<Full<Bytes>>>,
    addr: &str,
    room: &str,
    cookie: &str,
    csrf: &str,
    seq: u64,
    delivery: &Delivery,
) -> Option<u64> {
    if sender.is_none() {
        *sender = connect(addr).await.ok();
    }
    let (h, b) = message_request(cookie, csrf, &format!("fanout bmk{seq}z"));
    let t0 = Instant::now();
    delivery.sent.lock().unwrap().insert(seq, t0);
    match send(sender.as_mut()?, addr, "POST", &format!("/rooms/{room}/messages"), &h, b).await {
        Ok(r) if r.status < 400 => Some(t0.elapsed().as_micros() as u64),
        _ => {
            *sender = None;
            None
        }
    }
}

async fn wait_drain(delivery: &Delivery, seqs: &[u64], clients: usize, timeout: Duration) {
    let until = Instant::now() + timeout;
    while Instant::now() < until {
        let drained = {
            let got = delivery.got.lock().unwrap();
            seqs.iter().all(|s| got.get(s).map(|g| g.0 >= clients).unwrap_or(false))
        };
        if drained {
            return;
        }
        tokio::time::sleep(Duration::from_millis(50)).await;
    }
}

fn phase(name: &str) {
    let ms = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_millis();
    eprintln!("PHASE {name} {ms}");
}

fn fanout_stats(delivery: &Delivery, seqs: &[u64], clients: usize) -> (Histogram<u64>, usize, Option<Instant>) {
    let sent = delivery.sent.lock().unwrap();
    let got = delivery.got.lock().unwrap();
    let mut all = hist();
    let mut complete = 0;
    let mut last = None::<Instant>;
    for s in seqs {
        if let Some((n, t)) = got.get(s) {
            last = Some(last.map_or(*t, |l| l.max(*t)));
            if *n >= clients {
                complete += 1;
                all.record(t.duration_since(sent[s]).as_micros() as u64).ok();
            }
        }
    }
    (all, complete, last)
}

async fn cable(a: &Args) -> Res<Value> {
    let addr = host_port(&a.get("base"));
    let cookie = a.get("cookie");
    let room = a.get("room");
    let csrf = a.opt("csrf").unwrap_or_default();
    let clients: usize = a.num("clients", 100);
    let latency_msgs: u64 = a.num("latency-msgs", 30);
    let interval = Duration::from_millis(a.num("interval-ms", 200));
    let tput_secs: f64 = a.num("tput-secs", 15.0);
    let posters: usize = a.num("posters", 4);
    let hold_secs: u64 = a.num("hold-secs", 0);
    let deflate = a.num("deflate", 0u8) != 0;
    let sources: Vec<std::net::IpAddr> =
        a.opt("sources").unwrap_or_default().split(',').filter(|s| !s.is_empty()).map(|s| s.parse()).collect::<Result<_, _>>()?;

    // The chatter.js load shape: presence for the room, unread rooms, heartbeat, and the page's
    // turbo stream sources (rooms list, the room's messages, the user's rooms).
    let mut subs = vec![
        json!({"channel": "PresenceChannel", "room_id": room.parse::<u64>()?}).to_string(),
        json!({"channel": "UnreadRoomsChannel"}).to_string(),
        json!({"channel": "HeartbeatChannel"}).to_string(),
    ];
    for s in a.get("streams").split(',').filter(|s| !s.is_empty()) {
        let (channel, name) = s.split_once('|').unwrap_or(("Turbo::StreamsChannel", s));
        subs.push(json!({"channel": channel, "signed_stream_name": name}).to_string());
    }

    let delivery = Arc::new(Delivery {
        sent: Mutex::new(HashMap::new()),
        got: Mutex::new(HashMap::new()),
        per_client: Mutex::new(hist()),
        receipts: AtomicU64::new(0),
        wire_bytes: AtomicU64::new(0),
    });
    let confirmed = Arc::new(AtomicUsize::new(0));
    let connected = Arc::new(AtomicUsize::new(0));
    let stop = Arc::new(AtomicBool::new(false));
    let failed = Arc::new(AtomicUsize::new(0));

    // Connect with bounded parallelism (50 handshakes in flight).
    phase("connect");
    let connect_start = Instant::now();
    let gate = Arc::new(tokio::sync::Semaphore::new(50));
    let mut handles = Vec::new();
    for n in 0..clients {
        let permit = gate.clone().acquire_owned().await?;
        let source = (!sources.is_empty()).then(|| sources[n % sources.len()]);
        let (addr, cookie, subs, confirmed, connected, stop, delivery, failed) = (
            addr.clone(),
            cookie.clone(),
            subs.clone(),
            confirmed.clone(),
            connected.clone(),
            stop.clone(),
            delivery.clone(),
            failed.clone(),
        );
        let before = connected.load(Ordering::Relaxed);
        handles.push(tokio::spawn(async move {
            let c2 = connected.clone();
            let task = if deflate {
                tokio::spawn(deflate_cable_client(addr, source, cookie, subs, confirmed, connected, stop, delivery))
            } else {
                tokio::spawn(cable_client(addr, source, cookie, subs, confirmed, connected, stop, delivery))
            };
            // Release the permit once this client has connected (or failed).
            let until = Instant::now() + Duration::from_secs(30);
            while c2.load(Ordering::Relaxed) <= before && !task.is_finished() && Instant::now() < until {
                tokio::time::sleep(Duration::from_millis(5)).await;
            }
            drop(permit);
            if let Ok(Err(_)) = task.await {
                failed.fetch_add(1, Ordering::Relaxed);
            }
        }));
    }
    let until = Instant::now() + Duration::from_secs(120.max(clients as u64 / 200));
    while confirmed.load(Ordering::Relaxed) + failed.load(Ordering::Relaxed) < clients && Instant::now() < until {
        tokio::time::sleep(Duration::from_millis(50)).await;
    }
    let connect_secs = connect_start.elapsed().as_secs_f64();
    let ready = confirmed.load(Ordering::Relaxed);
    phase("connected");
    tokio::time::sleep(Duration::from_secs(1)).await;
    if hold_secs > 0 {
        // Everyone connected and idle: what the server spends on heartbeats and holding sockets.
        phase("idle");
        tokio::time::sleep(Duration::from_secs(hold_secs)).await;
        phase("idle_done");
    }
    phase("paced");

    // Phase 1: paced messages, one at a time (open loop at `interval`), for delivery latency.
    let mut poster = None;
    let mut post_h = hist();
    let mut seqs = Vec::new();
    let mut seq = 0u64;
    for _ in 0..latency_msgs {
        seq += 1;
        let tick = Instant::now();
        if let Some(us) = post_marked(&mut poster, &addr, &room, &cookie, &csrf, seq, &delivery).await {
            post_h.record(us).ok();
        }
        seqs.push(seq);
        let spent = tick.elapsed();
        if spent < interval {
            tokio::time::sleep(interval - spent).await;
        }
    }
    wait_drain(&delivery, &seqs, ready, Duration::from_secs(20)).await;
    phase("paced_drained");
    let (all_h, complete, _) = fanout_stats(&delivery, &seqs, ready);
    let client_h = std::mem::replace(&mut *delivery.per_client.lock().unwrap(), hist());
    let latency = json!({
        "messages": latency_msgs,
        "complete": complete,
        "post": summary(&post_h),
        "per_client": summary(&client_h),
        "all_clients": summary(&all_h),
    });

    // Phase 2: closed-loop posters for tput_secs, then drain; delivered messages/sec.
    let receipts_before = delivery.receipts.load(Ordering::Relaxed);
    let wire_before = delivery.wire_bytes.load(Ordering::Relaxed);
    let next = Arc::new(AtomicU64::new(seq + 1));
    phase("saturated");
    let tput_start = Instant::now();
    let tput_deadline = tput_start + Duration::from_secs_f64(tput_secs);
    let mut ptasks = Vec::new();
    for _ in 0..posters {
        let (addr, room, cookie, csrf, delivery, next) =
            (addr.clone(), room.clone(), cookie.clone(), csrf.clone(), delivery.clone(), next.clone());
        ptasks.push(tokio::spawn(async move {
            let mut conn = None;
            let mut mine = Vec::new();
            let mut h = hist();
            while Instant::now() < tput_deadline {
                let s = next.fetch_add(1, Ordering::Relaxed);
                if let Some(us) = post_marked(&mut conn, &addr, &room, &cookie, &csrf, s, &delivery).await {
                    h.record(us).ok();
                    mine.push(s);
                }
            }
            (mine, h)
        }));
    }
    let mut tseqs = Vec::new();
    let mut tpost_h = hist();
    for t in ptasks {
        let (m, h) = t.await?;
        tseqs.extend(m);
        tpost_h.add(&h).ok();
    }
    let posting_secs = tput_start.elapsed().as_secs_f64();
    phase("saturated_posted");
    wait_drain(&delivery, &tseqs, ready, Duration::from_secs(60)).await;
    phase("saturated_drained");
    let (tall_h, tcomplete, last) = fanout_stats(&delivery, &tseqs, ready);
    let span = last.map(|l| l.duration_since(tput_start).as_secs_f64()).unwrap_or(posting_secs).max(posting_secs);
    let tclient_h = delivery.per_client.lock().unwrap().clone();
    let receipts = delivery.receipts.load(Ordering::Relaxed) - receipts_before;
    let wire_bytes = delivery.wire_bytes.load(Ordering::Relaxed) - wire_before;
    let throughput = json!({
        "posters": posters,
        "posted": tseqs.len(),
        "posts_per_sec": ((tseqs.len() as f64 / posting_secs) * 10.0).round() / 10.0,
        "complete": tcomplete,
        "delivered_msgs_per_sec": ((tcomplete as f64 / span) * 10.0).round() / 10.0,
        "frames_per_sec": (receipts as f64 / span).round(),
        "wire_mb_per_sec": (wire_bytes as f64 / span / 1e6 * 10.0).round() / 10.0,
        "drain_secs": ((span - posting_secs) * 100.0).round() / 100.0,
        "post": summary(&tpost_h),
        "per_client": summary(&tclient_h),
        "all_clients": summary(&tall_h),
    });

    let hold: f64 = a.num("hold-secs", 0.0);
    if hold > 0.0 {
        tokio::time::sleep(Duration::from_secs_f64(hold)).await;
    }
    phase("done");
    stop.store(true, Ordering::Relaxed);
    for h in handles {
        h.abort();
    }
    Ok(json!({
        "clients": clients,
        "ready": ready,
        "failed": failed.load(Ordering::Relaxed),
        "connect_secs": (connect_secs * 100.0).round() / 100.0,
        "subscriptions_per_client": subs.len(),
        "latency": latency,
        "throughput": throughput,
    }))
}

// ---------------------------------------------------------------------------------------------
// Upload + thumbnail

async fn upload(a: &Args) -> Res<Value> {
    let addr = host_port(&a.get("base"));
    let cookie = a.get("cookie");
    let room = a.get("room");
    let csrf = a.opt("csrf").unwrap_or_default();
    let file = a.get("file");
    let reps: usize = a.num("reps", 5);
    let data = std::fs::read(&file)?;
    let name = std::path::Path::new(&file).file_name().unwrap().to_string_lossy().to_string();
    let ctype = if name.ends_with(".png") { "image/png" } else { "image/jpeg" };
    let img_re = regex::Regex::new(r#"<img[^>]+src="([^"]+)""#).unwrap();

    let mut runs = Vec::new();
    for _ in 0..reps {
        let boundary = format!("----bench{}", nonce());
        let mut body = Vec::new();
        for (k, v) in [("authenticity_token", csrf.as_str()), ("message[client_message_id]", &nonce())] {
            body.extend(format!("--{boundary}\r\nContent-Disposition: form-data; name=\"{k}\"\r\n\r\n{v}\r\n").as_bytes());
        }
        body.extend(
            format!("--{boundary}\r\nContent-Disposition: form-data; name=\"message[attachment]\"; filename=\"{name}\"\r\nContent-Type: {ctype}\r\n\r\n")
                .as_bytes(),
        );
        body.extend(&data);
        body.extend(format!("\r\n--{boundary}--\r\n").as_bytes());
        let t0 = Instant::now();
        let r = one_shot(
            &addr,
            "POST",
            &format!("/rooms/{room}/messages"),
            &[
                ("cookie", cookie.clone()),
                ("content-type", format!("multipart/form-data; boundary={boundary}")),
                ("accept", "text/vnd.turbo-stream.html, text/html".into()),
                ("x-csrf-token", csrf.clone()),
                same_origin(),
            ],
            Bytes::from(body),
        )
        .await?;
        let post_ms = t0.elapsed().as_secs_f64() * 1000.0;
        let html = String::from_utf8_lossy(&r.body).to_string();
        let Some(src) = img_re.captures(&html).map(|c| unescape(&c[1])) else {
            runs.push(json!({"post_status": r.status, "post_ms": post_ms, "error": "no <img> in response"}));
            continue;
        };
        // Follow redirects to the bytes (representations/redirect -> disk service).
        let mut url = src.clone();
        let mut status = 0;
        let mut size = 0;
        for _ in 0..5 {
            let path = url.trim_start_matches(&format!("http://{addr}")).to_string();
            let g = one_shot(&addr, "GET", &path, &[("cookie", cookie.clone())], Bytes::new()).await?;
            status = g.status;
            size = g.body.len();
            match g.headers.get("location") {
                Some(loc) if (300..400).contains(&g.status) => url = loc.to_str()?.to_string(),
                _ => break,
            }
        }
        let total_ms = t0.elapsed().as_secs_f64() * 1000.0;
        runs.push(json!({
            "post_status": r.status, "post_ms": (post_ms * 10.0).round() / 10.0,
            "thumb_status": status, "thumb_bytes": size, "thumb_ms": ((total_ms - post_ms) * 10.0).round() / 10.0,
            "total_ms": (total_ms * 10.0).round() / 10.0,
        }));
    }
    let mut totals: Vec<f64> = runs.iter().filter_map(|r| r["total_ms"].as_f64()).collect();
    totals.sort_by(|a, b| a.partial_cmp(b).unwrap());
    Ok(json!({
        "file": name, "bytes": data.len(),
        "median_total_ms": totals.get(totals.len() / 2),
        "runs": runs,
    }))
}

// ---------------------------------------------------------------------------------------------
// Compression cost

async fn fetch(a: &Args) -> Res<Value> {
    let addr = host_port(&a.get("base"));
    let path = a.get("path");
    let r = one_shot(&addr, "GET", &path, &[("cookie", a.opt("cookie").unwrap_or_default())], Bytes::new()).await?;
    std::fs::write(a.get("out"), &r.body)?;
    Ok(
        json!({"status": r.status, "bytes": r.body.len(), "content_encoding": r.headers.get("content-encoding").map(|v| v.to_str().unwrap_or("").to_string())}),
    )
}

/// CPU per compression of one body. zlib-rs is the app's backend; the app's `Rack::Deflater` port
/// writes the body as one chunk with a sync flush and then finishes, at `Compression::default()`
/// (6). `miniz_oxide` is flate2's default `rust_backend`, which the app used before.
fn gzip_cost(a: &Args) -> Res<Value> {
    use std::io::Write;
    let data = std::fs::read(a.get("file"))?;
    let iters: u32 = a.num("iters", 200);
    let time = |f: &dyn Fn() -> usize| {
        let mut out = 0;
        for _ in 0..3 {
            out = f();
        }
        let mut samples: Vec<f64> = (0..iters)
            .map(|_| {
                let t0 = Instant::now();
                out = f();
                t0.elapsed().as_secs_f64() * 1e6
            })
            .collect();
        samples.sort_by(|a, b| a.partial_cmp(b).unwrap());
        json!({"median_us": samples[samples.len() / 2].round(), "min_us": samples[0].round(), "out_bytes": out})
    };
    let mut results = serde_json::Map::new();
    for level in [1u8, 4, 6, 9] {
        results.insert(format!("miniz_oxide_l{level}"), time(&|| miniz_oxide::deflate::compress_to_vec(&data, level).len()));
        results.insert(
            format!("zlib_rs_l{level}"),
            time(&|| {
                // The app's exact call sequence: one write, sync flush, finish.
                let mut e = flate2::GzBuilder::new().mtime(0).operating_system(3).write(Vec::new(), flate2::Compression::new(level as u32));
                e.write_all(&data).unwrap();
                e.flush().unwrap();
                e.finish().unwrap().len()
            }),
        );
    }
    Ok(json!({"file": a.get("file"), "bytes": data.len(), "iters": iters, "results": results}))
}

#[tokio::main]
async fn main() {
    let raw: Vec<String> = std::env::args().collect();
    let cmd = raw.get(1).cloned().unwrap_or_default();
    let a = Args::parse(&raw[2.min(raw.len())..]);
    USER_AGENT.set(a.opt("user-agent")).expect("set once");
    let out = match cmd.as_str() {
        "login" => login(&a).await,
        "scrape" => scrape(&a).await,
        "http" => http_load(&a).await,
        "cable" => cable(&a).await,
        "upload" => upload(&a).await,
        "fetch" => fetch(&a).await,
        "gzip" => gzip_cost(&a),
        _ => Err("usage: loadgen login|scrape|http|cable|upload|fetch|gzip --base URL ...".into()),
    };
    match out {
        Ok(v) => println!("{v}"),
        Err(e) => {
            eprintln!("loadgen {cmd}: {e}");
            std::process::exit(1);
        }
    }
}
