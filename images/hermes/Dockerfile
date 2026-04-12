FROM nousresearch/hermes-agent:latest

USER root

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      bash curl ca-certificates git jq tree ripgrep htop ncdu && \
    rm -rf /var/lib/apt/lists/*

RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

RUN pip install --no-cache-dir \
    youtube-transcript-api
