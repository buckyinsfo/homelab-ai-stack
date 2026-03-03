:::writing{variant=“standard” id=“48261”}

camp-fai-infra

Infrastructure repository for the camp-fai AI workstation.
This repo defines all containerized services using Docker Compose stacks deployed through Portainer GitOps.

The goal is simple:

A new machine should be able to rebuild the entire system in minutes by installing Docker + Portainer and connecting this repository.

⸻

System Architecture

Rocky Linux
   │
Docker + NVIDIA Container Toolkit
   │
Portainer
   │
GitOps Repo (this repo)
   │
Stacks
 ├── Mining
 ├── AI tools
 ├── Databases
 ├── Infrastructure
 └── Monitoring

Portainer pulls stack definitions from this repository and deploys them as Docker stacks.

This repo is the single source of truth for infrastructure.

⸻

Repository Structure

camp-fai-infra
│
├── stacks
│   ├── quai-miner
│   │   ├── compose.yml
│   │   └── .env.example
│   │
│   ├── openclaw
│   │   ├── compose.yml
│   │   └── .env.example
│   │
│   ├── ollama
│   │   ├── compose.yml
│   │   └── .env.example
│   │
│   ├── postgres
│   │   ├── compose.yml
│   │   └── .env.example
│   │
│   ├── redis
│   │   ├── compose.yml
│   │   └── .env.example
│   │
│   └── monitoring
│       └── compose.yml
│
└── README.md

Each directory represents one Portainer stack.

⸻

Secrets Strategy

Secrets are never stored in Git.

Instead:

Repository contains:

.env.example

Server contains:

/opt/stacks/<stack-name>/.env

Example .env file:

OPENAI_API_KEY=xxxxxxxx
ANTHROPIC_API_KEY=xxxxxxxx
GEMINI_API_KEY=xxxxxxxx
WALLET=0x0047D81244b5B49bd56D9265583E127aF1AD0d4C
POOL=stratum+tcp://us.quai.herominers.com:1185
WORKER=camp-fai

Compose files reference variables like:

${OPENAI_API_KEY}


⸻

Portainer Deployment Workflow

Deploy stacks via:

Portainer → Stacks → Add Stack → Repository

Example settings:

Repository URL:
https://github.com/<user>/camp-fai-infra

Repository reference:
refs/heads/main

Compose path:
stacks/quai-miner/compose.yml

Portainer will automatically:

git clone
docker compose up


⸻

GPU Container Template

Containers requiring GPU access should include:

runtime: nvidia

Example:

services:
  ollama:
    image: ollama/ollama
    runtime: nvidia


⸻

Mining + AI GPU Mode Strategy

The workstation runs both:
	•	AI workloads
	•	GPU mining

Two simple modes can be used:

Mining Mode

quai-miner stack running
ollama stopped
openclaw stopped

AI Mode

quai-miner stopped
ollama running
openclaw running

This allows GPU resources to be reclaimed instantly.

⸻

Monitoring Stack

Recommended monitoring stack:

Prometheus
Grafana
Node Exporter
NVIDIA GPU Exporter

Metrics collected:
	•	GPU usage
	•	VRAM usage
	•	mining performance
	•	container health
	•	system load

⸻

Docker Volume Strategy

Persistent data should always use named volumes.

Example:

volumes:
  postgres-data:
  ollama-data:

Compose example:

services:
  postgres:
    volumes:
      - postgres-data:/var/lib/postgresql/data


⸻

Backup Strategy

Docker volumes contain critical data such as:
	•	databases
	•	vector indexes
	•	AI model caches
	•	configuration

Backups should be performed automatically.

⸻

Volume Backup Script

Example backup script:

#!/bin/bash

BACKUP_DIR=/backup/docker-volumes
DATE=$(date +%Y-%m-%d)

mkdir -p $BACKUP_DIR

docker run --rm \
  -v /var/lib/docker/volumes:/volumes \
  -v $BACKUP_DIR:/backup \
  alpine \
  tar czf /backup/docker-volumes-$DATE.tar.gz /volumes

This produces:

docker-volumes-YYYY-MM-DD.tar.gz


⸻

Recommended Backup Schedule

Daily incremental backup
Weekly full backup

Example cron job:

0 3 * * * /usr/local/bin/docker-volume-backup.sh


⸻

Restore Procedure

Restore volumes:

docker stop $(docker ps -q)

tar xzf docker-volumes-YYYY-MM-DD.tar.gz -C /

docker start $(docker ps -aq)


⸻

Full Server Recovery Procedure

If the server is lost:
	1.	Install Rocky Linux
	2.	Install Docker
	3.	Install NVIDIA container toolkit
	4.	Install Portainer
	5.	Connect stacks to this repository
	6.	Restore volume backups

System will be fully restored.

⸻

Future Infrastructure

Planned stacks:

OpenClaw agent system
Ollama local LLMs
Postgres
Redis
Vector database
Monitoring stack
Mining stack
Reverse proxy


⸻

Goal

This repository allows the entire AI workstation to be recreated quickly and reliably.

Infrastructure as Code
GitOps deployment
Containerized services
Reproducible system

The system should always be rebuildable from:

Docker + Portainer + this repository

:::
