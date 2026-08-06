ARG MUSICBRAINZ_IMAGE=metabrainz/musicbrainz-docker-musicbrainz:v-2026-07-30.1-build0
ARG MB_SOLR_VERSION=4.1.0

# Stage 1: Solr helper scripts from the search image
FROM metabrainz/mb-solr:${MB_SOLR_VERSION} AS search-scripts

# Stage 2: init runtime image
FROM ${MUSICBRAINZ_IMAGE}

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
      postgresql-client \
      curl \
      jq \
      netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

COPY --from=search-scripts /usr/local/bin/fetch-backup-archives /usr/local/bin/
COPY --from=search-scripts /usr/local/bin/load-backup-archives /usr/local/bin/
COPY --from=search-scripts /usr/local/bin/remove-backup-archives /usr/local/bin/

COPY scripts/init.sh /usr/local/bin/init.sh
RUN chmod +x /usr/local/bin/init.sh

ENTRYPOINT ["init.sh"]
