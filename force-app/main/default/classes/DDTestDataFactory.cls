/**
 * @description Central test data factory for the Delta Dental Digital Insurance CPQ platform.
 *
 *              All test classes use this factory so field-level changes propagate
 *              to every test through a single edit.  Every method returns an
 *              un-inserted SObject unless the name ends with "AndInsert" — the
 *              caller controls when DML happens, keeping governor limits low.
 *
 *              Unique-constrained fields (DD_Group_Number__c, Product_Code__c)
 *              are seeded with a counter so the same factory method can be
 *              called multiple times within one transaction without conflicts.
 *
 * @author Enterprise Architecture Team
 * @date 2026-03
 */
@IsTest
public class DDTestDataFactory {

    // Sequential counter — incremented each time a unique-keyed record is built
    private static Integer seq = 0;

    private static Integer nextSeq() {
        return ++seq;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // TIER 1 — CATALOG FOUNDATION
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Creates and INSERTS a DD_Product_Catalog__c (active, 2025 vintage).
     * Inserted immediately because downstream objects need its Id.
     */
    public static DD_Product_Catalog__c createProductCatalog() {
        DD_Product_Catalog__c catalog = new DD_Product_Catalog__c(
            Catalog_Name__c  = 'Delta Dental 2025 Test',
            Version__c       = '2025',
            Status__c        = 'Active',
            Effective_Date__c = Date.newInstance(2025, 1, 1),
            Expiration_Date__c = Date.newInstance(2025, 12, 31)
        );
        insert catalog;
        return catalog;
    }

    /**
     * Creates and INSERTS a DD_Product_Category__c under the given catalog.
     * Product_Category__c is a required Lookup on DD_Product__c.
     */
    public static DD_Product_Category__c createProductCategory(Id catalogId) {
        DD_Product_Category__c cat = new DD_Product_Category__c(
            Category_Name__c  = 'PPO Plans ' + nextSeq(),
            Product_Catalog__c = catalogId,
            Display_Order__c  = 1
        );
        insert cat;
        return cat;
    }

    /**
     * Creates a DD_Rate_Table__c and inserts it.
     * Selling models need a Rate_Table__c; build one here so the factory
     * doesn't force callers to wire it up every time.
     */
    public static DD_Rate_Table__c createRateTable(String segment) {
        DD_Rate_Table__c rt = new DD_Rate_Table__c(
            Table_Name__c    = 'Test Rate Table ' + nextSeq(),
            Segment__c       = segment,
            Rate_Level__c    = 'Level 1',
            Status__c        = 'Active',
            Effective_Date__c = Date.newInstance(2025, 1, 1),
            Expiration_Date__c = Date.newInstance(2025, 12, 31)
        );
        insert rt;
        return rt;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // TIER 2 — PRODUCT LAYER
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Creates an un-inserted DD_Product__c.
     * @param name        Display name (e.g. "Advantage 200")
     * @param family      Plan family picklist value (e.g. DDConstants.PLAN_FAMILY_PPO_ADVANTAGE)
     * @param network     Network fee basis picklist value
     * @param categoryId  Id of the DD_Product_Category__c (required field)
     */
    public static DD_Product__c createProduct(
        String name,
        String family,
        String network,
        Id     categoryId
    ) {
        Integer s = nextSeq();
        // Product_Line__c is a restricted picklist: DPPO or DHMO
        String productLine = (family == DDConstants.PLAN_FAMILY_DHMO) ? 'DHMO' : 'DPPO';
        return new DD_Product__c(
            Product_Name__c         = name,
            Product_Code__c         = 'TST-' + s,
            Plan_Family__c          = family,
            Network_Fee_Basis__c    = network,
            Product_Line__c         = productLine,
            Product_Category__c     = categoryId,
            Is_Active__c            = true,
            Ortho_Available__c      = true,
            DnP_Max_Waiver_Available__c = true,
            Deductible_Individual__c = 50,
            Deductible_Family__c     = 150,
            State__c                 = 'CA'
        );
    }

    /**
     * Creates an un-inserted DD_Selling_Model__c with sensible SB defaults.
     * Available_Annual_Maxes__c list includes 1000, 1500, 2000 so tests can
     * exercise the parsing and validation paths without extra configuration.
     * @param rateTableId  Id of a DD_Rate_Table__c (returned by createRateTable)
     */
    public static DD_Selling_Model__c createSellingModel(
        Id      productId,
        String  segment,
        Integer minSize,
        Integer maxSize,
        Id      rateTableId
    ) {
        return new DD_Selling_Model__c(
            Product__c                    = productId,
            Segment__c                    = segment,
            Is_Active__c                  = true,
            Min_Group_Size__c             = minSize,
            Max_Group_Size__c             = maxSize,
            Min_Contribution_Pct__c       = 50,
            Voluntary_Available__c        = false,
            Employer_Paid_Available__c    = true,
            Available_Annual_Maxes__c     = '1000,1500,2000',
            Available_Ortho_Types__c      = 'Child Only,Adult and Child',
            Available_Ortho_Maxes__c      = '1000,1500',
            Waiting_Period_Months__c      = 6,
            Waiting_Period_Waiver_Allowed__c = true,
            Rate_Table__c                 = rateTableId
        );
    }

    /**
     * Creates an un-inserted DD_Coverage_Spec__c.
     * @param productId     Parent DD_Product__c Id
     * @param name          Coverage name (e.g. "Diagnostic & Preventive")
     * @param code          Coverage code (e.g. "DNP")
     * @param coinsPPO      PPO coinsurance percentage (0-100)
     * @param coinsNonPPO   Non-PPO coinsurance percentage (0-100)
     */
    public static DD_Coverage_Spec__c createCoverageSpec(
        Id      productId,
        String  name,
        String  code,
        Decimal coinsPPO,
        Decimal coinsNonPPO
    ) {
        return new DD_Coverage_Spec__c(
            Product__c            = productId,
            Coverage_Name__c      = name,
            Coverage_Code__c      = code,
            Coinsurance_PPO__c    = coinsPPO,
            Coinsurance_NonPPO__c = coinsNonPPO,
            Deductible_Applies__c = (code != 'DNP'),  // D&P never has deductible
            Counts_Toward_Max__c  = true,
            Display_Order__c      = 1
        );
    }

    /**
     * Creates an un-inserted DD_Benefit_Spec__c.
     * @param coverageId   Parent DD_Coverage_Spec__c Id
     * @param cdtCode      CDT procedure code (e.g. "D0120")
     * @param description  Human-readable procedure name
     * @param freqLimit    Numeric frequency limit (e.g. 2)
     * @param freqPeriod   Frequency period picklist (e.g. "Calendar Year")
     */
    public static DD_Benefit_Spec__c createBenefitSpec(
        Id      coverageId,
        String  cdtCode,
        String  description,
        Integer freqLimit,
        String  freqPeriod
    ) {
        return new DD_Benefit_Spec__c(
            Coverage_Spec__c  = coverageId,
            CDT_Code__c       = cdtCode,
            CDT_Description__c = description,
            Frequency_Limit__c = freqLimit,
            Frequency_Period__c = freqPeriod
        );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // TIER 4 — ACCOUNT AND CENSUS
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Creates an un-inserted Account representing an employer group.
     * DD_Group_Number__c has a unique constraint — seeded with a counter.
     * @param name      Employer group name
     * @param sicCode   4-digit SIC code string (e.g. '7372')
     * @param groupSize Total eligible employee count
     */
    public static Account createGroupAccount(String name, String sicCode, Integer groupSize) {
        return new Account(
            Name                  = name,
            SIC_Code__c           = sicCode,
            Group_Size__c         = groupSize,
            Market_Segment__c     = 'Small Business',
            Industry_Rate_Level__c = 'Level 1',
            BillingState          = 'CA',
            BillingPostalCode     = '90210',
            DD_Group_Number__c    = 'TEST-' + nextSeq()
        );
    }

    /**
     * Creates and INSERTS `count` DD_Census__c records for the given account.
     * Tiers cycle EE → ES → EC → EF to ensure every tier is represented.
     * @param accountId  Parent Account Id
     * @param count      Number of census members to create
     * @return Inserted list (Ids populated)
     */
    public static List<DD_Census__c> createCensus(Id accountId, Integer count) {
        List<String> tiers = new List<String>{ 'EE', 'ES', 'EC', 'EF' };
        List<DD_Census__c> records = new List<DD_Census__c>();
        for (Integer i = 0; i < count; i++) {
            records.add(new DD_Census__c(
                Account__c       = accountId,
                Employee_Name__c = 'Employee ' + i,
                DOB__c           = Date.today().addYears(-30 - Math.mod(i, 20)),
                Gender__c        = Math.mod(i, 2) == 0 ? 'M' : 'F',
                Zip_Code__c      = '9' + String.valueOf(1000 + Math.mod(i, 9000)),
                Hire_Date__c     = Date.today().addMonths(-12 - Math.mod(i, 60)),
                Enrollment_Tier__c = tiers[Math.mod(i, 4)],
                Status__c        = DDConstants.STATUS_ACTIVE
            ));
        }
        insert records;
        return records;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // QUOTE LAYER — FULL STACK SETUP
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Creates and INSERTS a complete quote stack:
     *   Opportunity → Quote → DD_Quote_Plan_Config__c
     *
     * The Quote is linked to an Opportunity so the rating engine SOQL traversal
     * Quote__r.Opportunity.Account.SIC_Code__c resolves correctly.
     *
     * @param accountId   Id of the employer group Account
     * @param productId   Id of the DD_Product__c to configure
     * @param smId        Id of the DD_Selling_Model__c (drives defaults)
     * @return The inserted DD_Quote_Plan_Config__c (Quote__c and Product__c set)
     */
    public static DD_Quote_Plan_Config__c createQuoteWithConfig(
        Id accountId,
        Id productId,
        Id smId
    ) {
        // Opportunity
        Opportunity opp = new Opportunity(
            Name            = 'Test Opp ' + nextSeq(),
            AccountId       = accountId,
            StageName       = 'Prospecting',
            CloseDate       = Date.today().addDays(30)
        );
        insert opp;

        // Standard Quote
        Quote q = new Quote(
            Name            = 'Test Quote ' + nextSeq(),
            OpportunityId   = opp.Id,
            Pricebook2Id    = Test.getStandardPricebookId(),
            Status          = 'Draft',
            Effective_Date__c = Date.today().addMonths(1)
        );
        insert q;

        // Quote Plan Config using service (ensures defaults are applied)
        DD_Quote_Plan_Config__c config = DDQuoteConfigService.createConfigFromDefaults(
            q.Id, productId, smId
        );
        return config;
    }

    /**
     * Creates and inserts four DD_Rate_Entry__c records (one per tier) for the
     * given product and rate table.  Rates are simple round numbers to make
     * assertions deterministic.
     */
    public static List<DD_Rate_Entry__c> createRateEntries(Id rateTableId, Id productId) {
        List<DD_Rate_Entry__c> entries = new List<DD_Rate_Entry__c>{
            new DD_Rate_Entry__c(Rate_Table__c = rateTableId, Product__c = productId,
                Rate_Tier__c = 'EE', Monthly_Rate__c = 100.00),
            new DD_Rate_Entry__c(Rate_Table__c = rateTableId, Product__c = productId,
                Rate_Tier__c = 'ES', Monthly_Rate__c = 190.00),
            new DD_Rate_Entry__c(Rate_Table__c = rateTableId, Product__c = productId,
                Rate_Tier__c = 'EC', Monthly_Rate__c = 170.00),
            new DD_Rate_Entry__c(Rate_Table__c = rateTableId, Product__c = productId,
                Rate_Tier__c = 'EF', Monthly_Rate__c = 250.00)
        };
        insert entries;
        return entries;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // CLAIMS LAYER
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Creates an un-inserted DD_Claim__c.
     * @param memberId   Id of the DD_Enrollment__c member record
     * @param policyId   Id of the DD_Policy__c under which the claim falls
     */
    public static DD_Claim__c createClaim(Id memberId, Id policyId) {
        return new DD_Claim__c(
            Member__c         = memberId,
            Policy__c         = policyId,
            Date_of_Service__c = Date.today().addDays(-10),
            Status__c          = DDConstants.STATUS_RECEIVED,
            Total_Charged__c   = 250.00
        );
    }
}
