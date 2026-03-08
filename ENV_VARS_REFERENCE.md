# CacheHive — Environment Variables Reference

Use this document to prepare all secrets and configuration values **before** deploying stacks in Portainer. Enter these as environment variables in the Portainer stack editor — never commit them to git.

> **Placeholders:** Replace `<hostname>` with your server's hostname and `<domain>` with your Traefik routing domain before filling in values. See the README `Before You Begin` section for details.

> **Tip:** Work through each stack in deploy order:
> `infra → postgres → redis → qdrant → monitoring → ollama → openclaw → openwebui → adminer → quai-miner`

---

## infra (Traefik)

| Variable | Required | Example / Default | Description |
|---|---|---|---|
| `DOMAIN` | ✅ Yes | `<domain>` | Base domain for all Traefik routing rules. Must be set consistently across every stack that uses Traefik labels. |

> **Host prerequisite:** Before deploying `infra`, `/srv/traefik/dynamic.yml` and certs under `/srv/certs/` must exist. Run `bootstrap-server.sh` first.

> **Group ID note:** `group_add: "978"` in `compose.yml` is the GID of the Docker socket on the original server. Verify on your host with `stat -c '%g' /var/run/docker.sock` and update if different.

---

## postgres

| Variable | Required | Example / Default | Description |
|---|---|---|---|
| `POSTGRES_USER` | ✅ Yes | `<db-user>` | Database superuser name. Used by any service that connects to Postgres. |
| `POSTGRES_PASSWORD` | ✅ Yes | *(strong secret)* | Password for `POSTGRES_USER`. Generate with `openssl rand -hex 20`. |
| `POSTGRES_DB` | ✅ Yes | `<db-name>` | Name of the default database created on first boot. |

> Other stacks connect to Postgres at `postgres:5432` on the `proxy` network.

---

## redis

No environment variables required.

| Variable | Required | Notes |
|---|---|---|
| *(none)* | — | Redis is reachable at `redis:6379` on the `proxy` network. AOF persistence and 256 MB memory cap are hardcoded. |

---

## qdrant

| Variable | Required | Example / Default | Description |
|---|---|---|---|
| `DOMAIN` | ✅ Yes | `<domain>` | Used in the Traefik routing rule (`qdrant.${DOMAIN}`). Must match the value in `infra`. |

> REST API available to other containers at `qdrant:6333`. gRPC on `qdrant:6334`.

---

## monitoring

| Variable | Required | Example / Default | Description |
|---|---|---|---|
| `DOMAIN` | ✅ Yes | `<domain>` | Used in Traefik rules for Grafana and Prometheus. Must match the value in `infra`. |
| `GF_ADMIN_USER` | ✅ Yes | `admin` | Grafana admin username. Set on first boot — changing it later requires a manual Grafana reset. |
| `GF_ADMIN_PASSWORD` | ✅ Yes | *(strong secret)* | Grafana admin password. Generate with `openssl rand -hex 20`. |

> Prometheus is mapped to host port `9091` to avoid conflict with Cockpit (which occupies `9090`). Traefik routes it correctly via the container port.
>
> After first deploy, import dashboards in Grafana:
> - **NVIDIA GPU:** Dashboard ID `12239`
> - **Node Exporter Full:** Dashboard ID `1860`

---

## ollama

| Variable | Required | Example / Default | Description |
|---|---|---|---|
| `DOMAIN` | ✅ Yes | `<domain>` | Used in the Traefik routing rule (`ollama.${DOMAIN}`). Must match the value in `infra`. |

> After deploying, pull a model:
> ```bash
> docker exec -it ollama ollama pull llama3.2
> ```
> Ollama is reachable by other containers at `http://ollama:11434`.

---

## openclaw

| Variable | Required | Example / Default | Description |
|---|---|---|---|
| `DOMAIN` | ✅ Yes | `<domain>` | Used in the Traefik routing rule (`openclaw.${DOMAIN}`). |
| `ANTHROPIC_API_KEY` | ⚠️ Recommended | `sk-ant-…` | API key for Claude (Anthropic). Required for cloud model access. |
| `OPENAI_API_KEY` | ⚠️ Optional | `sk-…` | API key for OpenAI models. |
| `OPENROUTER_API_KEY` | ⚠️ Optional | `sk-or-v1-…` | API key for OpenRouter (access to many models via one key). |
| `EXA_API_KEY` | ⚠️ Optional | `exa-…` | API key for Exa web search. Required if using Exa-based skills. |

> `OLLAMA_BASE_URL` is hardcoded in the compose file as `http://ollama:11434` — no env var needed.
>
> After first deploy, run the setup wizard:
> ```bash
> docker exec -it openclaw node dist/index.js setup
> ```
>
> **Note:** The auth token is stored in `/srv/openclaw/config/openclaw.json` on the host (not a Portainer env var). See the README for token rotation instructions.

---

## openwebui

| Variable | Required | Example / Default | Description |
|---|---|---|---|
| `DOMAIN` | ✅ Yes | `<domain>` | Used in the Traefik routing rule (`ai.${DOMAIN}`). |

> Connects to Ollama at `http://ollama:11434` (hardcoded in compose). Uses SQLite for local storage (stored in the `openwebui-data` volume). After deploying, open `https://ai.<DOMAIN>` and create an admin account on the first-run screen.

---

## adminer

| Variable | Required | Example / Default | Description |
|---|---|---|---|
| `DOMAIN` | ✅ Yes | `<domain>` | Used in the Traefik routing rule (`adminer.${DOMAIN}`). |
| `ADMINER_BASICAUTH_USERS` | ✅ Yes | `admin:$$apr1$$…` | Traefik basic-auth credentials (browser login prompt). See note below. |

> **Generating the hash** (no extra packages needed):
> ```bash
> openssl passwd -apr1 yourpassword
> ```
> Example output: `$apr1$OKylGb66$DfmJfv9OK3IuyzrN04zr0.`
>
> **⚠️ Dollar-sign escaping required in Portainer:** Docker Compose treats `$` as a variable interpolation character. Every `$` in the hash must be entered as `$$` in Portainer's environment variable UI — even though it looks like a plain text field.
>
> If your hash is `$apr1$OKylGb66$DfmJfv9OK3IuyzrN04zr0.`, enter this in Portainer:
> ```
> admin:$$apr1$$OKylGb66$$DfmJfv9OK3IuyzrN04zr0.
> ```
>
> **Two-layer auth:** The browser popup is Traefik basic auth (uses `ADMINER_BASICAUTH_USERS`). The Adminer login form that follows is the Postgres credential layer (uses `POSTGRES_USER` / `POSTGRES_PASSWORD`).

---

## quai-miner

| Variable | Required | Example / Default | Description |
|---|---|---|---|
| `ALGO` | ✅ Yes | `kawpow` | Mining algorithm. `kawpow` for Quai. |
| `POOL` | ✅ Yes | `stratum+tcp://us.quai.herominers.com:1185` | Stratum pool URL including port. |
| `WALLET` | ✅ Yes | `0xYOUR_WALLET_ADDRESS` | Your Quai wallet address. |
| `WORKER` | ✅ Yes | `<worker-name>` | Worker name shown in the pool dashboard. |

> ⚠️ Deploy this stack **paused**. The RTX 3070 (8 GB VRAM) cannot run Ollama and the miner simultaneously at full load. Activate manually during off-peak hours.

---

## Quick-fill Cheatsheet

Copy this block and fill in before your Portainer session:

```
# === infra ===
DOMAIN=

# === postgres ===
POSTGRES_USER=
POSTGRES_PASSWORD=
POSTGRES_DB=

# === qdrant ===
DOMAIN=

# === monitoring ===
DOMAIN=
GF_ADMIN_USER=
GF_ADMIN_PASSWORD=

# === ollama ===
DOMAIN=

# === openclaw ===
DOMAIN=
ANTHROPIC_API_KEY=
OPENAI_API_KEY=
OPENROUTER_API_KEY=
EXA_API_KEY=

# === openwebui ===
DOMAIN=

# === adminer ===
DOMAIN=
ADMINER_BASICAUTH_USERS=   ← remember: escape every $ as $$

# === quai-miner ===
ALGO=kawpow
POOL=
WALLET=
WORKER=
```

---

## Secrets Generation Helpers

```bash
# Strong random password (40 hex chars)
openssl rand -hex 20

# Strong API token (64 hex chars)
openssl rand -hex 32

# Adminer basic-auth hash
# NOTE: enter the output in Portainer with every $ escaped as $$
openssl passwd -apr1 yourpassword
```
