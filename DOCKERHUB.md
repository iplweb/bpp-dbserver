<p align="center">
  <img src="https://github.com/iplweb/bpp/raw/dev/src/bpp/static/bpp/images/logo_bpp.png" width="480" alt="Logo BPP">
</p>

<h1 align="center">bpp-dbserver — PostgreSQL dla BPP</h1>

<p align="center">
  <b>Wsparcie komercyjne zapewnia</b><br><br>
  <a href="https://bpp.iplweb.pl"><img src="https://www.iplweb.pl/images/ipl-logo-large.png" width="150" alt="IPL Web"></a>
</p>

<p align="center">
  <a href="https://github.com/iplweb/bpp-dbserver">Source on GitHub</a> •
  <a href="https://www.iplweb.pl">iplweb.pl</a> •
  <a href="https://bpp.iplweb.pl">bpp.iplweb.pl</a>
</p>

---

## Co to jest

Obraz Dockera z PostgreSQL-em przygotowany pod aplikację **BPP — Bibliografia
Publikacji Pracowników** ([bpp.iplweb.pl](https://bpp.iplweb.pl)). Bazuje na
oficjalnym `postgres:*` z dołożonymi:

- **`plpython3u`** — proceduralny Python dla PostgreSQL (wymagany przez funkcje BPP).
- **Locale `pl_PL.UTF-8`** + **ICU collation `pl-PL`** — poprawne sortowanie polskich znaków.
- **Autotune** — dynamiczna konfiguracja pamięci i parallelizmu PG na podstawie cgroup / `/proc/meminfo` / env vars.
- **Healthcheck** (`pg_isready`).
- **`apt-get upgrade`** przy buildzie — patche Debiana podciągnięte bez czekania na rebuild upstream.

## Tagi

**Brak tagu `:latest`** — celowo, żeby przypadkowy `docker pull` nie ściągnął
niekompatybilnej major wersji PG i nie uszkodził istniejącego `PGDATA`.

| Tag | Przykład | Znaczenie |
|---|---|---|
| `psql-<MAJOR>.<MINOR>` | `psql-16.13` | Pinning do konkretnej wersji patch. Zalecane dla produkcji. |
| `psql-<MAJOR>` | `psql-16` | Rolling w ramach jednej major. OK dla dev/CI. |

Aktualnie wspierane: **PG 16, 17, 18**.

## Quickstart

```bash
docker run --rm -d \
    --name bpp-db \
    -e POSTGRES_PASSWORD=secret \
    -p 5432:5432 \
    iplweb/bpp_dbserver:psql-16.13
```

## docker compose

```yaml
services:
  db:
    image: iplweb/bpp_dbserver:psql-16.13
    environment:
      POSTGRES_PASSWORD: ${DB_PASSWORD:?required}
      POSTGRES_HOST_AUTH_METHOD: scram-sha-256   # NIE zostawiaj domyślnego 'trust' w produkcji
      POSTGRESQL_RAM_THIS_MUCH_GB: 8192          # opcjonalnie
    volumes:
      - pgdata:/var/lib/postgresql/data
    ports:
      - "5432:5432"
volumes:
  pgdata:
```

## Najważniejsze env vars

| Zmienna | Default | Opis |
|---|---|---|
| `POSTGRES_PASSWORD` | — | Hasło superusera. **Wymagane** w produkcji. |
| `POSTGRES_HOST_AUTH_METHOD` | `trust` (!) | Dev only. W produkcji: `scram-sha-256`. |
| `POSTGRESQL_RAM_PERCENT` | `0.95` | Ułamek RAM dla Postgresa. |
| `POSTGRESQL_RAM_THIS_MUCH_GB` | auto-detect | Override rozmiaru RAM (MB). |
| `POSTGRESQL_MAX_LOCKS_PER_TRANSACTION` | 64 (PG default) | Podnoś dla pytest-xdist / Celery. |
| `POSTGRESQL_UNSAFE_BUT_FAST` | — | Dev only — wyłącza fsync/WAL/synchronous_commit. NIGDY w prod. |

Pełna lista, szczegóły autotune i parametry build-time:
[github.com/iplweb/bpp-dbserver](https://github.com/iplweb/bpp-dbserver#parametry-konfiguracyjne).

## ⚠ Upgrade major → major

**Nie podmieniaj tagu** między major wersjami na tym samym volumenie. Plik
`PG_VERSION` w `PGDATA` trzyma major, a binaria nowej major odmówią startu
albo, co gorsza, uszkodzą dane. Użyj `pg_upgrade` albo `pg_dump` + `pg_restore`.

## O projekcie

BPP to otwartoźródłowy (MIT) system do katalogowania bibliografii publikacji
pracowników naukowych — dla bibliotek uniwersyteckich w Polsce.

- 💻 **Kod dbservera**: [github.com/iplweb/bpp-dbserver](https://github.com/iplweb/bpp-dbserver)
- 📦 **Aplikacja BPP**: [github.com/iplweb/bpp](https://github.com/iplweb/bpp)
- 🌐 **Demo / instalacja**: [bpp.iplweb.pl](https://bpp.iplweb.pl)
- 💼 **Wsparcie komercyjne**: [iplweb.pl](https://www.iplweb.pl)

## Licencja

[MIT](https://github.com/iplweb/bpp-dbserver/blob/main/LICENSE) — Copyright © 2017–2026 Michał Pasternak &lt;michal.dtz@gmail.com&gt;.
