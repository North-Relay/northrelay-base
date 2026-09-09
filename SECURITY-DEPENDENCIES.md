# Dependency hardening — September 2026

Application dependencies and Prisma 6.19.3 remain governed by this repository's reviewed lock. The independently locked npm 11.19.1 toolchain replaces the older bundled npm in builders and reports zero npm audit findings. Runners remove package managers after installation.

The old MinIO release binary has been replaced by a source build using a pinned Go 1.27 compiler and updated crypto, network, system, text, gRPC Prometheus and etcd modules. The client remains available for backup scripts. The Go dependency lock and source provenance are in tools/mc.

All four built images now receive smoke tests and complete vulnerability scans before publication. See SECURITY.md for the release gate and version 2 migration details.
