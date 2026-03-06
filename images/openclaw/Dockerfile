FROM ghcr.io/openclaw/openclaw:latest

USER root

RUN apt-get update && \
    apt-get install -y --no-install-recommends bash curl ca-certificates unzip git && \
    rm -rf /var/lib/apt/lists/*

ENV BUN_INSTALL=/opt/bun
ENV PATH="${BUN_INSTALL}/bin:${PATH}"

RUN set -eux; \
    export BUN_INSTALL=/opt/bun; \
    curl -fsSL https://bun.sh/install | bash; \
    /opt/bun/bin/bun --version; \
    /opt/bun/bin/bun install -g https://github.com/tobi/qmd; \
    ln -sf /opt/bun/bin/qmd /usr/local/bin/qmd; \
    /usr/local/bin/qmd --help >/dev/null 2>&1

RUN chown -R node:node /opt/bun

USER node
