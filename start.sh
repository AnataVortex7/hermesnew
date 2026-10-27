#!/bin/bash
set -u

PORT="${PORT:-10000}"
TS_HOSTNAME="${TS_HOSTNAME:-render-hermes}"

# 1) Tailscale in userspace mode (Render has no /dev/net/tun)
mkdir -p /var/lib/tailscale /var/run/tailscale
tailscaled --tun=userspace-networking \
  --state=/var/lib/tailscale/tailscaled.state \
  --socket=/var/run/tailscale/tailscaled.sock &

sleep 4

if [ -n "${TS_AUTHKEY:-}" ]; then
  tailscale up --authkey="${TS_AUTHKEY}" --hostname="${TS_HOSTNAME}" --ssh --accept-dns=false \
    || echo "tailscale up failed - check TS_AUTHKEY"
else
  echo "TS_AUTHKEY not set, skipping tailscale up"
fi

# 2) Backup / restore through tgstorage (Telegram). Needs BACKUP_URL + BACKUP_TOKEN.
BACKUP_ON=0
if [ -n "${BACKUP_URL:-}" ] && [ -n "${BACKUP_TOKEN:-}" ]; then
  BACKUP_ON=1
  # settings file read by `hermes-sync` (Render blocks sudo, so it must be readable by the hermes user)
  umask 077
  {
    echo "export BACKUP_URL='${BACKUP_URL}'"
    echo "export BACKUP_TOKEN='${BACKUP_TOKEN}'"
    echo "export BACKUP_NAME='${BACKUP_NAME:-hermes}'"
    echo "export BACKUP_EXCLUDE='${BACKUP_EXCLUDE:-}'"
  } > /home/hermes/.hermes-sync.env
  chown hermes:hermes /home/hermes/.hermes-sync.env
  umask 022
  rm -f /tmp/.hermes_restore_done
  echo "Restoring Hermes data from tgstorage..."
  su hermes -s /bin/bash -c '/usr/local/bin/hermes-sync restore' || echo "restore not finished yet, will keep retrying in background"
else
  echo "BACKUP_URL / BACKUP_TOKEN not set - data will be LOST on restart"
fi

# 3) Make sure Hermes is installed (retry if build-time install failed)
if ! su - hermes -c 'command -v hermes >/dev/null 2>&1'; then
  echo "Hermes not found, installing..."
  su - hermes -c 'curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash' \
    || echo "Hermes install failed - run it manually in the terminal"
fi

# 3b) Hermes messaging gateway (Telegram bot) - restarts itself if it crashes
su - hermes -c 'while true; do
  if grep -qi telegram "$HOME/.hermes/.env" 2>/dev/null; then
    hermes gateway run >> "$HOME/gateway.log" 2>&1
  fi
  sleep 30
done' >/dev/null 2>&1 &

# 4) Periodic backup (only when something changed, and only after a successful restore check)
if [ "$BACKUP_ON" = 1 ]; then
  (
    while true; do
      sleep "${BACKUP_INTERVAL:-600}"
      if [ ! -f /tmp/.hermes_restore_done ]; then
        su hermes -s /bin/bash -c 'RESTORE_TRIES=1 /usr/local/bin/hermes-sync restore --late'
      fi
      [ -f /tmp/.hermes_restore_done ] && su hermes -s /bin/bash -c '/usr/local/bin/hermes-sync backup --if-changed'
    done
  ) &
fi

# 5) Keep-alive ping (Render free sleeps after 15 min without traffic)
if [ -n "${RENDER_EXTERNAL_URL:-}" ]; then
  ( while true; do sleep 600; curl -fsS "${RENDER_EXTERNAL_URL}" >/dev/null 2>&1 || true; done ) &
fi

# 6) Web terminal on the port Render expects
if [ -z "${TERMINAL_PASSWORD:-}" ]; then
  echo "TERMINAL_PASSWORD not set - refusing to start an open web terminal"
  exec python3 -m http.server "${PORT}" 2>/dev/null || exec sleep infinity
fi

# ttyd prints the base64 credential in its startup log, so filter that line out
ttyd -p "${PORT}" -W -c "${TERMINAL_USER:-admin}:${TERMINAL_PASSWORD}" su - hermes 2>&1 \
  | grep --line-buffered -v 'credential:' &
TTYD=$!

# Render sends SIGTERM on restart/redeploy (~30 s grace): take a last backup first
final_backup() {
  if [ "$BACKUP_ON" = 1 ] && [ -f /tmp/.hermes_restore_done ]; then
    timeout 25 su hermes -s /bin/bash -c '/usr/local/bin/hermes-sync backup --if-changed'
  fi
  pkill -f 'hermes gateway' 2>/dev/null
  pkill ttyd 2>/dev/null
  exit 0
}
trap final_backup TERM INT
wait "$TTYD"
