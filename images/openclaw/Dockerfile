FROM ghcr.io/openclaw/openclaw:latest

USER root

RUN apt-get update && \
    apt-get install -y --no-install-recommends bash curl ca-certificates unzip git && \
    rm -rf /var/lib/apt/lists/*

ENV BUN_INSTALL=/opt/bun
ENV PATH="${BUN_INSTALL}/bin:${PATH}"

RUN curl -fsSL https://bun.sh/install | BUN_INSTALL="${BUN_INSTALL}" bash && \
    "${BUN_INSTALL}/bin/bun" install -g https://github.com/tobi/qmd && \
    command -v qmd >/dev/null 2>&1

RUN chown -R node:node /opt/bun

USER node
