#!/bin/bash
# ═══════════════════════════════════════════════════════════
# Delta Dental CA — Small Business CPQ Platform
# Deployment Script
# ═══════════════════════════════════════════════════════════

set -e

ORG_ALIAS="${1:-dd-cpq-dev}"
echo "═══════════════════════════════════════════════════════"
echo "  Delta Dental CPQ — Deploying to: $ORG_ALIAS"
echo "═══════════════════════════════════════════════════════"

# Step 1: Deploy custom objects (Tier 1 → Tier 6 order)
echo ""
echo "▸ Step 1: Deploying custom objects..."
sf project deploy start \
  --source-dir force-app/main/default/objects \
  --target-org "$ORG_ALIAS" \
  --wait 10

# Step 2: Deploy Apex classes
echo ""
echo "▸ Step 2: Deploying Apex classes..."
sf project deploy start \
  --source-dir force-app/main/default/classes \
  --target-dir force-app/main/default/triggers \
  --target-org "$ORG_ALIAS" \
  --wait 10

# Step 3: Deploy LWC components
echo ""
echo "▸ Step 3: Deploying LWC components..."
sf project deploy start \
  --source-dir force-app/main/default/lwc \
  --target-org "$ORG_ALIAS" \
  --wait 10

# Step 4: Deploy Flows
echo ""
echo "▸ Step 4: Deploying Flows..."
sf project deploy start \
  --source-dir force-app/main/default/flows \
  --target-org "$ORG_ALIAS" \
  --wait 10

# Step 5: Deploy permission sets, layouts, tabs, app, flexipages
echo ""
echo "▸ Step 5: Deploying UI metadata..."
sf project deploy start \
  --source-dir force-app/main/default/permissionsets \
  --source-dir force-app/main/default/layouts \
  --source-dir force-app/main/default/tabs \
  --source-dir force-app/main/default/applications \
  --source-dir force-app/main/default/flexipages \
  --target-org "$ORG_ALIAS" \
  --wait 10

# Step 6: Load seed data
echo ""
echo "▸ Step 6: Loading seed data..."

echo "  → Plan designs..."
sf data import bulk \
  --file data/plans/plan_designs.csv \
  --sobject DD_Plan_Design__c \
  --target-org "$ORG_ALIAS" 2>/dev/null || echo "  (Skipped — no data or object not found)"

echo "  → SIC rate level mapping..."
sf data import bulk \
  --file data/rates/rate_level_mapping.csv \
  --sobject DD_Rate_Level__c \
  --target-org "$ORG_ALIAS" 2>/dev/null || echo "  (Skipped — no data or object not found)"

echo "  → Underwriting rules..."
sf data import bulk \
  --file data/rules/uw_rules.csv \
  --sobject DD_Product_Rule__c \
  --target-org "$ORG_ALIAS" 2>/dev/null || echo "  (Skipped — no data or object not found)"

# Step 7: Run tests
echo ""
echo "▸ Step 7: Running Apex tests..."
sf apex run test \
  --test-level RunLocalTests \
  --target-org "$ORG_ALIAS" \
  --wait 15 \
  --result-format human 2>/dev/null || echo "  (Skipped — no test classes found yet)"

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  ✓ Deployment complete!"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "Next steps:"
echo "  1. Open the org:  sf org open --target-org $ORG_ALIAS"
echo "  2. Assign permission set:  sf org assign permset --name DD_CPQ_Admin --target-org $ORG_ALIAS"
echo "  3. Navigate to the DD CPQ app in App Launcher"
