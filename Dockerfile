#check=skip=SecretsUsedInArgOrEnv
ARG POSTGRES_VERSION=16.13
FROM postgres:${POSTGRES_VERSION}

RUN localedef -i pl_PL -c -f UTF-8 -A /usr/share/locale/locale.alias pl_PL.UTF-8

ENV LANG=pl_PL.utf-8
ENV POSTGRES_INITDB_ARGS="--locale-provider=icu --icu-locale=pl-PL"
ENV POSTGRES_HOST_AUTH_METHOD=trust

HEALTHCHECK --interval=5s --timeout=3s --retries=5 --start-period=10s \
  CMD pg_isready -U "${POSTGRES_USER:-postgres}"

# PG_MAJOR is exported by the upstream postgres image so the plpython3
# package picks the right major version automatically.
# hadolint ignore=DL3005,DL3008
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked,id=apt-cache \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked,id=apt-lists \
    apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
        "postgresql-plpython3-${PG_MAJOR}" \
        python-is-python3

COPY --chmod=755 autotune.py /
COPY --chmod=755 docker-entrypoint-autotune.sh /usr/local/bin/

ENTRYPOINT ["docker-entrypoint-autotune.sh"]

CMD ["postgres"]
