# Hermes Agent + Tailscale on Render (free web service)

Ha repo Render chya free Docker web service var chalto:
- Tailscale background madhe sada chalto (userspace mode + Tailscale SSH)
- Hermes Agent install hoto (`curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash`)
- Terminal access: (1) Tailscale SSH, (2) Render URL var password-protected web terminal

## Setup

1. Tailscale admin panel -> Settings -> Keys -> **Generate auth key** (Reusable ON, Ephemeral ON recommended).
2. Hi files GitHub repo madhe push kara.
3. Render -> New -> **Web Service** -> repo select -> Runtime: **Docker** -> Instance type: **Free**.
4. Environment variables:
   - `TS_AUTHKEY` = tumchi tailscale key
   - `TS_HOSTNAME` = `render-hermes` (optional)
   - `TERMINAL_PASSWORD` = strong password (compulsory)
   - `TERMINAL_USER` = `admin` (optional)
5. Deploy.

## Terminal access

- **Tailscale SSH** (tumchya device var Tailscale chalu asava): `ssh hermes@render-hermes`
- **Web terminal**: Render la dilela `https://<service>.onrender.com` ughada, user/password taka.

Terminal madhe `hermes` command chalva ani setup che questions vichar-un setup karta yeil
(API key, model, ityadi).

## Free tier chya limits (mahatvache)

- Free web service ~15 min inactivity nantar sleep hoto. Script madhe self-ping ahe, pan Render
  baher-chya traffic chi apeksha karto, tyamule 100% "permanent" nahi. Jast reliable pahije asel
  tar UptimeRobot sarkha free monitor 5 min interval ne `https://<service>.onrender.com` var lava.
- Disk ephemeral ahe: restart/redeploy zalyavar Hermes cha config/data jaato. Persistent disk paid ahe.
- Free instance la ~750 hours/month milatat (ek service sathi mahinabhar pure).
- Render free var `/dev/net/tun` nahi, mhanun Tailscale userspace mode madhe chalto
  (SSH ani incoming connections kaam kartat).
