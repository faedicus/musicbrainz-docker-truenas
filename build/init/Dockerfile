# Init image: based on the musicbrainz image so createdb.sh and the Perl
# environment are available. Solr index helper scripts are copied from the
# search image build stage.

ARG POSTGRES_VERSION=18
ARG MB_SOLR_VERSION=4.1.0

# Stage 1: grab the Solr index helper scripts from the search image
FROM musicbrainz-docker_search:${MB_SOLR_VERSION} AS search-scripts
# The scripts are assumed to live in /usr/local/bin in the search image.
# If they are elsewhere, adjust the COPY paths below.

# Stage 2: init runtime image
FROM musicbrainz-docker_musicbrainz:latest
USER root

# Install tools needed by the init script
RUN apt-get update && apt-get install -y --no-install-recommends \
      postgresql-client \
      curl \
      jq \
      netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

# Copy Solr helper scripts from the search image
COPY --from=search-scripts /usr/local/bin/fetch-backup-archives /usr/local/bin/
COPY --from=search-scripts /usr/local/bin/load-backup-archives /usr/local/bin/
COPY --from=search-scripts /usr/local/bin/remove-backup-archives /usr/local/bin/

# Fallback: copy scripts from the forked build context if they are vendored
COPY build/solr/scripts/* /usr/local/bin/ 2>/dev/null || true

COPY scripts/init.sh /usr/local/bin/init.sh
RUN chmod +x /usr/local/bin/init.sh

ENTRYPOINT ["init.sh"]
