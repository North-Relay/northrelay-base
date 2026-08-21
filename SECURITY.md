# Security triage for `northrelay-base`

This repo builds the base images the platform is built on
(`ghcr.io/north-relay/northrelay-base:{builder,runner}-alpine-latest`).
Two things about it routinely mislead an alert responder, so they're written
down here.

## 1. The committed `package-lock.json` is a mirror, not the source of truth

`package.json`, `package-lock.json`, `.npmrc` and `prisma/schema.prisma` are
**re-fetched from `North-Relay/northrelay-platform` at build time** by the
`fetch-deps` job before any image is built. The copies committed here are only
used by a local `docker build`, and they drift as soon as the platform moves.

Consequences when triaging:

- Dependabot alerts on this repo's `package-lock.json` describe a **stale
  artifact that CI never builds**. They are near-duplicates of the alerts on
  `northrelay-platform`, which is where the fix belongs.
- Fixing a dependency CVE means bumping it in **`northrelay-platform`**, then
  rebuilding here (push to `main`, the weekly Sunday cron, or a
  `deps-updated` `repository_dispatch`).
- Bumping only this repo's lockfile changes nothing about what ships.

Check `northrelay-platform` first. If the CVE is already fixed there, the
alert here is noise pending the next base rebuild.

## 2. Accepted risk lives in `.trivyignore.yaml`, and nowhere else

`.trivyignore.yaml` is the single reviewed list of CVEs this project accepts.
It is read by Trivy (via the `trivyignores:` input in the build workflows) and
by `dismiss-false-positives.sh`, which will only dismiss a Code Scanning alert
whose CVE is listed there.

To accept a risk, add an entry with a `statement` a reviewer can argue with.
To auto-dismiss a **critical or high**, the entry additionally needs a
`# severity_ack: true` comment — a deliberate second step.

### What not to do

Do not scope acceptances by `paths:`, and do not select alerts by matching
`most_recent_instance.location.path`. These workflows scan **images**, so
Trivy reports OS and language packages and the SARIF location is the image
reference: every alert on this repo reports the path
`north-relay/northrelay-base`. Path matching therefore cannot tell two
findings apart.

That is not hypothetical. `dismiss-false-positives.sh` previously carried a
rule whose pattern was `north-relay/northrelay-base`, written to silence one
Alpine zlib CVE. It matched every open alert — criticals included — and
dismissed them as `won't fix`, which GitHub treats as sticky, so nothing
reopened on the next scan. The behaviour is pinned shut by
`tests/test-dismiss-false-positives.sh`.

Wildcards (`id: "*"`, `CVE-*`) don't work either: Trivy matches IDs exactly, so
those entries silence nothing while reading as though they do. CI rejects them.

## 3. What CI enforces

`.github/workflows/security-checks.yml` fails the build on:

- an unpinned `uses:` in any workflow — these jobs hold `security-events: write`
- a wildcard ID or a leftover plain `.trivyignore`
- a `dl.min.io` fetch in a runner Dockerfile with no `sha256sum -c`
- any regression in the dismissal-script tests

## Reporting

Report a suspected vulnerability in the images privately via GitHub Security
Advisories on this repo. Do not open a public issue.
