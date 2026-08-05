# Podman Containerfile for running the pi (or claude) coding agent in an Arch Linux sandbox.
#
# Build:
#   podman build -t pi-sandbox -f Containerfile .

FROM archlinux:latest

# Refresh package databases and install runtime dependencies pi needs
# (curl for the install script, git/ripgrep for tooling, ca-certificates for TLS).
# Refresh the keyring first: on a stale base image `-Syu` can fail because the
# bundled keyring predates the newer repo signatures.
RUN pacman -Sy archlinux-keyring --noconfirm && \
    pacman -Syu --noconfirm \
      base-devel \
      ca-certificates \
      clang \
      curl \
      ffmpeg \
      git \
      mdformat \
      musl \
      nodejs \
      noto-fonts \
      npm \
      prettier \
      python \
      python-pip \
      ripgrep \
      rustup \
      tailscale \
      yt-dlp \
    && pacman -Scc --noconfirm

# Create the unprivileged 'sandbox' user with a home directory.
RUN useradd --create-home -s /usr/bin/bash -u 1000 sandbox

# Install pi via the official installer as the sandbox user so binaries land
# in /home/sandbox/.local and use the sandbox user's PATH.
USER sandbox
WORKDIR /home/sandbox

# Install rust
RUN rustup default stable
RUN rustup target install x86_64-unknown-linux-musl

# Mount point for coding agent configs.
RUN mkdir -p /home/sandbox/.pi /home/sandbox/.claude

# Install pi coding agent.
RUN curl -fsSL https://pi.dev/install.sh | sh

# Install claude code locally under ~/.local so binaries land in ~/.local/bin.
RUN npm config set prefix /home/sandbox/.local && \
    npm install -g --allow-scripts=@anthropic-ai/claude-code @anthropic-ai/claude-code && \
    npm cache clean --force

# Default to a login-style shell for the sandbox user so PATH is set up
# (the installer typically amends ~/.bashrc / profile).
ENV PATH="/home/sandbox/.local/bin:${PATH}"
# run.sh overrides this with `-w /workspace`; /home/sandbox is a sensible,
# user-writable default for bare `docker run` without the bind mount.
WORKDIR /home/sandbox
CMD ["pi"]
