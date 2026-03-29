/**
 * @description Tests for DDPolicyBindService.
 *
 *              Coverage targets:
 *                • bindQuote — happy path: returns valid policy Id, creates
 *                  DD_Policy__c and DD_Policy_Coverage__c, verifies frozen values
 *                  match config, updates Quote.Status to Accepted and configs to Approved
 *                • bindQuoteAll — Dual Choice: two configs → two policies
 *                • Snapshot integrity: frozen annual max, deductibles, effective date,
 *                  term date, and coinsurance values verified against config inputs
 *                • Override inheritance: coverage-level override beats master default,
 *                  null override field inherits master
 *                • Excluded coverage: Is_Excluded__c = true → no policy coverage record
 *                • Guards: not-rated config throws, no configs throws, null quoteId throws,
 *                  no account throws (rollback verified)
 *
 * @author Enterprise Architecture Team
 * @date 2026-03
 */
@IsTest
private class DDPolicyBindServiceTest {

    // ─────────────────────────────────────────────────────────────────────────
    // @TestSetup — full quote-to-rated stack
    // ─────────────────────────────────────────────────────────────────────────

    @TestSetup
    static void setupTestData() {
        DD_Product_Catalog__c catalog = DDTestDataFactory.createProductCatalog();
        DD_Product_Category__c category = DDTestDataFactory.createProductCategory(catalog.Id);
        DD_Rate_Table__c rt = DDTestDataFactory.createRateTable(DDConstants.SEGMENT_SMALL_BUSINESS);

        DD_Product__c product = DDTestDataFactory.createProduct(
            'Advantage 200 Bind',
            DDConstants.PLAN_FAMILY_PPO_ADVANTAGE,
            DDConstants.NETWORK_PPO_PLUS_PREMIER,
            category.Id
        );
        insert product;

        DD_Selling_Model__c sm = DDTestDataFactory.createSellingModel(
            product.Id, DDConstants.SEGMENT_SMALL_BUSINESS, 2, 99, rt.Id
        );
        insert sm;

        DDTestDataFactory.createRateEntries(rt.Id, product.Id);

        // Coverage specs on the master product (these get snapshotted at bind)
        DD_Coverage_Spec__c dnp = DDTestDataFactory.createCoverageSpec(
            product.Id, DDConstants.CAT_DNP, DDConstants.CODE_DNP, 100, 80
        );
        DD_Coverage_Spec__c basic = DDTestDataFactory.createCoverageSpec(
            product.Id, DDConstants.CAT_BASIC, DDConstants.CODE_BASIC, 80, 60
        );
        insert new List<SObject>{ dnp, basic };

        // Employer group
        Account grp = DDTestDataFactory.createGroupAccount('Bind Test Corp', '7372', 25);
        insert grp;
        DDTestDataFactory.createCensus(grp.Id, 4);

        Opportunity opp = new Opportunity(
            Name = 'Bind Test Opp', AccountId = grp.Id,
            StageName = 'Prospecting', CloseDate = Date.today().addDays(30)
        );
        insert opp;

        Quote q = new Quote(
            Name = 'Bind Test Quote', OpportunityId = opp.Id,
            Pricebook2Id = Test.getStandardPricebookId(), Status = 'Draft',
            Effective_Date__c = Date.newInstance(2027, 1, 1)  // future date so resolveEffectiveDate honours it
        );
        insert q;

        // Config + rate calculation so bind guards pass
        DD_Quote_Plan_Config__c config =
            DDQuoteConfigService.createConfigFromDefaults(q.Id, product.Id, sm.Id);
        config.Selected_Annual_Max__c       = 1500;
        config.Employer_Contribution_Pct__c = 75;
        update config;

        DDRatingEngineService.calculateRate(q.Id);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // bindQuote — happy path
    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    static void testBindQuote_HappyPath_ReturnsPolicyId() {
        Quote q = [SELECT Id FROM Quote WHERE Name = 'Bind Test Quote' LIMIT 1];

        Test.startTest();
        Id policyId = DDPolicyBindService.bindQuote(q.Id);
        Test.stopTest();

        System.assertNotEquals(null, policyId, 'bindQuote should return a valid policy Id');
        DD_Policy__c policy = [SELECT Id FROM DD_Policy__c WHERE Id = :policyId LIMIT 1];
        System.assertNotEquals(null, policy, 'Policy record should exist in the database');
    }

    @IsTest
    static void testBindQuote_QuoteStatusUpdatedToAccepted() {
        Quote q = [SELECT Id FROM Quote WHERE Name = 'Bind Test Quote' LIMIT 1];

        Test.startTest();
        DDPolicyBindService.bindQuote(q.Id);
        Test.stopTest();

        Quote updated = [SELECT Status FROM Quote WHERE Id = :q.Id];
        System.assertEquals('Accepted', updated.Status, 'Quote status should be Accepted after bind');
    }

    @IsTest
    static void testBindQuote_ConfigStatusUpdatedToApproved() {
        Quote q = [SELECT Id FROM Quote WHERE Name = 'Bind Test Quote' LIMIT 1];

        Test.startTest();
        DDPolicyBindService.bindQuote(q.Id);
        Test.stopTest();

        List<DD_Quote_Plan_Config__c> configs =
            [SELECT Config_Status__c FROM DD_Quote_Plan_Config__c WHERE Quote__c = :q.Id];
        for (DD_Quote_Plan_Config__c c : configs) {
            System.assertEquals('Approved', c.Config_Status__c,
                'All configs should be Approved after bind');
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Snapshot integrity — verify frozen values match config
    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    static void testBindQuote_FrozenAnnualMax_MatchesConfig() {
        Quote q = [SELECT Id FROM Quote WHERE Name = 'Bind Test Quote' LIMIT 1];

        Test.startTest();
        Id policyId = DDPolicyBindService.bindQuote(q.Id);
        Test.stopTest();

        DD_Policy__c policy   = [SELECT Annual_Max__c FROM DD_Policy__c WHERE Id = :policyId];
        DD_Quote_Plan_Config__c cfg =
            [SELECT Selected_Annual_Max__c FROM DD_Quote_Plan_Config__c WHERE Quote__c = :q.Id LIMIT 1];

        System.assertEquals(cfg.Selected_Annual_Max__c, policy.Annual_Max__c,
            'Policy.Annual_Max__c must match config.Selected_Annual_Max__c at bind time');
    }

    @IsTest
    static void testBindQuote_FrozenDeductibles_MatchProduct() {
        Quote q = [SELECT Id FROM Quote WHERE Name = 'Bind Test Quote' LIMIT 1];

        Test.startTest();
        Id policyId = DDPolicyBindService.bindQuote(q.Id);
        Test.stopTest();

        DD_Policy__c policy = [
            SELECT Deductible_Individual__c, Deductible_Family__c, Product__c
            FROM DD_Policy__c WHERE Id = :policyId
        ];
        DD_Product__c product = [
            SELECT Deductible_Individual__c, Deductible_Family__c
            FROM DD_Product__c WHERE Id = :policy.Product__c
        ];

        System.assertEquals(product.Deductible_Individual__c, policy.Deductible_Individual__c,
            'Deductible_Individual should be copied from master product when no override set');
        System.assertEquals(product.Deductible_Family__c, policy.Deductible_Family__c,
            'Deductible_Family should be copied from master product when no override set');
    }

    @IsTest
    static void testBindQuote_FrozenEffectiveAndTermDates() {
        Quote q = [SELECT Id, Effective_Date__c FROM Quote WHERE Name = 'Bind Test Quote' LIMIT 1];

        Test.startTest();
        Id policyId = DDPolicyBindService.bindQuote(q.Id);
        Test.stopTest();

        DD_Policy__c policy = [
            SELECT Effective_Date__c, Anniversary_Date__c, Term_Date__c
            FROM DD_Policy__c WHERE Id = :policyId
        ];

        System.assertEquals(q.Effective_Date__c, policy.Effective_Date__c,
            'Policy effective date should match quote effective date');
        Date expectedAnniversary = q.Effective_Date__c.addYears(1);
        System.assertEquals(expectedAnniversary, policy.Anniversary_Date__c,
            'Anniversary date should be 1 year after effective date');
        System.assertEquals(expectedAnniversary.addDays(-1), policy.Term_Date__c,
            'Term date should be one day before anniversary date');
    }

    @IsTest
    static void testBindQuote_MonthlyPremium_SumsRateResults() {
        Quote q = [SELECT Id FROM Quote WHERE Name = 'Bind Test Quote' LIMIT 1];

        Test.startTest();
        Id policyId = DDPolicyBindService.bindQuote(q.Id);
        Test.stopTest();

        DD_Policy__c policy = [SELECT Monthly_Premium__c FROM DD_Policy__c WHERE Id = :policyId];
        DD_Quote_Plan_Config__c cfg =
            [SELECT Id FROM DD_Quote_Plan_Config__c WHERE Quote__c = :q.Id LIMIT 1];

        Decimal expectedPremium = 0;
        for (DD_Quote_Rate_Result__c rr :
            [SELECT Monthly_Premium__c FROM DD_Quote_Rate_Result__c WHERE Quote_Plan_Config__c = :cfg.Id]) {
            if (rr.Monthly_Premium__c != null) {
                expectedPremium += rr.Monthly_Premium__c;
            }
        }
        System.assertEquals(expectedPremium.setScale(2, RoundingMode.HALF_UP), policy.Monthly_Premium__c,
            'Policy monthly premium should be sum of all tier rate results');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Policy coverages — snapshot and inheritance
    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    static void testBindQuote_PolicyCoveragesCreated_OnePerMasterSpec() {
        Quote q = [SELECT Id FROM Quote WHERE Name = 'Bind Test Quote' LIMIT 1];

        Test.startTest();
        Id policyId = DDPolicyBindService.bindQuote(q.Id);
        Test.stopTest();

        List<DD_Policy_Coverage__c> coverages =
            [SELECT Id FROM DD_Policy_Coverage__c WHERE Policy__c = :policyId];
        // @TestSetup created 2 coverage specs (DNP + Basic)
        System.assertEquals(2, coverages.size(),
            'Should create one DD_Policy_Coverage__c per master coverage spec');
    }

    @IsTest
    static void testBindQuote_FrozenCoinsurance_InheritsFromMaster() {
        Quote q = [SELECT Id FROM Quote WHERE Name = 'Bind Test Quote' LIMIT 1];

        Test.startTest();
        Id policyId = DDPolicyBindService.bindQuote(q.Id);
        Test.stopTest();

        DD_Coverage_Spec__c masterDNP = [
            SELECT Coinsurance_PPO__c, Coinsurance_NonPPO__c
            FROM DD_Coverage_Spec__c WHERE Coverage_Code__c = 'DNP' LIMIT 1
        ];
        DD_Policy_Coverage__c policyCoverage = [
            SELECT Coinsurance_PPO__c, Coinsurance_NonPPO__c
            FROM DD_Policy_Coverage__c
            WHERE Policy__c = :policyId AND Coverage_Spec__c = :masterDNP.Id
        ];

        System.assertEquals(masterDNP.Coinsurance_PPO__c, policyCoverage.Coinsurance_PPO__c,
            'PPO coinsurance should be inherited from master spec when no override exists');
        System.assertEquals(masterDNP.Coinsurance_NonPPO__c, policyCoverage.Coinsurance_NonPPO__c,
            'Non-PPO coinsurance should be inherited from master spec when no override exists');
    }

    @IsTest
    static void testBindQuote_CoverageOverride_OverrideBeatsmaster() {
        Quote q = [SELECT Id FROM Quote WHERE Name = 'Bind Test Quote' LIMIT 1];
        DD_Quote_Plan_Config__c config =
            [SELECT Id FROM DD_Quote_Plan_Config__c WHERE Quote__c = :q.Id LIMIT 1];
        DD_Coverage_Spec__c basicSpec = [
            SELECT Id FROM DD_Coverage_Spec__c WHERE Coverage_Code__c = 'BASIC' LIMIT 1
        ];

        // Agent overrides Basic coinsurance PPO to 90 (master = 80)
        DD_Quote_Coverage_Config__c qcc = new DD_Quote_Coverage_Config__c(
            Quote_Plan_Config__c          = config.Id,
            Coverage_Spec__c              = basicSpec.Id,
            Is_Excluded__c                = false,
            Override_Coinsurance_PPO__c   = 90,
            Override_Coinsurance_NonPPO__c = null  // null = inherit master (60)
        );
        insert qcc;

        Test.startTest();
        Id policyId = DDPolicyBindService.bindQuote(q.Id);
        Test.stopTest();

        DD_Policy_Coverage__c pc = [
            SELECT Coinsurance_PPO__c, Coinsurance_NonPPO__c
            FROM DD_Policy_Coverage__c
            WHERE Policy__c = :policyId AND Coverage_Spec__c = :basicSpec.Id
        ];

        System.assertEquals(90, pc.Coinsurance_PPO__c,
            'PPO coinsurance should be 90 from the override (not 80 from master)');
        System.assertEquals(60, pc.Coinsurance_NonPPO__c,
            'NonPPO coinsurance should be 60 from master (null override → inherit)');
    }

    @IsTest
    static void testBindQuote_ExcludedCoverage_NoCoveragRecord() {
        Quote q = [SELECT Id FROM Quote WHERE Name = 'Bind Test Quote' LIMIT 1];
        DD_Quote_Plan_Config__c config =
            [SELECT Id FROM DD_Quote_Plan_Config__c WHERE Quote__c = :q.Id LIMIT 1];
        DD_Coverage_Spec__c basicSpec = [
            SELECT Id FROM DD_Coverage_Spec__c WHERE Coverage_Code__c = 'BASIC' LIMIT 1
        ];

        // Agent excludes Basic coverage entirely
        DD_Quote_Coverage_Config__c qcc = new DD_Quote_Coverage_Config__c(
            Quote_Plan_Config__c = config.Id,
            Coverage_Spec__c     = basicSpec.Id,
            Is_Excluded__c       = true
        );
        insert qcc;

        Test.startTest();
        Id policyId = DDPolicyBindService.bindQuote(q.Id);
        Test.stopTest();

        Integer excludedCount = [
            SELECT COUNT() FROM DD_Policy_Coverage__c
            WHERE Policy__c = :policyId AND Coverage_Spec__c = :basicSpec.Id
        ];
        System.assertEquals(0, excludedCount,
            'Excluded coverage should NOT produce a DD_Policy_Coverage__c record');

        // DNP coverage should still exist (only Basic was excluded)
        Integer remainingCount = [SELECT COUNT() FROM DD_Policy_Coverage__c WHERE Policy__c = :policyId];
        System.assertEquals(1, remainingCount, 'One coverage (DNP) should remain after excluding Basic');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Dual Choice — bindQuoteAll
    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    static void testBindQuoteAll_DualChoice_TwoPoliciesCreated() {
        // Build a second product + selling model + rate entries for the same quote
        DD_Product_Category__c cat = [SELECT Id FROM DD_Product_Category__c LIMIT 1];
        DD_Rate_Table__c rt = DDTestDataFactory.createRateTable(DDConstants.SEGMENT_SMALL_BUSINESS);
        DD_Product__c dhmo = DDTestDataFactory.createProduct(
            'DeltaCare Bind', DDConstants.PLAN_FAMILY_DHMO, DDConstants.NETWORK_DELTACARE, cat.Id
        );
        dhmo.Ortho_Available__c = false;
        insert dhmo;

        DD_Selling_Model__c smDHMO = DDTestDataFactory.createSellingModel(
            dhmo.Id, DDConstants.SEGMENT_SMALL_BUSINESS, 2, 99, rt.Id
        );
        smDHMO.Available_Ortho_Types__c = null;
        smDHMO.Available_Ortho_Maxes__c = null;
        insert smDHMO;

        DDTestDataFactory.createRateEntries(rt.Id, dhmo.Id);

        Quote q = [SELECT Id FROM Quote WHERE Name = 'Bind Test Quote' LIMIT 1];

        // Add second config to the same quote
        DD_Quote_Plan_Config__c cfg2 =
            DDQuoteConfigService.createConfigFromDefaults(q.Id, dhmo.Id, smDHMO.Id);
        cfg2.Selected_Annual_Max__c       = null;
        cfg2.Employer_Contribution_Pct__c = 50;
        update cfg2;

        // Rate both configs
        DDRatingEngineService.calculateRate(q.Id);

        Test.startTest();
        List<Id> policyIds = DDPolicyBindService.bindQuoteAll(q.Id);
        Test.stopTest();

        System.assertEquals(2, policyIds.size(), 'Dual Choice bind should return two policy IDs');
        Integer policyCount = [SELECT COUNT() FROM DD_Policy__c WHERE Id IN :policyIds];
        System.assertEquals(2, policyCount, 'Two DD_Policy__c records should exist after dual-choice bind');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Guards and rollback behaviour
    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    static void testBindQuote_NullQuoteId_ThrowsValidationException() {
        Test.startTest();
        try {
            DDPolicyBindService.bindQuote(null);
            System.assert(false, 'Null quoteId should throw DDValidationException');
        } catch (DDValidationException e) {
            System.assert(e.getMessage().containsIgnoreCase('quoteId'), 'Error should mention quoteId');
        }
        Test.stopTest();
    }

    @IsTest
    static void testBindQuote_NoConfigs_ThrowsValidationException() {
        Opportunity opp = [SELECT Id FROM Opportunity WHERE Name = 'Bind Test Opp' LIMIT 1];
        Quote empty = new Quote(
            Name = 'Empty Bind Quote', OpportunityId = opp.Id,
            Pricebook2Id = Test.getStandardPricebookId(), Status = 'Draft'
        );
        insert empty;

        Test.startTest();
        try {
            DDPolicyBindService.bindQuote(empty.Id);
            System.assert(false, 'Quote without configs should throw');
        } catch (DDValidationException e) {
            System.assert(e.getMessage() != null, 'Exception should carry a message');
        }
        Test.stopTest();
    }

    @IsTest
    static void testBindQuote_UnratedConfig_ThrowsValidationException() {
        // Create a second fresh quote with a config that has never been rated
        Opportunity opp = [SELECT Id FROM Opportunity WHERE Name = 'Bind Test Opp' LIMIT 1];
        Quote q2 = new Quote(
            Name = 'Unrated Bind Quote', OpportunityId = opp.Id,
            Pricebook2Id = Test.getStandardPricebookId(), Status = 'Draft'
        );
        insert q2;

        DD_Product__c product = [SELECT Id FROM DD_Product__c WHERE Product_Name__c = 'Advantage 200 Bind' LIMIT 1];
        DD_Selling_Model__c sm = [SELECT Id FROM DD_Selling_Model__c WHERE Product__c = :product.Id LIMIT 1];

        // Create config but do NOT call calculateRate — config stays in 'Draft' status
        DDQuoteConfigService.createConfigFromDefaults(q2.Id, product.Id, sm.Id);

        Test.startTest();
        try {
            DDPolicyBindService.bindQuote(q2.Id);
            System.assert(false, 'Unrated config (Draft status) should throw before binding');
        } catch (DDValidationException e) {
            System.assert(
                e.getMessage().containsIgnoreCase('rate')
                    || e.getMessage().containsIgnoreCase('bind'),
                'Error should describe that rating is required before bind'
            );
        } catch (DDRatingException e) {
            // Also acceptable if service wraps as DDRatingException
            System.assert(e.getMessage() != null);
        }
        Test.stopTest();
    }

    @IsTest
    static void testBindQuote_RollbackOnFailure_NoPoliciesCreated() {
        // Simulate a scenario where bind fails atomically:
        // Quote's Opportunity has no AccountId → AccountId traversal is null → DDValidationException
        Opportunity noAcctOpp = new Opportunity(
            Name      = 'No Account Opp',
            // AccountId intentionally omitted — no employer group
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert noAcctOpp;

        Quote orphan = new Quote(
            Name         = 'Orphan Bind Quote',
            OpportunityId = noAcctOpp.Id,
            Pricebook2Id = Test.getStandardPricebookId(),
            Status       = 'Draft'
        );
        insert orphan;

        // Manually insert a rated config (bypass service to skip opportunity guard)
        DD_Product__c product = [SELECT Id FROM DD_Product__c WHERE Product_Name__c = 'Advantage 200 Bind' LIMIT 1];
        DD_Selling_Model__c sm = [SELECT Id FROM DD_Selling_Model__c WHERE Product__c = :product.Id LIMIT 1];

        DD_Quote_Plan_Config__c orphanConfig = new DD_Quote_Plan_Config__c(
            Quote__c              = orphan.Id,
            Product__c            = product.Id,
            Selling_Model__c      = sm.Id,
            Config_Status__c      = 'Rated',
            Selected_Annual_Max__c = 1500,
            Contribution_Type__c  = 'Percentage',
            Employer_Contribution_Pct__c = 50,
            Rate_Guarantee_Months__c = 12
        );
        insert orphanConfig;

        Integer policiesBefore = [SELECT COUNT() FROM DD_Policy__c];

        Test.startTest();
        try {
            DDPolicyBindService.bindQuote(orphan.Id);
        } catch (Exception e) {
            // Expected — bind should fail and roll back
        }
        Test.stopTest();

        Integer policiesAfter = [SELECT COUNT() FROM DD_Policy__c];
        System.assertEquals(policiesBefore, policiesAfter,
            'Failed bind should roll back — no new policy records should exist');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Effective date — default to 1st of next month when not set / in the past
    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    static void testBindQuote_NullEffectiveDate_DefaultsToFirstOfNextMonth() {
        Opportunity opp = [SELECT Id FROM Opportunity WHERE Name = 'Bind Test Opp' LIMIT 1];
        Quote q2 = new Quote(
            Name = 'No Date Bind Quote', OpportunityId = opp.Id,
            Pricebook2Id = Test.getStandardPricebookId(), Status = 'Draft'
            // Effective_Date__c intentionally omitted
        );
        insert q2;

        DD_Product__c product = [SELECT Id FROM DD_Product__c WHERE Product_Name__c = 'Advantage 200 Bind' LIMIT 1];
        DD_Selling_Model__c sm = [SELECT Id FROM DD_Selling_Model__c WHERE Product__c = :product.Id LIMIT 1];

        DD_Quote_Plan_Config__c cfg =
            DDQuoteConfigService.createConfigFromDefaults(q2.Id, product.Id, sm.Id);
        cfg.Employer_Contribution_Pct__c = 75;
        update cfg;

        DDRatingEngineService.calculateRate(q2.Id);

        Test.startTest();
        Id policyId = DDPolicyBindService.bindQuote(q2.Id);
        Test.stopTest();

        DD_Policy__c policy = [SELECT Effective_Date__c FROM DD_Policy__c WHERE Id = :policyId];
        Date today = Date.today();
        Date expectedFirst = Date.newInstance(today.year(), today.month(), 1).addMonths(1);

        System.assertEquals(expectedFirst, policy.Effective_Date__c,
            'When quote has no effective date, policy should default to 1st of next month');
    }
}
