#!/bin/bash
set -u

PORT="${PORT:-10000}"
TS_HOSTNAME="${TS_HOSTNAME:-render-hermes}"

# 1) Tailscale in userspace mode (Render has no /dev/net/tun)
mkdir -p /var/lib/tailscale /var/run/tailscale
tailscaled --tun=userspace-networking \
  --state=/var/lib/tailscale/tailscaled.state \
  --socket=/var/run/tailscale/tailscaled.sock \
  --socks5-server=localhost:1055 &

sleep 4

if [ -n "${TS_AUTHKEY:-}" ]; then
  tailscale up --authkey="${TS_AUTHKEY}" --hostname="${TS_HOSTNAME}" --ssh --accept-dns=false \
    || echo "tailscale up failed - check TS_AUTHKEY"
else
  echo "TS_AUTHKEY not set, skipping tailscale up"
fi

# 2) Make sure Hermes is installed (retry if build-time install failed)
if ! su - hermes -c 'command -v hermes >/dev/null 2>&1'; then
  echo "Hermes not found, installing..."
  su - hermes -c 'curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash' \
    || echo "Hermes install failed - run it manually in the terminal"
fi

# 3) Keep-alive ping so the free service does not sleep (needs RENDER_EXTERNAL_URL, set automatically by Render)
if [ -n "${RENDER_EXTERNAL_URL:-}" ]; then
  ( while true; do sleep 600; curl -fsS "${RENDER_EXTERNAL_URL}" >/dev/null 2>&1 || true; done ) &
fi

# 4) Web terminal on the port Render expects (also keeps the web service "healthy")
if [ -z "${TERMINAL_PASSWORD:-}" ]; then
  echo "TERMINAL_PASSWORD not set - refusing to start an open web terminal"
  # still bind the port with a plain responder so Render does not kill the service
  exec python3 -m http.server "${PORT}" 2>/dev/null || exec sleep infinity
fi

exec ttyd -p "${PORT}" -W -c "${TERMINAL_USER:-admin}:${TERMINAL_PASSWORD}" su - hermes
