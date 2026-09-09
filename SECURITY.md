# Base-image security
The committed package.json/package-lock.json and Prisma schema are the reviewed build inputs. CI never replaces them from another repository's moving branch. Builders also install npm 11.19.1 from the separate tools/npm lock; npm's bundled dependencies are audited independently.
## Image tooling
Version 2 uses Alpine for all maintained tags and pins the official Node 22 base by digest. Available Alpine OS updates are applied. Builder images retain the reviewed npm release for application builds. Runtime images remove npm, npx, Yarn and Corepack and run as UID 1001. Invoke runtime workers with Node directly, for example `node node_modules/tsx/dist/cli.mjs src/workers/email-worker.ts`.
The runtime MinIO client remains available for backups. It is compiled from a checksum-verified, pinned source archive with the reviewed tools/mc module locks and a digest-pinned Go compiler. See tools/mc/README.md for provenance and maintenance.
## Release verification
A single build-base.yml workflow builds the builder and runner under all four published tag names on pull requests, main updates and weekly rebuilds. It runs actual image smoke tests and scans OS packages, application dependencies, package-manager internals and compiled Go dependencies at every severity.
Every high/critical vulnerability blocks publication even without a published fix. Any other vulnerability with a published fixed version also blocks publication. Unfixed findings remain visible in full JSON/SARIF reports. Scanner failures and missing reports fail closed. No new ignores or alert dismissals are part of this remediation.
All four variants must pass before publishing the exact saved image artifacts. Commit-SHA tags identify the verified build; latest, dated and version aliases point at that same image. The duplicate publisher was removed. The original SARIF categories are retained so fresh scans resolve the existing alerts.
## Version 2 compatibility
The default builder-latest and runner-latest tags now use Alpine/musl, matching the explicitly named Alpine tags. Old version 1 Debian tags are not overwritten and are no longer maintained; rebuild native dependencies for Alpine when migrating. Runner images no longer provide package managers and now enforce the existing nextjs user. Build/install dependencies in a builder stage. Operators needing a root maintenance operation must explicitly select the user for that operation.
The current northrelay-platform Dockerfile builds from the official Node image with its own dependency lock and scan gate. Republishing these bases does not replace the running platform image.
## Triage
Review the complete scan artifact and the exact image revision. Do not label bundled tooling findings false positives merely because the main web process does not call the tool. The historical dismissal helper remains protected by regression tests and its empty reviewed allowlist; this workflow does not use it.

## Remaining module-level finding

GO-2026-5932 applies to golang.org/x/crypto/openpgp. The client does not import any affected package. Its build rejects those imports and includes the compiled package inventory at /usr/share/minio-mc/compiled-packages.txt. govulncheck v1.8.0 reports zero affected symbols and imported packages. Trivy's module-level warning is retained in reports; it is not dismissed or broadly ignored.
