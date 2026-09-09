# Maintained MinIO client build

The runners retain the backup client's CLI. Its archived upstream source is pinned to commit 77f82e18b5401a65958f1619df6ebb994634bd88. Docker verifies the source archive SHA-256 before unpacking it.

The adjacent go.mod and go.sum replace the upstream dependency graph. They update the vulnerable Go crypto, network, system, text, gRPC and Prometheus dependencies. Development lint tools were removed from this binary's module graph. Both runners compile the same static binary with pinned Go 1.27 and GOTOOLCHAIN=local, using -mod=readonly.

Updating requires reviewing the upstream source revision, archive checksum, module lock and compiler digest together, then building and scanning both runner images. CI exercises the client as the non-root application user, including a local backup-file copy. No S3 credentials are used in CI.
