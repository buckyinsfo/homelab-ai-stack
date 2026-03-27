# Private TLS Setup for Homelab

Trusted internal HTTPS certificate for your homelab domain using a private CA accepted by Safari/Chrome/macOS.

## Overview

- **Server**: your homelab server running Traefik
- **Client**: Mac workstation
- **Reverse proxy**: Traefik v3
- **Domain pattern**: `*.your-domain` (e.g. `*.homelab.local`)

## Key Rules

1. Server certificates must be ≤ 825 days (Apple hard requirement — longer lifetimes cause "not standards compliant" errors)
2. Server certificate must include SubjectAltName (SAN) entries
3. Server certificate must include SubjectKeyIdentifier
4. Root CA must be installed and trusted in macOS System keychain via Keychain Access UI (CLI alone is not sufficient)
5. Traefik must use the fullchain cert (server cert + CA cert concatenated), not just the server cert
6. Wildcards may fail on macOS — explicit hostnames in SAN are safer

---

## Step 1 — Create Root CA Key

Run on your server:

```bash
sudo openssl genrsa -out /srv/certs/ca.key 4096
```

## Step 2 — Create Root CA Certificate

```bash
sudo openssl req -x509 -new -nodes \
  -key /srv/certs/ca.key \
  -sha256 \
  -days 3650 \
  -out /srv/certs/ca.crt \
  -subj "/CN=your-ca-name"
```

## Step 3 — Create Server Private Key

```bash
sudo openssl genrsa -out /srv/certs/server.key 4096
```

## Step 4 — Create Server CSR

```bash
sudo openssl req -new \
  -key /srv/certs/server.key \
  -out /srv/certs/server.csr \
  -subj "/CN=your-domain"
```

## Step 5 — Create server-ext.cnf

Create on your server (e.g. `~/server-ext.cnf`):

```ini
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
subjectKeyIdentifier=hash
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = your-domain
DNS.2 = service1.your-domain
DNS.3 = service2.your-domain
DNS.4 = service3.your-domain
```

Add one `DNS.N` entry per subdomain you need. Using explicit hostnames is more reliable than wildcard-only SAN on macOS.

## Step 6 — Sign Server Certificate

825 days is the maximum Apple allows:

```bash
sudo openssl x509 -req \
  -in /srv/certs/server.csr \
  -CA /srv/certs/ca.crt \
  -CAkey /srv/certs/ca.key \
  -CAcreateserial \
  -out /srv/certs/server.crt \
  -days 825 \
  -sha256 \
  -extfile server-ext.cnf
```

## Step 7 — Build Fullchain Certificate

Shell redirection must run as root when writing to protected paths:

```bash
sudo sh -c 'cat /srv/certs/server.crt /srv/certs/ca.crt > /srv/certs/server-fullchain.crt'
```

## Step 8 — Configure Traefik

Point Traefik's `dynamic.yml` at the fullchain cert:

```yaml
tls:
  certificates:
    - certFile: /etc/certs/server-fullchain.crt
      keyFile: /etc/certs/server.key
```

Restart Traefik and verify no TLS errors in logs:

```bash
docker restart traefik
docker logs traefik --since=10s
```

## Step 9 — Install Root CA on Mac

From your Mac:

```bash
scp user@server:/srv/certs/ca.crt ~/homelab-ca.crt
```

Then:

1. Double-click `homelab-ca.crt`
2. Install into **System** keychain
3. Open **Keychain Access**, find your CA entry
4. Double-click it → expand **Trust**
5. Set **When using this certificate** → **Always Trust**
6. Close window and enter Mac password
7. Confirm blue "+" icon and "Trusted for all users" appears

> The `security add-trusted-cert` CLI alone is not sufficient — you must set trust via the Keychain Access UI.

## Step 10 — Clear macOS TLS Cache

```bash
killall Safari
sudo dscacheutil -flushcache
```

## Step 11 — Verify from Mac

```bash
openssl s_client \
  -connect service1.your-domain:443 \
  -servername service1.your-domain \
  </dev/null 2>/dev/null \
  | openssl x509 -noout -dates
```

`notAfter` should be ~825 days out.

## Step 12 — Node.js Tools

Node.js does not use the macOS system keychain. Add this to `~/.zshrc`:

```bash
export NODE_EXTRA_CA_CERTS=~/homelab-ca.crt
```

This covers tools like opencode, npm scripts, etc.

---

## Files Reference

| File | Purpose |
|------|---------|
| `/srv/certs/ca.key` | CA private key — keep secure, never commit |
| `/srv/certs/ca.crt` | CA certificate — install on all client machines |
| `/srv/certs/server.key` | Server private key |
| `/srv/certs/server.crt` | Server certificate |
| `/srv/certs/server-fullchain.crt` | Server cert + CA cert — Traefik uses this |
| `~/server-ext.cnf` | SAN config — keep for renewal |

## Renewal

Cert expires in 825 days. To renew, repeat Steps 3–8 (CA key and cert can be reused for its full 10-year lifetime). Update `server-ext.cnf` with any new subdomains before re-signing.
