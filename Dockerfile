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

# Hermes version is PINNED (v0.4.0). Change here (and nowhere else) to move to another release tag.
ARG HERMES_VERSION=v2026.3.23
ENV HERMES_VERSION=${HERMES_VERSION}

# Install Hermes Agent as that user - installer script AND code both come from the pinned tag
USER hermes
WORKDIR /home/hermes
RUN curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/${HERMES_VERSION}/scripts/install.sh \
      | bash -s -- --branch ${HERMES_VERSION} --skip-setup \
    || echo "Hermes install at build failed, will retry at start"

USER root
COPY start.sh /start.sh
COPY hermes-sync /usr/local/bin/hermes-sync
RUN chmod +x /start.sh /usr/local/bin/hermes-sync

CMD ["/start.sh"]
