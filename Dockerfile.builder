# syntax=docker/dockerfile:1
# Locked application dependencies and scanned tooling; see SECURITY.md.

FROM node:22-slim@sha256:83f487e0a63425e5b4d146fb5e5be574bcbe1b7b843d3ebafdd95eaf7767a7e5
RUN apt-get update && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends openssl python3 make g++ \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
# Replace Node's bundled npm with the separately reviewed maintenance release.
COPY tools/npm/package.json tools/npm/package-lock.json /opt/build-npm/
RUN npm ci --prefix /opt/build-npm --ignore-scripts --no-audit --no-fund \
    && rm -rf /usr/local/lib/node_modules/npm /usr/local/lib/node_modules/corepack /opt/yarn-* \
    && rm -f /usr/local/bin/npm /usr/local/bin/npx /usr/local/bin/corepack /usr/local/bin/yarn /usr/local/bin/yarnpkg \
    && ln -s /opt/build-npm/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
    && ln -s /opt/build-npm/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx
COPY package.json package-lock.json ./
COPY prisma/schema.prisma prisma/schema.prisma
RUN --mount=type=cache,target=/root/.npm \
    npm ci --prefer-offline --no-audit --no-fund --legacy-peer-deps \
    && npx prisma generate \
    && npm cache clean --force

ENV NEXT_TELEMETRY_DISABLED=1 NODE_ENV=production
LABEL org.opencontainers.image.source="https://github.com/North-Relay/northrelay-base"
LABEL org.opencontainers.image.base.name="docker.io/library/node:22-slim"
LABEL org.opencontainers.image.base.digest="sha256:83f487e0a63425e5b4d146fb5e5be574bcbe1b7b843d3ebafdd95eaf7767a7e5"
