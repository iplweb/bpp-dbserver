# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Docker image `iplweb/bpp_dbserver` — PostgreSQL base image for the BPP
application ([bpp.iplweb.pl](https://bpp.iplweb.pl)), with `plpython3u`, ICU
`pl-PL` collation, and a Python autotune script that generates a
`postgresql.conf` include at container start.

## Commands

### Build (local)
- All PG majors in matrix: `docker buildx bake`
- Single target: `docker buildx bake dbserver-16-13`
- Print plan (no build): `docker buildx bake --print`
- Override a patch version: `docker buildx bake --set "dbserver-16-13.args.POSTGRES_VERSION=16.14"`

### Autotune self-test
- `python autotune.py --test` — asserts deterministic config for fixed RAM sizes.

### Smoke test
See README "Smoke test" section (loop over `psql-16`, `psql-17`, `psql-18`).

## Architecture

Three moving pieces:

1. **`Dockerfile`** — `FROM postgres:${POSTGRES_VERSION}`, adds `plpython3u`
   using `${PG_MAJOR}` from the base image (one Dockerfile covers all majors).
   Healthcheck via `pg_isready`.
2. **`autotune.py`** — reads cgroup limit → `/proc/meminfo` → `POSTGRESQL_*`
   env overrides; emits a pgtune-style config to stdout. Written to
   `/postgresql_optimized.conf` at startup and included by `postgresql.conf`
   via `include_if_exists`.
3. **`docker-entrypoint-autotune.sh`** — wraps upstream
   `docker-ensure-initdb.sh`, idempotently appends the `include_if_exists`
   line to `postgresql.conf`, runs `autotune.py`, then chains to
   `docker-entrypoint.sh`.

Build matrix lives in `docker-bake.hcl` (variable `POSTGRES_VERSIONS`). CI
in `.github/workflows/build.yml` triggers on git tag `v*` and runs
`docker buildx bake` + Trivy per major.

## Release flow

1. Bump `POSTGRES_VERSIONS` in `docker-bake.hcl` (verify against
   [postgresql.org/support/versioning](https://www.postgresql.org/support/versioning/)).
2. Update `CHANGELOG.md`.
3. Git tag `v<YYYYMMDD>` (e.g. `v20260417`; suffix `.N` if >1/day).
   Push → GH Actions builds matrix + pushes Docker tags + Trivy.

## Non-obvious

- **No `:latest` Docker tag** — by design. Accidental major bump on an
  existing `PGDATA` volume corrupts data, so the image is only published
  under versioned tags (`psql-<X.Y>`, `psql-<X>`).
- **Git tag format is independent of Docker tag format.** Git uses
  `vYYYYMMDD`; Docker uses `psql-X.Y` / `psql-X` (from `docker-bake.hcl`).
- **Default `POSTGRES_HOST_AUTH_METHOD=trust`** in the image is dev/test
  convenience. Production deployments MUST override to `scram-sha-256`.
- `docker-entrypoint-autotune.sh` depends on upstream `docker-ensure-initdb.sh`
  behavior — bumping the base `postgres` image may require re-checking
  entrypoint compatibility.
