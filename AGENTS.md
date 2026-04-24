# AGENTS.md — cockroach

Guidance for AI coding agents working in this submodule.

## What this is

Oxide Computer's long-term maintenance fork of CockroachDB 22.1 (BSL
licence). All CCL (enterprise) code has been removed. This is the database
engine used by `multiplayer-fabric-zone-backend` and the hosting stack.
It builds on illumos, Linux, and macOS.

This is a large upstream codebase — do not make application-level changes
here. Only apply patches required for illumos / Linux / macOS build
compatibility or security fixes.

## Build

```sh
make build         # Go-based build (no Bazel required)
```

Pre-built binaries for each commit are published by Buildomat:
```
https://buildomat.eng.oxide.computer/public/file/oxidecomputer/cockroach/<series>/<sha>/cockroach.tgz
```
where `<series>` is `illumos-amd64`, `linux-amd64`, or `darwin-amd64`.

## Key files

| Path | Purpose |
|------|---------|
| `go.mod` | Go module definition |
| `Makefile` | Top-level build entry point |
| `pkg/` | Core database packages |
| `build/` | Build scripts and Docker images |
| `scripts/` | Developer tooling |
| `patches/` | Oxide-specific patches over upstream |

## Conventions

- The repo does not need to be cloned into `$GOPATH` — paths are self-contained.
- Linux builds require Ubuntu 22.04 toolchain (glibc >= 2.35, GCC >= 11).
- Commit message style: sentence case, no `type(scope):` prefix.
  Example: `Apply illumos sendfile compatibility patch`
