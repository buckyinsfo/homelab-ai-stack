FROM ghcr.io/openclaw/openclaw:latest

USER root

RUN apt-get update && \
    apt-get install -y --no-install-recommends bash curl ca-certificates unzip git gh jq tree ripgrep htop ncdu python3-venv && \
    rm -rf /var/lib/apt/lists/*

ENV BUN_INSTALL=/opt/bun
ENV PATH="${BUN_INSTALL}/bin:/root/.bun/bin:${PATH}"

RUN set -eux; \
    export BUN_INSTALL=/opt/bun; \
    curl -fsSL https://bun.sh/install | bash; \
    if [ -x /opt/bun/bin/bun ]; then \
      ln -sf /opt/bun/bin/bun /usr/local/bin/bun; \
    elif [ -x /root/.bun/bin/bun ]; then \
      ln -sf /root/.bun/bin/bun /usr/local/bin/bun; \
    fi; \
    bun --version; \
    bun install -g github:tobi/qmd || true; \
    if command -v qmd >/dev/null 2>&1; then \
      true; \
    elif [ -x /opt/bun/bin/qmd ]; then \
      ln -sf /opt/bun/bin/qmd /usr/local/bin/qmd; \
    elif [ -x /root/.bun/bin/qmd ]; then \
      ln -sf /root/.bun/bin/qmd /usr/local/bin/qmd; \
    else \
      npm install -g @tobilu/qmd; \
    fi; \
    command -v qmd >/dev/null 2>&1

RUN chown -R node:node /opt/bun

# Install fnm and pnpm
ENV FNM_DIR=/opt/fnm
ENV PATH="/opt/fnm:/root/.local/share/fnm:${PATH}"

RUN set -eux; \
    curl -fsSL https://fnm.vercel.app/install | bash -s -- --install-dir /opt/fnm --skip-shell; \
    ln -sf /opt/fnm/fnm /usr/local/bin/fnm; \
    fnm install --lts; \
    FNM_NODE_PATH=$(ls -d /opt/fnm/node-versions/*/installation/bin | tail -1); \
    ln -sf ${FNM_NODE_PATH}/node /usr/local/bin/node; \
    ln -sf ${FNM_NODE_PATH}/npm /usr/local/bin/npm; \
    ln -sf ${FNM_NODE_PATH}/corepack /usr/local/bin/corepack; \
    corepack enable; \
    corepack prepare pnpm@latest --activate; \
    pnpm --version

RUN chown -R node:node /opt/fnm

USER node
