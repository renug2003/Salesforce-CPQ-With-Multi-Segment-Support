# Delta Dental of California — Small Business CPQ Platform

A Salesforce DX project implementing dental insurance CPQ (Configure-Price-Quote) and Digital Insurance capabilities for Delta Dental of California's Small Business Program.

## Overview

This platform manages the complete lifecycle for dental insurance groups of 2–99 employees:
- **Product Catalog**: 20+ plan designs (PPO Deluxe/Advantage/Core, DeltaCare USA DHMO, Dual Choice, Core/Buy-Up, Pediatric)
- **Group Quoting**: Multi-step quote builder with real-time rating engine
- **Underwriting**: 16 automated underwriting rules with SIC code eligibility
- **Enrollment**: Individual and bulk enrollment with waiting period management
- **Claims**: Auto-adjudication pipeline with 15 dental-specific rules
- **Billing**: Monthly premium billing with employer/employee split
- **Provider Management**: Network directory with fee schedules
- **Producer/Broker**: Commission tracking and portal access

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Platform | Salesforce Sales Cloud (Enterprise) |
| Backend | Apex (Service/Domain/Selector pattern) |
| Frontend | Lightning Web Components (LWC) |
| Automation | Salesforce Flows + Apex Triggers |
| Data | Sales Cloud standard objects + 28 custom objects |
| API Version | 62.0 (Spring '26) |

## Getting Started

### Prerequisites
- Salesforce CLI (`sf`) installed
- VS Code with Salesforce Extension Pack
- Dev Hub enabled org
- Claude Code Agent extension (for AI-assisted development)

### Setup
```bash
# Clone the repository
git clone <repo-url>
cd dd-salesforce-cpq

# Authorize Dev Hub
sf org login web --set-default-dev-hub --alias DevHub

# Create scratch org
sf org create scratch --definition-file config/project-scratch-def.json --alias dd-cpq-dev --duration-days 30

# Push source
sf project deploy start --target-org dd-cpq-dev

# Load seed data
sf data import tree --files data/plans/plan_designs.json --target-org dd-cpq-dev
```

### Using Claude Code Agent
This project includes a `CLAUDE.md` file and skill files in `.claude/skills/` that guide Claude Code Agent through building each component. Open the project in VS Code and use Claude Code to:

1. **Create custom objects**: "Create the DD_Plan_Design__c custom object with all fields"
2. **Build Apex services**: "Create the DDRatingEngineService class"
3. **Build LWC components**: "Create the ddQuoteBuilder component"
4. **Write tests**: "Create test class for DDRatingEngineService"
5. **Load data**: "Generate the plan design data load script"

## Project Structure

```
dd-salesforce-cpq/
├── CLAUDE.md                    ← Master instructions for Claude Code Agent
├── .claude/skills/              ← Skill files for pattern guidance
├── force-app/main/default/      ← Salesforce DX source
│   ├── objects/                  ← Custom object metadata
│   ├── classes/                  ← Apex classes
│   ├── lwc/                      ← Lightning Web Components
│   ├── flows/                    ← Flow definitions
│   └── ...
├── data/                         ← Seed data CSVs
├── config/                       ← Scratch org configs
├── scripts/                      ← Deployment scripts
└── docs/                         ← Architecture documentation
```

## Architecture

The solution follows **Separation of Concerns**:

```
LWC Components (UI)
    ↓
Screen Flows (Orchestration)
    ↓
Apex Services (Transaction Management)
    ↓
Apex Domain (Business Logic)
    ↓
Apex Selectors (Data Access)
    ↓
Custom Objects (Data Model)
```

## Branding

Delta Dental Green Theme:
- Primary: `#00796B`
- Dark: `#004D40`
- Light: `#E0F2F1`
- Accent Teal: `#00897B`
- Gold: `#FF8F00`

## License

Proprietary — Delta Dental of California. Internal use only.
