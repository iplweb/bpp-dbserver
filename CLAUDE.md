# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

BPP's tuned PostgreSQL, run on the **stock `postgres` image** (no custom image
is built). Two files are bind-mounted into the container: a Python-free
autotune script and an entrypoint wrapper. Polish collation comes from ICU
(`POSTGRES_INITDB_ARGS`), so no OS `pl_PL` locale is needed. There is no
`plpython3u`, no Python, and no published Docker image.

## Commands

### Autotune self-test
- `sh autotune.sh --test` — asserts deterministic config for fixed RAM sizes
  (Python-free; `autotune.py` is kept only as the parity reference).

### Run / smoke locally
- Bind-mount onto stock postgres (see `examples/docker-compose.yml`):
  `docker compose -f examples/docker-compose.yml up`
- The equivalent `docker run` is documented in the README "Szybki start".

## Architecture

Two moving pieces, both bind-mounted onto `postgres:<major>`:

1. **`autotune.sh`** — pure shell + awk (no Python). Reads cgroup limit →
   `/proc/meminfo` → `POSTGRESQL_*` env overrides; emits a pgtune-style config
   to stdout. Written to `/postgresql_optimized.conf` at startup and included
   by `postgresql.conf` via `include_if_exists`. `autotune.py` is the original
   and is kept as a byte-for-byte parity reference (verify via `sh autotune.sh
   --test`; the two were diffed across forced/host/cgroup/unsafe/lock paths).
2. **`docker-entrypoint-autotune.sh`** — wraps upstream
   `docker-ensure-initdb.sh`, idempotently appends the `include_if_exists`
   line to `$PGDATA/postgresql.conf`, runs `autotune.sh`, then chains to
   `docker-entrypoint.sh`. Python-free and `$PGDATA`-aware so it works on the
   stock image; pin `PGDATA=/var/lib/postgresql/data` (stock PG18+ defaults it
   to `/var/lib/postgresql/<major>/docker`).

CI in `.github/workflows/ci.yml`: autotune self-test, `pre-commit` (ruff +
shellcheck), and a smoke job that bind-mounts onto `postgres:16/17/18` and
checks autotune applied + ICU Polish collation works.

## Non-obvious

- **No custom image / no Docker Hub publish** — by design. Everything BPP needs
  is env vars + two bind-mounted scripts; the only thing a custom build added
  was the OS `pl_PL` locale (messages/number/date formatting), and Polish
  *sorting* is handled by ICU regardless.
- **Polish collation = ICU, not the OS locale.** `--icu-locale=pl-PL` works on
  the stock image with no `pl_PL` locale generated; dropping `LANG=pl_PL` is
  intentional.
- **Default `POSTGRES_HOST_AUTH_METHOD=trust`** in examples is dev/test
  convenience. Production deployments MUST override to `scram-sha-256`.
- `docker-entrypoint-autotune.sh` depends on upstream `docker-ensure-initdb.sh`
  / `docker-entrypoint.sh` behavior — bumping the base `postgres` major may
  require re-checking entrypoint compatibility.
- `autotune.sh` delegates all floating-point math to `awk` (same IEEE-754
  doubles as Python) so unit normalization / `int()` truncation match
  `autotune.py` exactly. Preserve that when editing.
