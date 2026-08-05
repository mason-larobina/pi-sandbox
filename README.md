# pi-sandbox

Podman sandbox for running the [pi](https://pi.dev) (or Claude Code) coding agent
in an isolated Arch Linux container, with your configs and the current directory
mounted in.

## Prerequisites

- [Podman](https://podman.io/) (or Docker, with minor mount tweaks)

## Build

```sh
./build.sh
```

This builds the `sandbox` image from the `Containerfile` (installs pi, Claude
Code, and the tools they need).

## Run

```sh
./run.sh <args...>
```

The current directory is mounted at `/workspace` inside the container. Your
`~/.pi`, `~/.claude`, `~/.claude.json`, and `~/.gitconfig` are mounted read/write
(or read-only for gitconfig) so agent configs persist on the host. Arguments
are passed through, e.g.:

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
