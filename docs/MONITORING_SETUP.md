# Monitoring Stack Setup

The monitoring stack (Prometheus + Grafana + exporters) is largely self-configuring — Prometheus scrape targets and the Grafana datasource are provisioned automatically on first deploy. The only manual step after deploying is importing community Grafana dashboards and applying a one-time datasource variable fix.

---

## What auto-provisions on first deploy

- **Prometheus** scrape config (embedded in `compose.yml` via Docker `configs` block) — scrapes Prometheus itself, `dcgm-exporter`, `node-exporter`, and `cadvisor` every 15s
- **Grafana Prometheus datasource** — provisioned at startup via the `grafana_datasource` config block; no manual datasource setup needed
- **DCGM metrics config** — embedded in `compose.yml`; includes standard GPU metrics plus profiling metrics (see [GPU profiling note](#gpu-profiling-note) below)

---

## After deploying: import Grafana dashboards

Open Grafana at `https://grafana.<domain>` and import these three community dashboards.

### Step 1 — Import each dashboard

**Dashboards → New → Import**, paste the ID, click **Load**, select the Prometheus datasource, click **Import**.

| Dashboard | ID | Purpose |
|---|---|---|
| Node Exporter Full | `1860` | Host CPU, memory, disk, network |
| cAdvisor Docker Insights | `19908` | Per-container CPU, memory, network, disk I/O |
| NVIDIA DCGM Exporter Dashboard | `12239` | GPU temp, power, utilization, memory |

### Step 2 — Fix the `${DS_PROMETHEUS}` variable

Community dashboards use a `${DS_PROMETHEUS}` placeholder that doesn't resolve automatically in Portainer-managed Grafana. Run this script **once** on the server after importing all three dashboards. It patches all three in one pass.

```bash
GRAFANA_USER=admin
GRAFANA_PASS=<your-grafana-password>
AUTH=$(echo -n "${GRAFANA_USER}:${GRAFANA_PASS}" | base64)
DS_UID=$(curl -s http://localhost:3000/api/datasources/name/Prometheus \
  -H "Authorization: Basic ${AUTH}" | python3 -c "import json,sys; print(json.load(sys.stdin)['uid'])")

for UID in rYdddlPWk ae3c41d7-cea5-4cca-a918-5708706b4d1a Oxed_c6Wz; do
  echo "Patching dashboard ${UID}..."
  curl -s http://localhost:3000/api/dashboards/uid/${UID} \
    -H "Authorization: Basic ${AUTH}" > /tmp/dash_${UID}.json

  python3 -c "
import json
with open('/tmp/dash_${UID}.json') as f:
    raw = f.read()
fixed = raw.replace('\${DS_PROMETHEUS}', '${DS_UID}')
data = json.loads(fixed)
payload = {'dashboard': data['dashboard'], 'folderId': data.get('meta',{}).get('folderId',0), 'overwrite': True}
with open('/tmp/dash_${UID}_fixed.json','w') as f:
    json.dump(payload, f)
"
  result=$(curl -s -X POST http://localhost:3000/api/dashboards/db \
    -H "Authorization: Basic ${AUTH}" \
    -H "Content-Type: application/json" \
    -d @/tmp/dash_${UID}_fixed.json | python3 -c "import json,sys; print(json.load(sys.stdin).get('status','unknown'))")
  echo "  → ${result}"
done
echo "Done."
```

### Step 3 — Fix the DCGM dashboard variables

The DCGM dashboard variable queries also need to be pointed at the right datasource. Run this after Step 2:

```bash
GRAFANA_USER=admin
GRAFANA_PASS=<your-grafana-password>
AUTH=$(echo -n "${GRAFANA_USER}:${GRAFANA_PASS}" | base64)
DS_UID=$(curl -s http://localhost:3000/api/datasources/name/Prometheus \
  -H "Authorization: Basic ${AUTH}" | python3 -c "import json,sys; print(json.load(sys.stdin)['uid'])")

curl -s http://localhost:3000/api/dashboards/uid/Oxed_c6Wz \
  -H "Authorization: Basic ${AUTH}" > /tmp/dcgm.json

python3 -c "
import json
with open('/tmp/dcgm.json') as f:
    raw = f.read()
fixed = raw.replace('\${DS_PROMETHEUS}', '${DS_UID}')
data = json.loads(fixed)
dashboard = data['dashboard']
for t in dashboard.get('templating', {}).get('list', []):
    if t.get('name') == 'instance':
        t['datasource'] = {'type': 'prometheus', 'uid': '${DS_UID}'}
        t['query'] = {'query': 'label_values(DCGM_FI_DEV_GPU_UTIL, instance)', 'refId': 'A'}
    if t.get('name') == 'gpu':
        t['datasource'] = {'type': 'prometheus', 'uid': '${DS_UID}'}
        t['query'] = {'query': 'label_values(DCGM_FI_DEV_GPU_UTIL{instance=~\"\$instance\"}, gpu)', 'refId': 'A'}
payload = {'dashboard': dashboard, 'folderId': data.get('meta',{}).get('folderId',0), 'overwrite': True}
with open('/tmp/dcgm_fixed.json','w') as f:
    json.dump(payload, f)
"

curl -s -X POST http://localhost:3000/api/dashboards/db \
  -H "Authorization: Basic ${AUTH}" \
  -H "Content-Type: application/json" \
  -d @/tmp/dcgm_fixed.json | python3 -c "import json,sys; print(json.load(sys.stdin).get('status'))"
```

---

## Verify everything is working

```bash
# All 4 scrape targets should be UP
curl -s http://localhost:9091/api/v1/targets | \
  python3 -c "import json,sys; [print(t['labels']['job'], t['health']) for t in json.load(sys.stdin)['data']['activeTargets']]"

# DCGM metrics should include GPU temp and power
curl -s http://localhost:9400/metrics | grep -E "DCGM_FI_DEV_(GPU_TEMP|POWER_USAGE)"
```

Expected scrape targets: `prometheus`, `dcgm-exporter`, `node-exporter`, `cadvisor` — all `up`.

---

## GPU profiling note

The `compose.yml` includes DCGM profiling metrics (`DCGM_FI_PROF_*`) such as Tensor Core Utilization in the embedded metrics config. These metrics are only collected by datacenter-class NVIDIA GPUs (A100, H100, etc.). On consumer GPUs (RTX series), DCGM logs:

```
Not collecting DCP metrics: This request is serviced by a module of DCGM that is not currently loaded
```

This is a driver-level restriction on consumer hardware — not a config issue. The standard metrics (temperature, power, utilization, framebuffer memory) work correctly on all supported GPUs. The Tensor Core Utilization panel in the DCGM dashboard will show "No data" on consumer cards — this is expected.

---

## Known limitations

| Dashboard | Status | Notes |
|---|---|---|
| Node Exporter Full (`1860`) | ✅ Fully working | All panels operational |
| NVIDIA DCGM (`12239`) | ✅ Working | Tensor Core panel always "No data" on consumer GPUs |
| cAdvisor Docker Insights (`19908`) | ✅ Fully working | All panels operational — replaces dashboard `893` which used deprecated node-exporter metric names |
