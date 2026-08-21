#!/bin/bash
# ==============================================================================
# Dismiss ACCEPTED security alerts in northrelay-base
# ==============================================================================
# Dismisses Code Scanning alerts whose CVE appears in .trivyignore.yaml — the
# single, reviewed source of truth for accepted risk in this repo.
#
# Usage:
#   ./dismiss-false-positives.sh              # dry run (default)
#   ./dismiss-false-positives.sh --apply      # actually dismiss
#
# SAFETY MODEL
# ------------
# This script used to select alerts by substring-matching the alert's
# `location.path`. For Trivy *container* scans that field is the image
# reference — every alert on this repo reports the path
# "north-relay/northrelay-base" — so the rule intended to silence one Alpine
# zlib CVE matched all 683 open alerts, criticals included, and dismissed them
# as "won't fix". GitHub treats "won't fix" as sticky, so nothing reopened.
#
# The rules are now:
#   1. Allowlist, never pattern. Only CVEs written down in .trivyignore.yaml
#      are eligible. An empty allowlist dismisses nothing.
#   2. Match on rule.id (the CVE), not on a path that carries no per-alert
#      information.
#   3. Dry run unless --apply is passed explicitly.
#   4. critical/high require an opt-in `# severity_ack: true` comment on the
#      entry, so the blast radius of a careless line is bounded to low/medium.
#      It is a YAML comment on purpose: Trivy never sees it, so the file stays
#      a valid Trivy ignore file while carrying our extra gate.
# ==============================================================================

set -euo pipefail

REPO="North-Relay/northrelay-base"
IGNORE_FILE="$(dirname "$0")/.trivyignore.yaml"
APPLY=false

for arg in "$@"; do
  case "$arg" in
    --apply)   APPLY=true ;;
    --dry-run) APPLY=false ;;
    *) echo "Unknown argument: $arg" >&2; exit 2 ;;
  esac
done

if [[ ! -f "$IGNORE_FILE" ]]; then
  echo "❌ Missing $IGNORE_FILE — nothing is accepted, so nothing can be dismissed." >&2
  exit 1
fi

# ------------------------------------------------------------------------------
# Parse the allowlist: "- id: CVE-xxxx-nnnn" entries, plus an optional
# "severity_ack: true" that must appear before the next "- id:" to count.
# ------------------------------------------------------------------------------
declare -A ALLOWED=()      # CVE -> "ack" | "noack"
current=""
while IFS= read -r line; do
  if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*id:[[:space:]]*\"?([A-Za-z0-9]+-[0-9]+-[0-9A-Za-z-]+)\"?[[:space:]]*$ ]]; then
    current="${BASH_REMATCH[1]}"
    ALLOWED["$current"]="noack"
  elif [[ -n "$current" && "$line" =~ ^[[:space:]]*#[[:space:]]*severity_ack:[[:space:]]*true[[:space:]]*$ ]]; then
    ALLOWED["$current"]="ack"
  fi
done < "$IGNORE_FILE"

if [[ ${#ALLOWED[@]} -eq 0 ]]; then
  echo "✅ Allowlist is empty — no alert is eligible for dismissal."
  echo "   Add a reviewed entry to $IGNORE_FILE to accept a specific CVE."
  exit 0
fi

echo "📋 Allowlisted CVEs (${#ALLOWED[@]}): ${!ALLOWED[*]}"
[[ "$APPLY" == "true" ]] || echo "🔍 DRY RUN — pass --apply to dismiss for real"
echo ""

echo "📊 Fetching open Code Scanning alerts from $REPO..."
# gh merges top-level JSON arrays across pages, so this is a single array.
ALERTS_JSON=$(gh api "repos/$REPO/code-scanning/alerts" --paginate)

dismissed=0
skipped_sev=0
considered=0

while IFS=$'\t' read -r num rule_id severity state; do
  [[ "$state" == "open" ]] || continue
  [[ -n "${ALLOWED[$rule_id]:-}" ]] || continue
  considered=$((considered + 1))

  # critical/high need an explicit acknowledgement on the allowlist entry.
  if [[ "$severity" == "critical" || "$severity" == "high" ]] \
     && [[ "${ALLOWED[$rule_id]}" != "ack" ]]; then
    echo "  ⛔ #$num $rule_id ($severity) — allowlisted but no 'severity_ack: true'; leaving open"
    skipped_sev=$((skipped_sev + 1))
    continue
  fi

  if [[ "$APPLY" == "true" ]]; then
    gh api -X PATCH "repos/$REPO/code-scanning/alerts/$num" \
      -f state='dismissed' \
      -f dismissed_reason='won'"'"'t fix' \
      -f dismissed_comment="Accepted risk recorded in .trivyignore.yaml for $rule_id." >/dev/null
    echo "  ✅ Dismissed #$num $rule_id ($severity)"
  else
    echo "  [DRY RUN] Would dismiss #$num $rule_id ($severity)"
  fi
  dismissed=$((dismissed + 1))
done < <(echo "$ALERTS_JSON" | jq -r '.[] | [(.number|tostring), .rule.id, (.rule.security_severity_level // .rule.severity // "unknown"), .state] | @tsv')

echo ""
echo "📊 Matched allowlist: $considered | dismissed: $dismissed | held back for severity: $skipped_sev"

REMAINING=$(echo "$ALERTS_JSON" | jq '[.[] | select(.state == "open")] | length')
echo "⚠️  $REMAINING alerts open before this run — anything not allowlisted stays open by design."
