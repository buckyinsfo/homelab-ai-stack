# AI Server CacheHive

Self-hosted AI + GPU mining server on Rocky Linux — fully reproducible from bare metal using **Portainer GitOps**.

This repo is the single source of truth. Every stack is a Docker Compose file deployed directly from GitHub. Rebuilding from scratch takes roughly 20–30 minutes (most of that is image pulls and the custom image builds).

> **NVIDIA GPU?** This is the AMD ROCm branch. See [`main`](https://github.com/buckyinsfo/AI_server_cachehive/tree/main) for the NVIDIA CUDA version.

> **AMD Radeon GPU?** See the [`amd-rocm`](https://github.com/buckyinsfo/AI_server_cachehive/tree/amd-rocm) branch for an equivalent setup using ROCm instead of NVIDIA CUDA.

---

## Before You Begin — Placeholders

Two placeholders are used throughout this document. **Do a find-and-replace in your notes or editor before following the steps.**

| Placeholder | What to replace it with | Example |
|---|---|---|
| `<hostname>` | Your server's hostname — used for direct SSH/port access | `camp-fai` |
| `<domain>` | Your Traefik routing domain — used in DNS, URLs, and certs | `myserver.local` |

These can be the same value if you're routing by hostname rather than a separate local domain.

---

## Stack Overview

| Stack | Purpose | Compose Path | Optional |
|---|---|---|---|
| **infra** | Traefik reverse proxy + shared `proxy` network | `stacks/infra/compose.yml` | No |
| **postgres** | PostgreSQL 16 database | `stacks/postgres/compose.yml` | No |
| **redis** | Redis 7 cache / message broker | `stacks/redis/compose.yml` | No |
| **qdrant** | Vector database for RAG / semantic search | `stacks/qdrant/compose.yml` | No |
| **monitoring** | Prometheus + Grafana + AMD device-metrics-exporter + node-exporter + cAdvisor | `stacks/monitoring/compose.yml` | No |
| **ollama** | Local LLM inference on GPU | `stacks/ollama/compose.yml` | No |
| **openclaw** | Self-hosted AI assistant (Ollama + Anthropic + OpenAI) | `stacks/openclaw/compose.yml` | No |
| **openwebui** | Browser chat UI for Ollama | `stacks/openwebui/compose.yml` | No |
| **adminer** | Web-based Postgres (and multi-DB) admin UI | `stacks/adminer/compose.yml` | No |
| **quai-miner** | Rigel GPU miner (Quai / KawPow) | `stacks/quai-miner/compose.yml` | Yes |

---

## Install Order at a Glance

```
1.  Rocky Linux OS install
2.  NVIDIA driver
3.  Docker
4.  NVIDIA Container Toolkit
5.  GPU tuning (power limit, persistence)
6.  Portainer
7.  Run bootstrap-server.sh  ← creates /srv paths, certs, Traefik config
8.  Add repo to Portainer GitOps
9.  Deploy stacks in order:
      infra → postgres → redis → qdrant → monitoring → ollama
      → openclaw → openwebui → adminer → quai-miner (paused)
```

> **Prepare env vars before you start deploying.** See [`ENV_VARS_REFERENCE.md`](ENV_VARS_REFERENCE.md) for a table of every variable per stack and a copy-paste cheatsheet.

---

## Deploy Order Details

### Host filesystem bootstrap (before Portainer stack deploys)

Run this once on `<hostname>` to create required host paths (`/srv/openclaw/*`, `/srv/certs`, `/srv/traefik`, `/srv/backups/volumes`), set OpenClaw ownership, generate self-signed certs, and write Traefik `dynamic.yml`.

**On a clean server (no local clone yet) — pull and run directly from GitHub:**

```bash
curl -fsSL https://raw.githubusercontent.com/buckyinsfo/AI_server_cachehive/main/scripts/bootstrap-server.sh \
  -o /tmp/bootstrap-server.sh
chmod +x /tmp/bootstrap-server.sh
sudo DOMAIN=<domain> CERT_BASENAME=<domain> /tmp/bootstrap-server.sh
```

**If you've already cloned the repo on the server:**

```bash
sudo DOMAIN=<domain> CERT_BASENAME=<domain> \
  /path/to/AI_server_cachehive/scripts/bootstrap-server.sh
```

#### Preinstalling OpenClaw skills at bootstrap time

Skills must be present on the host *before* the OpenClaw container starts for the first time. The `OPENCLAW_SKILLS` variable clones skills into `/srv/openclaw/config/skills/` — the same directory that gets bind-mounted into the container as `~/.openclaw/skills/`. Skills listed here are skipped if already installed.

```bash
sudo DOMAIN=<domain> CERT_BASENAME=<domain> \
  OPENCLAW_SKILLS="levineam/qmd-skill" \
  /tmp/bootstrap-server.sh
```

`OPENCLAW_SKILLS` accepts a comma-separated list of `owner/repo` GitHub paths:

```bash
OPENCLAW_SKILLS="owner/repo-a,owner/repo-b"
```

If you forgot to preinstall skills and the container is already running, clone them manually and restart:

```bash
sudo git clone --depth 1 https://github.com/owner/repo-name.git \
  /srv/openclaw/config/skills/owner__repo-name
sudo chown -R 1000:1000 /srv/openclaw/config/skills
docker restart openclaw
```

#### Bootstrap flags reference

| Variable | Default | Description |
|---|---|---|
| `DOMAIN` | `<your-hostname>` | Server hostname or local domain |
| `CERT_BASENAME` | `$DOMAIN` | Filename prefix for cert/key (e.g. `<domain>.crt`) |
| `CERT_DAYS` | `3650` | Certificate validity in days (~10 years) |
| `OPENCLAW_UID` | `1000` | UID for OpenClaw bind-mount ownership |
| `OPENCLAW_GID` | `1000` | GID for OpenClaw bind-mount ownership |
| `WORKSPACE_SUBDIR` | `development` | Subfolder under `/srv/openclaw/workspace/` |
| `OPENCLAW_SKILLS` | *(empty)* | Comma-separated `owner/repo` skills to preinstall |
| `FORCE_CERTS` | `0` | Set to `1` to regenerate cert/key even if they exist |
| `FORCE_DYNAMIC` | `0` | Set to `1` to overwrite `/srv/traefik/dynamic.yml` |

### Deploy stacks in Portainer (this order)

```
infra → postgres → redis → qdrant → monitoring → ollama → openclaw → openwebui → adminer → quai-miner
```

> Deploy `quai-miner` paused — activate manually during off-peak hours when AI inference isn't needed.

---

## 1) Base OS Prep

```bash
sudo dnf upgrade -y
sudo reboot
```

After reboot, verify the kernel:

```bash
uname -r
```

---

## 2) Install AMD ROCm Driver

### 2.1 Install amdgpu-install

```bash
sudo dnf install -y https://repo.radeon.com/amdgpu-install/6.3.1/el/9.4/amdgpu-install-6.3.1.60301-1.el9.noarch.rpm
sudo dnf clean expire-cache
```

### 2.2 Install ROCm

```bash
sudo amdgpu-install -y --usecase=rocm
sudo reboot
```

### 2.3 Add your user to the required groups

```bash
sudo usermod -aG render,video $USER
newgrp render
```

### 2.4 Verify

```bash
rocm-smi
```

---

## 3) Install Docker

```bash
sudo dnf -y install dnf-plugins-core
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

sudo dnf -y install docker-ce docker-ce-cli containerd.io
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
newgrp docker
```

Verify:

```bash
docker version
docker run --rm hello-world
```

---

## 4) Verify AMD GPU Docker Passthrough

AMD does not require a container toolkit. GPU access is handled via device mounts (`/dev/kfd` and `/dev/dri`) directly in each compose file. Verify the devices exist on your host:

```bash
ls /dev/kfd /dev/dri
```

Test GPU passthrough in Docker:

```bash
docker run --rm \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add video \
  --group-add render \
  rocm/rocm-terminal \
  rocm-smi
```

---

## 5) GPU Tuning (Host-Level)

### 5.1 Set power limit

Check current power usage and limits:

```bash
rocm-smi --showpower
```

Set a power cap (replace `<WATTS>` with your target, e.g. `150`):

```bash
sudo rocm-smi --setpoweroverdrive <WATTS>
```

### 5.2 Make it survive reboots

```bash
sudo tee /etc/systemd/system/gpu-tune.service >/dev/null <<'EOF'
[Unit]
Description=GPU tune (power limit)
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/bin/rocm-smi --setpoweroverdrive <WATTS>
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now gpu-tune.service
```

---

## 6) Install Portainer

```bash
docker volume create portainer_data
docker run -d \
  --name portainer \
  --restart=unless-stopped \
  -p 9000:9000 \
  -p 9443:9443 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:latest
```

Open the Portainer UI at `https://<hostname>:9443`.

---

## 7) Add This Repo to Portainer (GitOps)

Use a GitHub Personal Access Token (PAT) as the password.

In Portainer: **Stacks → Add stack → Repository**

- **Repo URL:** `https://github.com/buckyinsfo/AI_server_cachehive.git`
- **Reference:** `refs/heads/main`
- **Auth:** ON
- **Username:** `buckyinsfo`
- **Password:** `<GITHUB_PAT>`

Then deploy each stack using the compose paths from the table above. Set environment variables in Portainer for each stack — never commit real `.env` files.

---

## 8) Stack Details

### infra (Traefik)

Creates the shared `proxy` network that all other stacks join. Routes traffic by hostname so you get clean URLs instead of port numbers.

| Service | URL |
|---|---|
| Traefik dashboard | `https://traefik.<domain>` |
| Grafana | `https://grafana.<domain>` |
| Prometheus | `https://prometheus.<domain>` |
| Ollama API | `https://ollama.<domain>` |
| OpenClaw | `https://openclaw.<domain>` |
| Open WebUI | `https://ai.<domain>` |
| Adminer | `https://adminer.<domain>` |

> **Note:** For the `.local` hostnames to work on your LAN, add entries to your DNS server or `/etc/hosts` on client machines pointing to the server's IP.

#### Traefik default TLS certificate (host file)

The `infra` stack mounts a host file at `/srv/traefik/dynamic.yml` and loads it with:

```yaml
--providers.file.filename=/etc/traefik/dynamic.yml
```

Versioned template: `stacks/infra/dynamic.example.yml`

Recommended: use `scripts/bootstrap-server.sh` to create certs + `dynamic.yml` automatically.

Create a self-signed cert on the server:

```bash
sudo mkdir -p /srv/certs
sudo openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
  -keyout /srv/certs/<domain>.key \
  -out /srv/certs/<domain>.crt \
  -subj "/CN=<domain>" \
  -addext "subjectAltName=DNS:<domain>,DNS:*.<domain>"
```

Then create the dynamic Traefik TLS config:

```bash
sudo mkdir -p /srv/traefik
sudo tee /srv/traefik/dynamic.yml > /dev/null <<'EOF'
tls:
  stores:
    default:
      defaultCertificate:
        certFile: /etc/certs/<domain>.crt
        keyFile: /etc/certs/<domain>.key
EOF
```

Replace `<domain>` with your chosen routing domain. This must match the `DOMAIN` and `CERT_BASENAME` values you used with `bootstrap-server.sh`.

Then redeploy the `infra` stack in Portainer (or restart Traefik) to apply changes.

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

Full observability stack. Grafana auto-provisions Prometheus as a data source on first boot.

After deploying, import the AMD GPU dashboard in Grafana:
1. Go to **Dashboards → Import**
2. Download the dashboard JSON from the [ROCm device-metrics-exporter repo](https://github.com/ROCm/device-metrics-exporter/tree/main/grafana)
3. Upload the JSON and select the Prometheus data source

For host metrics, import Node Exporter Full (dashboard ID **1860**).

### ollama

Local LLM inference with full GPU access. After deploying, pull a model:

```bash
docker exec -it ollama ollama pull llama3.2
```

The Ollama API is available to other containers on the `proxy` network at `http://ollama:11434`.

### openclaw

Self-hosted AI assistant. Connects to Ollama for local models and to Anthropic/OpenAI/OpenRouter for cloud models. Set `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `OPENROUTER_API_KEY`, and `EXA_API_KEY` in Portainer environment variables.

This stack builds a custom image from `images/openclaw/Dockerfile` so required skill runtime binaries (`bun` and `qmd`) are preinstalled at image build time.

After first deploy, run the setup wizard:

```bash
docker exec -it openclaw node dist/index.js setup
```

If you want Exa web search available in OpenClaw skills, configure `EXA_API_KEY` and install an Exa skill (for example via `OPENCLAW_SKILLS="owner/repo"` in `scripts/bootstrap-server.sh`).

OpenRouter API smoke test (from `<hostname>`):

```bash
export OPENROUTER_API_KEY='sk-or-v1-REPLACE_ME'
curl -sS https://openrouter.ai/api/v1/models \
  -H "Authorization: Bearer ${OPENROUTER_API_KEY}" \
  -H "Content-Type: application/json"
```

Expected: JSON response containing a `data` array of available models.

Exa API smoke test (from `<hostname>`):

```bash
export EXA_API_KEY='exa-REPLACE_ME'
curl -sS https://api.exa.ai/search \
  -H "x-api-key: ${EXA_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"query":"latest nvidia driver rocky linux","numResults":1}'
```

Expected: JSON response with `results` and non-zero `searchTime`.

#### Rotate OpenClaw auth token (host-side secret)

OpenClaw auth token is stored on the host at `/srv/openclaw/config/openclaw.json` and is **not** managed by GitOps.

On `<hostname>`:

```bash
# 1) Backup current config
sudo cp /srv/openclaw/config/openclaw.json /srv/openclaw/config/openclaw.json.bak.$(date +%F-%H%M%S)

# 2) Generate and set a new token
NEW_TOKEN=$(openssl rand -hex 32)
sudo sed -E -i 's#("token"[[:space:]]*:[[:space:]]*")[^"]+(")#\1'"$NEW_TOKEN"'\2#' /srv/openclaw/config/openclaw.json

# 3) Restart OpenClaw
docker restart openclaw

# 4) Verify host + container read the same token
sudo grep -nE '"auth"|"token"' /srv/openclaw/config/openclaw.json
docker exec openclaw sh -lc "grep -nE '\"auth\"|\"token\"' /home/node/.openclaw/openclaw.json"
```

Usability check (from any browser on LAN):

1. Open a private window with:
   - `https://openclaw.<domain>/?gatewayUrl=wss://openclaw.<domain>&token=<NEW_TOKEN>`
2. If UI shows `pairing required`, approve the pending device on `<hostname>`:

```bash
docker exec -it openclaw openclaw devices list
docker exec -it openclaw openclaw devices approve <REQUEST_ID>
```

3. Refresh the browser and confirm dashboard connects and chat session loads.
4. Remove tokenized URLs from browser history after successful login.

If the UI shows lockout (`too many failed authentication attempts`), wait 2-3 minutes or restart `openclaw` and retry once.

To verify loaded skills from inside the container:

```bash
docker exec -it openclaw openclaw skills list
```

### openwebui

Browser-based chat UI for Ollama. Provides a clean, ChatGPT-style interface for running models locally. Connects to Ollama at `http://ollama:11434` (hardcoded in compose — no env var needed beyond `DOMAIN`).

After deploying, open `https://ai.<DOMAIN>` and create an admin account on the first-run screen.

### adminer

Lightweight web-based database admin UI. Works with PostgreSQL, MySQL, SQLite, and others — same concept as Mongo Express but for SQL databases. Pre-configured to connect to the `postgres` container.

Access at `https://adminer.<DOMAIN>`. The Traefik basic-auth middleware requires an `ADMINER_BASICAUTH_USERS` env var in Portainer.

To generate the password hash:

```bash
# Install apache utils if needed
sudo dnf install -y httpd-tools

# Generate hash (you'll be prompted for a password)
htpasswd -nb admin yourpassword
# Output example: admin:$apr1$xyz...
```

When entering in Portainer, escape every `$` as `$$`.

> **Security note:** Adminer exposes full database access. Keep this behind the Traefik basic-auth middleware and never expose port 8080 directly.

### quai-miner

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

Running Ollama and the Quai miner simultaneously will compete for GPU memory. Check your card's VRAM with `rocm-smi --showmeminfo vram`. Options:

- **Time-share:** Stop the miner when using Ollama, and vice versa.
- **VRAM budget:** Use a small model in Ollama (e.g., `llama3.2:1b`) alongside mining.
- **Upgrade:** A second GPU solves the problem entirely.

---

## 11) Backups

### One-liner volume backup

```bash
mkdir -p /srv/backups/volumes
docker run --rm \
  -v grafana-data:/v \
  -v /srv/backups/volumes:/b \
  alpine sh -c "cd /v && tar czf /b/grafana-data-$(date +%F).tgz ."
```

Key volumes to back up: `grafana-data`, `prometheus-data`, `postgres-data`, `qdrant-data`, `ollama-data`, `openclaw-config`, `portainer_data`.

### Automate

Run nightly via systemd timer or cron, and sync `/srv/backups` to NAS or cloud storage.

---

## Troubleshooting

- **Portainer can't pull the repo** — check your PAT is valid and has `repo` scope.
- **`/dev/kfd` not found** — verify ROCm is installed (`rocm-smi`) and your user is in the `render` and `video` groups.
- **device-metrics-exporter crashes** — ensure `/dev/kfd` and `/dev/dri` exist on the host and the container has `group_add: [video, render]`.
- **Ollama OOM** — pull a smaller model or stop the miner first.
- **Traefik routes not working** — make sure the service has `traefik.enable: "true"` label and is on the `proxy` network.
- **Mining performance drops** — verify `rocm-smi --showpower` and check power cap is still applied.

---

## Repo Layout

```
stacks/
  infra/compose.yml              # Traefik reverse proxy
  postgres/compose.yml           # PostgreSQL 16
  redis/compose.yml              # Redis 7
  qdrant/compose.yml             # Vector database (RAG)
  monitoring/
    compose.yml                  # Prometheus + Grafana + exporters
    prometheus.yml               # Scrape config
    grafana/provisioning/        # Auto-provision datasources
  ollama/compose.yml             # Local LLM inference
  openclaw/compose.yml           # AI assistant
  openwebui/compose.yml          # Browser chat UI for Ollama
  adminer/compose.yml            # Web DB admin (Postgres + others)
  quai-miner/compose.yml         # GPU miner
images/
  openclaw/Dockerfile            # Custom OpenClaw image (bun + qmd preinstalled)
  rigel/Dockerfile               # Custom Rigel miner image
scripts/
  bootstrap-server.sh            # Create /srv paths, certs, and Traefik dynamic.yml
```
