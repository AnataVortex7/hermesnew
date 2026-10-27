# Hermes Agent v0.4.0 (pinned) + Tailscale on Render (free) with Telegram backup

Hermes version **v2026.3.23 (v0.4.0)** var pin kelela ahe (`Dockerfile` madhe `HERMES_VERSION`).
Install script ani code donhi tya tag madhun yetat, `main` nahi. `hermes update` chalvu naka (to main var nel).
Dusrya release var jaycha tar fakt `Dockerfile` madhli `HERMES_VERSION` badla.

Render free var disk restart/redeploy nantar pusat hoto. Mhanun Hermes cha data (`~/.hermes`: config,
API keys, memory, sessions) tgstorage (Koyeb) madhun Telegram madhe backup hoto ani restart nantar
apoap restore hoto.

## Render env vars
| Name | Value |
|---|---|
| `TS_AUTHKEY` | Tailscale auth key |
| `TERMINAL_PASSWORD` | web terminal password (compulsory) |
| `BACKUP_URL` | `https://<tumcha-app>.koyeb.app` (tgstorage cha URL) |
| `BACKUP_TOKEN` | tgstorage var set kelela `BACKUP_TOKEN` (same value) |
| `TELEGRAM_BOT_TOKEN` | Telegram bot token (BotFather). Deploy var `~/.hermes/.env` madhe apoap jato, ani gateway suru hoto |
| `TELEGRAM_ALLOWED_USERS` | tumcha Telegram numeric user ID (comma separated). Nasel tar bot kunalach uttar deu shakto nahi |
| `OPENROUTER_API_KEY` / `ANTHROPIC_API_KEY` / `OPENAI_API_KEY` / `GOOGLE_API_KEY` / `GEMINI_API_KEY` / `GROQ_API_KEY` / `DEEPSEEK_API_KEY` / `NOUS_API_KEY` | LLM key (jo vaprta to) - same pramane `.env` madhe jato |
| `HERMES_EXTRA_ENV_KEYS` | optional, vadhiv env var nave (space separated) jyanna `.env` madhe lihaycha ahe |
| `BACKUP_INTERVAL` | optional, don uploads madhla kamit kami gap (seconds), default **10800 (3 tas)** |
| `BACKUP_EXCLUDE` | optional, extra paths (space separated), e.g. `.hermes/big_dir` |
| `BACKUP_MAX_MB` | optional, backup jyast mothha asel tar skip, default 200 |

## Outbound bandwidth (Render) - mahatvache
Render Hobby (free) workspace la fakt **5 GB/mahina** outbound milto (render.com/docs/outbound-bandwidth).
Sampla ani payment method nasel tar saglya services mahina sampey paryant band hotat.
- **Backup UPLOAD outbound madhe mojla jato** (Render -> Koyeb = public internet). Restore (download) inbound, free.
- Mhanun backup rare theval: data khara badalla asel **ani** `BACKUP_INTERVAL` (3 tas) gela asel tarach upload.
- Logs / cache / `*.lock` / `*.pid` badalle tari upload hot nahi (te backup madhe pan nahit).
- Restart/redeploy (SIGTERM) var shevatcha backup: data badalla asel tarach, gap na pahta.
- Baki outbound: Hermes cha LLM API calls, web tools, Telegram, web terminal (ttyd), Tailscale traffic.
  Kiti vaparla te Render Dashboard -> service -> Metrics -> Outbound Bandwidth madhe pahu shakta.

## Kasa kaam karto
- Web terminal pahile suru hoto (Render la port lagech disto). Tailscale, restore, Hermes gateway, backup he background madhe.
- Render env vars (bot token, API keys) dar boot la `~/.hermes/.env` madhe lihile jatat; Render madhe badalla ki te jinkte.
- Start var: `hermes-sync restore` -> latest backup download karun `~/.hermes` madhe thevto.
  Backup nasel (first run) tar skip. Storage jaag nasel tar background madhe retry; tovar backups pause.
- Dar 10 min la local check (network nahi). Upload fakt upar sangitlelya ataincha.
- `hermes-agent/` ani `tools/` (Hermes code + Python) backup madhe nahi, te image madhe aadhich ahet.

## Terminal commands
```
hermes-sync backup      # lagech backup (manual, nehmi upload karto)
hermes-sync status      # backups list + "uploaded since container start" (kiti MB gela)
hermes-sync restore     # latest restore
hermes --version        # v0.4.0 disla pahije
```
Mahatvache: `hermes setup` zalyavar `hermes-sync backup` ek vela chalva, mhanje setup lagech surakshit.
