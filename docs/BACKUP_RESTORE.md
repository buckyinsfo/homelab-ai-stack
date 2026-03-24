# Backup and Restore

Backups are staged locally at `/srv/backups/<timestamp>/` and can be synced to NAS or cloud storage from there. Each backup run creates a timestamped directory containing two subdirectories:

- `volumes/` — Docker named volumes (tarballs) and a PostgreSQL SQL dump
- `srv/` — `/srv` bind mounts (tarballs)

---

## Running a backup

```bash
sudo bash scripts/backup.sh
```

Output lands in `/srv/backups/<YYYY-MM-DD-HHMMSS>/`. The script skips any volume or path that doesn't exist, so it's safe to run even if some stacks are not deployed.

---

## Automating backups

Add a cron entry to run nightly:

```bash
sudo crontab -e
```

```
0 2 * * * bash /path/to/homelab-ai-stack/scripts/backup.sh >> /srv/backups/backup.log 2>&1
```

To sync to a remote location after each run, append an `rsync` or `rclone` command at the end of the cron entry or add it to `scripts/backup.sh` directly.

---

## Restore procedures

### PostgreSQL

```bash
# Stop any services that use the database
docker stop openclaw nextcloud

# Restore from SQL dump
docker exec -i postgres psql -U postgres < /srv/backups/<timestamp>/volumes/postgres_dumpall.sql

# Restart services
docker start openclaw nextcloud
```

### Docker named volumes

```bash
# Example: restore grafana-data
docker run --rm \
  -v monitoring_grafana-data:/v \
  -i alpine sh -c "tar xzf - -C /v" \
  < /srv/backups/<timestamp>/volumes/monitoring_grafana-data.tgz
```

Repeat for each volume. Stop the relevant container before restoring and restart after.

### /srv bind mounts

```bash
# Example: restore /srv/openclaw
docker stop openclaw
sudo tar xzf /srv/backups/<timestamp>/srv/openclaw.tgz -C /srv
sudo chown -R 1000:1000 /srv/openclaw
docker start openclaw
```

Repeat for each path (`sandbox`, `certs`, `traefik`, `nextcloud`). Note:

- After restoring `/srv/certs` and `/srv/traefik`, restart the `infra` stack in Portainer to reload the certs and dynamic config.
- After restoring `/srv/sandbox`, run the post-deploy onboard steps again if the `openclaw.json` config was reset. See the README openclaw-sandbox section.

### Restore order (full rebuild)

If restoring from scratch after a bare metal reinstall, restore in this order:

1. Run `scripts/bootstrap-server.sh` to recreate `/srv` paths
2. Restore `/srv/certs` and `/srv/traefik`
3. Deploy `infra` stack in Portainer
4. Deploy `postgres`, `redis`, `qdrant` stacks
5. Restore PostgreSQL dump
6. Restore `redis_redis-data`, `qdrant_qdrant-data` volumes
7. Deploy remaining stacks
8. Restore remaining volumes and `/srv` paths
9. Restart all stacks

---

## What is backed up

| Item | Type | Notes |
|---|---|---|
| `monitoring_grafana-data` | Docker volume | Dashboards, datasources, preferences |
| `monitoring_prometheus-data` | Docker volume | Metrics history |
| `postgres_postgres-data` | pg_dump SQL | All databases, users, schemas |
| `redis_redis-data` | Docker volume | AOF persistence file |
| `qdrant_qdrant-data` | Docker volume | Vector collections |
| `qdrant_qdrant-snapshots` | Docker volume | Qdrant snapshots |
| `openwebui_openwebui-data` | Docker volume | Open WebUI config and history |
| `portainer_data` | Docker volume | Portainer stacks, users, settings |
| `gila_mongodb_data` | Docker volume | Gila MongoDB data |
| `/srv/openclaw` | Bind mount | Agent config, workspace, memory, sessions |
| `/srv/sandbox` | Bind mount | Sandbox agent config and workspace |
| `/srv/certs` | Bind mount | TLS certificates |
| `/srv/traefik` | Bind mount | Traefik dynamic config |
| `/srv/nextcloud` | Bind mount | Nextcloud data, config, apps |
