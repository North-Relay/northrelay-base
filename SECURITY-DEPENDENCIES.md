# Dependency hardening — September 2026

The reviewed dependency lock now reports zero npm audit findings (including development dependencies). Runtime runners use npm ci rather than separate package installs that replaced lockfile versions. Nodemailer 10 requires Node >=20; these images use Node 22. tsx is a runtime dependency for workers. Prisma 6.19.3 is retained for this repository's existing generated schema; applications must install and generate from their own reviewed locks.

The scoped @prisma/config deepmerge-ts 8.0.2 override resolves the advisory affecting the CLI. Its major-version merge behavior needs rechecking on Prisma upgrades; generation of this repository's client passed.

Build workflows now package files from the reviewed base commit. They no longer silently overwrite them from the platform's moving default branch. Future synchronization must update package files/schema in a PR. Existing application builds should run npm ci after copying their own sources.

Validation: dependency install, full npm audit and Prisma generation passed locally. CI repeats these checks. Container OS packages, bundled npm and the pinned MinIO Go binary remain separate scan targets; an npm audit does not prove an image clean. Remove unused runtime tools in application images or patch/rebuild them before promotion. No image was deployed and no historical credential rotation was performed.
