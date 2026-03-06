# AI Server CacheHive

Reproducible Rocky Linux GPU server — rebuild from bare metal in about 5 minutes.

This repo is the single source of truth for a self-hosted AI + mining server managed entirely through **Portainer GitOps**. Every stack is a Docker Compose file deployed from this repo.

---

## What's in the Box

| Stack | Purpose | Compose Path |
|---|---|---|
| **infra** | Traefik reverse proxy + shared `proxy` network | `stacks/infra/compose.yml` |
| **postgres** | PostgreSQL 16 database | `stacks/postgres/compose.yml` |
| **redis** | Redis 7 cache / message broker | `stacks/redis/compose.yml` |
| **qdrant** | Vector database for RAG / semantic search | `stacks/qdrant/compose.yml` |
| **monitoring** | Prometheus + Grafana + NVIDIA dcgm-exporter + node-exporter + cAdvisor | `stacks/monitoring/compose.yml` |
| **ollama** | Local LLM inference on GPU | `stacks/ollama/compose.yml` |
| **openclaw** | Self-hosted AI assistant (Ollama + Anthropic + OpenAI) | `stacks/openclaw/compose.yml` |
| **quai-miner** | Rigel GPU miner (Quai / KawPow) | `stacks/quai-miner/compose.yml` |

---

## Deploy Order for a Fresh Server

### Host setup (one-time)

```
1. Install Rocky Linux
2. Install NVIDIA driver
3. Install Docker
4. Install NVIDIA Container Toolkit
5. Install Portainer
```

### Host filesystem bootstrap (before Portainer stack deploys)

Run this once on `camp-fai` to create required host paths (`/srv/openclaw/*`, `/srv/certs`, `/srv/traefik`, `/srv/backups/volumes`), set OpenClaw ownership, generate self-signed certs, and write Traefik `dynamic.yml`.

```bash
sudo DOMAIN=camp-fai CERT_BASENAME=camp-fai \
  /path/to/AI_server_cachehive/scripts/bootstrap-server.sh
```

By default this also creates `/srv/openclaw/workspace/development` for git clones and dev work.

Option 2 (no local clone on server): pull bootstrap script directly from GitHub:

```bash
curl -fsSL https://raw.githubusercontent.com/buckyinsfo/AI_server_cachehive/main/scripts/bootstrap-server.sh -o /tmp/bootstrap-server.sh
chmod +x /tmp/bootstrap-server.sh
sudo DOMAIN=camp-fai CERT_BASENAME=camp-fai /tmp/bootstrap-server.sh
```

With OpenClaw skill preinstall:

```bash
sudo DOMAIN=camp-fai CERT_BASENAME=camp-fai \
  OPENCLAW_SKILLS="levineam/qmd-skill" \
  /path/to/AI_server_cachehive/scripts/bootstrap-server.sh
```

`OPENCLAW_SKILLS` expects comma-separated GitHub repos (`owner/repo`). The script clones each skill into `/srv/openclaw/config/skills/` (which maps to OpenClaw's `~/.openclaw/skills`) and skips ones already installed.

If your domain is `cachehive.local`:

```bash
sudo DOMAIN=cachehive.local CERT_BASENAME=cachehive.local \
  /path/to/AI_server_cachehive/scripts/bootstrap-server.sh
```

Optional flags:

- `FORCE_CERTS=1` regenerate cert/key even if they already exist.
- `FORCE_DYNAMIC=1` overwrite `/srv/traefik/dynamic.yml`.
- `OPENCLAW_SKILLS="owner/repo-a,owner/repo-b"` preinstall skills into `/srv/openclaw/config/skills` before deploy.
- `WORKSPACE_SUBDIR=development` choose workspace subfolder name under `/srv/openclaw/workspace/`.

### Deploy stacks in Portainer (this order)

```
infra
postgres
redis
qdrant
monitoring
ollama
openclaw
quai-miner
```

Takes about **5 minutes total** once the host is ready.

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

## 2) Install NVIDIA Driver

### 2.1 Add NVIDIA repo

```bash
sudo dnf -y install dnf-plugins-core
sudo dnf config-manager --add-repo \
  http://developer.download.nvidia.com/compute/cuda/repos/rhel10/$(uname -m)/cuda-rhel10.repo

sudo dnf clean expire-cache
```

### 2.2 Install driver

```bash
sudo dnf -y install nvidia-driver
sudo reboot
```

### 2.3 Verify

```bash
nvidia-smi
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

## 4) Install NVIDIA Container Toolkit

```bash
sudo dnf -y install curl
curl -s -L https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo | \
  sudo tee /etc/yum.repos.d/nvidia-container-toolkit.repo

sudo dnf -y install nvidia-container-toolkit
```

Configure the Docker runtime:

```bash
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

Verify GPU passthrough:

```bash
docker run --rm --gpus all nvidia/cuda:12.3.2-base-ubuntu22.04 nvidia-smi
```

---

## 5) GPU Tuning (Host-Level)

### 5.1 Set power limit and persistence

```bash
sudo nvidia-smi -pm 1
sudo nvidia-smi -pl 140
```

### 5.2 Make it survive reboots

```bash
sudo tee /etc/systemd/system/gpu-tune.service >/dev/null <<'EOF'
[Unit]
Description=GPU tune (power limit + persistence)
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/bin/nvidia-smi -pm 1
ExecStart=/usr/bin/nvidia-smi -pl 140
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
| Traefik dashboard | `https://traefik.cachehive.local` |
| Grafana | `https://grafana.cachehive.local` |
| Prometheus | `https://prometheus.cachehive.local` |
| Ollama API | `https://ollama.cachehive.local` |
| OpenClaw | `https://openclaw.cachehive.local` |

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
  -keyout /srv/certs/camp-fai.key \
  -out /srv/certs/camp-fai.crt \
  -subj "/CN=camp-fai" \
  -addext "subjectAltName=DNS:camp-fai,DNS:*.camp-fai"
```

Then create the dynamic Traefik TLS config:

```bash
sudo mkdir -p /srv/traefik
sudo tee /srv/traefik/dynamic.yml > /dev/null <<'EOF'
tls:
  stores:
    default:
      defaultCertificate:
        certFile: /etc/certs/camp-fai.crt
        keyFile: /etc/certs/camp-fai.key
EOF
```

If your domain is not `camp-fai` (for example `cachehive.local`), change both cert filenames and the `CN`/`subjectAltName` values to match your domain.

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
curl http://camp-fai:6333/healthz
```

### monitoring

Full observability stack. Grafana auto-provisions Prometheus as a data source on first boot.

After deploying, import NVIDIA GPU dashboard in Grafana:
1. Go to **Dashboards → Import**
2. Enter dashboard ID **12239** (or grab a newer JSON from the [dcgm-exporter repo](https://github.com/NVIDIA/dcgm-exporter))
3. Select the Prometheus data source

For host metrics, import Node Exporter Full (dashboard ID **1860**).

### ollama

Local LLM inference with full GPU access. After deploying, pull a model:

```bash
docker exec -it ollama ollama pull llama3.2
```

The Ollama API is available to other containers on the `proxy` network at `http://ollama:11434`.

### openclaw

Self-hosted AI assistant. Connects to Ollama for local models and to Anthropic/OpenAI for cloud models. Set `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, and `EXA_API_KEY` in Portainer environment variables.

This stack builds a custom image from `images/openclaw/Dockerfile` so required skill runtime binaries (`bun` and `qmd`) are preinstalled at image build time.

After first deploy, run the setup wizard:

```bash
docker exec -it openclaw node dist/index.js setup
```

If you want Exa web search available in OpenClaw skills, configure `EXA_API_KEY` and install an Exa skill (for example via `OPENCLAW_SKILLS="owner/repo"` in `scripts/bootstrap-server.sh`).

#### Rotate OpenClaw auth token (host-side secret)

OpenClaw auth token is stored on the host at `/srv/openclaw/config/openclaw.json` and is **not** managed by GitOps.

On `camp-fai`:

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
   - `https://openclaw.camp-fai/?gatewayUrl=wss://openclaw.camp-fai&token=<NEW_TOKEN>`
2. If UI shows `pairing required`, approve the pending device on `camp-fai`:

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

### quai-miner

Rigel GPU miner for Quai (KawPow). Set `ALGO`, `POOL`, `WALLET`, and `WORKER` in Portainer environment variables. See `stacks/quai-miner/.env.example` for defaults.

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
    compose.yml                  # Prometheus + Grafana + exporters
    prometheus.yml               # Scrape config
    grafana/provisioning/        # Auto-provision datasources
  ollama/compose.yml             # Local LLM inference
  openclaw/compose.yml           # AI assistant
  quai-miner/compose.yml         # GPU miner
images/
  openclaw/Dockerfile            # Custom OpenClaw image (bun + qmd preinstalled)
  rigel/Dockerfile               # Custom Rigel miner image
scripts/
  bootstrap-server.sh            # Create /srv paths, certs, and Traefik dynamic.yml
```
