#!/bin/bash
# Regression tests for dismiss-false-positives.sh
#
# The bug these pin: the script selected alerts by substring-matching
# `most_recent_instance.location.path`. Every Trivy *container*-scan alert on
# this repo reports that path as "north-relay/northrelay-base", so a rule meant
# to silence one Alpine zlib CVE matched all 683 open alerts — criticals
# included — and dismissed them as "won't fix", which GitHub makes sticky.
#
# Run: bash tests/test-dismiss-false-positives.sh

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$REPO_ROOT/dismiss-false-positives.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass=0; fail=0
ok()   { echo "  ✅ $1"; pass=$((pass+1)); }
bad()  { echo "  ❌ $1"; fail=$((fail+1)); }

# ---------------------------------------------------------------------------
# Fixture: shaped like real Trivy SARIF alerts on this repo — note that every
# alert shares the same location.path, which is precisely why path matching
# cannot discriminate between them.
# ---------------------------------------------------------------------------
cat > "$TMP/alerts.json" <<'JSON'
[
  {"number": 101, "state": "open",
   "rule": {"id": "CVE-2023-45853", "security_severity_level": "critical"},
   "most_recent_instance": {"location": {"path": "north-relay/northrelay-base"}}},
  {"number": 102, "state": "open",
   "rule": {"id": "CVE-2026-7210", "security_severity_level": "high"},
   "most_recent_instance": {"location": {"path": "north-relay/northrelay-base"}}},
  {"number": 103, "state": "open",
   "rule": {"id": "CVE-2026-6879", "security_severity_level": "low"},
   "most_recent_instance": {"location": {"path": "north-relay/northrelay-base"}}},
  {"number": 104, "state": "dismissed",
   "rule": {"id": "CVE-2026-0864", "security_severity_level": "medium"},
   "most_recent_instance": {"location": {"path": "north-relay/northrelay-base"}}}
]
JSON

# Fake `gh`: serves the fixture, and hard-fails the run if the script ever
# attempts a real mutation during a dry run.
mkdir -p "$TMP/bin"
cat > "$TMP/bin/gh" <<'GH'
#!/bin/bash
for a in "$@"; do
  if [[ "$a" == "PATCH" ]]; then
    echo "FAKE_GH_PATCH_CALLED" >> "$FAKE_GH_LOG"
    exit 0
  fi
done
cat "$FAKE_GH_ALERTS"
GH
chmod +x "$TMP/bin/gh"
export FAKE_GH_ALERTS="$TMP/alerts.json"
export FAKE_GH_LOG="$TMP/patch.log"
: > "$FAKE_GH_LOG"
export PATH="$TMP/bin:$PATH"

# Run the script against a given .trivyignore.yaml body, in a sandbox copy.
run_with_allowlist() {
  local body="$1"; shift
  rm -rf "$TMP/run"; mkdir -p "$TMP/run"
  cp "$SCRIPT" "$TMP/run/dismiss-false-positives.sh"
  printf '%s\n' "$body" > "$TMP/run/.trivyignore.yaml"
  : > "$FAKE_GH_LOG"
  bash "$TMP/run/dismiss-false-positives.sh" "$@" 2>&1
}

echo "TEST 1: empty allowlist dismisses nothing"
out=$(run_with_allowlist 'vulnerabilities: []')
if grep -q "Allowlist is empty" <<<"$out" && ! grep -q "Would dismiss" <<<"$out"; then
  ok "no alert selected with an empty allowlist"
else
  bad "empty allowlist selected something"; echo "$out" | sed 's/^/     /'
fi

echo "TEST 2: shared location.path does NOT sweep in unlisted alerts"
out=$(run_with_allowlist 'vulnerabilities:
  - id: CVE-2026-6879
    statement: test fixture')
if grep -q "Would dismiss #103 CVE-2026-6879" <<<"$out" \
   && ! grep -qE "Would dismiss #10[12]" <<<"$out"; then
  ok "only the allowlisted CVE selected; #101/#102 left open"
else
  bad "unlisted alerts were selected (the original blanket-match bug)"
  echo "$out" | sed 's/^/     /'
fi

echo "TEST 3: critical/high held back without an explicit severity_ack"
out=$(run_with_allowlist 'vulnerabilities:
  - id: CVE-2023-45853
    statement: test fixture
  - id: CVE-2026-7210
    statement: test fixture')
if grep -q "⛔ #101" <<<"$out" && grep -q "⛔ #102" <<<"$out" \
   && ! grep -q "Would dismiss" <<<"$out"; then
  ok "critical and high require severity_ack"
else
  bad "critical/high were selected without severity_ack"; echo "$out" | sed 's/^/     /'
fi

echo "TEST 4: severity_ack opts a high in"
out=$(run_with_allowlist 'vulnerabilities:
  - id: CVE-2026-7210
    # severity_ack: true
    statement: test fixture')
if grep -q "Would dismiss #102 CVE-2026-7210" <<<"$out"; then
  ok "acknowledged high is selected"
else
  bad "severity_ack did not take effect"; echo "$out" | sed 's/^/     /'
fi

echo "TEST 5: already-dismissed alerts are skipped"
out=$(run_with_allowlist 'vulnerabilities:
  - id: CVE-2026-0864
    statement: test fixture')
if ! grep -q "#104" <<<"$out"; then
  ok "non-open alert ignored"
else
  bad "re-processed an already-dismissed alert"; echo "$out" | sed 's/^/     /'
fi

echo "TEST 6: dry run is the default — no PATCH without --apply"
run_with_allowlist 'vulnerabilities:
  - id: CVE-2026-6879
    statement: test fixture' >/dev/null
if [[ ! -s "$FAKE_GH_LOG" ]]; then
  ok "no mutation attempted without --apply"
else
  bad "dry run issued a PATCH"
fi

echo ""
echo "passed: $pass  failed: $fail"
[[ $fail -eq 0 ]]
