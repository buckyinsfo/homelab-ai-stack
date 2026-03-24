# ONLYOFFICE + Nextcloud Setup

This guide covers the post-deploy steps to connect ONLYOFFICE to Nextcloud on a fresh install. The `nextcloud` stack includes both services in a single `compose.yml` — once deployed, you need to wire them together through the Nextcloud admin UI and a few `occ` commands.

> **Prerequisites:** The `nextcloud` stack is deployed and running. `ONLYOFFICE_JWT_SECRET` is set in Portainer. Both `https://cloud.<domain>` and `https://office.<domain>` are accessible in your browser (you may need to accept the self-signed cert warning on each).

---

## 1. Accept the self-signed cert in your browser

Visit both URLs directly in your browser and accept the security warning on each:

```
https://office.<domain>/welcome/
https://cloud.<domain>
```

The browser needs an active exception for both hostnames before the editor will load.

---

## 2. Run post-deploy occ commands (run once after first deploy)

These configure Nextcloud to work correctly behind the Traefik reverse proxy and allow internal server-to-server requests:

```bash
# Allow ONLYOFFICE to make internal requests back to Nextcloud
sudo docker exec -u www-data nextcloud php occ config:system:set allow_local_remote_servers --value=true --type=boolean

# Add Docker internal hostname as a trusted domain
sudo docker exec -u www-data nextcloud php occ config:system:set trusted_domains 2 --value="nextcloud"

# Trust the Docker proxy network for forwarded headers
sudo docker exec -u www-data nextcloud php occ config:system:set trusted_proxies 0 --value="172.18.0.0/16"

# Set the canonical CLI URL (used for server-side link generation)
sudo docker exec -u www-data nextcloud php occ config:system:set overwrite.cli.url --value="https://cloud.<domain>"
```

---

## 3. Install the ONLYOFFICE app in Nextcloud

1. Go to `https://cloud.<domain>` and log in as admin
2. Click your avatar (top right) → **Apps**
3. Search for **ONLYOFFICE**
4. Click **Install**

---

## 4. Configure the ONLYOFFICE plugin

1. Click your avatar → **Administration settings**
2. In the left sidebar under **Administration**, click **ONLYOFFICE**
3. Fill in the fields:

| Field | Value |
|---|---|
| ONLYOFFICE Docs address | `https://office.<domain>/` |
| Disable certificate verification | ✅ Checked (required for self-signed certs) |
| Secret key | *(paste your `ONLYOFFICE_JWT_SECRET` value)* |

4. Expand **Advanced server settings** and fill in:

| Field | Value |
|---|---|
| ONLYOFFICE Docs address for internal requests from the server | `http://onlyoffice` |
| Server address for internal requests from ONLYOFFICE Docs | `http://nextcloud` |

> These internal addresses route server-to-server traffic over plain HTTP on the Docker network, bypassing the self-signed TLS cert entirely. The browser still uses the public HTTPS addresses.

5. Click **Save**

You should see: **Settings have been successfully updated (version 8.x.x.xx)**

---

## 5. Verify

Go to **Files**, click **New** (+ button), and create a new spreadsheet or document. It should open in the ONLYOFFICE editor in the browser. The bottom bar should show **All changes saved**.

---

## How it works

The tricky part of this setup is that Nextcloud and ONLYOFFICE need to talk to each other in two directions, and the self-signed cert creates problems at each layer:

- **Browser → ONLYOFFICE**: handled by the cert exception you accepted in step 2
- **Nextcloud → ONLYOFFICE** (healthcheck, settings save): uses `http://onlyoffice` over Docker network — no TLS involved
- **ONLYOFFICE → Nextcloud** (document download): uses `http://nextcloud` over Docker network — no TLS involved
- **Browser → Nextcloud** (file save callbacks): uses `https://cloud.<domain>` — handled by Traefik + cert exception

The `X-Forwarded-Proto: https` Traefik middleware on the ONLYOFFICE router ensures ONLYOFFICE generates `https://` cache URLs for the browser, preventing mixed content errors.

The self-signed cert is also mounted into the ONLYOFFICE container at `/usr/local/share/ca-certificates/` and imported via `update-ca-certificates` on startup, so the Node.js process trusts it for any direct HTTPS calls it needs to make.

---

## Troubleshooting

**Settings save fails with "cURL error 6: Could not resolve host: office.\<domain\>"**
The Nextcloud container can't resolve `office.<domain>`. Verify the `extra_hosts` entry in the nextcloud service in `compose.yml` points to your server's LAN IP.

**Settings save fails with "502 Bad Gateway"**
ONLYOFFICE is still starting up — it takes 2–3 minutes after container start. Wait and retry.

**Settings save fails with "Mixed Active Content is not allowed"**
`http://onlyoffice` was entered as the main ONLYOFFICE Docs address instead of just the internal address field. The top field must be `https://office.<domain>/`.

**"Download failed" when opening a document**
Check `docker logs onlyoffice --tail 30`. Common causes:
- `DEPTH_ZERO_SELF_SIGNED_CERT`: cert not mounted or `update-ca-certificates` didn't run — redeploy the stack
- `statusCode:400` from Nextcloud: `trusted_domains` doesn't include `nextcloud` — run the occ command in step 3
- Mixed content error in browser console (`http://office.<domain>/cache/...`): `X-Forwarded-Proto` middleware missing from the onlyoffice Traefik labels

**Login loop after redeploying Nextcloud**
`OVERWRITEPROTOCOL` was removed from the compose env. It must stay set to `https` — without it, Nextcloud doesn't know it's behind HTTPS and generates broken redirect URLs after login.
