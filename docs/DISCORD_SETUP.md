# Discord Multi-Bot Setup for OpenClaw

OpenClaw supports **one Discord bot per agent**. Each bot has its own token,
its own account ID in the config, and its own binding. Bots can share
channels — agents respond when mentioned (`@BotName`).

---

## 1. Create a Bot for Each Agent

Repeat these steps once per agent you want to connect to Discord.

1. Go to [Discord Developer Portal](https://discord.com/developers/applications)
2. Click **New Application** → name it after the agent
3. In the left sidebar → **Bot**
4. Under **Privileged Gateway Intents**, enable **Message Content Intent**
5. Under **TOKEN** → click **Reset Token** → copy the token
6. Keep each token somewhere safe — you'll need them in Step 3

---

## 2. Set Bot Permissions and Invite Each Bot

For each bot:

1. Left sidebar → **OAuth2** → **URL Generator**
2. Under **SCOPES** select: `bot`
3. Under **BOT PERMISSIONS** select:
   - `Send Messages`
   - `Read Messages / View Channels`
   - `Read Message History`
   - `Use Slash Commands`
4. Copy the generated URL → paste in browser → select your server → **Authorize**

All bots can be in the same server and same channels.

---

## 3. Add Tokens to Your Environment

OpenClaw reads bot tokens from environment variables. Each agent needs its own
variable. For example, if your config uses `DISCORD_BOT_TOKEN_AGENTNAME`, set:

```
DISCORD_BOT_TOKEN          # for your primary/default agent
DISCORD_BOT_TOKEN_AGENT2
DISCORD_BOT_TOKEN_AGENT3
# ... one per agent
```

How you set these depends on your deployment:
- **Docker Compose** — add to your `environment:` block or a `.env` file
- **Portainer** — Stacks → your stack → Environment variables
- **Direct** — export them in your shell before starting OpenClaw

Never commit tokens to source control.

---

## 4. Reference Tokens in openclaw.json

In your `openclaw.json`, reference each variable using `${VAR_NAME}`:

```json
"accounts": {
  "default": {
    "type": "discord",
    "token": "${DISCORD_BOT_TOKEN}"
  },
  "agent2": {
    "type": "discord",
    "token": "${DISCORD_BOT_TOKEN_AGENT2}"
  }
}
```

---

## 5. Add Channel IDs to the Config (Optional)

If you want to restrict an agent to specific channels, add a `channels` block
to the account's guild entry in `openclaw.json`:

```json
"agent2": {
  "token": "${DISCORD_BOT_TOKEN_AGENT2}",
  "guilds": {
    "YOUR_GUILD_ID": {
      "requireMention": true,
      "users": ["YOUR_USER_ID"],
      "channels": {
        "YOUR_CHANNEL_ID": { "allow": true }
      }
    }
  }
}
```

To find IDs: right-click a server/channel/user in Discord → **Copy ID**
(requires Developer Mode: User Settings → Advanced → Developer Mode).

Accounts without a `channels` block will accept messages from any allowed
channel in the guild when the bot is mentioned.

---

## 6. How Mention Routing Works

- **Default agent** — can be configured with `requireMention: false` to respond
  freely in its assigned channel
- **All other agents** — set `requireMention: true` so they only respond when
  explicitly mentioned

In a shared channel, mention the bot you want:
```
@Agent2 can you review this?
@Agent3 research competitors for X
```

Each bot only sees messages directed at it (Discord delivers per-bot).

---

## 7. Verify

After starting OpenClaw:

```bash
docker logs openclaw --tail 100 | grep -i discord
```

You should see a separate Discord bot connection for each configured agent.

```bash
# Check all agents and their bindings
docker exec openclaw openclaw agents list --bindings
```

---

## Troubleshooting

**Bot doesn't respond:**
- Confirm the token is correct in your environment (no extra spaces)
- Confirm Message Content Intent is enabled in the Developer Portal
- Confirm the bot is invited to the server
- Check that the channel ID is in the `channels` allowlist (if set)
- Restart OpenClaw and check logs

**"Missing permissions" error:**
- Regenerate the invite URL and re-authorize with correct permissions

**Token invalid:**
- Regenerate in the Developer Portal → update your environment → restart

**All messages going to the default agent only:**
- The single-bot config routes everything to `default`
- Verify `requireMention: true` is set on the other agents
- Verify each account has its own unique token
