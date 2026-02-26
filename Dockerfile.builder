# syntax=docker/dockerfile:1
# =============================================================================
# NorthRelay Base Builder Image
# =============================================================================
# Pre-bakes all npm dependencies and Prisma client for fast application builds.
# Published to: ghcr.io/north-relay/northrelay-base:builder-<tag>
#
# This image contains:
#   - Node.js 20 (Debian slim, pinned by digest)
#   - OpenSSL (for Prisma)
#   - All npm dependencies (production + dev)
#   - Generated Prisma client
#
# Usage in application Dockerfile:
#   FROM ghcr.io/north-relay/northrelay-base:builder-latest AS builder
#   COPY . .
#   RUN npm run build
# =============================================================================

# Pin to specific digest for reproducibility
FROM node:20-slim@sha256:d8a35d586fad3af7abb6fdb9ba972388395405f4d462da9e4a4ddcde67b5e0fb

# Install build-time OS dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends openssl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy dependency files (fetched from platform repo during CI)
COPY package.json package-lock.json ./

# Copy Prisma schema (needed for prisma generate, no DATABASE_URL required)
COPY prisma/schema.prisma prisma/schema.prisma

# Install ALL dependencies (production + dev) with BuildKit cache
RUN --mount=type=cache,target=/root/.npm \
    npm ci

# Generate Prisma client (works offline)
RUN npx prisma generate

# Set build-time environment
ENV NEXT_TELEMETRY_DISABLED=1
ENV NODE_ENV=production
