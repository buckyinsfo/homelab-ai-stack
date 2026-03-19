# Homelab AI Stack — Environment Variables Reference

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
> After first deploy, follow the dashboard import steps in [`docs/MONITORING_SETUP.md`](MONITORING_SETUP.md).

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
| `GEMINI_API_KEY` | ⚠️ Optional | `AIza…` | Google Gemini API key. Required for the nano-banana-pro image generation skill (Gemini 3 Pro Image). Get one from [Google AI Studio](https://aistudio.google.com). |
| `TELEGRAM_BOT_TOKEN` | ⚠️ Optional | `123456:ABC-…` | Telegram bot token for OpenClaw Telegram channel integration. Create a bot via [@BotFather](https://t.me/botfather). |
| `TRELLO_API_KEY` | ⚠️ Optional | `<trello-api-key>` | Trello API key for OpenClaw skills or tools that access Trello boards and cards. |
| `TRELLO_TOKEN` | ⚠️ Optional | `<trello-token>` | Trello token paired with `TRELLO_API_KEY` for authenticated Trello API access from OpenClaw. |
| `DISCORD_BOT_TOKEN` | ⚠️ Optional | `MTE0MjIw…` | Discord bot token for OpenClaw Discord channel integration. Create a bot in your Discord Server Settings → Integrations → Bots. |
| `GH_TOKEN` | ⚠️ Optional | `github_pat_…` | GitHub personal access token used by the OpenClaw GitHub auth profile in `openclaw.json`. Required for GitHub API access from skills or tools. |
| `GITHUB_USERNAME` | ⚠️ Optional | `your-github-username` | GitHub username paired with `GH_TOKEN` for the `github:default` auth profile in `openclaw.json`. |
| `NEXTCLOUD_AGENTS_PASSWORD` | ✅ Yes | *(strong secret)* | Shared password for Nextcloud agent accounts. Used by OpenClaw agents to connect to Nextcloud for document storage. Generate with `openssl rand -hex 20`. |
| `OPENCLAW_GATEWAY_TOKEN` | 📝 Manual convenience | `<token>` | Optional Portainer-side scratch value for copy/paste during pairing. It is **not** consumed by the compose file or container. The real gateway token lives in `/srv/openclaw/config/openclaw.json`. |

> `OLLAMA_BASE_URL` is hardcoded in the compose file as `http://ollama:11434` — no env var needed.
>
> After first deploy, run the setup wizard:
> ```bash
> docker exec -it openclaw node dist/index.js setup
> ```
>
> **Note:** The auth token is stored in `/srv/openclaw/config/openclaw.json` on the host (not a Portainer env var). See the README for token rotation instructions.
>
> **Convenience note:** If you keep `OPENCLAW_GATEWAY_TOKEN` in Portainer for easy copy/paste during pairing, treat it as a manual reference only. Updating it in Portainer does not change OpenClaw's actual gateway token.

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

## nextcloud *(optional)*

| Variable | Required | Example / Default | Description |
|---|---|---|---|
| `DOMAIN` | ✅ Yes | `<domain>` | Used in the Traefik routing rule (`cloud.${DOMAIN}`). Must match the value in `infra`. |
| `POSTGRES_USER` | ✅ Yes | `<db-user>` | Must match the value set in the `postgres` stack. |
| `POSTGRES_PASSWORD` | ✅ Yes | *(strong secret)* | Must match the value set in the `postgres` stack. |
| `NEXTCLOUD_DB_NAME` | ✅ Yes | `nextcloud` | Name of the Nextcloud database. Must exist in Postgres before first boot — create it manually. |
| `NEXTCLOUD_ADMIN_USER` | ✅ Yes | `admin` | Admin account created on first boot. Cannot be changed via env var after initial setup. |
| `NEXTCLOUD_ADMIN_PASSWORD` | ✅ Yes | *(strong secret)* | Admin password set on first boot. Generate with `openssl rand -hex 20`. |
| `NEXTCLOUD_PHP_MEMORY_LIMIT` | ⚠️ Optional | `512M` | PHP memory limit. Increase for large file operations or many users. |
| `NEXTCLOUD_PHP_UPLOAD_LIMIT` | ⚠️ Optional | `512M` | Maximum upload size. Match or exceed your largest expected file transfer. |

> **Pre-deploy steps:** Create host directories and the Nextcloud database before deploying:
> ```bash
> sudo mkdir -p /srv/nextcloud/{data,apps,config}
> docker exec -it postgres psql -U <POSTGRES_USER> -c "CREATE DATABASE nextcloud;"
> ```
>
> Redis is used automatically for session caching and locking — no Redis password needed since the stack uses unauthenticated Redis.
>
> After deploying, open `https://cloud.<DOMAIN>` and log in with the admin credentials above.
>
> **Agent accounts:** Three service accounts (eamon, maeve, ronan) are created in Nextcloud for OpenClaw agents. They share the password stored in `NEXTCLOUD_AGENTS_PASSWORD` (set in the openclaw stack environment). Each has a dedicated folder (`/Eamon/`, `/Maeve/`, `/Ronan/`) with read/write access.

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
GEMINI_API_KEY=
TELEGRAM_BOT_TOKEN=
TRELLO_API_KEY=
TRELLO_TOKEN=
DISCORD_BOT_TOKEN=
GH_TOKEN=
GITHUB_USERNAME=
NEXTCLOUD_AGENTS_PASSWORD=   ← shared password for agent accounts (eamon, maeve, ronan)
OPENCLAW_GATEWAY_TOKEN=      ← optional convenience-only value; not consumed by the stack

# === openwebui ===
DOMAIN=

# === adminer ===
DOMAIN=
ADMINER_BASICAUTH_USERS=   ← remember: escape every $ as $

# === nextcloud (optional) ===
DOMAIN=
POSTGRES_USER=
POSTGRES_PASSWORD=
NEXTCLOUD_DB_NAME=nextcloud
NEXTCLOUD_ADMIN_USER=admin
NEXTCLOUD_ADMIN_PASSWORD=
NEXTCLOUD_PHP_MEMORY_LIMIT=512M
NEXTCLOUD_PHP_UPLOAD_LIMIT=512M

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
