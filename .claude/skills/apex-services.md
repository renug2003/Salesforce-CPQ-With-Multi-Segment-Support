# Skill: Apex Service Class Development

## When to Use
Use this skill when creating Apex classes in `force-app/main/default/classes/`.

## Architecture Pattern — Separation of Concerns

```
DDRatingEngineService (Service Layer)
    ├── DDPlanDesignDomain (Business Logic)
    ├── DDRateTableSelector (SOQL Queries)
    └── DDConstants (Constants & Picklist Values)
```

- **Service Layer**: Orchestrates operations, handles DML, enforces transactions
- **Domain Layer**: Pure business logic, no SOQL or DML
- **Selector Layer**: All SOQL queries, returns typed lists
- **Constants**: All picklist values, magic strings, thresholds

## Service Class Template

```apex
/**
 * @description Service class for Delta Dental premium rating calculations.
 *              Handles the 11-step rating pipeline for PPO and DHMO plans.
 * @author Enterprise Architecture Team
 * @date 2026-03
 */
public with sharing class DDRatingEngineService {

    /**
     * @description Calculate group premium rates for a quote
     * @param quoteId The Quote record ID
     * @return DDRatingResult wrapper with calculated rates
     * @throws DDRatingException if rating fails validation
     */
    public static DDRatingResult calculateGroupRate(Id quoteId) {
        // 1. Load quote with related data
        Quote quote = DDQuoteSelector.getQuoteWithLineItems(quoteId);

        // 2. Validate SIC code eligibility
        DDSICValidationService.validateEligibility(quote.Opportunity.Account.SIC_Code__c);

        // 3. Determine rate level
        String rateLevel = DDSICValidationService.getRateLevel(
            quote.Opportunity.Account.SIC_Code__c
        );

        // 4. Load census data
        List<DD_Census__c> census = DDCensusSelector.getCensusByAccount(
            quote.Opportunity.AccountId
        );

        // 5. Look up base rates
        List<PricebookEntry> rates = DDRateTableSelector.getRatesForPlan(
            quote.QuoteLineItems[0].Product2Id,
            quote.Opportunity.Account.BillingState,
            quote.Requested_Effective_Date__c
        );

        // 6. Calculate using domain logic
        DDRatingResult result = DDRatingDomain.calculateCompositeRate(
            quote, census, rates, rateLevel
        );

        // 7. Persist results
        updateQuoteLineItems(quote.Id, result);

        return result;
    }

    private static void updateQuoteLineItems(Id quoteId, DDRatingResult result) {
        List<QuoteLineItem> updates = new List<QuoteLineItem>();
        for (DDRatingResult.TierRate tier : result.tierRates) {
            updates.add(new QuoteLineItem(
                Id = tier.lineItemId,
                Monthly_Rate_Per_Member__c = tier.monthlyRate,
                Monthly_Premium__c = tier.monthlyPremium,
                Employer_Share__c = tier.employerShare,
                Employee_Share__c = tier.employeeShare
            ));
        }
        update updates;
    }
}
```

## Domain Class Template

```apex
/**
 * @description Domain logic for premium rating calculations.
 *              Contains pure business logic — no SOQL or DML.
 */
public with sharing class DDRatingDomain {

    public static DDRatingResult calculateCompositeRate(
        Quote quote,
        List<DD_Census__c> census,
        List<PricebookEntry> rates,
        String rateLevel
    ) {
        DDRatingResult result = new DDRatingResult();
        // Business logic here...
        return result;
    }
}
```

## Selector Class Template

```apex
/**
 * @description Selector class for DD_Plan_Design__c queries.
 *              All SOQL for plan designs is centralized here.
 */
public with sharing class DDPlanDesignSelector {

    public static List<DD_Plan_Design__c> getActivePlans() {
        return [
            SELECT Id, Plan_Name__c, Plan_Family__c, Network_Fee_Basis__c,
                   DnP_Coinsurance_PPO__c, Basic_Coinsurance_PPO__c,
                   Major_Coinsurance_PPO__c, Deductible_Individual__c,
                   Min_Group_Size__c, Is_Active__c
            FROM DD_Plan_Design__c
            WHERE Is_Active__c = true
            ORDER BY Plan_Family__c, Plan_Name__c
        ];
    }

    public static DD_Plan_Design__c getPlanById(Id planId) {
        return [
            SELECT Id, Plan_Name__c, Plan_Family__c, Network_Fee_Basis__c,
                   DnP_Coinsurance_PPO__c, DnP_Coinsurance_NonPPO__c,
                   Basic_Coinsurance_PPO__c, Basic_Coinsurance_NonPPO__c,
                   Endo_Perio_OS_Coinsurance_PPO__c, Endo_Perio_OS_Coinsurance_NonPPO__c,
                   Major_Coinsurance_PPO__c, Major_Coinsurance_NonPPO__c,
                   Deductible_Individual__c, Deductible_Family__c
            FROM DD_Plan_Design__c
            WHERE Id = :planId
            LIMIT 1
        ];
    }
}
```

## Constants Class

```apex
/**
 * @description Constants for Delta Dental CPQ platform.
 *              All picklist values, magic strings, and business thresholds.
 */
public with sharing class DDConstants {
    // Plan Families
    public static final String PLAN_FAMILY_PPO_DELUXE = 'PPO Deluxe';
    public static final String PLAN_FAMILY_PPO_ADVANTAGE = 'PPO Advantage';
    public static final String PLAN_FAMILY_PPO_CORE = 'PPO Core';
    public static final String PLAN_FAMILY_DHMO = 'DeltaCare USA';

    // Network Fee Basis
    public static final String NETWORK_PPO = 'PPO';
    public static final String NETWORK_PPO_PLUS_PREMIER = 'PPO Plus Premier';
    public static final String NETWORK_DELTACARE = 'DeltaCare USA';

    // Rate Tiers
    public static final String TIER_EE = 'EE';
    public static final String TIER_ES = 'ES';
    public static final String TIER_EC = 'EC';
    public static final String TIER_EF = 'EF';

    // Coverage Categories
    public static final String CAT_DNP = 'Diagnostic & Preventive';
    public static final String CAT_BASIC = 'Basic';
    public static final String CAT_ENDO_PERIO_OS = 'Endodontics Periodontics Oral Surgery';
    public static final String CAT_MAJOR = 'Major';
    public static final String CAT_ORTHO = 'Orthodontia';

    // Rate Levels
    public static final String RATE_LEVEL_1 = 'Level 1';
    public static final String RATE_LEVEL_2 = 'Level 2';

    // Business Thresholds
    public static final Integer MIN_GROUP_SIZE = 2;
    public static final Integer MIN_ENROLLED_DUAL_CHOICE = 5;
    public static final Integer MIN_ENROLLED_ORTHO = 5;
    public static final Integer MIN_ENROLLED_ADULT_ORTHO_VOL = 50;
    public static final Decimal MIN_CONTRIBUTION_CORE_BUYUP = 50.0;
    public static final Integer VOLUNTARY_WAIT_MONTHS = 12;
    public static final Integer DEPENDENT_AGE_LIMIT = 26;
    public static final Decimal COBRA_RATE_MULTIPLIER = 1.02;

    // Ineligible SIC Codes
    public static final Set<String> INELIGIBLE_SIC_RANGES = new Set<String>{
        '0761-0783', '7231-7241', '7361-7363', '7389',
        '8021', '8071', '8072', '8600-8699', '8811', '8999', '9721'
    };
}
```

## Custom Exception Template

```apex
/**
 * @description Custom exception for rating engine errors
 */
public class DDRatingException extends Exception {}
```

## Wrapper Class Template

```apex
/**
 * @description Wrapper for rating calculation results
 */
public class DDRatingResult {
    @AuraEnabled public Decimal totalMonthlyPremium;
    @AuraEnabled public Decimal employerMonthlyShare;
    @AuraEnabled public Decimal employeeMonthlyShare;
    @AuraEnabled public List<TierRate> tierRates;
    @AuraEnabled public String rateLevel;
    @AuraEnabled public String rateGuaranteePeriod;

    public class TierRate {
        @AuraEnabled public Id lineItemId;
        @AuraEnabled public String tier;
        @AuraEnabled public Integer enrolledCount;
        @AuraEnabled public Decimal monthlyRate;
        @AuraEnabled public Decimal monthlyPremium;
        @AuraEnabled public Decimal employerShare;
        @AuraEnabled public Decimal employeeShare;
    }
}
```

## Apex Metadata XML
Every `.cls` file needs a companion `.cls-meta.xml`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<ApexClass xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>62.0</apiVersion>
    <status>Active</status>
</ApexClass>
```

## Trigger Template (1 per object)
```apex
/**
 * @description Single trigger for DD_Claim__c delegating to handler
 */
trigger DDClaimTrigger on DD_Claim__c (before insert, after insert, before update, after update) {
    DDClaimTriggerHandler handler = new DDClaimTriggerHandler();

    if (Trigger.isBefore && Trigger.isInsert) handler.beforeInsert(Trigger.new);
    if (Trigger.isAfter && Trigger.isInsert) handler.afterInsert(Trigger.new, Trigger.newMap);
    if (Trigger.isBefore && Trigger.isUpdate) handler.beforeUpdate(Trigger.new, Trigger.oldMap);
    if (Trigger.isAfter && Trigger.isUpdate) handler.afterUpdate(Trigger.new, Trigger.oldMap);
}
```
