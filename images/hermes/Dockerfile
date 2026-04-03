FROM nousresearch/hermes-agent:latest

USER root

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      bash curl ca-certificates git jq tree ripgrep htop ncdu && \
    rm -rf /var/lib/apt/lists/*
