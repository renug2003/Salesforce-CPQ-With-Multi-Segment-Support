#!/bin/bash
# ═══════════════════════════════════════════════════════════
# Delta Dental CPQ — Scratch Org Setup
# Creates a fresh scratch org and deploys everything
# ═══════════════════════════════════════════════════════════

set -e

ORG_ALIAS="dd-cpq-dev"
DURATION=30

echo "═══════════════════════════════════════════════════════"
echo "  Delta Dental CPQ — Scratch Org Setup"
echo "═══════════════════════════════════════════════════════"

# Step 1: Create scratch org
echo ""
echo "▸ Creating scratch org: $ORG_ALIAS (${DURATION} days)..."
sf org create scratch \
  --definition-file config/project-scratch-def.json \
  --alias "$ORG_ALIAS" \
  --duration-days "$DURATION" \
  --set-default \
  --wait 10

# Step 2: Push source
echo ""
echo "▸ Pushing source to scratch org..."
sf project deploy start --target-org "$ORG_ALIAS"

# Step 3: Load data
echo ""
echo "▸ Loading seed data..."
bash scripts/deploy.sh "$ORG_ALIAS"

# Step 4: Open the org
echo ""
echo "▸ Opening scratch org..."
sf org open --target-org "$ORG_ALIAS"

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  ✓ Scratch org ready: $ORG_ALIAS"
echo "═══════════════════════════════════════════════════════"
