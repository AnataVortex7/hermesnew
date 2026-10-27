#!/bin/bash
set -u

PORT="${PORT:-10000}"
TS_HOSTNAME="${TS_HOSTNAME:-render-hermes}"
HERMES_VERSION="${HERMES_VERSION:-v2026.3.23}"   # pinned release tag (Hermes v0.4.0)
HH=/home/hermes

# 0) Web terminal FIRST, so Render sees the open port within a second.
#    (Before, ttyd started only after restore/install, and a slow tgstorage kept the port closed.)
if [ -z "${TERMINAL_PASSWORD:-}" ]; then
  echo "TERMINAL_PASSWORD not set - refusing to start an open web terminal"
  exec python3 -m http.server "${PORT}" 2>/dev/null || exec sleep infinity
fi
# ttyd prints the base64 credential in its startup log, so filter that line out
ttyd -p "${PORT}" -W -c "${TERMINAL_USER:-admin}:${TERMINAL_PASSWORD}" su - hermes 2>&1 \
  | grep --line-buffered -v 'credential:' &
TTYD=$!

BACKUP_ON=0
[ -n "${BACKUP_URL:-}" ] && [ -n "${BACKUP_TOKEN:-}" ] && BACKUP_ON=1

# Secrets/settings from Render env vars -> ~/.hermes/.env (re-applied on EVERY boot, so Render env wins)
apply_env() {
  local f="$HH/.hermes/.env" k v
  local keys="TELEGRAM_BOT_TOKEN TELEGRAM_ALLOWED_USERS TELEGRAM_HOME_CHANNEL \
OPENROUTER_API_KEY ANTHROPIC_API_KEY OPENAI_API_KEY GOOGLE_API_KEY GEMINI_API_KEY \
GROQ_API_KEY DEEPSEEK_API_KEY NOUS_API_KEY ${HERMES_EXTRA_ENV_KEYS:-}"
  mkdir -p "$HH/.hermes"; touch "$f"
  for k in $keys; do
    v="${!k:-}"; [ -z "$v" ] && continue
    { grep -v "^${k}=" "$f" 2>/dev/null; printf '%s=%s\n' "$k" "$v"; } > "$f.tmp"
    mv -f "$f.tmp" "$f"
  done
  chown -R hermes:hermes "$HH/.hermes"; chmod 600 "$f"
}

# Everything slow runs in the background; the terminal is already up.
boot() {
  # 1) Tailscale in userspace mode (Render has no /dev/net/tun). `env -u PORT`: tailscaled must not reuse Render's PORT.
  mkdir -p /var/lib/tailscale /var/run/tailscale
  env -u PORT tailscaled --tun=userspace-networking \
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
  if [ "$BACKUP_ON" = 1 ]; then
    # settings file read by `hermes-sync` (Render blocks sudo, so it must be readable by the hermes user)
    umask 077
    {
      echo "export BACKUP_URL='${BACKUP_URL}'"
      echo "export BACKUP_TOKEN='${BACKUP_TOKEN}'"
      echo "export BACKUP_NAME='${BACKUP_NAME:-hermes}'"
      echo "export BACKUP_INTERVAL='${BACKUP_INTERVAL:-10800}'"
      echo "export BACKUP_MAX_MB='${BACKUP_MAX_MB:-200}'"
      echo "export BACKUP_EXCLUDE='${BACKUP_EXCLUDE:-}'"
    } > "$HH/.hermes-sync.env"
    chown hermes:hermes "$HH/.hermes-sync.env"
    umask 022
    rm -f /tmp/.hermes_restore_done
    echo "Restoring Hermes data from tgstorage..."
    su hermes -s /bin/bash -c '/usr/local/bin/hermes-sync restore' || echo "restore not finished yet, will keep retrying in background"
  else
    echo "BACKUP_URL / BACKUP_TOKEN not set - data will be LOST on restart"
  fi

  # 2b) Apply Render env vars (bot token, API keys, ...) on top of whatever was restored
  apply_env

  # 3) Make sure Hermes is installed (retry if build-time install failed)
  if ! su - hermes -c 'command -v hermes >/dev/null 2>&1'; then
    echo "Hermes not found, installing..."
    su - hermes -c "curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/${HERMES_VERSION}/scripts/install.sh | bash -s -- --branch ${HERMES_VERSION} --skip-setup" \
      || echo "Hermes install failed - run it manually in the terminal"
  fi
  echo "Hermes version: $(su - hermes -c 'hermes --version' 2>&1 | head -n 1)  (pinned tag: ${HERMES_VERSION})"

  # 3b) Hermes messaging gateway (Telegram bot) - restarts itself if it crashes
  su - hermes -c 'while true; do
    if grep -qi telegram "$HOME/.hermes/.env" 2>/dev/null; then
      hermes gateway run >> "$HOME/gateway.log" 2>&1
    fi
    sleep 30
  done' >/dev/null 2>&1 &

  # 4) Periodic backup. Wakes every 10 min (local check only); `--if-changed` uploads only when
  #    real data changed AND BACKUP_INTERVAL s (default 3 h) passed. Uploads = Render OUTBOUND bandwidth.
  if [ "$BACKUP_ON" = 1 ]; then
    (
      while true; do
        sleep 600
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
}
boot &

# Render sends SIGTERM on restart/redeploy (~30 s grace): take a last backup first
final_backup() {
  if [ "$BACKUP_ON" = 1 ] && [ -f /tmp/.hermes_restore_done ]; then
    timeout 25 su hermes -s /bin/bash -c '/usr/local/bin/hermes-sync backup --final'
  fi
  pkill -f 'hermes gateway' 2>/dev/null
  pkill ttyd 2>/dev/null
  exit 0
}
trap final_backup TERM INT
wait "$TTYD"
