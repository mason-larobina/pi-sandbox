# pi-sandbox

Podman sandbox for running the [pi](https://pi.dev) (or Claude Code) coding agent
in an isolated Arch Linux container, with your configs and the current directory
mounted in.

> **Note:** This project is primarily for my personal use and tailored to my own
> setup, so I don't actively review or merge pull requests. If it's useful to
> you, feel free to **fork it and make it your own** — that's the best way to
> get what you want out of it. That said, bug reports and suggestions for
> cleaner approaches are always welcome and reasonable.

## Prerequisites

- [Podman](https://podman.io/) (or Docker, with minor mount tweaks)

## Build

```sh
./build.sh
```

This builds the `sandbox` image from the `Containerfile` (installs pi, Claude
Code, and the tools they need).

The image also includes the [`yay`](https://github.com/Jguer/yay) AUR helper,
the [`flamegraph-git`](https://aur.archlinux.org/packages/flamegraph-git) AUR
package (which tracks upstream `HEAD`), an
[`async-profiler`](https://github.com/async-profiler/async-profiler) build from
upstream `HEAD`, and the JDK's `jfr`, `jlink`, `jmod`, `jhsdb`, `jstatd`, and
`serialver` tools symlinked into `/usr/local/bin`. Everything is installed at
image-build time. `sudo` is intentionally left locked (the `sandbox` account has
no password), so packages cannot be installed at runtime — only those baked into
this image are available. yay still works for read-only operations such as
searching and inspecting the AUR.

## Run

```sh
./run.sh <args...>
```

It is recommended to add a symbolic link to `run.sh` in `~/.local/bin/` so it's
on your `PATH`:

```sh
ln -s "$PWD/run.sh" ~/.local/bin/s
```

I use the short name `s`, so I can launch agents from any directory with e.g.
`s pi` or `s claude`.

The current directory is mounted at `/workspace` inside the container. Your
`~/.pi`, `~/.claude`, `~/.claude.json`, `~/.cargo`, and `~/.gitconfig` are
mounted read/write (or read-only for gitconfig) so agent configs and
`cargo install`-ed binaries persist on the host. `/tmp` is backed by
`~/src/tmp/<date>` (today's date), so each day gets a fresh scratch space and
stale files are easy to spot; set `TMP_DATE=...` to override the date.
Arguments are passed through, e.g.:

```sh
./run.sh            # start the default agent
./run.sh pi help    # run a specific command
```

## Files

| File            | Purpose                              |
| --------------- | ------------------------------------ |
| `Containerfile` | Image definition (Arch + agents)     |
| `build.sh`      | Build the `sandbox` image            |
| `run.sh`        | Launch the container with mount setup |
