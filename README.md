# Hermes Agent + Tailscale on Render (free) with Telegram backup

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
| `BACKUP_INTERVAL` | optional, seconds, default 600 |
| `BACKUP_EXCLUDE` | optional, extra paths (space separated), e.g. `.hermes/big_dir` |

## Kasa kaam karto
- Start var: `hermes-sync restore` -> latest backup download karun `~/.hermes` madhe thevto.
  Backup nasel (first run) tar skip. Storage jaag nasel tar background madhe retry; tovar backups pause.
- Dar 10 min la: kahi badal zala asel tarach navin backup jato. Mage 5 backups thevle jatat.
- Render SIGTERM (restart/redeploy) var: shevatcha backup ghet.
- `hermes-agent/` ani `tools/` (Hermes code + Python) backup madhe nahi, te image madhe aadhich ahet.

## Terminal commands
```
hermes-sync backup      # lagech backup
hermes-sync status      # backups chi list
hermes-sync restore     # latest restore
```
Mahatvache: `hermes setup` zalyavar `hermes-sync backup` ek vela chalva, mhanje setup lagech surakshit.
