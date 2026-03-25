# Discord Multi-Bot Setup for OpenClaw

OpenClaw uses **one Discord bot per agent**. Each bot has its own token,
its own account ID in the config, and its own binding. Bots can share
channels — agents respond when mentioned (`@BotName`).

## Agents and Their Bots

| Agent | Bot Name (suggestion) | Account ID | Portainer Env Var |
|-------|----------------------|------------|-------------------|
| Noah (main) | `Noah` | `default` | `DISCORD_BOT_TOKEN` |
| Dan | `Dan` | `dan` | `DISCORD_BOT_TOKEN_DAN` |
| Declan | `Declan` | `declan` | `DISCORD_BOT_TOKEN_DECLAN` |
| Eamon | `Eamon` | `eamon` | `DISCORD_BOT_TOKEN_EAMON` |
| Maeve | `Maeve` | `maeve` | `DISCORD_BOT_TOKEN_MAEVE` |
| Ronan | `Ronan` | `ronan` | `DISCORD_BOT_TOKEN_RONAN` |

---

## 1. Create a Bot for Each Agent

Repeat these steps once per agent (6 total).

1. Go to [Discord Developer Portal](https://discord.com/developers/applications)
2. Click **New Application** → name it after the agent (e.g. `Declan`)
3. In the left sidebar → **Bot**
4. Under **Privileged Gateway Intents**, enable **Message Content Intent**
5. Under **TOKEN** → click **Reset Token** → copy the token
6. Keep each token somewhere safe — you'll add them to Portainer shortly

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

Repeat for all 6 bots. All bots can be in the same server and same channels.

---

## 3. Add Tokens to Portainer

1. Open Portainer → **Stacks** → **openclaw** → **Editor**
2. Scroll to **Environment variables**
3. Add each token (see table above):
   - `DISCORD_BOT_TOKEN` — Noah's token (existing)
   - `DISCORD_BOT_TOKEN_DAN`
   - `DISCORD_BOT_TOKEN_DECLAN`
   - `DISCORD_BOT_TOKEN_EAMON`
   - `DISCORD_BOT_TOKEN_MAEVE`
   - `DISCORD_BOT_TOKEN_RONAN`
4. Click **Update** → restart the stack

---

## 4. Add Channel IDs to the Config

Once you've created Discord channels for the agents that need them,
add the channel IDs to the relevant account block in `openclaw.json`:

```json
"eamon": {
  "token": "${DISCORD_BOT_TOKEN_EAMON}",
  "guilds": {
    "1482519507871334607": {
      "requireMention": true,
      "users": ["298234100878278668"],
      "channels": {
        "YOUR_CHANNEL_ID_HERE": { "allow": true }
      }
    }
  }
}
```

To get a channel ID: right-click the channel in Discord → **Copy Channel ID**
(requires Developer Mode: User Settings → Advanced → Developer Mode).

Accounts without a `channels` block will accept messages from any allowed
channel in the guild when the bot is mentioned.

---

## 5. How Mention Routing Works

- **Noah** (`default`) — `requireMention: false` on his assigned channel, responds freely
- **All other agents** — `requireMention: true`, only respond when mentioned by name

In a shared channel, mention the bot you want:
- `@Declan can you review this PR?`
- `@Eamon research competitors for X`
- `@Maeve what's the status on Y?`

Each bot only sees messages directed at it (Discord delivers per-bot).

---

## 6. Verify

After restarting:

```bash
docker logs openclaw --tail 100 | grep -i discord
```

You should see 6 separate Discord bot connections, one per agent.

```bash
# Check all agents and their bindings
docker exec openclaw openclaw agents list --bindings
```

---

## Troubleshooting

**Bot doesn't respond:**
- Confirm token is correct in Portainer (no extra spaces)
- Confirm Message Content Intent is enabled in the Developer Portal
- Confirm the bot is invited to the server
- Check that the channel ID is in the `channels` allowlist (if set)
- Restart the stack and check logs

**"Missing permissions" error:**
- Regenerate the invite URL and re-authorize with correct permissions

**Token invalid:**
- Regenerate in the Developer Portal → update in Portainer → restart

**All messages going to Noah only:**
- The old single-bot config routed everything to `default`
- Verify you've set `requireMention: true` on the other agents
- Verify each account has its own unique token
