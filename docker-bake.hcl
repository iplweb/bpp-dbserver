# docker-bake.hcl - Matrix build dla iplweb/bpp_dbserver
#
# Buduje obraz bpp_dbserver dla wszystkich wspieranych major wersji
# PostgreSQL jednym bake'em. NIE publikuje tagu :latest — przypadkowy
# pull mogłby ściągnąć niekompatybilną major i uszkodzić PGDATA.
#
# Lokalny build (wszystkie wersje równolegle):
#   docker buildx bake
#
# Build konkretnej wersji:
#   docker buildx bake dbserver-16-6
#
# Build i push do registry:
#   docker buildx bake --push
#
# Override wersji:
#   docker buildx bake --set dbserver.args.POSTGRES_VERSION=16.6

variable "POSTGRES_VERSIONS" {
  # Najnowsze stabilne patche w każdej wspieranej major. Aktualizować
  # przy release'ach PostgreSQL (patrz https://www.postgresql.org/support/versioning/).
  default = ["16.13", "17.9", "18.3"]
}

variable "PLATFORM" {
  # Multi-arch: x86_64 (linux/amd64) + Apple Silicon / ARM (linux/arm64).
  # Override np. dla lokalnego buildu single-arch:
  #   docker buildx bake --set "*.platform=linux/amd64"
  default = "linux/amd64,linux/arm64"
}

variable "PUSH" {
  default = false
}

group "default" {
  targets = ["dbserver"]
}

target "dbserver" {
  name = "dbserver-${replace(pg, ".", "-")}"
  matrix = {
    pg = POSTGRES_VERSIONS
  }
  dockerfile = "Dockerfile"
  context    = "."
  args = {
    POSTGRES_VERSION = pg
  }
  tags = [
    "iplweb/bpp_dbserver:psql-${pg}",
    "iplweb/bpp_dbserver:psql-${split(".", pg)[0]}"
  ]
  platforms = split(",", PLATFORM)
  output    = PUSH ? ["type=registry"] : ["type=docker"]
}
