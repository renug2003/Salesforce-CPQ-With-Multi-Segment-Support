/**
 * @description Tests for DDRatingEngineService.
 *
 *              Coverage targets:
 *                • calculateRate — happy path (PPO, $1500 max → factor 1.0),
 *                  above base max (factor > 1), below base max (factor < 1),
 *                  DHMO plan (factor always 1.0), ineligible SIC throws,
 *                  null quoteId throws, no configs throws, no rate entries throws,
 *                  dollar-amount contribution type, bulk census (200+ records),
 *                  re-rate (stale results deleted before insert)
 *
 * @author Enterprise Architecture Team
 * @date 2026-03
 */
@IsTest
private class DDRatingEngineServiceTest {

    // ─────────────────────────────────────────────────────────────────────────
    // @TestSetup — build the full product / rate / account stack once
    // ─────────────────────────────────────────────────────────────────────────

    @TestSetup
    static void setupTestData() {
        DD_Product_Catalog__c catalog = DDTestDataFactory.createProductCatalog();
        DD_Product_Category__c category = DDTestDataFactory.createProductCategory(catalog.Id);
        DD_Rate_Table__c rt = DDTestDataFactory.createRateTable(DDConstants.SEGMENT_SMALL_BUSINESS);

        // PPO product (annual max factor applies)
        DD_Product__c ppo = DDTestDataFactory.createProduct(
            'Advantage 200 Rating',
            DDConstants.PLAN_FAMILY_PPO_ADVANTAGE,
            DDConstants.NETWORK_PPO_PLUS_PREMIER,
            category.Id
        );
        insert ppo;

        DD_Selling_Model__c smPPO = DDTestDataFactory.createSellingModel(
            ppo.Id, DDConstants.SEGMENT_SMALL_BUSINESS, 2, 99, rt.Id
        );
        insert smPPO;

        DDTestDataFactory.createRateEntries(rt.Id, ppo.Id);

        // DHMO product (no annual max factor)
        DD_Product__c dhmo = DDTestDataFactory.createProduct(
            'DeltaCare 11A Rating',
            DDConstants.PLAN_FAMILY_DHMO,
            DDConstants.NETWORK_DELTACARE,
            category.Id
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

        // Employer group Account (eligible SIC 7372)
        Account grp = DDTestDataFactory.createGroupAccount('Rating Test Corp', '7372', 25);
        insert grp;

        // Census: 4 members (one per tier) — sufficient for rate calculation
        DDTestDataFactory.createCensus(grp.Id, 4);

        // Opportunity + Quote linked to the PPO product
        Opportunity opp = new Opportunity(
            Name = 'Rating Test Opp', AccountId = grp.Id,
            StageName = 'Prospecting', CloseDate = Date.today().addDays(30)
        );
        insert opp;

        Quote q = new Quote(
            Name = 'Rating Test Quote', OpportunityId = opp.Id,
            Pricebook2Id = Test.getStandardPricebookId(), Status = 'Draft',
            Effective_Date__c = Date.today().addMonths(1)
        );
        insert q;

        // Config at $1500 (base max — factor should be exactly 1.0)
        DD_Quote_Plan_Config__c config =
            DDQuoteConfigService.createConfigFromDefaults(q.Id, ppo.Id, smPPO.Id);
        config.Selected_Annual_Max__c       = 1500;
        config.Employer_Contribution_Pct__c = 75;
        config.Contribution_Type__c         = 'Percentage';
        update config;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // calculateRate — positive paths
    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    static void testCalculateRate_PPO_BaseMax_FactorIsOne() {
        Quote q = [SELECT Id FROM Quote WHERE Name = 'Rating Test Quote' LIMIT 1];

        Test.startTest();
        List<DDRatingResult> results = DDRatingEngineService.calculateRate(q.Id);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return one result for one config');
        DDRatingResult r = results[0];
        System.assert(r.totalMonthlyPremium > 0, 'Total premium should be positive');
        System.assertEquals(4, r.tierRates.size(), 'Should have 4 tier entries');
        System.assertEquals('Level 1', r.rateLevel, 'SIC 7372 should be Level 1');

        // At base max $1500 the factor is sqrt(1500/1500) = 1.0
        // EE=100, ES=190, EC=170, EF=250 with 1 enrolled per tier
        // Total = 100+190+170+250 = 710
        System.assertEquals(710, r.totalMonthlyPremium, 'At base max, premium should equal sum of raw rates');
    }

    @IsTest
    static void testCalculateRate_PPO_AboveBaseMax_FactorGreaterThanOne() {
        Quote q = [SELECT Id FROM Quote WHERE Name = 'Rating Test Quote' LIMIT 1];
        DD_Quote_Plan_Config__c config =
            [SELECT Id, Config_Status__c FROM DD_Quote_Plan_Config__c WHERE Quote__c = :q.Id LIMIT 1];

        // $2000 max → factor = sqrt(2000/1500) ≈ 1.1547 → rates go up
        config.Selected_Annual_Max__c = 2000;
        update config;

        Test.startTest();
        List<DDRatingResult> results = DDRatingEngineService.calculateRate(q.Id);
        Test.stopTest();

        System.assert(results[0].totalMonthlyPremium > 710,
            'Higher annual max should increase premium (factor > 1)');
    }

    @IsTest
    static void testCalculateRate_PPO_BelowBaseMax_FactorLessThanOne() {
        Quote q = [SELECT Id FROM Quote WHERE Name = 'Rating Test Quote' LIMIT 1];
        DD_Quote_Plan_Config__c config =
            [SELECT Id FROM DD_Quote_Plan_Config__c WHERE Quote__c = :q.Id LIMIT 1];

        // $1000 max → factor = sqrt(1000/1500) ≈ 0.8165 → rates go down
        config.Selected_Annual_Max__c = 1000;
        update config;

        Test.startTest();
        List<DDRatingResult> results = DDRatingEngineService.calculateRate(q.Id);
        Test.stopTest();

        System.assert(results[0].totalMonthlyPremium < 710,
            'Lower annual max should decrease premium (factor < 1)');
    }

    @IsTest
    static void testCalculateRate_DHMO_FactorAlwaysOne() {
        Account grp = [SELECT Id FROM Account WHERE Name = 'Rating Test Corp' LIMIT 1];
        DD_Product__c dhmo = [SELECT Id FROM DD_Product__c WHERE Product_Name__c = 'DeltaCare 11A Rating' LIMIT 1];
        DD_Selling_Model__c smDHMO =
            [SELECT Id FROM DD_Selling_Model__c WHERE Product__c = :dhmo.Id LIMIT 1];

        Opportunity opp = [SELECT Id FROM Opportunity WHERE Name = 'Rating Test Opp' LIMIT 1];
        Quote q2 = new Quote(
            Name = 'DHMO Test Quote', OpportunityId = opp.Id,
            Pricebook2Id = Test.getStandardPricebookId(), Status = 'Draft'
        );
        insert q2;

        DD_Quote_Plan_Config__c cfg =
            DDQuoteConfigService.createConfigFromDefaults(q2.Id, dhmo.Id, smDHMO.Id);
        // DHMO: Selected_Annual_Max__c null (no annual max) — factor must stay 1.0
        cfg.Selected_Annual_Max__c = null;
        cfg.Employer_Contribution_Pct__c = 50;
        update cfg;

        Test.startTest();
        List<DDRatingResult> results = DDRatingEngineService.calculateRate(q2.Id);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'One DHMO config → one result');
        // 4 census records × rates = 100+190+170+250 = 710 (factor = 1.0 for DHMO)
        System.assertEquals(710, results[0].totalMonthlyPremium,
            'DHMO plans should apply factor 1.0 regardless of annual max');
    }

    @IsTest
    static void testCalculateRate_DollarContributionType_SplitsCorrect() {
        Quote q = [SELECT Id FROM Quote WHERE Name = 'Rating Test Quote' LIMIT 1];
        DD_Quote_Plan_Config__c config =
            [SELECT Id FROM DD_Quote_Plan_Config__c WHERE Quote__c = :q.Id LIMIT 1];

        config.Selected_Annual_Max__c   = 1500;
        config.Contribution_Type__c     = 'Dollar Amount';
        config.Contribution_Dollar__c   = 100;  // $100 per enrolled member per month
        config.Employer_Contribution_Pct__c = null;
        update config;

        Test.startTest();
        List<DDRatingResult> results = DDRatingEngineService.calculateRate(q.Id);
        Test.stopTest();

        DDRatingResult r = results[0];
        // 4 enrolled × $100 = $400 employer share (capped at total premium if needed)
        Decimal expectedEmployer = Math.min(400, r.totalMonthlyPremium);
        System.assertEquals(expectedEmployer, r.employerShare,
            'Dollar amount contribution: employer share should be enrolled × dollar amount');
    }

    @IsTest
    static void testCalculateRate_PercentageContributionType_SplitsCorrect() {
        Quote q = [SELECT Id FROM Quote WHERE Name = 'Rating Test Quote' LIMIT 1];

        Test.startTest();
        List<DDRatingResult> results = DDRatingEngineService.calculateRate(q.Id);
        Test.stopTest();

        DDRatingResult r = results[0];
        Decimal expectedEmployer = (r.totalMonthlyPremium * 75 / 100).setScale(2, RoundingMode.HALF_UP);
        System.assertEquals(expectedEmployer, r.employerShare,
            '75% contribution: employer share should be 75% of total premium');
        System.assert(r.employeeShare >= 0, 'Employee share should not be negative');
    }

    @IsTest
    static void testCalculateRate_ResultsPersistedToRateResult() {
        Quote q = [SELECT Id FROM Quote WHERE Name = 'Rating Test Quote' LIMIT 1];

        Test.startTest();
        DDRatingEngineService.calculateRate(q.Id);
        Test.stopTest();

        DD_Quote_Plan_Config__c config =
            [SELECT Id, Config_Status__c FROM DD_Quote_Plan_Config__c WHERE Quote__c = :q.Id LIMIT 1];
        System.assertEquals('Rated', config.Config_Status__c, 'Config status should be updated to Rated');

        Integer resultCount = [
            SELECT COUNT() FROM DD_Quote_Rate_Result__c
            WHERE Quote_Plan_Config__c = :config.Id
        ];
        System.assertEquals(4, resultCount, 'Should write 4 rate results (one per tier)');
    }

    @IsTest
    static void testCalculateRate_RerateDeletesStaleResults() {
        Quote q = [SELECT Id FROM Quote WHERE Name = 'Rating Test Quote' LIMIT 1];

        // First rate
        DDRatingEngineService.calculateRate(q.Id);

        DD_Quote_Plan_Config__c config =
            [SELECT Id FROM DD_Quote_Plan_Config__c WHERE Quote__c = :q.Id LIMIT 1];
        Integer firstCount = [
            SELECT COUNT() FROM DD_Quote_Rate_Result__c WHERE Quote_Plan_Config__c = :config.Id
        ];

        // Second rate (re-rate) — stale results must be deleted first
        Test.startTest();
        DDRatingEngineService.calculateRate(q.Id);
        Test.stopTest();

        Integer secondCount = [
            SELECT COUNT() FROM DD_Quote_Rate_Result__c WHERE Quote_Plan_Config__c = :config.Id
        ];
        System.assertEquals(firstCount, secondCount,
            'Re-rating should delete and replace rate results — count should be identical');
    }

    @IsTest
    static void testCalculateRate_BulkCensus_200Members() {
        Account grp  = [SELECT Id FROM Account WHERE Name = 'Rating Test Corp' LIMIT 1];
        // Already have 4 from @TestSetup; add 196 more = 200 total
        DDTestDataFactory.createCensus(grp.Id, 196);

        Quote q = [SELECT Id FROM Quote WHERE Name = 'Rating Test Quote' LIMIT 1];

        Test.startTest();
        List<DDRatingResult> results = DDRatingEngineService.calculateRate(q.Id);
        Test.stopTest();

        System.assertEquals(200, results[0].totalEnrolledCount,
            'Should count all 200 census members');
        System.assert(results[0].totalMonthlyPremium > 0, 'Premium should be positive with bulk census');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // calculateRate — negative paths
    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    static void testCalculateRate_NullQuoteId_ThrowsRatingException() {
        Test.startTest();
        try {
            DDRatingEngineService.calculateRate(null);
            System.assert(false, 'Null quoteId should throw DDRatingException');
        } catch (DDRatingException e) {
            System.assert(e.getMessage().containsIgnoreCase('quoteId'), 'Error should mention quoteId');
        }
        Test.stopTest();
    }

    @IsTest
    static void testCalculateRate_NoConfigs_ThrowsRatingException() {
        // Create a brand-new quote with no configs
        Opportunity opp = [SELECT Id FROM Opportunity WHERE Name = 'Rating Test Opp' LIMIT 1];
        Quote emptyQ = new Quote(
            Name = 'Empty Quote', OpportunityId = opp.Id,
            Pricebook2Id = Test.getStandardPricebookId(), Status = 'Draft'
        );
        insert emptyQ;

        Test.startTest();
        try {
            DDRatingEngineService.calculateRate(emptyQ.Id);
            System.assert(false, 'Quote with no configs should throw DDRatingException');
        } catch (DDRatingException e) {
            System.assert(
                e.getMessage().containsIgnoreCase('no quote plan config')
                    || e.getMessage().containsIgnoreCase('plan'),
                'Error should describe missing configs'
            );
        }
        Test.stopTest();
    }

    @IsTest
    static void testCalculateRate_IneligibleSIC_ThrowsValidationException() {
        // Account with dental office SIC (8021) — ineligible
        Account dentalGrp = DDTestDataFactory.createGroupAccount('Dental Office Test', '8021', 10);
        insert dentalGrp;
        DDTestDataFactory.createCensus(dentalGrp.Id, 4);

        DD_Product__c ppo = [SELECT Id FROM DD_Product__c WHERE Product_Name__c = 'Advantage 200 Rating' LIMIT 1];
        DD_Selling_Model__c sm = [SELECT Id FROM DD_Selling_Model__c WHERE Product__c = :ppo.Id LIMIT 1];

        Opportunity opp = new Opportunity(
            Name = 'Dental Office Opp', AccountId = dentalGrp.Id,
            StageName = 'Prospecting', CloseDate = Date.today().addDays(30)
        );
        insert opp;

        Quote q = new Quote(
            Name = 'Dental Office Quote', OpportunityId = opp.Id,
            Pricebook2Id = Test.getStandardPricebookId(), Status = 'Draft'
        );
        insert q;

        DDQuoteConfigService.createConfigFromDefaults(q.Id, ppo.Id, sm.Id);

        Test.startTest();
        try {
            DDRatingEngineService.calculateRate(q.Id);
            System.assert(false, 'Ineligible SIC should throw DDValidationException');
        } catch (DDValidationException e) {
            System.assert(
                e.getMessage().contains('8021') || e.getMessage().containsIgnoreCase('ineligible'),
                'Error should mention the ineligible SIC code'
            );
        }
        Test.stopTest();
    }

    @IsTest
    static void testCalculateRate_NoRateEntries_ThrowsRatingException() {
        // Product with a selling model but NO rate entries in the rate table
        DD_Product_Category__c cat = [SELECT Id FROM DD_Product_Category__c LIMIT 1];
        DD_Rate_Table__c rt2 = DDTestDataFactory.createRateTable(DDConstants.SEGMENT_SMALL_BUSINESS);
        DD_Product__c product2 = DDTestDataFactory.createProduct(
            'No Rates Plan', DDConstants.PLAN_FAMILY_PPO_CORE, DDConstants.NETWORK_PPO, cat.Id
        );
        insert product2;

        DD_Selling_Model__c sm2 = DDTestDataFactory.createSellingModel(
            product2.Id, DDConstants.SEGMENT_SMALL_BUSINESS, 2, 99, rt2.Id
        );
        insert sm2;
        // Deliberately NOT creating rate entries for product2

        Opportunity opp = [SELECT Id FROM Opportunity WHERE Name = 'Rating Test Opp' LIMIT 1];
        Quote q3 = new Quote(
            Name = 'No Rates Quote', OpportunityId = opp.Id,
            Pricebook2Id = Test.getStandardPricebookId(), Status = 'Draft'
        );
        insert q3;

        DDQuoteConfigService.createConfigFromDefaults(q3.Id, product2.Id, sm2.Id);

        Test.startTest();
        try {
            DDRatingEngineService.calculateRate(q3.Id);
            System.assert(false, 'Missing rate entries should throw DDRatingException');
        } catch (DDRatingException e) {
            System.assert(
                e.getMessage().containsIgnoreCase('rate')
                    || e.getMessage().containsIgnoreCase('no rate'),
                'Error should describe missing rate data'
            );
        }
        Test.stopTest();
    }
}
