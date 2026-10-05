FROM debian:trixie-slim
RUN apt-get update && apt-get install -y --no-install-recommends bash ca-certificates curl git python3 sqlite3 util-linux procps coreutils build-essential docker-cli \
 && rm -rf /var/lib/apt/lists/*
ENV MISE_DATA_DIR=/opt/mise MISE_YES=1 PATH=/opt/mise/shims:/usr/local/bin:$PATH CARGO_HOME=/opt/cargo RUSTUP_HOME=/opt/rustup
RUN curl -fsSL https://mise.run | MISE_INSTALL_PATH=/usr/local/bin/mise sh && mise install rust@1.98.1 && mkdir -p /opt/cargo/registry && chmod -R a+rwX /opt/mise /opt/cargo /opt/rustup
