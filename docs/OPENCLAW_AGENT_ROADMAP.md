# OpenClaw Agent Roadmap

A learning roadmap for building custom OpenClaw agents, starting with a practical bug reporter and expanding into more complex automation.

---

## Agent 1: Bug Reporter

**Goal:** Take a structured markdown doc (like `ROCKY10_WIFI_SETUP.md`) and transform it into a properly formatted bug report for submission to a project's issue tracker.

### What you'll learn

- OpenClaw agent/skill architecture — how tools, prompts, and configs fit together
- Structured output — getting the LLM to produce a specific format reliably
- Tool use basics — reading files, formatting data, calling APIs

### How it works

1. **Input:** A markdown file path + target project (e.g., "Rocky Linux")
2. **Processing:** The agent reads the doc and extracts:
   - Environment details (OS version, kernel, hardware)
   - Steps to reproduce
   - Expected vs actual behavior
   - Root cause (if known)
   - Workaround / fix
3. **Output:** A formatted bug report ready for submission, structured as:
   - Title (concise, searchable)
   - Environment section
   - Description
   - Steps to reproduce
   - Expected behavior
   - Actual behavior
   - Workaround
   - Additional context (dmesg output, config files, etc.)

### Implementation sketch

```
agent/
  bug-reporter/
    config.json          # Agent definition — name, description, tools
    system-prompt.md     # Instructions for how to read docs and produce reports
    tools/
      read-doc.js        # Tool: read a markdown file from the filesystem
      format-report.js   # Tool: transform extracted data into bug report format
      submit-issue.js    # Tool: POST to Gitea/GitHub API (future)
```

### Milestones

1. **v0.1 — Manual paste:** Agent reads your doc, produces a formatted bug report you copy-paste into the tracker manually
2. **v0.2 — API submission:** Agent calls the Gitea API (`bugs.rockylinux.org`) to create the issue directly
3. **v0.3 — Interactive:** Agent asks clarifying questions if the doc is missing required fields (e.g., no kernel version mentioned)

### Rocky Linux bug report (first target)

**Tracker:** `https://bugs.rockylinux.org` (Gitea instance)

**Suggested title:** `Minimal install missing wireless packages (NetworkManager-wifi, wireless-regdb) — Wi-Fi non-functional despite working in Anaconda`

**Key points to include:**
- Rocky Linux 10.1 minimal (no desktop) install
- MediaTek MT7922 (mt7921e driver) — Wi-Fi worked in Anaconda installer
- Post-install: `nmcli device wifi list` → "No Wi-Fi device found"
- NM logs: `'wifi' plugin not available; creating generic device`
- Missing packages: `wireless-regdb`, `NetworkManager-wifi` (+ `wpa_supplicant` dep)
- Also: `/etc/NetworkManager/conf.d/10-managed.conf` sets device unmanaged by default
- Fix: install the three packages, update NM config, reload driver

---

## Agent 2: Stack Health Monitor (future)

**Goal:** An agent that checks the health of your Docker stacks and reports issues.

### What you'll learn

- Long-running / scheduled agent patterns
- Multi-tool orchestration (SSH, Docker API, Prometheus queries)
- Alert formatting and notification routing

### Rough idea

- Query Prometheus for container health metrics
- Check `docker ps` for crashed or restarting containers
- Compare current state against expected state (from your compose files)
- Produce a summary report or alert via webhook

---

## Agent 3: Doc Maintainer (future)

**Goal:** An agent that keeps your repo docs in sync with actual infrastructure state.

### What you'll learn

- RAG patterns (using qdrant to index your docs)
- Diff detection — comparing doc claims vs reality
- PR/commit workflows — agent proposes doc updates as PRs

### Rough idea

- Index all markdown docs in the repo into qdrant
- Periodically compare documented ports, versions, and configs against live state
- Flag discrepancies and draft updates
- Optionally create a PR via GitHub API

---

## Getting Started

Before building the bug reporter agent, get familiar with how OpenClaw skills work:

1. **Read the OpenClaw docs** on custom skills/agents (check their GitHub wiki or docs site)
2. **Look at an existing skill** — examine the file structure in `/srv/openclaw/config/skills/` on camp-fai
3. **Start with v0.1** — just the read + format flow, no API calls. Get the LLM producing clean bug reports from your markdown docs
4. **Iterate** — add API submission once the formatting is solid

The bug reporter is a great first agent because it's useful immediately (you have a real bug to report), the scope is small enough to finish in a session or two, and it touches all the fundamentals without requiring complex orchestration.
