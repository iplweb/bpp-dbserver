<p align="center">
  <img src="https://github.com/iplweb/bpp/raw/dev/src/bpp/static/bpp/images/logo_bpp.png" width="480" alt="Logo BPP">
</p>

<h1 align="center">bpp-dbserver — obraz PostgreSQL dla BPP</h1>

<p align="center">
  <a href="https://github.com/iplweb/bpp-dbserver/actions/workflows/build.yml"><img src="https://github.com/iplweb/bpp-dbserver/actions/workflows/build.yml/badge.svg" alt="Build"></a>
  <a href="https://hub.docker.com/r/iplweb/bpp_dbserver"><img src="https://img.shields.io/docker/pulls/iplweb/bpp_dbserver" alt="Docker Pulls"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License: MIT"></a>
</p>

<p align="center">
  <b>Wsparcie komercyjne zapewnia</b><br><br>
  <a href="https://bpp.iplweb.pl"><img src="https://www.iplweb.pl/images/ipl-logo-large.png" width="150" alt="IPL Web"></a>
</p>

<p align="center">
  <a href="https://www.iplweb.pl">iplweb.pl</a> •
  <a href="https://bpp.iplweb.pl">bpp.iplweb.pl</a> •
  <a href="https://github.com/iplweb/bpp">iplweb/bpp</a>
</p>

## O projekcie

Obraz Dockera z PostgreSQL-em dla aplikacji **BPP** (Bibliografia Publikacji
Pracowników). Bazuje na oficjalnym obrazie `postgres:${POSTGRES_VERSION}`
z dołożonymi:

- **`plpython3u`** — proceduralny język Python dla PostgreSQL (używany
  przez funkcje BPP).
- **Locale `pl_PL.UTF-8`** + **ICU collation `pl-PL`** — poprawne
  sortowanie polskich znaków (`initdb --locale-provider=icu`).
- **Autotune** (`/autotune.py`) — dynamiczna konfiguracja pamięci PG na
  podstawie cgroup/proc, z pgtune jako podstawą.
- **Healthcheck** (`pg_isready`).

Obraz jest publikowany jako `iplweb/bpp_dbserver:psql-<version>` na Docker Hub.

---

## Tagi (Docker Hub)

Obraz publikowany pod **wyłącznie wersjonowanymi** tagami. **Nie istnieje
tag `:latest`** — celowo, żeby przypadkowy `docker pull` nie ściągnął
niekompatybilnej major wersji PG i nie uszkodził istniejącego `PGDATA`.

| Tag | Przykład | Znaczenie |
|---|---|---|
| `psql-<MAJOR>.<MINOR>` | `psql-16.13` | Pinning do konkretnej wersji patch. Zalecane dla produkcji. |
| `psql-<MAJOR>` | `psql-16` | Rolling w ramach jednej major. OK dla dev/CI, w produkcji pinuj patch. |

Aktualnie wspierane major wersje: **16, 17, 18**.

**Upgrade między major wersjami** (np. `psql-16` → `psql-17`) **wymaga**
pg_upgrade albo pg_dump/restore na volumenie `PGDATA`. Nie podmieniaj
tagu w locie na tym samym volumenie — stracisz dane.

---

## Użycie

### docker run (smoke test)

```bash
docker run --rm -d \
    --name bpp-db \
    -e POSTGRES_PASSWORD=secret \
    -p 5432:5432 \
    iplweb/bpp_dbserver:psql-16.13
```

### docker compose (aplikacja BPP)

```yaml
services:
  db:
    image: iplweb/bpp_dbserver:psql-16.13
    environment:
      POSTGRES_PASSWORD: ${DB_PASSWORD:?required}
      POSTGRES_HOST_AUTH_METHOD: scram-sha-256   # NIE zostawiaj domyślnego 'trust' w produkcji
      POSTGRESQL_RAM_THIS_MUCH_GB: 8192          # opcjonalnie: wymusza ilość RAM dla PG
    volumes:
      - pgdata:/var/lib/postgresql/data
    ports:
      - "5432:5432"
volumes:
  pgdata:
```

---

## Parametry konfiguracyjne

### Build-time (ARG)

Zmienne ustawiane na etapie builda (przez `docker buildx bake` lub
`--build-arg`):

| Zmienna | Default | Opis |
|---|---|---|
| `POSTGRES_VERSION` | `16.13` (ARG w Dockerfile) / `["16.13","17.9","18.3"]` (matrix w bake) | Wersja bazowego obrazu `postgres:*`. `Dockerfile` używa `${PG_MAJOR}` eksportowanej z base image, więc instalowany jest `postgresql-plpython3-${PG_MAJOR}` — jeden Dockerfile pokrywa każdą major. |

### Runtime — standardowe Postgres

| Zmienna | Default | Opis |
|---|---|---|
| `POSTGRES_PASSWORD` | — | Hasło superusera. **Wymagane**, chyba że `POSTGRES_HOST_AUTH_METHOD=trust` (dev only). |
| `POSTGRES_USER` | `postgres` | Nazwa superusera. |
| `POSTGRES_DB` | `$POSTGRES_USER` | Domyślna baza tworzona na starcie. |
| `POSTGRES_HOST_AUTH_METHOD` | **`trust`** (!) | Ten obraz domyślnie **ufa wszystkim połączeniom** dla wygody dev/test. W produkcji **MUSI** być nadpisane na `scram-sha-256` lub `md5`. |
| `POSTGRES_INITDB_ARGS` | `--locale-provider=icu --icu-locale=pl-PL` | Argumenty dla `initdb`. Domyślnie ICU pl-PL (sortowanie polskie). |
| `LANG` | `pl_PL.utf-8` | Locale procesu Postgresa (komunikaty, format daty). |
| `PGDATA` | `/var/lib/postgresql/data` | Ścieżka do katalogu danych (dziedziczona z base image). |

### Runtime — autotune.py (**unikalne dla tego obrazu**)

Wszystkie opcjonalne — brak = auto-detekcja z cgroup (limit kontenera)
lub `/proc/meminfo` (host).

| Zmienna | Default | Opis |
|---|---|---|
| `POSTGRESQL_RAM_PERCENT` | `0.95` | Ułamek dostępnego RAM przeznaczony na Postgres (0.0–1.0). |
| `POSTGRESQL_RAM_THIS_MUCH_GB` | — | **Override** detekcji — wymusza podany rozmiar RAM w MB. Używaj gdy docker/cgroup nie eksponuje poprawnego limitu. |
| `POSTGRESQL_DEFAULT_RAM` | `4096` | Fallback (MB) gdy autotune nie może odczytać ani cgroup, ani `/proc/meminfo`. |
| `POSTGRESQL_UNSAFE_BUT_FAST` | — | `1`/`true`/`yes` → tryb niebezpieczny: `fsync=off`, `full_page_writes=off`, `synchronous_commit=off`, `wal_level=minimal`, `max_wal_senders=0`, `archive_mode=off`, `wal_writer_delay=10s`, `commit_delay=100ms`, `random_page_cost=1.1`, `effective_io_concurrency=200`. **NIGDY** w produkcji — ryzyko utraty danych. OK dla testów. |
| `POSTGRESQL_MAX_LOCKS_PER_TRANSACTION` | PG default (64) | Override `max_locks_per_transaction`. Podnoś gdy pytest-xdist lub Celery workery rzucają "out of shared memory". Zalecane: `128` dla CI, `512` dla dev. |
| `POSTGRESQL_MAX_PRED_LOCKS_PER_TRANSACTION` | PG default | Analogicznie dla predicate locks (`SERIALIZABLE` isolation). |

### Parametry generowane przez autotune automatycznie

Autotune ustawia na podstawie RAM i liczby CPU (nie są to env vars):

- `shared_buffers` = RAM / 4
- `effective_cache_size` = RAM × 3/4
- `maintenance_work_mem` = min(RAM/16, 2 GB)
- `max_connections` = min(100 × RAM_GB, 250)
- `work_mem` = (RAM × 3/4) / (max_connections × 3) / max_parallel
- `min_wal_size` = 1 GB, `max_wal_size` = 4 GB
- `wal_buffers` = min(RAM × 3/4 / 100, 16 MB)
- `checkpoint_completion_target` = 0.7
- `default_statistics_target` = 100
- `max_worker_processes` = nproc
- `max_parallel_workers_per_gather` = 1/2/3/4 (zależnie od nproc)
- `max_parallel_workers` = nproc
- `max_parallel_maintenance_workers` = jak gather

Formuły pochodzą z pgtune z drobnymi modyfikacjami — szczegóły w
komentarzach w `autotune.py`.

### Volumes / persistence

- `PGDATA` (`/var/lib/postgresql/data`) — zamountuj volume, inaczej dane
  zostaną utracone przy restarcie kontenera.
- **Nie podmieniaj tagu między major wersjami** na tym samym volumenie
  — plik `PG_VERSION` w `PGDATA` trzyma major, a binaria Postgresa
  z nowej major mogą odmówić startu lub, co gorsza, uszkodzić dane.
- Upgrade major → major: użyj `pg_upgrade` (z dwoma podmapowanymi
  kontenerami) albo `pg_dump` + `pg_restore`.

---

## Build lokalny

```bash
# Wszystkie major wersje z matrixa (docker-bake.hcl)
docker buildx bake --print          # plan
docker buildx bake                  # build lokalny (load do dockerd)

# Konkretna major:
docker buildx bake dbserver-16-13

# Override wersji patch:
docker buildx bake --set "dbserver-16-13.args.POSTGRES_VERSION=16.14"
```

Build w GH Actions (trigger: tag `v*`) publikuje wszystkie 6 tagów
(`psql-16.13`, `psql-16`, `psql-17.9`, `psql-17`, `psql-18.3`, `psql-18`)
do Docker Hub i skanuje każdą major wersję Trivy.

---

## Smoke test (po zbudowaniu / pull)

```bash
for tag in psql-16 psql-17 psql-18; do
  docker run --rm -d --name smoke_$tag \
      -e POSTGRES_PASSWORD=x iplweb/bpp_dbserver:$tag
  sleep 5
  docker exec smoke_$tag psql -U postgres -c "CREATE EXTENSION plpython3u;"
  docker exec smoke_$tag psql -U postgres -c "SHOW lc_collate;"
  docker stop smoke_$tag && docker rm smoke_$tag
done
```

---

## Release flow

1. Update `POSTGRES_VERSIONS` w `docker-bake.hcl` do aktualnych patchy
   (np. po release PostgreSQL — patrz
   [postgresql.org/support/versioning](https://www.postgresql.org/support/versioning/)).
2. Update `CHANGELOG.md` — nota o zmianie patchy.
3. Tag git kalendarzowy: `git tag v<YYYYMMDD>` (np. `v20260417`); gdy
   w tym samym dniu jest więcej niż jedno wydanie, kolejne dostają sufiks
   `.N` (`v20260417.1`, `v20260417.2`, ...). Tag git jest **niezależny** od
   tagów Docker (`psql-<X.Y>`, `psql-<X>`) — te drugie wynikają z
   `docker-bake.hcl`. Push tagu → GH Actions builduje i publikuje.
4. Trivy scan musi przejść (critical/high severity = fail).

---

## Historia

Wcześniej `docker/dbserver/` żył w monorepo
[`iplweb/bpp`](https://github.com/iplweb/bpp) i publikował obraz
`iplweb/bpp_dbserver:latest` razem z appserverem przy każdym release BPP.
Wydzielenie do osobnego repo (2026-04) daje:

- niezależny release cycle (bump Postgresa nie wymaga release'u BPP),
- matrix build dla wielu major wersji na raz,
- eliminację tagu `:latest` — bezpieczny pinning po stronie konsumentów.

## O BPP

BPP (Bibliografia Publikacji Pracowników) to otwartoźródłowy (MIT) system
informatyczny do katalogowania bibliografii publikacji pracowników naukowych —
skierowany do bibliotek naukowych i uniwersyteckich w Polsce. Więcej:

- [bpp.iplweb.pl](https://bpp.iplweb.pl) — strona projektu, live demo, instalacja
- [github.com/iplweb/bpp](https://github.com/iplweb/bpp) — repozytorium aplikacji
- [iplweb.pl](https://www.iplweb.pl) — wsparcie komercyjne

## Licencja

[MIT](LICENSE) — Copyright (c) 2017-2026 Michał Pasternak &lt;michal.dtz@gmail.com&gt;.
