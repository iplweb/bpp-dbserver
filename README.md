<p align="center">
  <img src="https://github.com/iplweb/bpp/raw/dev/src/bpp/static/bpp/images/logo_bpp.png" width="480" alt="Logo BPP">
</p>

<h1 align="center">bpp-dbserver — autostrojony PostgreSQL dla BPP</h1>

<p align="center">
  <a href="https://github.com/iplweb/bpp-dbserver/actions/workflows/ci.yml"><img src="https://github.com/iplweb/bpp-dbserver/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
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

Lekka konfiguracja PostgreSQL dla aplikacji **BPP** (Bibliografia Publikacji
Pracowników) — uruchamiana na **oficjalnym obrazie `postgres`**, bez budowania
własnego obrazu. Dwa pliki podmontowuje się (bind-mount) do kontenera:

- **`autotune.sh`** — czysty skrypt **shell + awk** (bez Pythona). Na starcie
  czyta limit pamięci z cgroup (limit kontenera) lub `/proc/meminfo` (host)
  i generuje konfigurację w stylu pgtune (`shared_buffers`, `work_mem`,
  parallelizm itd.), dołączaną przez `include_if_exists`.
- **`docker-entrypoint-autotune.sh`** — entrypoint, który inicjalizuje bazę
  standardowo, uruchamia autotune i przekazuje sterowanie do upstreamowego
  `docker-entrypoint.sh`.

**Polskie sortowanie** zapewnia **ICU** (`--locale-provider=icu --icu-locale=pl-PL`)
ustawiane przez zmienną `POSTGRES_INITDB_ARGS` — więc **nie jest potrzebny**
systemowy locale `pl_PL` (ani `LANG`). Brak własnego obrazu = brak `plpython3u`,
brak Pythona, brak osobnego cyklu wydawniczego obrazu.

> **Dlaczego nie własny obraz?** Wszystko, czego potrzebuje BPP, da się ustawić
> zmiennymi środowiskowymi (ICU, `PGDATA`, auth) plus podmontowanym autotune.
> Jedyne, co dawał własny build, to systemowy locale `pl_PL` (komunikaty /
> formatowanie liczb i dat po polsku) — sortowanie i tak załatwia ICU.

---

## Szybki start

### docker compose

Gotowy przykład: [`examples/docker-compose.yml`](examples/docker-compose.yml):

```bash
docker compose -f examples/docker-compose.yml up
```

### docker run

```bash
docker run --rm -d --name bpp-db \
    --memory=2g \
    -e POSTGRES_HOST_AUTH_METHOD=trust \
    -e PGDATA=/var/lib/postgresql/data \
    -e POSTGRES_INITDB_ARGS="--locale-provider=icu --icu-locale=pl-PL" \
    -v "$PWD/docker-entrypoint-autotune.sh:/usr/local/bin/docker-entrypoint-autotune.sh:ro" \
    -v "$PWD/autotune.sh:/autotune.sh:ro" \
    -p 5432:5432 \
    --entrypoint bash \
    postgres:18 /usr/local/bin/docker-entrypoint-autotune.sh postgres
```

Autotune skaluje konfigurację do limitu `--memory` / `mem_limit` kontenera.
Wspierane major wersje PostgreSQL: **16, 17, 18** (dowolny tag `postgres:*`).

> **`POSTGRES_HOST_AUTH_METHOD=trust`** w przykładach to wygoda dev/test —
> kontener ufa wszystkim połączeniom **bez hasła**. W produkcji ustaw
> `-e POSTGRES_PASSWORD=… -e POSTGRES_HOST_AUTH_METHOD=scram-sha-256`.

---

## Parametry konfiguracyjne

### Runtime — standardowe Postgres

| Zmienna | Default | Opis |
|---|---|---|
| `POSTGRES_PASSWORD` | — | Hasło superusera. **Wymagane**, chyba że `POSTGRES_HOST_AUTH_METHOD=trust` (dev only). |
| `POSTGRES_USER` | `postgres` | Nazwa superusera. |
| `POSTGRES_DB` | `$POSTGRES_USER` | Domyślna baza tworzona na starcie. |
| `POSTGRES_HOST_AUTH_METHOD` | — (ustaw `trust` dla dev) | W produkcji **MUSI** być `scram-sha-256` lub `md5`. |
| `POSTGRES_INITDB_ARGS` | — (ustaw `--locale-provider=icu --icu-locale=pl-PL`) | Argumenty dla `initdb`; ICU pl-PL daje polskie sortowanie bez systemowego locale. |
| `PGDATA` | `/var/lib/postgresql/data` (zalecane) | Katalog danych. Pinujemy klasyczny układ; stock `postgres:18+` domyślnie użyłby `/var/lib/postgresql/18/docker`. |

### Runtime — autotune

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

Formuły pochodzą z pgtune z drobnymi modyfikacjami — szczegóły w komentarzach
w `autotune.sh`. Skrypt jest portem oryginalnego `autotune.py` (zachowanego
jako referencja) i daje **identyczny bajt w bajt** wynik.

### Volumes / persistence

- Zamountuj volume na `PGDATA` (`/var/lib/postgresql/data`), inaczej dane
  zostaną utracone przy `docker rm`.
- **Nie podpinaj tego samego volumenu pod inną major wersję** `postgres`
  (np. `postgres:16` → `postgres:17`) — plik `PG_VERSION` w `PGDATA` trzyma
  major, a binaria z nowej major odmówią startu lub uszkodzą dane.
- Upgrade major → major: `pg_upgrade` (dwa podmapowane kontenery) albo
  `pg_dump` + `pg_restore`.

---

## Self-test

`autotune.sh` ma wbudowany test deterministycznych wartości:

```bash
sh autotune.sh --test     # -> OK
```

CI (`.github/workflows/ci.yml`) odpala self-test, `pre-commit` (ruff +
shellcheck) oraz smoke test: podmontowuje autotune na stockowy
`postgres:16/17/18` i weryfikuje, że konfiguracja jest strojona i działa
polskie sortowanie ICU.

---

## Historia

Wcześniej to repo budowało i publikowało własny obraz
`iplweb/bpp_dbserver:psql-<X.Y>` na Docker Hub (z `plpython3u`, później bez).
Okazało się jednak, że całą wartość (autotune + ICU pl-PL) da się dostarczyć
**bez własnego obrazu** — przez podmontowanie skryptów do oficjalnego
`postgres`. Usunięto więc `Dockerfile`, `docker-bake.hcl` oraz pipeline
budowania/publikacji obrazu; autotune przepisano z Pythona na czysty shell.

## O BPP

BPP (Bibliografia Publikacji Pracowników) to otwartoźródłowy (MIT) system
informatyczny do katalogowania bibliografii publikacji pracowników naukowych —
skierowany do bibliotek naukowych i uniwersyteckich w Polsce. Więcej:

- [bpp.iplweb.pl](https://bpp.iplweb.pl) — strona projektu, live demo, instalacja
- [github.com/iplweb/bpp](https://github.com/iplweb/bpp) — repozytorium aplikacji
- [iplweb.pl](https://www.iplweb.pl) — wsparcie komercyjne

## Licencja

[MIT](LICENSE) — Copyright (c) 2017-2026 Michał Pasternak &lt;michal.dtz@gmail.com&gt;.
