# Skill: Data Loading & Seed Data

## When to Use
Use this skill when creating CSV data files for plan catalog, rates, and rules seed data.

## Data Load Order
1. DD_Coverage_Category__c (5 records)
2. DD_Plan_Design__c (20+ records)
3. DD_Annual_Max_Option__c (per plan)
4. DD_Ortho_Option__c (per plan)
5. DD_Benefit_Schedule__c (400+ CDT codes per plan)
6. DD_DHMO_Copay__c (400+ CDT codes per DHMO plan)
7. DD_Product_Bundle__c (5 dual choice/core-buyup combos)
8. DD_Waiting_Period__c (per plan/contribution type)
9. DD_Product_Rule__c (16 UW rules)
10. DD_Adj_Rule__c (15 adjudication rules)
11. DD_Rate_Level__c (SIC code mapping)
12. DD_Fee_Schedule__c + DD_Fee_Line__c (fee schedules)
13. PricebookEntry (rate tables)

## CSV Format Requirements
- UTF-8 encoding
- Header row with API field names
- Use SFDX data import: `sf data import tree` or `sf data import bulk`
- Date format: YYYY-MM-DD
- Boolean: true/false
- Currency: decimal without $ sign
- Percent: decimal (e.g., 80 for 80%)

## Sample Plan Design CSV
```csv
Plan_Name__c,Plan_Family__c,Network_Fee_Basis__c,DnP_Coinsurance_PPO__c,DnP_Coinsurance_NonPPO__c,Basic_Coinsurance_PPO__c,Basic_Coinsurance_NonPPO__c,Endo_Perio_OS_Coinsurance_PPO__c,Endo_Perio_OS_Coinsurance_NonPPO__c,Major_Coinsurance_PPO__c,Major_Coinsurance_NonPPO__c,Deductible_Individual__c,Deductible_Family__c,Min_Group_Size__c,Is_Active__c,SmileWay_Eligible__c,Voluntary_Available__c
Deluxe 100,PPO Deluxe,PPO Plus Premier,100,100,100,80,100,80,60,50,50,150,5,true,true,true
Deluxe 200,PPO Deluxe,PPO Plus Premier,100,100,90,80,90,80,60,50,50,150,2,true,true,true
Deluxe 300,PPO Deluxe,PPO,100,100,90,80,90,80,60,50,50,150,2,true,true,true
Advantage 100,PPO Advantage,PPO Plus Premier,100,100,80,80,80,80,60,50,50,150,2,true,true,true
Advantage 200,PPO Advantage,PPO Plus Premier,100,100,80,80,80,80,50,50,50,150,2,true,true,true
Advantage 300,PPO Advantage,PPO Plus Premier,100,80,80,60,80,60,50,50,50,150,2,true,true,true
Advantage 400,PPO Advantage,PPO,100,100,80,80,80,80,50,50,50,150,2,true,true,true
Core 100,PPO Core,PPO,100,100,80,80,50,50,50,50,50,150,2,true,true,true
Core 201,PPO Core,PPO,100,100,80,80,0,0,0,0,50,150,2,true,false,true
DeltaCare 11A,DeltaCare USA,DeltaCare USA,100,0,100,0,100,0,100,0,0,0,2,true,true,true
DeltaCare 15B,DeltaCare USA,DeltaCare USA,100,0,100,0,100,0,100,0,0,0,2,true,true,true
DeltaCare 17B,DeltaCare USA,DeltaCare USA,100,0,100,0,100,0,100,0,0,0,2,true,true,true
```

## Deployment Script Template (scripts/deploy.sh)
```bash
#!/bin/bash
# Deploy DD Salesforce CPQ Platform

echo "=== Delta Dental CPQ Deployment ==="

# Step 1: Deploy metadata
echo "Deploying custom objects..."
sf project deploy start --source-dir force-app/main/default/objects

echo "Deploying Apex classes..."
sf project deploy start --source-dir force-app/main/default/classes

echo "Deploying LWC components..."
sf project deploy start --source-dir force-app/main/default/lwc

echo "Deploying flows..."
sf project deploy start --source-dir force-app/main/default/flows

# Step 2: Load seed data
echo "Loading plan designs..."
sf data import tree --files data/plans/plan_designs.json

echo "Loading rate tables..."
sf data import tree --files data/rates/rate_tables.json

echo "Loading rules..."
sf data import tree --files data/rules/uw_rules.json

echo "=== Deployment Complete ==="
```
