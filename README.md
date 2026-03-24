# Homelab AI Stack

Self-hosted AI + GPU mining server on Debian 12 (Bookworm) — fully reproducible from bare metal using **Portainer GitOps**.

This repo is the single source of truth. Every stack is a Docker Compose file deployed directly from GitHub. Rebuilding from scratch takes roughly 20–30 minutes (most of that is image pulls and the custom image builds).

> **Migrated from Rocky Linux 10.1.** Rocky 10 had unresolvable NVIDIA driver dependency issues (`egl-gbm`, `egl-wayland`, `egl-x11` not packaged) and missing wireless packages on minimal installs. See [`docs/ROCKY10_WIFI_SETUP.md`](docs/ROCKY10_WIFI_SETUP.md) for the Wi-Fi saga.

---

## Before You Begin — Placeholders

Three placeholders are used throughout this document. **Do a find-and-replace in your notes or editor before following the steps.**

| Placeholder | What to replace it with | Example |
|---|---|---|
| `<hostname>` | Your server's hostname — used for direct SSH/port access | `myserver` |
| `<domain>` | Your Traefik routing domain — used in DNS, URLs, and certs | `myserver.local` |
| `<server-ip>` | Your server's LAN IP address | `192.168.1.100` |

These can be the same value if you're routing by hostname rather than a separate local domain.

---

## Stack Overview

| Stack | Purpose | Compose Path | Optional |
|---|---|---|---|
| **infra** | Traefik reverse proxy + shared `proxy` network | `stacks/infra/compose.yml` | No |
| **postgres** | PostgreSQL 16 database | `stacks/postgres/compose.yml` | No |
| **redis** | Redis 7 cache / message broker | `stacks/redis/compose.yml` | No |
| **qdrant** | Vector database for RAG / semantic search | `stacks/qdrant/compose.yml` | No |
| **monitoring** | Prometheus + Grafana + NVIDIA dcgm-exporter + node-exporter + cAdvisor | `stacks/monitoring/compose.yml` | No |
| **ollama** | Local LLM inference on GPU | `stacks/ollama/compose.yml` | No |
| **openclaw** | Self-hosted AI assistant (Ollama + Anthropic + OpenAI) | `stacks/openclaw/compose.yml` | No |
| **openwebui** | Browser chat UI for Ollama | `stacks/openwebui/compose.yml` | No |
| **adminer** | Web-based Postgres (and multi-DB) admin UI | `stacks/adminer/compose.yml` | Yes |
| **nextcloud** | Self-hosted file storage, sync, and document editing (ONLYOFFICE included) | `stacks/nextcloud/compose.yml` | Yes |
| **quai-miner** | Rigel GPU miner (Quai / KawPow) | `stacks/quai-miner/compose.yml` | Yes |
| **openclaw-sandbox** | Ephemeral OpenClaw for config experimentation | `stacks/openclaw-sandbox/compose.yml` | Yes |

---

## Install Order at a Glance

```
1.  Debian 12 OS install
2.  NVIDIA driver + CUDA + GPU tuning ← scripts/install-nvidia-drivers.sh
3.  Docker + NVIDIA Container
    Toolkit + Portainer           ← scripts/install-docker-portainer.sh
4.  Bootstrap host filesystem     ← scripts/bootstrap-server.sh
5.  Node.js via fnm (optional)    ← scripts/install-node.sh
6.  Deploy stacks via Portainer   ← repeat Add Stack flow once per stack (§7)
```

> **Step 5 is only needed if you are developing or debugging Node.js apps (e.g. Gila) directly on the server.** Skip it for a pure inference/mining box.

> **Prepare env vars before deploying.** Each stack needs its own env vars set in Portainer before clicking Deploy. See [`docs/ENV_VARS_REFERENCE.md`](docs/ENV_VARS_REFERENCE.md) for the full table.

---

## 5) Node.js (Optional — Dev Only)

Only needed if you are developing or debugging Node.js applications directly on the server. Run as the **dev user** (not root) — fnm installs to the user's home directory with no system-level changes.

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/buckyinsfo/homelab-ai-stack/main/scripts/install-node.sh)
```

After the script completes, reload your shell:

```bash
source ~/.bashrc
```

Verify:

```bash
node --version
npm --version
```

By default Node 22 is installed. To install a different version:

```bash
NODE_VERSION=20 bash <(curl -fsSL ...)
```

To install project dependencies after cloning:

```bash
cd ~/development/gila/client && npm install
cd ~/development/gila/server && npm install
```

---

## 1) Base OS Prep

Install Debian 12 using the **non-free firmware** ISO to ensure Wi-Fi and GPU hardware are detected. During install, select "SSH server" and "standard system utilities" — no desktop environment needed.

After first boot:

```bash
sudo apt update && sudo apt upgrade -y
sudo reboot
```

After reboot, verify the kernel:

```bash
uname -r
```

Install essential tools:

```bash
sudo apt install -y curl wget git sudo apt-transport-https ca-certificates gnupg lsb-release
```

---

## 2) Install NVIDIA Driver

Run the install script directly from GitHub. It handles everything: kernel headers, non-free repo enablement, Nouveau blacklisting, the NVIDIA driver, the full CUDA toolkit, and CUDA environment variables.

```bash
curl -fsSL https://raw.githubusercontent.com/buckyinsfo/homelab-ai-stack/main/scripts/install-nvidia-drivers.sh \
  -o /tmp/install-nvidia-drivers.sh
chmod +x /tmp/install-nvidia-drivers.sh
sudo /tmp/install-nvidia-drivers.sh
```

The script will prompt to reboot at the end. After rebooting, verify:

```bash
nvidia-smi
nvcc --version
```

---

## 3) Install Docker, NVIDIA Container Toolkit, and Portainer

Run the install script directly from GitHub as root. It handles everything: Docker CE, the NVIDIA Container Toolkit, GPU passthrough verification, and Portainer CE.

```bash
curl -fsSL https://raw.githubusercontent.com/buckyinsfo/homelab-ai-stack/main/scripts/install-docker-portainer.sh \
  -o /tmp/install-docker-portainer.sh
chmod +x /tmp/install-docker-portainer.sh
sudo /tmp/install-docker-portainer.sh
```

After the script completes, log out and back in (or run `newgrp docker`) for the docker group to take effect, then open Portainer at `https://<hostname>:9443`.

---

## 4) Bootstrap Host Filesystem

Run this once to create required host paths (`/srv/openclaw/*`, `/srv/certs`, `/srv/traefik`, `/srv/backups/volumes`), set OpenClaw ownership, generate self-signed certs, and write Traefik `dynamic.yml`.

```bash
curl -fsSL https://raw.githubusercontent.com/buckyinsfo/homelab-ai-stack/main/scripts/bootstrap-server.sh \
  -o /tmp/bootstrap-server.sh
chmod +x /tmp/bootstrap-server.sh
sudo DOMAIN=<domain> CERT_BASENAME=<domain> /tmp/bootstrap-server.sh
```

#### Bootstrap flags reference

| Variable | Default | Description |
|---|---|---|
| `DOMAIN` | `<your-hostname>` | Server hostname or local domain |
| `CERT_BASENAME` | `$DOMAIN` | Filename prefix for cert/key (e.g. `<domain>.crt`) |
| `CERT_DAYS` | `3650` | Certificate validity in days (~10 years) |
| `OPENCLAW_UID` | `1000` | UID for OpenClaw bind-mount ownership |
| `OPENCLAW_GID` | `1000` | GID for OpenClaw bind-mount ownership |
| `FORCE_CERTS` | `0` | Set to `1` to regenerate cert/key even if they exist |
| `FORCE_DYNAMIC` | `0` | Set to `1` to overwrite `/srv/traefik/dynamic.yml` |
| `SANDBOX_ROOT` | `/srv/sandbox` | Root path for the sandbox bind-mount (left empty — OpenClaw populates on first boot) |

---

## 6) GPU Tuning (Host-Level)

Handled automatically by `install-nvidia-drivers.sh` — it creates and enables a `gpu-tune.service` systemd unit that applies persistence mode and a 140W power limit on every boot.

To verify after rebooting:

```bash
systemctl status gpu-tune.service
nvidia-smi  # confirm Power Limit shows 140W
```

To adjust the power limit for a different GPU:

```bash
sudo nvidia-smi -pl <watts>
sudo sed -i 's/-pl 140/-pl <watts>/' /etc/systemd/system/gpu-tune.service
sudo systemctl daemon-reload
```

---

## 7) Deploy Stacks via Portainer GitOps

Each stack in this repo is deployed individually through Portainer. You'll repeat the same flow once per stack, in order. The repo is public so no authentication is needed.

### How to add a stack in Portainer

For **each** stack, go to **Stacks → Add stack** and fill in:

| Field | Value |
|---|---|
| Name | The stack name (e.g. `infra`, `postgres`, etc.) |
| Build method | **Repository** |
| Repository URL | `https://github.com/buckyinsfo/homelab-ai-stack.git` |
| Repository reference | `refs/heads/main` |
| Compose path | The path from the table below (e.g. `stacks/infra/compose.yml`) |
| Authentication | OFF (repo is public) |
| GitOps updates | ON — enables **Pull and redeploy** when you push changes |

Before clicking **Deploy**, scroll down to the **Environment variables** section and add the required vars for that stack. See [`docs/ENV_VARS_REFERENCE.md`](docs/ENV_VARS_REFERENCE.md) for a full table and copy-paste cheatsheet. **Never commit real `.env` files** — Portainer env vars are the secrets store.

### Deploy in this order

| # | Stack | Compose path | Notes |
|---|---|---|---|
| 1 | **infra** | `stacks/infra/compose.yml` | Must be first — creates the shared `proxy` network |
| 2 | **postgres** | `stacks/postgres/compose.yml` | |
| 3 | **redis** | `stacks/redis/compose.yml` | |
| 4 | **qdrant** | `stacks/qdrant/compose.yml` | |
| 5 | **monitoring** | `stacks/monitoring/compose.yml` | See post-deploy steps in §7 |
| 6 | **ollama** | `stacks/ollama/compose.yml` | Pull models after deploy |
| 7 | **openclaw** | `stacks/openclaw/compose.yml` | See post-deploy steps in §7 |
| 8 | **openwebui** | `stacks/openwebui/compose.yml` | |
| 9 | **adminer** *(optional)* | `stacks/adminer/compose.yml` | |
| 10 | **nextcloud** *(optional)* | `stacks/nextcloud/compose.yml` | Create `nextcloud` DB in Postgres first |
| 11 | **quai-miner** *(optional)* | `stacks/quai-miner/compose.yml` | Deploy paused — start manually |
| 12 | **openclaw-sandbox** *(optional)* | `stacks/openclaw-sandbox/compose.yml` | Standalone — no shared state with openclaw |

> **infra must be deployed first.** Every other stack joins the `proxy` network that infra creates. Deploying any other stack before infra will fail.

---

## 8) Post-Deploy Steps per Stack

Most stacks are fully self-configuring once deployed. A few require post-deploy steps on the server or in the browser. Those are documented below — stacks with no entry here need nothing beyond deploying in Portainer.

### infra (Traefik)

Creates the shared `proxy` network that all other stacks join. Routes traffic by hostname so you get clean URLs instead of port numbers. No post-deploy steps — certs and `dynamic.yml` are created by `bootstrap-server.sh` in step 4.

Once deployed, all services are available at:

| Service | URL |
|---|---|
| Traefik dashboard | `https://traefik.<domain>` |
| Grafana | `https://grafana.<domain>` |
| Prometheus | `https://prometheus.<domain>` |
| Ollama API | `https://ollama.<domain>` |
| OpenClaw | `https://openclaw.<domain>` |
| OpenClaw Sandbox | `https://sandbox.<domain>` |
| Open WebUI | `https://ai.<domain>` |
| Adminer | `https://adminer.<domain>` |
| Nextcloud | `https://cloud.<domain>` |
| ONLYOFFICE | `https://office.<domain>` |

> For `.local` hostnames to resolve on your LAN, see [Local DNS Setup](#local-dns-setup) below.

### postgres

PostgreSQL 16 on the `proxy` network. Other stacks reach it at `postgres:5432`. Set `POSTGRES_USER`, `POSTGRES_PASSWORD`, and `POSTGRES_DB` in Portainer environment variables.

### redis

Redis 7 with AOF persistence, capped at 256 MB. Other stacks reach it at `redis:6379`.

### qdrant

Vector database for storing embeddings and enabling semantic search (RAG). Ollama generates embeddings locally, Qdrant stores and indexes them, and OpenClaw queries them for context-aware responses.

The REST API is available at `qdrant:6333` on the `proxy` network. The gRPC API is on port `6334`.

After deploying, verify:

```bash
curl http://<hostname>:6333/healthz
```

### monitoring

Full observability stack. Grafana auto-provisions Prometheus as a datasource on first boot — no manual datasource setup needed.

After deploying, import community dashboards and apply a one-time variable fix. See [`docs/MONITORING_SETUP.md`](docs/MONITORING_SETUP.md) for the full walkthrough.

### ollama

Local LLM inference with full GPU access. After deploying, pull a model:

```bash
docker exec -it ollama ollama pull llama3.2
```

The Ollama API is available to other containers on the `proxy` network at `http://ollama:11434`.

### openclaw

Self-hosted AI assistant. Connects to Ollama for local models and to Anthropic/OpenAI/OpenRouter for cloud models. This stack builds a custom image from `images/openclaw/Dockerfile` so required skill runtime binaries (`bun` and `qmd`) are preinstalled at image build time.

#### Before deploying — generate a gateway token

Generate a token and add it as `OPENCLAW_GATEWAY_TOKEN` in Portainer before clicking Deploy:

```bash
openssl rand -hex 32
```

Set your env vars in Portainer before deploying. Only `ANTHROPIC_API_KEY` is required to get started — add others as needed for the integrations you want:

| Variable | Purpose |
|---|---|
| `ANTHROPIC_API_KEY` | Primary model provider (required) |
| `OPENAI_API_KEY` | OpenAI model access |
| `GEMINI_API_KEY` | Google Gemini model access |
| `TELEGRAM_BOT_TOKEN` | Telegram channel integration |
| `DISCORD_BOT_TOKEN` | Discord channel integration |
| `TRELLO_API_KEY` / `TRELLO_TOKEN` | Trello tool access |
| `GH_TOKEN` + `GITHUB_USERNAME` | GitHub tool access |

#### Post-deploy setup (run once after first deploy)

The container will already be running. Run these steps on `<hostname>`:

```bash
# 1. Run onboard to configure auth and bind the gateway token as an env ref
docker exec openclaw \
  node dist/index.js onboard --non-interactive \
  --accept-risk \
  --mode local \
  --auth-choice anthropic-api-key \
  --secret-input-mode ref \
  --gateway-auth token \
  --gateway-token-ref-env OPENCLAW_GATEWAY_TOKEN \
  --gateway-bind lan

# 2. Start the container back up (onboard stops the gateway)
docker start openclaw

# 3. Set allowedOrigins for your domain
docker exec openclaw \
  node dist/index.js config set gateway.controlUi.allowedOrigins '["https://openclaw.<domain>"]'

# 4. Restart to apply
docker restart openclaw
```

#### First login

Navigate to:

```
https://openclaw.<domain>
```

If the UI shows `pairing required`, approve the device on `<hostname>`:

```bash
docker exec -it openclaw openclaw devices list
docker exec -it openclaw openclaw devices approve <REQUEST_ID>
```

Refresh and the dashboard will connect.

For next steps — routing heartbeats to a local model, setting up agent identity, and configuring the heartbeat routine — see [`docs/OPENCLAW_AGENT_SETUP.md`](docs/OPENCLAW_AGENT_SETUP.md).

#### Periodic maintenance — rotate gateway token

The gateway auth token is stored in Portainer as `OPENCLAW_GATEWAY_TOKEN` and read at runtime via env ref — no secret is written to disk or config files.

To rotate:

1. Generate a new token: `openssl rand -hex 32`
2. In Portainer, open the **openclaw** stack → **Environment variables** → update `OPENCLAW_GATEWAY_TOKEN`.
3. Click **Update the stack** to redeploy with the new token.
4. Navigate to `https://openclaw.<domain>` and re-pair your device.

### openwebui

Browser-based chat UI for Ollama. Provides a clean, ChatGPT-style interface for running models locally. Connects to Ollama at `http://ollama:11434` (hardcoded in compose — no env var needed beyond `DOMAIN`).

After deploying, open `https://ai.<DOMAIN>` and create an admin account on the first-run screen.

### adminer *(optional)*

Lightweight web-based database admin UI. Works with PostgreSQL, MySQL, SQLite, and others — same concept as Mongo Express but for SQL databases. Pre-configured to connect to the `postgres` container.

Access at `https://adminer.<DOMAIN>`. The Traefik basic-auth middleware requires an `ADMINER_BASICAUTH_USERS` env var in Portainer.

To generate the password hash:

```bash
# Install apache utils if needed
sudo apt install -y apache2-utils

# Generate hash (you'll be prompted for a password)
htpasswd -nb admin yourpassword
# Output example: admin:$apr1$xyz...
```

When entering in Portainer, escape every `$` as `$$`.

> **Security note:** Adminer exposes full database access. Keep this behind the Traefik basic-auth middleware and never expose port 8080 directly.

### nextcloud *(optional)*

Self-hosted file sync, storage, and browser-based document editing. Includes ONLYOFFICE document server in the same compose stack. Uses the shared Postgres and Redis instances, and routes through Traefik at `https://cloud.<DOMAIN>` and `https://office.<DOMAIN>`.

Before deploying, create the Nextcloud database (host directories are created by `bootstrap-server.sh`):

```bash
docker exec -it postgres psql -U <POSTGRES_USER> -c "CREATE DATABASE nextcloud;"
```

Then deploy the stack in Portainer. On first boot, Nextcloud runs its installer using the env vars you set — no browser-based setup wizard needed.

After deploying, open `https://cloud.<DOMAIN>` and log in with `NEXTCLOUD_ADMIN_USER` / `NEXTCLOUD_ADMIN_PASSWORD`.

To connect ONLYOFFICE, follow the steps in [`docs/ONLYOFFICE_SETUP.md`](docs/ONLYOFFICE_SETUP.md).

> **Cron jobs:** Nextcloud background jobs default to AJAX mode (runs on page load). For a proper setup, switch to Cron mode in Settings → Basic Settings → Background jobs, then add a host-level cron entry:
> ```bash
> # /etc/cron.d/nextcloud
> */5 * * * * root docker exec -u www-data nextcloud php -f /var/www/html/cron.php
> ```

### openclaw-sandbox *(optional)*

An isolated OpenClaw instance for experimenting with config, models, and tools without affecting the production `openclaw` stack. Uses Anthropic, OpenAI, and Ollama (shared with the production stack) — no channel integrations. Config, workspace, logs, and memory are fully isolated at `/srv/sandbox`, separate from `/srv/openclaw`.

#### Before deploying — generate a gateway token

Generate a token and add it as `OPENCLAW_GATEWAY_TOKEN` in Portainer before clicking Deploy. Use a different value than the production `openclaw` stack:

```bash
openssl rand -hex 32
```

Deploy in Portainer and start the container.

#### Post-deploy setup (run once after first deploy)

The container will already be running. Run these steps on `<hostname>`:

```bash
# 1. Run onboard to configure auth and bind the gateway token as an env ref
docker exec openclaw-sandbox \
  node dist/index.js onboard --non-interactive \
  --accept-risk \
  --mode local \
  --auth-choice anthropic-api-key \
  --secret-input-mode ref \
  --gateway-auth token \
  --gateway-token-ref-env OPENCLAW_GATEWAY_TOKEN \
  --gateway-bind lan

# 2. Start the container back up (onboard stops the gateway)
docker start openclaw-sandbox

# 3. Set allowedOrigins for your domain
docker exec openclaw-sandbox \
  node dist/index.js config set gateway.controlUi.allowedOrigins '["https://sandbox.<domain>"]'

# 4. Set heartbeat model to use local Ollama (saves API costs)
docker exec openclaw-sandbox \
  node dist/index.js config set agents.defaults.heartbeat '{"every":"30m","model":"ollama/mistral:7b-instruct"}'

# 5. Restart to apply
docker restart openclaw-sandbox
```

#### First login

Navigate to:

```
https://sandbox.<domain>
```

If the UI shows `pairing required`, approve the device on `<hostname>`:

```bash
docker exec -it openclaw-sandbox openclaw devices list
docker exec -it openclaw-sandbox openclaw devices approve <REQUEST_ID>
```

Refresh and the dashboard will connect.

For next steps — heartbeat model, agent identity, and workspace files — see [`docs/OPENCLAW_AGENT_SETUP.md`](docs/OPENCLAW_AGENT_SETUP.md).

> **Note:** `bootstrap-server.sh` creates `/srv/sandbox` and sets ownership automatically. No manual directory creation needed.

---

### quai-miner *(optional)*

Rigel GPU miner for Quai (KawPow). Set `ALGO`, `POOL`, `WALLET`, and `WORKER` in Portainer environment variables. See `stacks/quai-miner/.env.example` for defaults.

New to Quai? See [`docs/QUAI_WALLET_SETUP.md`](docs/QUAI_WALLET_SETUP.md) for a step-by-step guide to creating a Pelagus wallet and getting your mining address.

> ⚠️ **Deploy paused.** This stack competes with Ollama for VRAM. Deploy via Portainer but leave it in a stopped state. Start manually during off-peak hours when AI inference isn't needed.

```bash
docker logs rigel --tail 100
```

---

## 9) Secrets Strategy

**Never commit `.env` files.** Set environment variables directly in Portainer's stack editor.

Each stack includes a `.env.example` showing which variables are required.

---

## 10) GPU Sharing Note

The RTX 3070 has 8 GB VRAM. Running Ollama and the Quai miner simultaneously will compete for GPU memory. Options:

- **Time-share:** Stop the miner when using Ollama, and vice versa.
- **VRAM budget:** Use a small model in Ollama (e.g., `llama3.2:1b`) alongside mining.
- **Upgrade:** A second GPU solves the problem entirely.

---

## 11) Backups

Backups are staged at `/srv/backups/` (created by `bootstrap-server.sh`). The backup script handles both Docker named volumes and `/srv` bind mounts in one shot:

```bash
sudo bash scripts/backup.sh
```

Each run creates a timestamped directory under `/srv/backups/`. For full backup and restore procedures, automation, and restore order after a bare metal rebuild, see [`docs/BACKUP_RESTORE.md`](docs/BACKUP_RESTORE.md).

---

## Local DNS Setup

Traefik routes traffic by hostname (e.g. `traefik.<domain>`, `grafana.<domain>`). For these to resolve on your LAN, every client machine that needs access must know the server's IP for those hostnames. You have two options:

### Option A — /etc/hosts (single machine)

Add one line per service to `/etc/hosts` on each client machine. On macOS/Linux:

```bash
sudo tee -a /etc/hosts <<EOF
<server-ip>  traefik.<domain>
<server-ip>  grafana.<domain>
<server-ip>  prometheus.<domain>
<server-ip>  ollama.<domain>
<server-ip>  openclaw.<domain>
<server-ip>  sandbox.<domain>
<server-ip>  ai.<domain>
<server-ip>  adminer.<domain>
<server-ip>  cloud.<domain>
<server-ip>  qdrant.<domain>
EOF
```

Replace `<server-ip>` with your server's LAN IP and `<domain>` with your chosen domain (e.g. `myserver.local`).

On Windows, edit `C:\Windows\System32\drivers\etc\hosts` as Administrator with the same entries.

### Option B — Router DNS (whole network)

If your router supports custom DNS entries (most do under "Local DNS", "DNS Rewrites", or "Custom Hostnames"), add a wildcard or individual entries pointing `*.<domain>` (or each subdomain) to your server's IP. This means every device on your network resolves the hostnames automatically with no per-machine config.

Common router admin interfaces that support this:
- **pfSense / OPNsense** — DNS Resolver → Host Overrides, or use a wildcard entry
- **OpenWrt** — Network → DHCP and DNS → Hostnames
- **Unifi** — Network → DNS → Local DNS Records
- **Pi-hole** — Local DNS → DNS Records (add one entry per subdomain)

A single wildcard A record for `*.<domain>` pointing to `<server-ip>` is the cleanest solution — any new stack you deploy is instantly resolvable without adding new entries.

---

## Troubleshooting

- **Portainer can't pull the repo** — check your PAT is valid and has `repo` scope.
- **`docker run --gpus all` fails** — re-run `nvidia-ctk runtime configure` and restart Docker.
- **dcgm-exporter crashes** — needs `SYS_ADMIN` capability and matching driver/DCGM versions.
- **Ollama OOM** — pull a smaller model or stop the miner first.
- **Traefik routes not working** — make sure the service has `traefik.enable: "true"` label and is on the `proxy` network.
- **Mining performance drops** — verify `nvidia-smi` power limit is still applied and persistence mode is on.

---

## Repo Layout

```
stacks/
  infra/compose.yml              # Traefik reverse proxy
  postgres/compose.yml           # PostgreSQL 16
  redis/compose.yml              # Redis 7
  qdrant/compose.yml             # Vector database (RAG)
  monitoring/
    compose.yml                  # Prometheus + Grafana + exporters (configs embedded inline)
  ollama/compose.yml             # Local LLM inference
  openclaw/compose.yml           # AI assistant
  openclaw-sandbox/compose.yml   # Isolated OpenClaw for config experimentation (optional)
  openwebui/compose.yml          # Browser chat UI for Ollama
  adminer/compose.yml            # Web DB admin (Postgres + others)
  nextcloud/compose.yml          # Self-hosted file sync (optional)
  quai-miner/compose.yml         # GPU miner
images/
  openclaw/Dockerfile            # Custom OpenClaw image (bun + qmd preinstalled)
  rigel/Dockerfile               # Custom Rigel miner image
scripts/
  bootstrap-server.sh            # Create /srv paths, certs, and Traefik dynamic.yml
  backup.sh                      # Back up Docker volumes and /srv bind mounts to /srv/backups/
  install-nvidia-drivers.sh      # NVIDIA driver install + GPU tuning
  install-docker-portainer.sh    # Docker CE + NVIDIA Container Toolkit + Portainer
  install-node.sh                # Node.js via fnm (optional, dev-only)
docs/
  ENV_VARS_REFERENCE.md          # Environment variables per stack
  MONITORING_SETUP.md            # Grafana dashboard import + variable fix walkthrough
  QUAI_WALLET_SETUP.md           # Pelagus wallet + mining address guide
  OPENCLAW_AGENT_SETUP.md        # Post-onboard agent setup (heartbeats, identity, workspace files)
  BACKUP_RESTORE.md              # Backup and restore procedures for all stacks
```
