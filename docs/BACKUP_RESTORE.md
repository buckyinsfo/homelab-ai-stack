# Backup & Restore

## Overview

Backups run on a daily cron schedule on the server via root cron.
Script: `scripts/backup.sh`
Log: `<BACKUP_ROOT>/backup.log` (see `backup.sh` for `BACKUP_ROOT` value)

Each backup is a timestamped directory:

```
<BACKUP_ROOT>/
  YYYY-MM-DD-HHMMSS/
    volumes/
      <volume-name>.tgz     # one per named Docker volume
      postgres_dumpall.sql  # PostgreSQL full dump
    srv/
      <path>.tgz            # one per /srv bind mount
```

Retention: the last N backups are kept (see `RETAIN_COUNT` in `backup.sh`).
Older backups are auto-purged on each run.

---

## Checking Backups

```bash
# List available backups
ls -lah <BACKUP_ROOT>/

# Check last backup log
tail -50 <BACKUP_ROOT>/backup.log

# Check size of a specific backup
du -sh <BACKUP_ROOT>/YYYY-MM-DD-HHMMSS/
```

---

## Restore Procedures

### Prerequisites

Set a variable pointing to the backup you want to restore from:

```bash
BACKUP_DIR="<BACKUP_ROOT>/YYYY-MM-DD-HHMMSS"
```

---

### Docker Named Volume

```bash
# Stop any containers using the volume first
docker stop <container-name>

# Restore the volume (wipes existing contents)
docker run --rm \
  -v <volume-name>:/v \
  -v "${BACKUP_DIR}/volumes:/backup" \
  alpine sh -c "rm -rf /v/* && tar xzf /backup/<volume-name>.tgz -C /v"

# Restart the container
docker start <container-name>
```

---

### PostgreSQL

The backup uses `pg_dumpall` so all databases and roles are included in a
single SQL file. The superuser is read dynamically from the running container
at backup time — no hardcoded credentials in the script.

```bash
BACKUP_DIR="<BACKUP_ROOT>/YYYY-MM-DD-HHMMSS"
PG_USER=$(docker exec postgres printenv POSTGRES_USER)

docker exec -i postgres psql -U "${PG_USER}" -f - < "${BACKUP_DIR}/volumes/postgres_dumpall.sql"
```

> **Note:** If restoring to a fresh postgres container, the container must be
> running but target databases should not yet exist. Drop them first if needed.

---

### /srv Bind Mounts

Stop the relevant container before restoring its bind mount, then restore and
fix ownership before restarting.

```bash
BACKUP_DIR="<BACKUP_ROOT>/YYYY-MM-DD-HHMMSS"

docker stop <container-name>
rm -rf /srv/<path>
tar xzf "${BACKUP_DIR}/srv/<path>.tgz" -C /srv
chown -R <owner>:<group> /srv/<path>
docker start <container-name>
```

> **Ownership:** Each `/srv` path should be owned by whichever user or service
> manages it. Check your setup's conventions before restoring — container-managed
> paths (e.g. those written by `www-data`) should not be blindly chowned to your
> user account.

---

### Full Stack Disaster Recovery

If rebuilding the server from scratch:

1. Provision the OS and run `scripts/bootstrap-server.sh`
2. Install Docker + Portainer: `scripts/install-docker-portainer.sh`
3. Install any required GPU drivers: `scripts/install-nvidia-drivers.sh`
4. Restore `/srv/certs` and `/srv/traefik` before starting any stacks
5. Re-deploy all Portainer GitOps stacks from the repo
6. Restore each named Docker volume using the procedure above
7. Restore PostgreSQL using the `pg_dumpall` procedure above
8. Restore remaining `/srv` bind mounts
9. Verify all services are healthy

---

## Offsite Sync

Once a remote backup target (NAS, secondary server, etc.) is available,
add an rsync step to the end of `backup.sh` or as a separate cron job:

```bash
rsync -av --delete <BACKUP_ROOT>/ <user>@<remote-host>:<remote-path>/
```

The server's SSH key (`~/.ssh/id_ed25519`) should be added to the remote
host's `authorized_keys` to allow passwordless rsync.
