//! Route-specific contracts apply to every measured response, including warmups.
use std::{io::Read, path::Path};

use bytes::Bytes;
use hyper::HeaderMap;
use regex::Regex;
use serde_json::Value;

pub struct Validator {
    kind: String,
    content_type: String,
    message_ids: Option<Vec<u64>>,
    message_content: Option<Vec<String>>,
    required: Vec<String>,
    exact_body: Option<Vec<u8>>,
    ids: Regex,
    // Exact byte equality reuses validation of an immutable wire representation. No hashes,
    // unchecked samples, or cross-route entries; randomized pages are checked in full.
    valid_bodies: Vec<(String, String, Bytes)>,
    message_id: Option<u64>,
}

impl Validator {
    pub fn from_file(path: &Path) -> Result<Self, Box<dyn std::error::Error + Send + Sync>> {
        let value: Value = serde_json::from_slice(&std::fs::read(path)?)?;
        Self::from_value(value).map_err(Into::into)
    }

    fn from_value(value: Value) -> Result<Self, &'static str> {
        let kind = value["kind"].as_str().ok_or("validation contract needs kind")?.to_owned();
        if !["room_show", "messages_page", "sidebar", "search", "avatar", "static_css", "up", "post_message"].contains(&kind.as_str()) {
            return Err("unknown validation kind");
        }
        let content_type = value["content_type"].as_str().ok_or("validation contract needs content_type")?.to_owned();
        let message_ids = value
            .get("message_ids")
            .filter(|v| !v.is_null())
            .map(|v| {
                v.as_array()
                    .ok_or("message_ids must be an array")?
                    .iter()
                    .map(|v| v.as_u64().ok_or("invalid message ID"))
                    .collect::<Result<Vec<_>, _>>()
            })
            .transpose()?;
        if ["room_show", "messages_page", "search"].contains(&kind.as_str()) && message_ids.as_ref().is_none_or(Vec::is_empty) {
            return Err("message route needs expected IDs");
        }
        let message_content = value
            .get("message_content")
            .map(|v| {
                v.as_array()
                    .ok_or("message_content must be an array")?
                    .iter()
                    .map(|v| v.as_str().map(str::to_owned).ok_or("invalid message content"))
                    .collect::<Result<Vec<_>, _>>()
            })
            .transpose()?;
        if message_content.as_ref().is_some_and(|content| Some(content.len()) != message_ids.as_ref().map(Vec::len)) {
            return Err("message content must match expected IDs");
        }
        let required = value["required"]
            .as_array()
            .ok_or("validation contract needs required markers")?
            .iter()
            .map(|v| v.as_str().map(str::to_owned).ok_or("invalid marker"))
            .collect::<Result<Vec<_>, _>>()?;
        let exact_body = value
            .get("exact_body")
            .filter(|v| !v.is_null())
            .map(|v| {
                v.as_array()
                    .ok_or("exact_body must be bytes")?
                    .iter()
                    .map(|v| v.as_u64().and_then(|v| u8::try_from(v).ok()).ok_or("invalid body byte"))
                    .collect::<Result<Vec<_>, _>>()
            })
            .transpose()?;
        Ok(Self {
            kind,
            content_type,
            message_ids,
            message_content,
            required,
            exact_body,
            ids: Regex::new(r#"data-message-id="(\d+)""#).unwrap(),
            valid_bodies: Vec::new(),
            message_id: None,
        })
    }

    pub fn message_id(&self) -> Option<u64> {
        self.message_id
    }

    pub fn check(&mut self, status: u16, headers: &HeaderMap, wire: &Bytes, posted: Option<&str>) -> Result<(), &'static str> {
        let content_type = headers.get("content-type").and_then(|v| v.to_str().ok()).ok_or("missing content type")?;
        let encoding = headers.get("content-encoding").map(|v| v.to_str().unwrap_or("invalid")).unwrap_or("identity");
        if status != 200 || wire.is_empty() {
            return Err("unsuccessful or empty response");
        }
        if content_type.split(';').next().unwrap_or("").trim() != self.content_type {
            return Err("wrong content type");
        }
        if let Some(length) = headers.get("content-length")
            && length.to_str().ok().and_then(|s| s.parse::<usize>().ok()) != Some(wire.len())
        {
            return Err("wrong content length");
        }
        if self.kind != "post_message" && self.valid_bodies.iter().any(|(e, t, b)| e == encoding && t == content_type && b == wire) {
            return Ok(());
        }
        let decoded;
        let body = match encoding {
            "identity" => wire.as_ref(),
            "gzip" => {
                let mut decoder = flate2::bufread::GzDecoder::new(wire.as_ref());
                let mut output = Vec::new();
                decoder.by_ref().take(8 * 1024 * 1024 + 1).read_to_end(&mut output).map_err(|_| "invalid gzip stream")?;
                if output.len() > 8 * 1024 * 1024 || !decoder.into_inner().is_empty() {
                    return Err("oversized or trailing gzip data");
                }
                decoded = output;
                &decoded
            }
            _ => return Err("unsupported content encoding"),
        };
        if let Some(expected) = &self.exact_body {
            if body != expected {
                return Err("changed binary or static response");
            }
        } else {
            let text = std::str::from_utf8(body).map_err(|_| "invalid UTF-8")?;
            if self.required.iter().any(|marker| !text.contains(marker)) {
                return Err("missing expected content");
            }
            if ["room_show", "sidebar", "search"].contains(&self.kind.as_str())
                && (!text.trim_start().get(..15).is_some_and(|v| v.eq_ignore_ascii_case("<!doctype html>"))
                    || !text.trim_end().ends_with("</html>"))
            {
                return Err("incomplete HTML document");
            }
            let messages = self
                .ids
                .captures_iter(text)
                .map(|c| c[1].parse::<u64>().map(|id| (id, c.get(0).unwrap().end())))
                .collect::<Result<Vec<_>, _>>()
                .map_err(|_| "invalid message ID")?;
            let ids = messages.iter().map(|(id, _)| *id).collect::<Vec<_>>();
            if let Some(expected) = &self.message_ids
                && &ids != expected
            {
                return Err("incorrect message window");
            }
            if let Some(expected) = &self.message_content {
                for (i, marker) in expected.iter().enumerate() {
                    let end = messages.get(i + 1).map_or(text.len(), |(_, end)| *end);
                    if !text[messages[i].1..end].contains(marker) {
                        return Err("missing seeded message content");
                    }
                }
            }
            if self.kind == "post_message" {
                if !text.starts_with("<turbo-stream")
                    || !text.trim_end().ends_with("</turbo-stream>")
                    || !text.contains("<template>")
                    || !text.contains("</template>")
                    || ids.len() != 1
                {
                    return Err("invalid message Turbo Stream");
                }
                self.message_id = Some(ids[0]);
                if !posted.is_some_and(|token| text.contains(token)) {
                    return Err("POST did not render the requested message");
                }
            }
        }
        if self.kind != "post_message" {
            if self.valid_bodies.len() == 8 {
                self.valid_bodies.remove(0);
            }
            self.valid_bodies.push((encoding.to_owned(), content_type.to_owned(), wire.clone()));
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;
    use std::io::Write;

    fn validator(kind: &str) -> Validator {
        let content_type = if kind == "post_message" { "text/vnd.turbo-stream.html" } else { "text/html" };
        Validator::from_value(json!({"kind":kind,"content_type":content_type,"message_ids":if kind=="room_show" {json!([42])} else {Value::Null},"required":[]})).unwrap()
    }
    fn headers(content_type: &str, gzip: bool) -> HeaderMap {
        let mut h = HeaderMap::new();
        h.insert("content-type", content_type.parse().unwrap());
        if gzip {
            h.insert("content-encoding", "gzip".parse().unwrap());
        }
        h
    }
    #[test]
    fn rejects_200_error_pages_truncated_pages_and_wrong_message_windows() {
        let mut v = validator("room_show");
        let h = headers("text/html", false);
        let good = Bytes::from_static(b"<!DOCTYPE html><html><article data-message-id=\"42\">coffee</article></html>");
        assert!(v.check(200, &h, &good, None).is_ok());
        assert!(v.check(200, &h, &good, None).is_ok());
        for bad in [
            "error",
            "<!DOCTYPE html><html><article data-message-id=\"42\">coffee",
            "<!DOCTYPE html><html><article data-message-id=\"43\">coffee</article></html>",
            "<!DOCTYPE html><html></html>",
        ] {
            assert!(v.check(200, &h, &Bytes::from(bad), None).is_err());
        }
        assert!(v.check(500, &h, &good, None).is_err());
        assert!(v.check(200, &headers("text/plain", false), &good, None).is_err());
    }
    #[test]
    fn validates_gzip_crc_truncation_trailing_data_and_content_after_cache_hit() {
        let mut v = validator("room_show");
        let h = headers("text/html", true);
        let mut gz = flate2::write::GzEncoder::new(Vec::new(), flate2::Compression::fast());
        gz.write_all(b"<!DOCTYPE html><html><article data-message-id=\"42\">coffee</article></html>").unwrap();
        let bytes = gz.finish().unwrap();
        assert!(v.check(200, &h, &Bytes::from(bytes.clone()), None).is_ok());
        let mut corrupt = bytes.clone();
        let n = corrupt.len();
        corrupt[n - 8] ^= 1;
        assert!(v.check(200, &h, &Bytes::from(corrupt), None).is_err());
        assert!(v.check(200, &h, &Bytes::copy_from_slice(&bytes[..bytes.len() - 1]), None).is_err());
        let mut trailing = bytes;
        trailing.push(0);
        assert!(v.check(200, &h, &Bytes::from(trailing), None).is_err());
    }

    #[test]
    fn checks_each_seeded_body_and_rejects_overflowing_message_ids() {
        let mut v = Validator::from_value(json!({"kind":"messages_page","content_type":"text/html",
            "message_ids":[42,43],"message_content":["coffee","meeting"],"required":[]}))
        .unwrap();
        let h = headers("text/html", false);
        let good = Bytes::from_static(b"<article data-message-id=\"42\">coffee</article><article data-message-id=\"43\">meeting</article>");
        assert!(v.check(200, &h, &good, None).is_ok());
        let bad = Bytes::from_static(b"<article data-message-id=\"42\"></article><article data-message-id=\"43\">coffee meeting</article>");
        assert!(v.check(200, &h, &bad, None).is_err());
        let overflow = Bytes::from_static(b"<article data-message-id=\"18446744073709551616\">coffee</article>");
        assert!(v.check(200, &h, &overflow, None).is_err());
        assert!(
            Validator::from_value(json!({"kind":"messages_page","content_type":"text/html",
            "message_ids":[42],"message_content":["coffee","meeting"],"required":[]}))
            .is_err()
        );
    }
    #[test]
    fn post_requires_actual_message_and_per_request_body() {
        let mut v = validator("post_message");
        let h = headers("text/vnd.turbo-stream.html", false);
        let body=Bytes::from_static(b"<turbo-stream action=\"append\"><template><article data-message-id=\"42\">bench write unique</article></template></turbo-stream>");
        assert!(v.check(200, &h, &body, Some("bench write unique")).is_ok());
        assert!(v.check(200, &h, &body, Some("bench write different")).is_err());
        assert!(
            v.check(
                200,
                &h,
                &Bytes::from_static(b"<turbo-stream><template>This room was deleted.</template></turbo-stream>"),
                Some("bench write unique")
            )
            .is_err()
        );
    }
    #[test]
    fn invalid_validation_contract_fails_closed() {
        assert!(Validator::from_value(json!({"kind":"room_show","content_type":"text/html","required":[]})).is_err());
        assert!(Validator::from_value(json!({"kind":"unknown","content_type":"text/html","required":[]})).is_err());
    }
}
