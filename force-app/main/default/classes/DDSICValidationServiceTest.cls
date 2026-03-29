/**
 * @description Tests for DDSICValidationService.
 *
 *              Coverage targets:
 *                • validateEligibility — eligible code, blank code, ineligible code,
 *                  ineligible with DB record, ineligible without DB record (constants fallback)
 *                • getRateLevel — Level 1 SIC, Level 2 SIC, ineligible code throws
 *                • validateEligibilityBulk — mixed list, empty list
 *
 * @author Enterprise Architecture Team
 * @date 2026-03
 */
@IsTest
private class DDSICValidationServiceTest {

    // ── Eligible SIC codes ─────────────────────────────────────────────────
    // '7372' = Prepackaged Software — Level 1, clearly eligible
    private static final String SIC_ELIGIBLE_L1 = '7372';

    // '5812' = Eating Places (Restaurants) — Level 2, but ELIGIBLE for coverage
    private static final String SIC_ELIGIBLE_L2 = '5812';

    // ── Ineligible SIC codes ───────────────────────────────────────────────
    // '8021' = Dental Offices — ineligible per DDConstants
    private static final String SIC_INELIGIBLE_DENTAL = '8021';

    // '7231' = Beauty Shops — ineligible per DDConstants
    private static final String SIC_INELIGIBLE_BEAUTY = '7231';

    // ─────────────────────────────────────────────────────────────────────────
    // validateEligibility — positive paths
    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    static void testValidateEligibility_EligibleSIC_NoException() {
        // No DB mapping record — falls back to DDConstants (eligible by default)
        Test.startTest();
        DDSICValidationService.validateEligibility(SIC_ELIGIBLE_L1);
        Test.stopTest();
        // If we reach here without exception the test passes
        System.assert(true, 'Eligible SIC code should not throw');
    }

    @IsTest
    static void testValidateEligibility_EligibleSICWithDBRecord_NoException() {
        // Create a DB mapping record that marks this code eligible
        DD_SIC_Mapping__c mapping = new DD_SIC_Mapping__c(
            SIC_Start__c  = '7372',
            SIC_End__c    = '7372',
            Rate_Level__c = 'Level 1',
            Eligible__c   = true,
            Description__c = 'Prepackaged Software'
        );
        insert mapping;

        Test.startTest();
        DDSICValidationService.validateEligibility(SIC_ELIGIBLE_L1);
        Test.stopTest();
        System.assert(true, 'DB-backed eligible SIC should not throw');
    }

    @IsTest
    static void testValidateEligibility_Level2SIC_NoException() {
        // Level 2 SIC is still ELIGIBLE — only rate surcharge applies
        Test.startTest();
        DDSICValidationService.validateEligibility(SIC_ELIGIBLE_L2);
        Test.stopTest();
        System.assert(true, 'Level 2 SIC should be eligible (no exception)');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // validateEligibility — negative paths
    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    static void testValidateEligibility_BlankSIC_ThrowsValidationException() {
        Test.startTest();
        try {
            DDSICValidationService.validateEligibility('');
            System.assert(false, 'Expected DDValidationException for blank SIC');
        } catch (DDValidationException e) {
            System.assert(
                e.getMessage().containsIgnoreCase('required'),
                'Error message should mention "required". Got: ' + e.getMessage()
            );
        }
        Test.stopTest();
    }

    @IsTest
    static void testValidateEligibility_NullSIC_ThrowsValidationException() {
        Test.startTest();
        try {
            DDSICValidationService.validateEligibility(null);
            System.assert(false, 'Expected DDValidationException for null SIC');
        } catch (DDValidationException e) {
            System.assert(e.getMessage() != null, 'Exception message should not be null');
        }
        Test.stopTest();
    }

    @IsTest
    static void testValidateEligibility_IneligibleSICFromConstants_ThrowsException() {
        // No DB record — ineligibility resolved from DDConstants fallback
        Test.startTest();
        try {
            DDSICValidationService.validateEligibility(SIC_INELIGIBLE_DENTAL);
            System.assert(false, 'Expected DDValidationException for dental SIC 8021');
        } catch (DDValidationException e) {
            System.assert(
                e.getMessage().contains(SIC_INELIGIBLE_DENTAL),
                'Error should contain the offending SIC code'
            );
            System.assert(
                e.getMessage().containsIgnoreCase('ineligible')
                    || e.getMessage().containsIgnoreCase('excluded'),
                'Error should describe ineligibility'
            );
        }
        Test.stopTest();
    }

    @IsTest
    static void testValidateEligibility_IneligibleSICFromDB_ThrowsException() {
        // DB mapping record explicitly marks code ineligible
        DD_SIC_Mapping__c mapping = new DD_SIC_Mapping__c(
            SIC_Start__c   = '9990',
            SIC_End__c     = '9999',
            Rate_Level__c  = 'N/A',
            Eligible__c    = false,
            Description__c = 'Test Ineligible Industry'
        );
        insert mapping;

        Test.startTest();
        try {
            DDSICValidationService.validateEligibility('9995');  // within 9990-9999 range
            System.assert(false, 'Expected DDValidationException for DB-ineligible SIC');
        } catch (DDValidationException e) {
            System.assert(e.getMessage() != null, 'Should throw with a message');
        }
        Test.stopTest();
    }

    @IsTest
    static void testValidateEligibility_BeautyShop_ThrowsException() {
        Test.startTest();
        try {
            DDSICValidationService.validateEligibility(SIC_INELIGIBLE_BEAUTY);
            System.assert(false, 'Beauty shop SIC 7231 should be ineligible');
        } catch (DDValidationException e) {
            System.assert(e.getMessage().contains(SIC_INELIGIBLE_BEAUTY), 'Error should reference SIC');
        }
        Test.stopTest();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // getRateLevel — positive paths
    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    static void testGetRateLevel_Level1SIC_ReturnsLevel1() {
        Test.startTest();
        String level = DDSICValidationService.getRateLevel(SIC_ELIGIBLE_L1);
        Test.stopTest();

        System.assertEquals(
            DDConstants.RATE_LEVEL_1, level,
            'SIC 7372 (Prepackaged Software) should be Level 1'
        );
    }

    @IsTest
    static void testGetRateLevel_Level2SIC_ReturnsLevel2() {
        Test.startTest();
        String level = DDSICValidationService.getRateLevel(SIC_ELIGIBLE_L2);
        Test.stopTest();

        System.assertEquals(
            DDConstants.RATE_LEVEL_2, level,
            'SIC 5812 (Restaurants) should be Level 2'
        );
    }

    @IsTest
    static void testGetRateLevel_Level2SICFromDB_ReturnsLevel2() {
        // DB record overrides constant — marks a normally-Level-1 code as Level 2
        DD_SIC_Mapping__c mapping = new DD_SIC_Mapping__c(
            SIC_Start__c   = '1731',
            SIC_End__c     = '1731',
            Rate_Level__c  = 'Level 2',
            Eligible__c    = true,
            Description__c = 'Electrical Work'
        );
        insert mapping;

        Test.startTest();
        String level = DDSICValidationService.getRateLevel('1731');
        Test.stopTest();

        System.assertEquals(DDConstants.RATE_LEVEL_2, level, 'DB record should return Level 2');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // getRateLevel — negative path
    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    static void testGetRateLevel_IneligibleSIC_ThrowsException() {
        Test.startTest();
        try {
            DDSICValidationService.getRateLevel(SIC_INELIGIBLE_DENTAL);
            System.assert(false, 'Ineligible SIC should not return a rate level');
        } catch (DDValidationException e) {
            System.assert(e.getMessage() != null, 'Should throw with a message');
        }
        Test.stopTest();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // validateEligibilityBulk
    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    static void testValidateEligibilityBulk_MixedList_CorrectResults() {
        List<String> codes = new List<String>{
            SIC_ELIGIBLE_L1,      // eligible
            SIC_INELIGIBLE_DENTAL // ineligible
        };

        Test.startTest();
        Map<String, String> results = DDSICValidationService.validateEligibilityBulk(codes);
        Test.stopTest();

        System.assertEquals(2, results.size(), 'Should return result for every input code');
        System.assertEquals(
            '', results.get(SIC_ELIGIBLE_L1),
            'Eligible code should map to empty string'
        );
        System.assertNotEquals(
            '', results.get(SIC_INELIGIBLE_DENTAL),
            'Ineligible code should have a non-empty error message'
        );
    }

    @IsTest
    static void testValidateEligibilityBulk_EmptyList_ReturnsEmptyMap() {
        Test.startTest();
        Map<String, String> results = DDSICValidationService.validateEligibilityBulk(
            new List<String>()
        );
        Test.stopTest();

        System.assert(results.isEmpty(), 'Empty input should produce empty result map');
    }

    @IsTest
    static void testValidateEligibilityBulk_NullList_ReturnsEmptyMap() {
        Test.startTest();
        Map<String, String> results = DDSICValidationService.validateEligibilityBulk(null);
        Test.stopTest();

        System.assert(results.isEmpty(), 'Null input should produce empty result map');
    }

    @IsTest
    static void testValidateEligibilityBulk_AllEligible_AllEmptyStrings() {
        List<String> codes = new List<String>{ SIC_ELIGIBLE_L1, SIC_ELIGIBLE_L2 };

        Test.startTest();
        Map<String, String> results = DDSICValidationService.validateEligibilityBulk(codes);
        Test.stopTest();

        for (String code : codes) {
            System.assertEquals(
                '', results.get(code),
                code + ' should be eligible'
            );
        }
    }
}
