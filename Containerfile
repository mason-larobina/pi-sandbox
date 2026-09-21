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
# into this image are present. Most software below is compiled as the sandbox
# user and installed by the build's own root, so it needs no sudo; the one
# exception is the yay step, which grants and revokes a NOPASSWD rule inside a
# single layer so the rule never reaches the shipped image.

# Build the remaining software as the sandbox user: makepkg refuses to run as
# root, and npm-installed binaries land in /home/sandbox/.local on the sandbox
# user's PATH. The agents themselves come from the AUR further down, once yay
# exists.
USER sandbox
WORKDIR /home/sandbox

# Install rust
RUN rustup default stable
RUN rustup target install x86_64-unknown-linux-musl

# Mount point for coding agent configs.
RUN mkdir -p /home/sandbox/.pi /home/sandbox/.claude

# Point npm's global prefix at ~/.local so anything `npm install -g`-ed lands on
# the sandbox user's PATH instead of the unwritable /usr. Claude Code itself
# comes from the AUR below, not from npm.
RUN npm config set prefix /home/sandbox/.local

# Build the AUR packages (yay and flamegraph-git) from source. makepkg refuses
# to run as root, so build them as the sandbox user; the packages are installed
# as root below. `go` (yay's makedepend), git, perl, and awk are all provided by
# the system package step above. flamegraph-git tracks upstream HEAD.
RUN set -e; \
    mkdir -p /home/sandbox/src; \
    for pkg in yay flamegraph-git; do \
      curl -fsSL -o "/home/sandbox/src/$pkg.tar.gz" \
        "https://aur.archlinux.org/cgit/aur.git/snapshot/$pkg.tar.gz"; \
      tar -xzf "/home/sandbox/src/$pkg.tar.gz" -C /home/sandbox/src; \
      ( cd "/home/sandbox/src/$pkg" && makepkg --noconfirm ); \
    done

# async-profiler-git's PKGBUILD is stale (it still expects the pre-4.x build
# layout), so build upstream HEAD directly. `make all` is what the AUR package
# runs; only the install paths differ.
RUN git clone --depth 1 https://github.com/async-profiler/async-profiler.git \
      /home/sandbox/src/async-profiler && \
    cd /home/sandbox/src/async-profiler && \
    make all

# Install the AUR packages plus async-profiler, then drop the build trees and Go
# build cache to keep the image small. The `yay-[0-9]*` and `flamegraph-git-r*`
# globs skip any generated -debug packages.
USER root
RUN pacman -U --noconfirm \
      /home/sandbox/src/yay/yay-[0-9]*.pkg.tar.zst \
      /home/sandbox/src/flamegraph-git/flamegraph-git-r*.pkg.tar.zst && \
    install -d /opt/async-profiler/lib /opt/async-profiler/jar /opt/async-profiler/bin && \
    install -m644 /home/sandbox/src/async-profiler/build/lib/libasyncProfiler.so \
                 /opt/async-profiler/lib/ && \
    install -m644 /home/sandbox/src/async-profiler/build/jar/async-profiler.jar \
                 /home/sandbox/src/async-profiler/build/jar/jfr-converter.jar \
                 /opt/async-profiler/jar/ && \
    install -m755 /home/sandbox/src/async-profiler/build/bin/asprof \
                   /home/sandbox/src/async-profiler/build/bin/jfrconv \
                   /opt/async-profiler/bin/ && \
    ln -sf /opt/async-profiler/bin/asprof /usr/local/bin/asprof && \
    ln -sf /opt/async-profiler/bin/jfrconv /usr/local/bin/jfrconv && \
    rm -rf /home/sandbox/src /home/sandbox/.cache/go-build && \
    pacman -Scc --noconfirm

# Install both coding agents from the AUR with yay. yay refuses to run as root
# and shells out to pacman via sudo, so grant the sandbox user a NOPASSWD rule
# for the duration of this one layer and delete it again before the layer is
# committed -- the shipped image still has sudo locked. pi-coding-agent builds
# from source: yay pulls its runtime deps (fd, ripgrep) from the official repos
# and its makedepends (bun, npm) transiently, and --removemake drops those again
# while --cleanafter discards the build tree. claude-code is a prebuilt upstream
# binary; its packaged wrapper sets DISABLE_UPDATES=1, which suits an image
# whose /usr is read-only to the sandbox user anyway.
RUN printf 'sandbox ALL=(ALL) NOPASSWD: ALL\n' > /etc/sudoers.d/99-aur-build && \
    chmod 0440 /etc/sudoers.d/99-aur-build && \
    su - sandbox -c \
      'yay -Syu --noconfirm --removemake --cleanafter pi-coding-agent claude-code' && \
    rm -f /etc/sudoers.d/99-aur-build && \
    rm -rf /home/sandbox/.cache/yay && \
    pacman -Scc --noconfirm
USER sandbox

# Default to a login-style shell for the sandbox user so PATH is set up
# (the installer typically amends ~/.bashrc / profile).
# Include ~/.cargo/bin so `cargo install`-ed binaries are runnable; run.sh
# bind-mounts the host's ~/.cargo here so they persist across container runs.
ENV PATH="/home/sandbox/.cargo/bin:/home/sandbox/.local/bin:${PATH}"
# run.sh overrides this with `-w /workspace`; /home/sandbox is a sensible,
# user-writable default for bare `docker run` without the bind mount.
WORKDIR /home/sandbox
CMD ["pi"]
