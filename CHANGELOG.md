# Changelog

Wszystkie istotne zmiany w tym repo są dokumentowane tutaj.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
wersjonowanie tagów git: kalendarzowe `vYYYYMMDD` (sufiks `.N` gdy >1/dzień).
Tagi Docker są niezależne: `psql-<X.Y>` i `psql-<X>` z `docker-bake.hcl`.

## [Unreleased]

### Added

- **`autotune.sh`** — port `autotune.py` na czysty shell + awk (bez Pythona),
  identyczny bajt w bajt (zweryfikowane: wymuszony RAM, autodetekcja
  host/cgroup, tryb unsafe, override locków). Self-test: `sh autotune.sh --test`.
- **Tryb „bez budowania obrazu" (Option B):** entrypoint i autotune można
  podmontować (bind-mount) do oficjalnego obrazu `postgres` — nie trzeba
  budować własnego obrazu. Polskie sortowanie zapewnia ICU, więc systemowy
  locale `pl_PL` (ani `LANG`) nie jest potrzebny. Przykład:
  `examples/docker-compose.yml`.

### Changed

- `docker-entrypoint-autotune.sh` jest teraz Python-free (woła `autotune.sh`)
  i respektuje `$PGDATA` zamiast sztywnej ścieżki — dzięki czemu działa też
  podmontowany na stockowym `postgres`.
- CI: self-test autotune to teraz `sh autotune.sh --test` (bez `setup-python`).

### Removed

- **Cały własny obraz i pipeline jego budowy.** Usunięto `Dockerfile`,
  `docker-bake.hcl`, `DOCKERHUB.md` oraz zadania build/scan/push/scout/
  dockerhub w CI. Repo nie publikuje już obrazu `iplweb/bpp_dbserver` —
  autotune + ICU pl-PL uruchamia się przez bind-mount na oficjalnym
  `postgres` (patrz `examples/docker-compose.yml`). CI sprowadza się teraz
  do self-testu, `pre-commit` i smoke testu na stockowym `postgres:16/17/18`.
- Wraz z obrazem znika systemowy locale `pl_PL` (generowany w buildzie) —
  polskie sortowanie i tak zapewnia ICU. `plpython3u` oraz Python (`python3`/
  `python-is-python3`) usunięte już wcześniej; autotune jest w czystym shellu.

### Fixed

- Locale `pl_PL.UTF-8` jest teraz generowane **po** `apt-get upgrade`
  (wcześniej przed instalacją pakietów). Na obrazie bazowym Debian trixie
  `apt-get upgrade` podciąga nowy glibc/locales i regeneruje
  `/usr/lib/locale/locale-archive`, kasując locale zbudowane wcześniej —
  przez co `initdb` padał z `invalid locale settings`.

## [v20260427] — 2026-04-27

### Changed

- Domyślny build jest teraz multi-arch: `linux/amd64` + `linux/arm64`.
  Default zmiennej `PLATFORM` w `docker-bake.hcl` zmieniony z
  `linux/amd64` na `linux/amd64,linux/arm64`. Cel: natywne wsparcie
  Apple Silicon (Mac M1/M2/M3) bez emulacji QEMU. CI smoke test dalej
  leci na `linux/amd64` (runner GH Actions amd64, `--load` nie obsługuje
  multi-arch); multi-arch idzie dopiero w kroku push do Docker Hub.
  Dla single-arch lokalnie:
  `docker buildx bake --set "*.platform=linux/amd64"`.

## [v20260418.1] — 2026-04-18

### Fixed

- `docker-entrypoint-autotune.sh`: dodane `set -Eeuo pipefail`. Bez tego
  niepowodzenie `docker-ensure-initdb.sh` (np. konflikt layoutu PGDATA na
  PG18 przy starszym obrazie) nie zatrzymywało skryptu, który dalej
  dopisywał `include_if_exists` do hardcoded
  `/var/lib/postgresql/data/postgresql.conf`, zaśmiecając zamontowany
  volume i blokując kolejne próby `initdb` (initdb wymaga pustego katalogu).

### Added

- CI: smoke test obrazu przed pushem do Docker Hub. Build zawsze robi
  `--load`, następnie dla każdego majora PG 16/17/18 startuje kontener,
  czeka na `pg_isready`, weryfikuje `CREATE EXTENSION plpython3u` oraz
  obecność kolacji `pl-x-icu`. Push na Docker Hub tylko przy tagu
  `v*` (lub `workflow_dispatch` z `push_to_registry=true`) i wyłącznie
  gdy smoke przeszedł. Job odpala się teraz też na PR/main (bez pusha),
  żeby łapać regresje przed releasem.

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
