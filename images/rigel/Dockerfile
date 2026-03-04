FROM nvidia/cuda:12.3.0-runtime-ubuntu22.04

WORKDIR /miner

RUN apt-get update && \
    apt-get install -y wget unzip && \
    rm -rf /var/lib/apt/lists/*

RUN wget https://github.com/rigelminer/rigel/releases/download/1.23.0/rigel-1.23.0-linux.tar.gz && \
    tar -xvf rigel-1.23.0-linux.tar.gz && \
    mv rigel-* rigel && \
    chmod +x rigel

ENTRYPOINT ["/miner/rigel"]