# OpenClaw Agent Setup

After completing the onboard flow and verifying your gateway connects, these steps help you get the most out of your agent from day one. None of these are required — but each one meaningfully improves the experience.

---

## 1) Route heartbeats to a local model

By default, OpenClaw uses your primary cloud model for heartbeats. Heartbeats run every 30 minutes and are a lightweight check-in — they don't need a powerful model. Routing them to a local Ollama model saves API costs without sacrificing anything.

```bash
docker exec openclaw \
  node dist/index.js config set agents.defaults.heartbeat \
  '{"every":"30m","model":"ollama/mistral:7b-instruct"}'
docker restart openclaw
```

Replace `mistral:7b-instruct` with any model you have pulled in Ollama. `qwen2.5-coder:7b` also works well.

> **Important:** Always use the `ollama/` prefix to ensure the heartbeat runs locally. The Control UI model picker shows every configured provider — a model listed without a prefix (e.g. `llama3.1-8b · cerebras`) will route to that cloud provider, not your local Ollama instance. Look for models with the `ollama` suffix in the picker, or set the heartbeat model via `config set` as shown above to be explicit. The heartbeat model also needs a context window of at least 16k — avoid `llama3.2` (8k window).

---

## 2) Tell your agent who it is — IDENTITY.md

OpenClaw agents read `IDENTITY.md` from the workspace on startup to establish their persona. If this file doesn't exist, the agent starts with no sense of self and will ask you on first chat.

Create it at `/srv/openclaw/workspace/IDENTITY.md` (or let your agent write it during your first conversation):

```markdown
# Identity

Your name is Noah. You are a self-hosted AI assistant running on a private homelab server.
You are direct, thoughtful, and technically capable. You prefer to understand problems fully
before offering solutions. You have a dry sense of humor but keep it professional.
```

Adjust the name and personality to suit your preferences. Your agent will read this on every heartbeat and first message.

---

## 3) Tell your agent who you are — USER.md

Similarly, `USER.md` gives the agent context about you so it doesn't start cold every session.

Create it at `/srv/openclaw/workspace/USER.md`:

```markdown
# User

Name: Tim
Timezone: America/Los_Angeles
Working on: homelab AI stack, GPU mining scheduler, self-hosted agent infrastructure
Preferences: direct answers, minimal fluff, explain reasoning before committing to decisions
```

---

## 4) Give your agent a heartbeat routine — HEARTBEAT.md

The heartbeat fires every 30 minutes. Without `HEARTBEAT.md`, the agent has nothing to do and replies `HEARTBEAT_OK`. With it, you can give the agent standing instructions — things to check, maintain, or remember between sessions.

Create it at `/srv/openclaw/workspace/HEARTBEAT.md`:

```markdown
# Heartbeat Instructions

Read this file on every heartbeat. Follow these instructions strictly.
Do not infer tasks from prior conversations.

## Standing checks
- If there are no pending tasks, reply: HEARTBEAT_OK
- If USER.md or IDENTITY.md are missing or empty, note it and wait for the user to provide content

## Notes
- Do not start new tasks autonomously unless explicitly instructed
```

Adjust the standing checks to whatever makes sense for your use case. Over time this file becomes the agent's standing brief.

---

## 5) Verify everything loaded

After making changes to workspace files, restart the container and confirm the agent reads them on the next heartbeat:

```bash
docker restart openclaw
docker logs openclaw --tail 20
```

You can also trigger a manual check from the Control UI chat by asking the agent to read its `HEARTBEAT.md` directly.
