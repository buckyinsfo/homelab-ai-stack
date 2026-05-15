FROM nousresearch/hermes-agent:latest

USER root

# 1. Install System Dependencies (gh is now in Debian Trixie/Bookworm)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      bash curl ca-certificates git gh jq tree ripgrep htop ncdu \
      unzip build-essential python3-dev python3-venv && \
    # 2. Install uv for high-speed package management
    curl -LsSf https://astral.sh/uv/install.sh | BINDIR=/usr/local/bin sh && \
    rm -rf /var/lib/apt/lists/*

# 3. Setup Venv and global tools
RUN python3 -m venv --system-site-packages /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# 4. Use UV to install your python tools (much faster)
RUN uv pip install --no-cache-dir \
    youtube-transcript-api

# Return to non-root user (important for agent security)
USER 10000 
