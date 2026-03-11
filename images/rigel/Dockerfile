FROM nvidia/cuda:12.2.0-runtime-ubuntu22.04

WORKDIR /miner

RUN apt-get update && \
    apt-get install -y wget tar && \
    rm -rf /var/lib/apt/lists/*

ARG RIGEL_VERSION=1.23.1

RUN wget -q https://github.com/rigelminer/rigel/releases/download/${RIGEL_VERSION}/rigel-${RIGEL_VERSION}-linux.tar.gz \
 && tar -xzf rigel-${RIGEL_VERSION}-linux.tar.gz \
 && mv rigel-${RIGEL_VERSION}-linux/rigel /usr/local/bin/rigel \
 && chmod +x /usr/local/bin/rigel \
 && rm -rf rigel*

ENTRYPOINT ["rigel"]