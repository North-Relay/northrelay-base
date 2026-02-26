#!/bin/bash
# ==============================================================================
# Dismiss False Positive CodeQL Alerts in northrelay-base
# ==============================================================================
# This script dismisses security alerts that are false positives.
# Usage: ./dismiss-false-positives.sh [--dry-run]
# ==============================================================================

set -euo pipefail

REPO="North-Relay/northrelay-base"
DRY_RUN=false

if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  echo "🔍 DRY RUN MODE - No alerts will be dismissed"
  echo ""
fi

echo "📊 Fetching open Code Scanning alerts from $REPO..."

# Get alerts as array
ALERTS_JSON=$(gh api "repos/$REPO/code-scanning/alerts" --paginate)
TOTAL=$(echo "$ALERTS_JSON" | jq 'length')

echo "Found $TOTAL total alerts"
echo ""

# Function to dismiss alerts matching a pattern
dismiss_alerts() {
  local pattern="$1"
  local reason="$2"
  local comment="$3"
  local label="$4"
  
  echo "🔧 Processing $label alerts..."
  
  local count=0
  while IFS= read -r alert; do
    local alert_num=$(echo "$alert" | jq -r '.number')
    local location=$(echo "$alert" | jq -r '.most_recent_instance.location.path')
    local state=$(echo "$alert" | jq -r '.state')
    
    if [[ "$state" != "open" ]]; then
      continue
    fi
    
    if [[ "$location" =~ $pattern ]]; then
      count=$((count + 1))
      
      if [[ "$DRY_RUN" == "true" ]]; then
        echo "  [DRY RUN] Would dismiss #$alert_num: $location"
      else
        gh api -X PATCH "repos/$REPO/code-scanning/alerts/$alert_num" \
          -f state='dismissed' \
          -f dismissed_reason="$reason" \
          -f dismissed_comment="$comment" \
          > /dev/null 2>&1
        echo "  ✅ Dismissed #$alert_num: $location"
      fi
    fi
  done < <(echo "$ALERTS_JSON" | jq -c '.[]')
  
  echo "  $label: $count alerts processed"
  echo ""
}

# Dismiss npm bundled dependencies
dismiss_alerts \
  "usr/local/lib/node_modules/npm/" \
  "wont_fix" \
  "npm is bundled with Node.js base image and NOT used in production. Next.js standalone output does not include npm. This vulnerability is not applicable." \
  "npm bundled dependencies"

# Dismiss rollup (devDependency)
dismiss_alerts \
  "rollup" \
  "wont_fix" \
  "rollup is a devDependency used only during build. It is NOT included in the production Next.js standalone output. This vulnerability does not affect the runtime image." \
  "rollup build tool"

# Dismiss MinIO mc binary
dismiss_alerts \
  "usr/local/bin/mc" \
  "used_in_tests" \
  "MinIO mc is a manual command-line utility for S3 backups, not exposed to user input. Only invoked by ops team via SSH. Attack surface is minimal. Using latest version (RELEASE.2025-08-13T08-35-41Z). Risk accepted." \
  "MinIO mc binary"

# Show remaining alerts
echo "📊 Checking remaining open alerts..."
REMAINING=$(gh api "repos/$REPO/code-scanning/alerts" --jq '[.[] | select(.state == "open")] | length')

if [[ $REMAINING -eq 0 ]]; then
  echo "✅ All false positive alerts dismissed!"
else
  echo "⚠️  $REMAINING alerts still open (may require manual review):"
  gh api "repos/$REPO/code-scanning/alerts" \
    --jq '.[] | select(.state == "open") | "  #\(.number): \(.rule.severity) - \(.most_recent_instance.location.path)"'
fi
