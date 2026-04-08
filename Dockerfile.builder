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

# Pin to latest digest (verified 2026-03-19)
# Contains: Node.js v22.x LTS
FROM node:22-slim@sha256:4f77a690f2f8946ab16fe1e791a3ac0667ae1c3575c3e4d0d4589e9ed5bfaf3d

# Install build-time OS dependencies (minimal)
# apt-get upgrade patches OpenSSL and other base image CVEs
RUN apt-get update \
    && apt-get upgrade -y \
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
    npm ci --prefer-offline --no-audit --no-fund --legacy-peer-deps

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
LABEL org.opencontainers.image.base.digest="sha256:4f77a690f2f8946ab16fe1e791a3ac0667ae1c3575c3e4d0d4589e9ed5bfaf3d"
LABEL security.scan.note="npm vulnerabilities in /usr/local/lib/node_modules/npm/ are false positives (bundled with Node.js, not used in production)"
