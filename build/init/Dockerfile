ARG MUSICBRAINZ_IMAGE=metabrainz/musicbrainz-docker-musicbrainz:v-2026-07-30.1-build0

FROM ${MUSICBRAINZ_IMAGE}

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
      postgresql-client \
      curl \
      jq \
      netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

# Copy Solr helper scripts from the local build context
COPY build/solr/scripts/fetch-backup-archives /usr/local/bin/
COPY build/solr/scripts/load-backup-archives /usr/local/bin/
COPY build/solr/scripts/remove-backup-archives /usr/local/bin/

COPY scripts/init.sh /usr/local/bin/init.sh
RUN chmod +x /usr/local/bin/init.sh

ENTRYPOINT ["init.sh"]
