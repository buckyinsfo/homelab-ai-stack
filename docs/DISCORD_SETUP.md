# Discord Bot Setup for OpenClaw

This guide walks you through creating a Discord bot and configuring OpenClaw to integrate with it.

## 1. Create a Discord Bot

1. Go to [Discord Developer Portal](https://discord.com/developers/applications)
2. Click **New Application** in the top-right
3. Enter a name (e.g. `OpenClaw`)
4. Click **Create**

## 2. Generate the Bot Token

1. In the left sidebar, click **Bot**
2. Click **Add Bot**
3. Under the **TOKEN** section, click **Copy** to copy your bot token
4. **⚠️ Keep this secret** — treat it like a password. Never commit it to git.

This is the value you'll set as `DISCORD_BOT_TOKEN` in Portainer.

## 3. Configure Bot Permissions

1. In the left sidebar, click **OAuth2** → **URL Generator**
2. Under **SCOPES**, select:
   - `bot`
3. Under **PERMISSIONS**, select:
   - `Send Messages`
   - `Read Messages/View Channels`
   - `Read Message History`
   - `Mention @everyone, @here, and All Roles`
   - `React with Emojis`

4. Copy the generated URL at the bottom
5. Paste it in your browser to invite the bot to your Discord server
6. Select your server from the dropdown and authorize

## 4. Set Discord Bot Token in Portainer

1. Open your Portainer instance
2. Go to **Stacks** → **openclaw** → **Editor**
3. Scroll to **Environment variables**
4. Add or update `DISCORD_BOT_TOKEN` with the token you copied in step 2
5. Click **Update**
6. Restart the OpenClaw container:
```bash
   docker restart openclaw
```

## 5. Verify Integration

After restarting, check the OpenClaw logs:
```bash
docker logs openclaw --tail 50 | grep -i discord
```

You should see a message indicating the Discord bot connected successfully. Try sending a message to OpenClaw in Discord — it should respond!

## Troubleshooting

**Bot doesn't respond in Discord:**
- Verify the token is correct in Portainer (no extra spaces)
- Check that the bot is invited to your server and has appropriate permissions
- Restart the OpenClaw container
- Check logs: `docker logs openclaw --tail 100`

**"Missing permissions" error:**
- Go back to Discord Developer Portal
- Ensure your bot has the permissions listed in step 3
- Regenerate the invite URL and re-authorize the bot

**Token is invalid:**
- Regenerate a new token in the Discord Developer Portal
- Update it in Portainer and restart
