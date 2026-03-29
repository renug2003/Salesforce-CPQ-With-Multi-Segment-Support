# Delta Dental of California — Digital Insurance CPQ Platform

## Project Overview

This Salesforce DX project implements a **catalog-driven Digital Insurance platform** for Delta Dental of California, following the **Salesforce Industries Product Model pattern** (root product → coverage specs → attributes → rules). The master product catalog is the single source of truth. Quotes are **configured copies** — sales agents configure plan options at the quote level without modifying master plans.

**Phase 1**: Small Business (2–99 employees)
**Phase 2**: Individual & Family
**Phase 3**: Mid-Market (100–999) and Large Group (1000+)

All phases share the same master product catalog, with segment-specific **selling models**, **eligibility rules**, and **rating algorithms** layered on top.

## Architecture — Catalog-Driven Design

```
MASTER PRODUCT CATALOG (Single Source of Truth — read-only during quoting)

  Product Catalog → Product Category → Root Product (DD_Product__c)
                                          |
                          +---------------+----------------+
                          v               v                v
                    Coverage Spec    Coverage Spec    Coverage Spec
                          |               |                |
                     Attributes      Attributes       Attributes
                     (defaults)      (defaults)       (defaults)
                          |               |
                    Benefit Specs    Benefit Specs
                    (CDT codes)      (CDT codes)

                    Product Config Rules    Product Pricing Rules
                    (eligibility, UW)       (rating factors)

                              |
                    +---------+---------+
                    v                   v
         QUOTE LAYER              POLICY LAYER
         (Configurable Copy)      (Frozen Snapshot)

         Quote                    Policy
         +-- Quote Plan Config    +-- Policy Coverage
         |   (agent overrides)    |   (frozen values)
         +-- Rate Result          +-- Enrollment
         +-- Coverage Config      +-- Claims
             (optional overrides)
```

### Key Design Principles

1. **Master catalog is read-only during quoting** — agents never edit DD_Product__c, DD_Coverage_Spec__c, or DD_Benefit_Spec__c
2. **Quote-level configuration** — system copies defaults from master into DD_Quote_Plan_Config__c where agents adjust annual max, ortho, contribution, waiting period waivers
3. **Inheritance with override** — DD_Quote_Coverage_Config__c and DD_Quote_Benefit_Override__c let agents override specific values while inheriting everything else from master
4. **Segment-agnostic catalog** — same DD_Product__c serves SB, Individual, and Large Group through DD_Selling_Model__c records with segment-specific eligibility, pricing, and rules
5. **Snapshot at bind** — configured values frozen into DD_Policy__c and DD_Policy_Coverage__c

## Platform

- Salesforce Sales Cloud + custom objects (Digital Insurance pattern)
- No OmniStudio dependency in Phase 1
- Object model aligns with Salesforce Industries Insurance Product Management for future migration
- API Version: 62.0

## Product Model Hierarchy (Dental Insurance)

```
DD_Product_Catalog__c ("Delta Dental 2025")
  +-- DD_Product_Category__c "PPO Plans"
  |     +-- DD_Product__c "Deluxe 100" (Root Product)
  |     |     +-- DD_Coverage_Spec__c "Diagnostic & Preventive"
  |     |     |     +-- Coinsurance PPO = 100%, NonPPO = 100%
  |     |     |     +-- Deductible Applies = false
  |     |     |     +-- DD_Benefit_Spec__c D0120 Periodic Exam: 2/cal yr
  |     |     |     +-- DD_Benefit_Spec__c D1110 Cleaning: 2/cal yr
  |     |     |     +-- ... (100+ CDT codes)
  |     |     +-- DD_Coverage_Spec__c "Basic Services"
  |     |     +-- DD_Coverage_Spec__c "Endo/Perio/Oral Surgery"
  |     |     +-- DD_Coverage_Spec__c "Major Services"
  |     |     +-- DD_Coverage_Spec__c "Orthodontia" (optional rider)
  |     +-- DD_Product__c "Advantage 200"
  |     +-- ... (9 PPO plans total)
  +-- DD_Product_Category__c "DHMO Plans"
  |     +-- DD_Product__c "DeltaCare USA 11A" (copay-based)
  |     +-- ...
  +-- DD_Product_Category__c "Pediatric Plans"
        +-- ...
```

## Object Catalog — Full List (28 objects)

### Tier 1 — Catalog Foundation (no dependencies)
1. **DD_Product_Catalog__c** — Catalog version container (2025, 2026...)
2. **DD_Product_Category__c** — Groups: PPO Plans, DHMO Plans, Pediatric, Bundles
3. **DD_Attribute_Definition__c** — Reusable attribute definitions (Annual Max, Ortho Max, etc.)
4. **DD_SIC_Mapping__c** — SIC code to rate level + eligibility mapping
5. **DD_Rate_Table__c** — Rate table headers by segment/level/effective date

### Tier 2 — Product Layer (depends on Tier 1)
6. **DD_Product__c** — Root product (the plan design master record)
7. **DD_Selling_Model__c** — Segment-specific config per product (THIS IS THE SCALABILITY LAYER)
8. **DD_Rate_Entry__c** — Per-product/tier rate entries (child of Rate Table)
9. **DD_Product_Bundle__c** — Dual Choice / Core Buy-Up combinations
10. **DD_Product_Rule__c** — UW, eligibility, configuration, adjudication rules
11. **DD_Product_Attribute__c** — Attribute values on a product (junction: Product x Attribute Def)

### Tier 3 — Coverage & Benefit Specs (depends on Tier 2)
12. **DD_Coverage_Spec__c** — Coverage categories with default coinsurance (child of Product)
13. **DD_Benefit_Spec__c** — CDT code-level benefit definitions (child of Coverage Spec)

### Tier 4 — Quote Configuration Layer (depends on standard Quote + Tier 2/3)
14. **DD_Quote_Plan_Config__c** — AGENT CONFIGURES HERE (copy of defaults from master)
15. **DD_Quote_Coverage_Config__c** — Optional coverage-level overrides
16. **DD_Quote_Benefit_Override__c** — Optional CDT-level overrides (Phase 3 for large groups)
17. **DD_Quote_Rate_Result__c** — Calculated rate output per tier
18. **DD_Census__c** — Employee census data

### Tier 5 — Policy Layer (frozen at bind)
19. **DD_Policy__c** — Active policy with frozen configuration
20. **DD_Policy_Coverage__c** — Frozen coverage details
21. **DD_Enrollment__c** — Member enrollment records
22. **DD_Dependent__c** — Dependent details
23. **DD_Billing__c** — Monthly billing statements

### Tier 6 — Claims Layer
24. **DD_Claim__c** — Master dental claim
25. **DD_Claim_Line__c** — Per-CDT-code claim lines
26. **DD_PreAuth__c** — Pre-authorization/predetermination
27. **DD_EOB__c** — Explanation of Benefits

### Tier 7 — Producer
28. **DD_Commission__c** — Broker commission tracking

## How Quoting Works (Agent Experience)

```
1. Agent creates Opportunity for employer group
2. Agent clicks "New Quote" -> selects segment (Small Business)
3. System loads eligible products from DD_Selling_Model__c
     WHERE Segment = 'Small Business' AND Is_Active = true
     AND Min_Group_Size <= enrolled_count
4. Agent selects plan(s) -> system creates DD_Quote_Plan_Config__c
     populated with DEFAULTS from DD_Product__c + DD_Selling_Model__c
5. Agent CONFIGURES (modifies DD_Quote_Plan_Config__c ONLY):
     - Picks annual max from allowed list
     - Toggles ortho on/off, picks type and max
     - Toggles D&P waiver
     - Sets contribution %
     - Flags waiting period waiver
6. Agent clicks "Calculate Rates" -> Rating Engine reads:
     - DD_Quote_Plan_Config__c (agent selections)
     - DD_Rate_Entry__c (rates for product/tier)
     - DD_SIC_Mapping__c (rate level)
     - DD_Census__c (enrolled members)
   -> Writes to DD_Quote_Rate_Result__c
7. Agent reviews rates, adjusts, re-rates
8. Agent submits -> approval if needed
9. On acceptance -> DD_Policy__c + DD_Policy_Coverage__c created
   (frozen snapshot of configured values)
```

MASTER CATALOG IS NEVER MODIFIED. All agent changes live in Quote layer.

## Scalability Path

| Phase | Segment | What Changes | What Stays Same |
|-------|---------|-------------|----------------|
| Phase 1 | Small Business 2-99 | DD_Selling_Model__c for SB; SB rules; SB rate tables | Master catalog, coverage specs, benefit specs, CDT codes |
| Phase 2 | Individual | Add Selling_Model for Individual; individual rate tables; no census | Same products, coverages, benefits |
| Phase 3 | Mid/Large | Add Selling_Model for Mid/Large; experience rating; DD_Quote_Benefit_Override__c enabled | Same master catalog; benefit overrides unlock per-CDT customization |

## Apex Service Pattern — Inheritance Resolution

```
When reading a benefit for adjudication or display:
  1. Check DD_Quote_Benefit_Override__c (quote-level override)
  2. If null -> check DD_Quote_Coverage_Config__c (coverage override)
  3. If null -> read DD_Coverage_Spec__c / DD_Benefit_Spec__c (master default)
```

## Branding — Delta Dental Website Theme (deltadentalins.com)

Matches the deltadentalins.com/shopping quote flow and main site design.

### Primary Blues (navigation, headers, hero sections)
- Dark Navy: `#003B71` — top nav, table headers, footer, primary headings
- Mid Blue: `#00609A` — card headers, section backgrounds
- Bright Blue: `#0085CA` — links, active states, secondary CTAs
- Teal: `#00AEC7` — badges, icons, highlights

### Action Colors
- Green: `#78BE20` — primary CTA buttons ("Get Started", "Select Plan"), success states
- Green Dark: `#4C8C2B` — button hover state
- Orange: `#F47B20` — warnings, attention callouts
- Red: `#E03C31` — errors, required indicators

### Neutrals
- White: `#FFFFFF` — page/card backgrounds
- Off-White: `#F7F7F7` — alternate section backgrounds, table stripe rows
- Light Gray: `#E8E8E8` — borders, dividers
- Gray: `#6D6E71` — secondary text
- Dark Gray: `#333333` — primary body text
- Near-Black: `#1A1A1A` — headings on white

### Hero Gradient (used on banner/hero areas)
```
background: linear-gradient(135deg, #003B71 0%, #00609A 50%, #0085CA 100%);
```

See `.claude/skills/lwc-components.md` for full CSS custom properties and component patterns.

## Active Plans (20 designs)
Deluxe 100/200/300, Advantage 100/200/300/400, Core 100/201, DeltaCare 11A/15B/17B, Dual Choice 1-4, Core/Buy-Up, Children PPO, Family PPO, Children DHMO
