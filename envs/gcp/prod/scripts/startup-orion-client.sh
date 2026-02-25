#!/usr/bin/env bash
set -euo pipefail

exec > >(tee -a /var/log/orion-client-startup.log) 2>&1

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y --no-install-recommends \
  ca-certificates \
  curl \
  git \
  git-lfs \
  gettext-base \
  netcat-openbsd \
  procps \
  zstd \
  fuse3 \
  libssl3 \
  build-essential \
  pkg-config \
  cmake \
  clang \
  llvm-dev \
  libclang-dev \
  libssl-dev \
  libfuse3-dev \
  protobuf-compiler

echo "user_allow_other" >> /etc/fuse.conf || true

mkdir -p \
  /opt/orion-client \
  /opt/orion-client/src \
  /opt/orion-client/bin \
  /opt/orion-client/log \
  /data/scorpio/store \
  /data/scorpio/antares/upper \
  /data/scorpio/antares/cl \
  /data/scorpio/antares/mnt \
  /workspace/mount

# Install Rust toolchain if missing
if ! command -v rustc >/dev/null 2>&1; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
fi
export PATH="/root/.cargo/bin:${PATH}"

# Install Buck2
BUCK2_VERSION="2025-06-01"
ARCH="x86_64-unknown-linux-musl"
curl -fsSL -o /usr/local/bin/buck2.zst "https://github.com/facebook/buck2/releases/download/${BUCK2_VERSION}/buck2-${ARCH}.zst"
zstd -d /usr/local/bin/buck2.zst -o /usr/local/bin/buck2
chmod +x /usr/local/bin/buck2

# Create wrapper that behaves like the container entrypoint (start embedded scorpio then orion)
cat >/usr/local/bin/orion-worker-wrapper <<'WRAPPER'
#!/usr/bin/env bash
set -euo pipefail

log() { echo "[orion-worker-wrapper] $*"; }

: "${SERVER_WS:?SERVER_WS is required}"

# Defaults aligned with mega/orion/entrypoint.sh
: "${SCORPIO_API_BASE_URL:=http://127.0.0.1:2725}"
: "${SCORPIO_HTTP_ADDR:=0.0.0.0:2725}"
: "${ORION_WORKER_START_SCORPIO:=true}"

: "${SCORPIO_STORE_PATH:=/data/scorpio/store}"
: "${SCORPIO_WORKSPACE:=/workspace/mount}"

mkdir -p "$SCORPIO_STORE_PATH" "$SCORPIO_WORKSPACE" \
  /data/scorpio/antares/upper /data/scorpio/antares/cl /data/scorpio/antares/mnt

if [ "$ORION_WORKER_START_SCORPIO" != "false" ] && [ "$ORION_WORKER_START_SCORPIO" != "0" ]; then
  if [ ! -e /dev/fuse ]; then
    log "ERROR: /dev/fuse not found; Scorpio requires FUSE"
    exit 1
  fi

  log "Starting embedded scorpio..."
  scorpio -c /etc/scorpio/scorpio.toml --http-addr "$SCORPIO_HTTP_ADDR" &
  scorpio_pid=$!

  # Wait for scorpio to listen
  port="${SCORPIO_HTTP_ADDR##*:}"
  for i in $(seq 1 60); do
    if nc -z 127.0.0.1 "$port" >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done

  if ! nc -z 127.0.0.1 "$port" >/dev/null 2>&1; then
    log "ERROR: scorpio did not become ready on 127.0.0.1:$port"
    kill "$scorpio_pid" 2>/dev/null || true
    exit 1
  fi

  log "Scorpio ready on 127.0.0.1:$port"
  export SCORPIO_API_BASE_URL="http://127.0.0.1:$port"
fi

log "Starting orion worker..."
exec orion
WRAPPER

chmod +x /usr/local/bin/orion-worker-wrapper

# Write and enable systemd service for orion worker
cat >/etc/systemd/system/orion-worker.service <<'EOF'
[Unit]
Description=Orion Worker Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
Environment="SERVER_WS=wss://buck2hub-orion-504513835593.asia-east1.run.app/ws"
Environment="SCORPIO_BASE_URL=https://buck2hub-mono-504513835593.asia-east1.run.app"
Environment="SCORPIO_LFS_URL=https://buck2hub-mono-504513835593.asia-east1.run.app"
Environment="SCORPIO_STORE_PATH=/data/scorpio/store"
Environment="SCORPIO_WORKSPACE=/workspace/mount"
Environment="ORION_WORKER_START_SCORPIO=true"
Environment="SCORPIO_HTTP_ADDR=0.0.0.0:2725"
ExecStart=/usr/local/bin/orion-worker-wrapper
Restart=always
RestartSec=5
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable orion-worker.service

