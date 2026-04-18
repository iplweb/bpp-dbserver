# Changelog

Wszystkie istotne zmiany w tym repo są dokumentowane tutaj.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
wersjonowanie tagów git: kalendarzowe `vYYYYMMDD` (sufiks `.N` gdy >1/dzień).
Tagi Docker są niezależne: `psql-<X.Y>` i `psql-<X>` z `docker-bake.hcl`.

## [Unreleased]

## [v20260418.1] — 2026-04-18

### Fixed

- `docker-entrypoint-autotune.sh`: dodane `set -Eeuo pipefail`. Bez tego
  niepowodzenie `docker-ensure-initdb.sh` (np. konflikt layoutu PGDATA na
  PG18 przy starszym obrazie) nie zatrzymywało skryptu, który dalej
  dopisywał `include_if_exists` do hardcoded
  `/var/lib/postgresql/data/postgresql.conf`, zaśmiecając zamontowany
  volume i blokując kolejne próby `initdb` (initdb wymaga pustego katalogu).

## [v20260418] — 2026-04-18

### Fixed

- Wymuszenie klasycznego layoutu `PGDATA=/var/lib/postgresql/data` w
  `Dockerfile`. Upstream `postgres:18+` zmienił default na
  `/var/lib/postgresql/<major>/docker`, co łamało hardcoded ścieżki w
  `docker-entrypoint-autotune.sh` i kompatybilność z istniejącymi
  volume'ami PG16/17. Override jest no-opem dla PG16/17 (ich default) i
  fixem dla PG18.

## [v20260417] — 2026-04-17

### Added

- Wydzielenie obrazu `iplweb/bpp_dbserver` z monorepo `iplweb/bpp` do
  osobnego repozytorium `iplweb/bpp-dbserver`.
- Matrix build po `POSTGRES_VERSIONS` w `docker-bake.hcl` — jeden bake
  buduje PG 16, 17 i 18 równolegle.
- GH Actions workflow (`.github/workflows/build.yml`): trigger na tag
  `v*`, build matrix, push do Docker Hub, Trivy scan per major.
- README z logo BPP oraz IPL Web, linkami do iplweb.pl i bpp.iplweb.pl
  i pełną dokumentacją parametrów runtime (standardowe PG + autotune env vars).
- `LICENSE` (MIT, PL + EN).
- `CLAUDE.md` — krótki opis architektury i komend dla sesji Claude Code.
- Dependabot dla bazowego obrazu `postgres:*` i GH Actions dependencies.

### Changed

- `Dockerfile` używa `${PG_MAJOR}` z base image do instalacji
  `postgresql-plpython3-*` — bez hardcodowanej wersji major.
- Bump PostgreSQL: **16.6 → 16.13**, **17.2 → 17.9**, **18.0 → 18.3**
  (najnowsze stabilne patche wg postgresql.org/support/versioning).
- Schemat tagowania Docker: **tag `:latest` nie jest publikowany**. Zamiast
  tego publikowane są wyłącznie tagi wersjonowane: `psql-<X.Y>` (pin
  patch) i `psql-<X>` (rolling minor w ramach major). Cel: zapobiec
  przypadkowemu pullowi niekompatybilnej major wersji, który mógłby
  uszkodzić `PGDATA`.
- Schemat tagowania git: kalendarzowy `vYYYYMMDD` (+ sufiks `.N`),
  niezależny od schematu tagów Docker.
