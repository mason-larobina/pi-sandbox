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
      go \
      htop \
      hyperfine \
      imagemagick \
      jdk25-openjdk \
      jq \
      mdformat \
      mdformat-tables \
      musl \
      nodejs \
      noto-fonts \
      npm \
      prettier \
      python \
      python-numpy \
      python-pillow \
      python-pip \
      ripgrep \
      rustup \
      sysstat \
      tailscale \
      unzip \
      yt-dlp \
    && pacman -Scc --noconfirm

# Arch's jdk25-openjdk only links a subset of its tools into /usr/bin. Expose
# the rest on PATH; `jfr` in particular pairs with async-profiler/JFR output.
RUN for tool in jfr jlink jmod jhsdb jstatd serialver; do \
      ln -sf /usr/lib/jvm/java-25-openjdk/bin/"$tool" /usr/local/bin/"$tool"; \
    done

# Create the unprivileged 'sandbox' user with a home directory.
RUN useradd --create-home -s /usr/bin/bash -u 1000 sandbox

# sudo is deliberately left locked: the account has no password and gets no
# NOPASSWD rule, so packages cannot be installed at runtime -- only those baked
# into this image are present. The AUR packages (below) are built as the sandbox
# user and installed by the build's own root, so installing them needs no sudo.

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

# Build AUR packages from source. makepkg refuses to run as root, so build them
# as the sandbox user; the resulting packages are installed as root below. yay's
# `go` makedepend is installed in the system package step above, and flamegraph
# and async-profiler only need perl/awk/java which are already present.
RUN set -e; \
    mkdir -p /home/sandbox/src; \
    for pkg in yay flamegraph async-profiler; do \
      curl -fsSL -o "/home/sandbox/src/$pkg.tar.gz" \
        "https://aur.archlinux.org/cgit/aur.git/snapshot/$pkg.tar.gz"; \
      tar -xzf "/home/sandbox/src/$pkg.tar.gz" -C /home/sandbox/src; \
      ( cd "/home/sandbox/src/$pkg" && makepkg --noconfirm ); \
    done

# Install the built AUR packages, then drop the build tree and Go build cache to
# keep the image small. The `[0-9]*` globs skip the generated -debug packages.
USER root
RUN pacman -U --noconfirm \
      /home/sandbox/src/yay/yay-[0-9]*.pkg.tar.zst \
      /home/sandbox/src/flamegraph/flamegraph-[0-9]*.pkg.tar.zst \
      /home/sandbox/src/async-profiler/async-profiler-[0-9]*.pkg.tar.zst && \
    rm -rf /home/sandbox/src /home/sandbox/.cache/go-build && \
    pacman -Scc --noconfirm
USER sandbox

# Default to a login-style shell for the sandbox user so PATH is set up
# (the installer typically amends ~/.bashrc / profile).
ENV PATH="/home/sandbox/.local/bin:${PATH}"
# run.sh overrides this with `-w /workspace`; /home/sandbox is a sensible,
# user-writable default for bare `docker run` without the bind mount.
WORKDIR /home/sandbox
CMD ["pi"]
