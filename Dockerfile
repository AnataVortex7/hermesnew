FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates git sudo openssh-client iproute2 iptables procps xz-utils nano \
    && rm -rf /var/lib/apt/lists/*

# Tailscale
RUN curl -fsSL https://tailscale.com/install.sh | sh

# ttyd (web terminal, fallback access through the Render URL)
RUN curl -fsSL -o /usr/local/bin/ttyd \
    https://github.com/tsl0922/ttyd/releases/latest/download/ttyd.x86_64 \
    && chmod +x /usr/local/bin/ttyd

# Normal user for Hermes
RUN useradd -m -s /bin/bash hermes \
    && echo "hermes ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/hermes

# Install Hermes Agent as that user
USER hermes
WORKDIR /home/hermes
RUN curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash || echo "Hermes install at build failed, will retry at start"

USER root
COPY start.sh /start.sh
COPY hermes-sync /usr/local/bin/hermes-sync
RUN chmod +x /start.sh /usr/local/bin/hermes-sync

CMD ["/start.sh"]
