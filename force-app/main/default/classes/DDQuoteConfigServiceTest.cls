/**
 * @description Tests for DDQuoteConfigService.
 *
 *              Coverage targets:
 *                • createConfigFromDefaults — happy path, idempotency, null params,
 *                  bad sellingModelId, bad productId, ortho vs. non-ortho product
 *                • updateConfig — Draft → Configured status transition, invalid values
 *                • validateConfig — each of the 5 validation rules individually,
 *                  null config, no selling model on config
 *
 * @author Enterprise Architecture Team
 * @date 2026-03
 */
@IsTest
private class DDQuoteConfigServiceTest {

    // IDs captured in @TestSetup and used across methods
    private static Id productId  { get { return [SELECT Id FROM DD_Product__c WHERE Product_Name__c = 'Advantage 200 QCS' LIMIT 1].Id; } }
    private static Id smId       { get { return [SELECT Id FROM DD_Selling_Model__c WHERE Product__c = :productId LIMIT 1].Id; } }
    private static Id quoteId    { get { return [SELECT Id FROM Quote LIMIT 1].Id; } }

    @TestSetup
    static void setupTestData() {
        DD_Product_Catalog__c catalog = DDTestDataFactory.createProductCatalog();
        DD_Product_Category__c category = DDTestDataFactory.createProductCategory(catalog.Id);
        DD_Rate_Table__c rt = DDTestDataFactory.createRateTable(DDConstants.SEGMENT_SMALL_BUSINESS);

        DD_Product__c product = DDTestDataFactory.createProduct(
            'Advantage 200 QCS',
            DDConstants.PLAN_FAMILY_PPO_ADVANTAGE,
            DDConstants.NETWORK_PPO_PLUS_PREMIER,
            category.Id
        );
        insert product;

        DD_Selling_Model__c sm = DDTestDataFactory.createSellingModel(
            product.Id,
            DDConstants.SEGMENT_SMALL_BUSINESS,
            2, 99,
            rt.Id
        );
        insert sm;

        // Employer group Account + Opportunity + Quote (bare minimum)
        Account grp = DDTestDataFactory.createGroupAccount('QCS Test Corp', '7372', 25);
        insert grp;

        Opportunity opp = new Opportunity(
            Name      = 'QCS Test Opp',
            AccountId = grp.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;

        Quote q = new Quote(
            Name          = 'QCS Test Quote',
            OpportunityId = opp.Id,
            Pricebook2Id  = Test.getStandardPricebookId(),
            Status        = 'Draft'
        );
        insert q;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // createConfigFromDefaults — positive paths
    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    static void testCreateConfigFromDefaults_HappyPath_ConfigHasCorrectDefaults() {
        Id pId = productId;
        Id sId = smId;
        Id qId = quoteId;

        Test.startTest();
        DD_Quote_Plan_Config__c config = DDQuoteConfigService.createConfigFromDefaults(qId, pId, sId);
        Test.stopTest();

        System.assertNotEquals(null, config.Id, 'Config should be inserted');
        System.assertEquals('Draft', config.Config_Status__c, 'New config should start as Draft');
        System.assertEquals('Percentage', config.Contribution_Type__c, 'Default contribution type should be Percentage');
        System.assertEquals(DDConstants.RATE_GUARANTEE_MONTHS, config.Rate_Guarantee_Months__c.intValue(), 'Rate guarantee should be 12 months');
        System.assertEquals(false, config.Waiting_Period_Waived__c, 'Waiting period waived should default to false');
        System.assertEquals(false, config.DnP_Waiver_Selected__c, 'D&P waiver should default to false');
        System.assertEquals(1000, config.Selected_Annual_Max__c, 'Default annual max should be first in list (1000)');
        System.assertEquals(50, config.Employer_Contribution_Pct__c, 'Default contribution should be selling model minimum (50%)');
    }

    @IsTest
    static void testCreateConfigFromDefaults_OrthoProduct_OrthoDefaultsSet() {
        Id pId = productId;  // Advantage 200 has Ortho_Available__c = true
        Id sId = smId;
        Id qId = quoteId;

        Test.startTest();
        DD_Quote_Plan_Config__c config = DDQuoteConfigService.createConfigFromDefaults(qId, pId, sId);
        Test.stopTest();

        System.assertNotEquals(null, config.Selected_Ortho_Type__c, 'Ortho type should be defaulted for ortho product');
        System.assertNotEquals(null, config.Selected_Ortho_Max__c,  'Ortho max should be defaulted for ortho product');
        System.assertEquals('Child Only', config.Selected_Ortho_Type__c, 'First ortho type in list should be default');
        System.assertEquals(1000, config.Selected_Ortho_Max__c, 'First ortho max in list should be default');
    }

    @IsTest
    static void testCreateConfigFromDefaults_NonOrthoProduct_OrthoFieldsNull() {
        DD_Product_Category__c cat = [SELECT Id FROM DD_Product_Category__c LIMIT 1];
        DD_Rate_Table__c rt = DDTestDataFactory.createRateTable(DDConstants.SEGMENT_SMALL_BUSINESS);
        DD_Product__c noOrtho = DDTestDataFactory.createProduct(
            'Core 100 NoOrtho', DDConstants.PLAN_FAMILY_PPO_CORE, DDConstants.NETWORK_PPO, cat.Id
        );
        noOrtho.Ortho_Available__c = false;
        insert noOrtho;

        DD_Selling_Model__c sm2 = DDTestDataFactory.createSellingModel(
            noOrtho.Id, DDConstants.SEGMENT_SMALL_BUSINESS, 2, 99, rt.Id
        );
        insert sm2;

        Id qId = quoteId;

        Test.startTest();
        DD_Quote_Plan_Config__c config = DDQuoteConfigService.createConfigFromDefaults(qId, noOrtho.Id, sm2.Id);
        Test.stopTest();

        System.assertEquals(null, config.Selected_Ortho_Type__c, 'Non-ortho product should have null ortho type');
        System.assertEquals(null, config.Selected_Ortho_Max__c,  'Non-ortho product should have null ortho max');
    }

    @IsTest
    static void testCreateConfigFromDefaults_Idempotent_ReturnsExistingRecord() {
        Id pId = productId;
        Id sId = smId;
        Id qId = quoteId;

        DD_Quote_Plan_Config__c first  = DDQuoteConfigService.createConfigFromDefaults(qId, pId, sId);

        Test.startTest();
        DD_Quote_Plan_Config__c second = DDQuoteConfigService.createConfigFromDefaults(qId, pId, sId);
        Test.stopTest();

        System.assertEquals(first.Id, second.Id, 'Second call should return the same record (idempotent)');
        Integer count = [SELECT COUNT() FROM DD_Quote_Plan_Config__c WHERE Quote__c = :qId AND Product__c = :pId];
        System.assertEquals(1, count, 'Only one config record should exist for this quote+product combo');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // createConfigFromDefaults — negative paths
    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    static void testCreateConfigFromDefaults_NullQuoteId_ThrowsException() {
        Test.startTest();
        try {
            DDQuoteConfigService.createConfigFromDefaults(null, productId, smId);
            System.assert(false, 'Null quoteId should throw');
        } catch (DDValidationException e) {
            System.assert(e.getMessage().containsIgnoreCase('required'), 'Error should mention required params');
        }
        Test.stopTest();
    }

    @IsTest
    static void testCreateConfigFromDefaults_NullProductId_ThrowsException() {
        Test.startTest();
        try {
            DDQuoteConfigService.createConfigFromDefaults(quoteId, null, smId);
            System.assert(false, 'Null productId should throw');
        } catch (DDValidationException e) {
            System.assert(e.getMessage() != null);
        }
        Test.stopTest();
    }

    @IsTest
    static void testCreateConfigFromDefaults_BadSellingModelId_ThrowsException() {
        Id bogusSmId = '001000000000001AAA';  // non-existent but valid format
        Test.startTest();
        try {
            DDQuoteConfigService.createConfigFromDefaults(quoteId, productId, bogusSmId);
            System.assert(false, 'Bad selling model Id should throw DDValidationException');
        } catch (DDValidationException e) {
            System.assert(
                e.getMessage().containsIgnoreCase('not found')
                    || e.getMessage().containsIgnoreCase('selling model'),
                'Error should describe missing selling model'
            );
        } catch (System.QueryException qe) {
            // Also acceptable — SOQL may throw for wrong SObject type
            System.assert(qe.getMessage() != null);
        }
        Test.stopTest();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // updateConfig
    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    static void testUpdateConfig_DraftToConfigured_StatusChanges() {
        DD_Quote_Plan_Config__c config =
            DDQuoteConfigService.createConfigFromDefaults(quoteId, productId, smId);

        config.Selected_Annual_Max__c      = 1500;  // still in allowed list
        config.Employer_Contribution_Pct__c = 75;

        Test.startTest();
        DDQuoteConfigService.updateConfig(config);
        Test.stopTest();

        DD_Quote_Plan_Config__c updated =
            [SELECT Config_Status__c, Selected_Annual_Max__c FROM DD_Quote_Plan_Config__c WHERE Id = :config.Id];
        System.assertEquals('Configured', updated.Config_Status__c, 'Status should advance to Configured');
        System.assertEquals(1500, updated.Selected_Annual_Max__c, 'Annual max should be saved');
    }

    @IsTest
    static void testUpdateConfig_AlreadyConfigured_StaysConfigured() {
        DD_Quote_Plan_Config__c config =
            DDQuoteConfigService.createConfigFromDefaults(quoteId, productId, smId);
        config.Config_Status__c = 'Configured';
        update config;

        config.Selected_Annual_Max__c = 2000;

        Test.startTest();
        DDQuoteConfigService.updateConfig(config);
        Test.stopTest();

        DD_Quote_Plan_Config__c updated =
            [SELECT Config_Status__c FROM DD_Quote_Plan_Config__c WHERE Id = :config.Id];
        System.assertEquals('Configured', updated.Config_Status__c, 'Already-Configured record should stay Configured');
    }

    @IsTest
    static void testUpdateConfig_InvalidAnnualMax_ThrowsException() {
        DD_Quote_Plan_Config__c config =
            DDQuoteConfigService.createConfigFromDefaults(quoteId, productId, smId);

        config.Selected_Annual_Max__c = 9999;  // not in allowed list [1000, 1500, 2000]

        Test.startTest();
        try {
            DDQuoteConfigService.updateConfig(config);
            System.assert(false, 'Annual max 9999 is not in allowed list — should throw');
        } catch (DDValidationException e) {
            System.assert(
                e.getMessage().contains('9999') || e.getMessage().containsIgnoreCase('annual max'),
                'Error should reference the invalid annual max'
            );
        }
        Test.stopTest();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // validateConfig — individual validation rules
    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    static void testValidateConfig_NullConfig_ThrowsException() {
        Test.startTest();
        try {
            DDQuoteConfigService.validateConfig(null);
            System.assert(false, 'Null config should throw');
        } catch (DDValidationException e) {
            System.assert(e.getMessage().containsIgnoreCase('null'), 'Error should mention null config');
        }
        Test.stopTest();
    }

    @IsTest
    static void testValidateConfig_NoSellingModel_ThrowsException() {
        DD_Quote_Plan_Config__c config = new DD_Quote_Plan_Config__c(
            Quote__c   = quoteId,
            Product__c = productId
            // Selling_Model__c intentionally omitted
        );

        Test.startTest();
        try {
            DDQuoteConfigService.validateConfig(config);
            System.assert(false, 'Config without selling model should throw');
        } catch (DDValidationException e) {
            System.assert(
                e.getMessage().containsIgnoreCase('selling_model')
                    || e.getMessage().containsIgnoreCase('selling model'),
                'Error should mention selling model requirement'
            );
        }
        Test.stopTest();
    }

    @IsTest
    static void testValidateConfig_ContributionBelowFloor_ThrowsException() {
        DD_Quote_Plan_Config__c config =
            DDQuoteConfigService.createConfigFromDefaults(quoteId, productId, smId);

        config.Employer_Contribution_Pct__c = 25;  // below 50% floor

        Test.startTest();
        try {
            DDQuoteConfigService.validateConfig(config);
            System.assert(false, 'Contribution below floor should throw DDValidationException');
        } catch (DDValidationException e) {
            System.assert(
                e.getMessage().containsIgnoreCase('contribution')
                    || e.getMessage().containsIgnoreCase('minimum'),
                'Error should mention contribution floor'
            );
        }
        Test.stopTest();
    }

    @IsTest
    static void testValidateConfig_InvalidOrthoType_ThrowsException() {
        DD_Quote_Plan_Config__c config =
            DDQuoteConfigService.createConfigFromDefaults(quoteId, productId, smId);

        config.Selected_Ortho_Type__c = 'Employee Only';  // not in allowed list

        Test.startTest();
        try {
            DDQuoteConfigService.validateConfig(config);
            System.assert(false, 'Invalid ortho type should throw');
        } catch (DDValidationException e) {
            System.assert(
                e.getMessage().containsIgnoreCase('ortho'),
                'Error should mention ortho type'
            );
        }
        Test.stopTest();
    }

    @IsTest
    static void testValidateConfig_InvalidOrthoMax_ThrowsException() {
        DD_Quote_Plan_Config__c config =
            DDQuoteConfigService.createConfigFromDefaults(quoteId, productId, smId);

        config.Selected_Ortho_Max__c = 9999;  // not in allowed list [1000, 1500]

        Test.startTest();
        try {
            DDQuoteConfigService.validateConfig(config);
            System.assert(false, 'Invalid ortho max should throw');
        } catch (DDValidationException e) {
            System.assert(
                e.getMessage().contains('9999') || e.getMessage().containsIgnoreCase('ortho max'),
                'Error should reference invalid ortho max'
            );
        }
        Test.stopTest();
    }

    @IsTest
    static void testValidateConfig_CoreBuyUpBelowFloor_ThrowsException() {
        // Create a Core Buy-Up product — has hard 50% floor regardless of SM setting
        DD_Product_Category__c cat = [SELECT Id FROM DD_Product_Category__c LIMIT 1];
        DD_Rate_Table__c rt = DDTestDataFactory.createRateTable(DDConstants.SEGMENT_SMALL_BUSINESS);
        DD_Product__c coreBuyUp = DDTestDataFactory.createProduct(
            'Core Buy-Up Test',
            DDConstants.PLAN_FAMILY_CORE_BUYUP,
            DDConstants.NETWORK_PPO,
            cat.Id
        );
        insert coreBuyUp;

        DD_Selling_Model__c sm2 = DDTestDataFactory.createSellingModel(
            coreBuyUp.Id, DDConstants.SEGMENT_SMALL_BUSINESS, 2, 99, rt.Id
        );
        sm2.Min_Contribution_Pct__c = 0;  // SM floor set to 0, but Core Buy-Up hard floor = 50
        insert sm2;

        Quote q2 = new Quote(
            Name          = 'Core BU Quote',
            OpportunityId = [SELECT Id FROM Opportunity LIMIT 1].Id,
            Pricebook2Id  = Test.getStandardPricebookId(),
            Status        = 'Draft'
        );
        insert q2;

        DD_Quote_Plan_Config__c config =
            DDQuoteConfigService.createConfigFromDefaults(q2.Id, coreBuyUp.Id, sm2.Id);
        config.Employer_Contribution_Pct__c = 25;  // below Core Buy-Up hard floor of 50%

        Test.startTest();
        try {
            DDQuoteConfigService.validateConfig(config);
            System.assert(false, 'Core Buy-Up with 25% contribution should throw');
        } catch (DDValidationException e) {
            System.assert(
                e.getMessage().containsIgnoreCase('core buy-up')
                    || e.getMessage().containsIgnoreCase('50'),
                'Error should mention Core Buy-Up minimum'
            );
        }
        Test.stopTest();
    }

    @IsTest
    static void testValidateConfig_ValidConfig_NoException() {
        DD_Quote_Plan_Config__c config =
            DDQuoteConfigService.createConfigFromDefaults(quoteId, productId, smId);
        // All fields already at valid defaults

        Test.startTest();
        DDQuoteConfigService.validateConfig(config);
        Test.stopTest();

        System.assert(true, 'Valid config should pass without exceptions');
    }
}
