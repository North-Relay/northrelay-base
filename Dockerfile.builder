# syntax=docker/dockerfile:1
# =============================================================================
# NorthRelay Base Builder Image - SECURITY HARDENED
# =============================================================================
# Pre-bakes all npm dependencies and Prisma client for fast application builds.
# Published to: ghcr.io/north-relay/northrelay-base:builder-<tag>
#
# This image contains:
#   - Node.js 22 LTS (Debian slim, latest digest as of 2026-02-26)
#   - OpenSSL (for Prisma)
#   - All npm dependencies (production + dev)
#   - Generated Prisma client
#
# Security Hardening:
#   - Pinned to latest digest (updated 2026-02-24)
#   - Minimal OS packages (only openssl)
#   - BuildKit cache mounts for faster, cleaner builds
#   - SBOM generation ready (future: --sbom=true)
#
# Usage in application Dockerfile:
#   FROM ghcr.io/north-relay/northrelay-base:builder-latest AS builder
#   COPY . .
#   RUN npm run build
#
# SECURITY NOTE: 
# GitHub Code Scanning will report vulnerabilities in /usr/local/lib/node_modules/npm/
# These are FALSE POSITIVES - npm is bundled with Node.js base image and NOT used
# in production. The application uses Next.js standalone output which doesn't include npm.
# =============================================================================

# Pin to latest digest (verified 2026-02-26, built 2026-02-24)
# Contains: Node.js v22.22.0, npm 10.9.4
FROM node:22-slim@sha256:dd9d21971ec4395903fa6143c2b9267d048ae01ca6d3ea96f16cb30df6187d94

# Install build-time OS dependencies (minimal)
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       openssl \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Set working directory
WORKDIR /app

# Copy dependency files (fetched from platform repo during CI)
COPY package.json package-lock.json ./

# Copy Prisma schema (needed for prisma generate, no DATABASE_URL required)
COPY prisma/schema.prisma prisma/schema.prisma

# Install ALL dependencies (production + dev) with BuildKit cache
# Uses package-lock.json for reproducible builds
RUN --mount=type=cache,target=/root/.npm \
    npm ci --prefer-offline --no-audit --no-fund

# Generate Prisma client (works offline, no database connection needed)
RUN npx prisma generate

# Clean up npm cache and temporary files
RUN npm cache clean --force \
    && rm -rf /tmp/* /var/tmp/* /root/.npm/_cacache

# Set build-time environment
ENV NEXT_TELEMETRY_DISABLED=1
ENV NODE_ENV=production

# Metadata for security scanning
LABEL org.opencontainers.image.title="NorthRelay Base Builder"
LABEL org.opencontainers.image.description="Pre-compiled npm dependencies and Prisma client for NorthRelay platform"
LABEL org.opencontainers.image.vendor="North-Relay"
LABEL org.opencontainers.image.source="https://github.com/North-Relay/northrelay-base"
LABEL org.opencontainers.image.base.name="docker.io/library/node:22-slim"
LABEL org.opencontainers.image.base.digest="sha256:dd9d21971ec4395903fa6143c2b9267d048ae01ca6d3ea96f16cb30df6187d94"
LABEL security.scan.note="npm vulnerabilities in /usr/local/lib/node_modules/npm/ are false positives (bundled with Node.js, not used in production)"
