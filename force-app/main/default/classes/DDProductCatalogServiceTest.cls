/**
 * @description Tests for DDProductCatalogService.
 *
 *              Coverage targets:
 *                • getEligibleProducts — valid segment/size, below min size,
 *                  blank segment, contribution floor filter, no selling models
 *                • getAvailableAnnualMaxes — happy path, null productId, blank list
 *                • getAvailableOrthoOptions — happy path, no ortho product,
 *                  below enrollment minimum, null productId
 *                • getProductDetails — delegates to selector (smoke test)
 *
 * @author Enterprise Architecture Team
 * @date 2026-03
 */
@IsTest
private class DDProductCatalogServiceTest {

    @TestSetup
    static void setupTestData() {
        // Catalog foundation
        DD_Product_Catalog__c catalog = DDTestDataFactory.createProductCatalog();
        DD_Product_Category__c category = DDTestDataFactory.createProductCategory(catalog.Id);
        DD_Rate_Table__c rt = DDTestDataFactory.createRateTable(DDConstants.SEGMENT_SMALL_BUSINESS);

        // Product
        DD_Product__c product = DDTestDataFactory.createProduct(
            'Advantage 200',
            DDConstants.PLAN_FAMILY_PPO_ADVANTAGE,
            DDConstants.NETWORK_PPO_PLUS_PREMIER,
            category.Id
        );
        insert product;

        // Selling model — SB, groups 2-99, 50% min contribution
        DD_Selling_Model__c sm = DDTestDataFactory.createSellingModel(
            product.Id,
            DDConstants.SEGMENT_SMALL_BUSINESS,
            2, 99,
            rt.Id
        );
        insert sm;

        // A second product with no ortho (Ortho_Available__c = false)
        DD_Product__c noOrthoProduct = DDTestDataFactory.createProduct(
            'Core 100',
            DDConstants.PLAN_FAMILY_PPO_CORE,
            DDConstants.NETWORK_PPO,
            category.Id
        );
        noOrthoProduct.Ortho_Available__c = false;
        insert noOrthoProduct;

        DD_Selling_Model__c smCore = DDTestDataFactory.createSellingModel(
            noOrthoProduct.Id,
            DDConstants.SEGMENT_SMALL_BUSINESS,
            2, 99,
            rt.Id
        );
        insert smCore;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // getEligibleProducts — positive
    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    static void testGetEligibleProducts_ValidSegmentAndSize_ReturnsProducts() {
        Test.startTest();
        List<DDProductCatalogService.EligibleProduct> results =
            DDProductCatalogService.getEligibleProducts(
                DDConstants.SEGMENT_SMALL_BUSINESS, 25, 75
            );
        Test.stopTest();

        System.assert(!results.isEmpty(), 'Should return at least one eligible product');
        for (DDProductCatalogService.EligibleProduct ep : results) {
            System.assertNotEquals(null, ep.product,    'Product should be populated');
            System.assertNotEquals(null, ep.sellingModel, 'Selling model should be populated');
        }
    }

    @IsTest
    static void testGetEligibleProducts_ContributionAboveFloor_ReturnsProducts() {
        Test.startTest();
        List<DDProductCatalogService.EligibleProduct> results =
            DDProductCatalogService.getEligibleProducts(
                DDConstants.SEGMENT_SMALL_BUSINESS, 10, 100
            );
        Test.stopTest();

        System.assert(!results.isEmpty(), '100% contribution exceeds all floors — should return products');
    }

    @IsTest
    static void testGetEligibleProducts_ContributionBelowFloor_FiltersOut() {
        // Min_Contribution_Pct__c = 50; pass 10 → should filter products out
        Test.startTest();
        List<DDProductCatalogService.EligibleProduct> results =
            DDProductCatalogService.getEligibleProducts(
                DDConstants.SEGMENT_SMALL_BUSINESS, 10, 10
            );
        Test.stopTest();

        System.assert(results.isEmpty(), 'Products with 50% floor should be filtered when contribution is 10%');
    }

    @IsTest
    static void testGetEligibleProducts_NoSellingModelForSegment_ReturnsEmpty() {
        Test.startTest();
        List<DDProductCatalogService.EligibleProduct> results =
            DDProductCatalogService.getEligibleProducts(
                DDConstants.SEGMENT_LARGE_GROUP, 500, 75
            );
        Test.stopTest();

        System.assert(results.isEmpty(), 'No large group models in test data — should return empty list');
    }

    @IsTest
    static void testGetEligibleProducts_GroupSizeBelowMin_ThrowsException() {
        Test.startTest();
        try {
            DDProductCatalogService.getEligibleProducts(
                DDConstants.SEGMENT_SMALL_BUSINESS, 1, 75
            );
            System.assert(false, 'Group size 1 is below minimum — should throw');
        } catch (DDValidationException e) {
            System.assert(
                e.getMessage().contains(String.valueOf(DDConstants.MIN_GROUP_SIZE)),
                'Error should mention minimum group size'
            );
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetEligibleProducts_BlankSegment_ThrowsException() {
        Test.startTest();
        try {
            DDProductCatalogService.getEligibleProducts('', 25, 75);
            System.assert(false, 'Blank segment should throw DDValidationException');
        } catch (DDValidationException e) {
            System.assert(
                e.getMessage().containsIgnoreCase('segment'),
                'Error should mention the missing segment parameter'
            );
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetEligibleProducts_NullGroupSize_ThrowsException() {
        Test.startTest();
        try {
            DDProductCatalogService.getEligibleProducts(DDConstants.SEGMENT_SMALL_BUSINESS, null, 75);
            System.assert(false, 'Null group size should throw DDValidationException');
        } catch (DDValidationException e) {
            System.assert(e.getMessage() != null);
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetEligibleProducts_GroupAboveMaxSize_NotReturned() {
        // Max_Group_Size__c = 99; pass 150
        Test.startTest();
        List<DDProductCatalogService.EligibleProduct> results =
            DDProductCatalogService.getEligibleProducts(
                DDConstants.SEGMENT_SMALL_BUSINESS, 150, 75
            );
        Test.stopTest();

        System.assert(results.isEmpty(), 'Group size 150 exceeds SB max of 99 — no products should match');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // getAvailableAnnualMaxes
    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    static void testGetAvailableAnnualMaxes_ValidProduct_ReturnsSortedList() {
        DD_Product__c product = [SELECT Id FROM DD_Product__c WHERE Product_Name__c = 'Advantage 200' LIMIT 1];

        Test.startTest();
        List<Decimal> maxes = DDProductCatalogService.getAvailableAnnualMaxes(product.Id, 25, false);
        Test.stopTest();

        System.assertEquals(3, maxes.size(), 'Should return 3 annual max options (1000, 1500, 2000)');
        System.assertEquals(1000, maxes[0], 'First value should be lowest (sorted)');
        System.assertEquals(2000, maxes[2], 'Last value should be highest (sorted)');
    }

    @IsTest
    static void testGetAvailableAnnualMaxes_NullProductId_ThrowsException() {
        Test.startTest();
        try {
            DDProductCatalogService.getAvailableAnnualMaxes(null, 25, false);
            System.assert(false, 'Null productId should throw DDValidationException');
        } catch (DDValidationException e) {
            System.assert(
                e.getMessage().containsIgnoreCase('productId'),
                'Error should mention productId'
            );
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetAvailableAnnualMaxes_NoSellingModel_ReturnsEmpty() {
        // Create a product with NO selling model attached
        DD_Product_Category__c cat = [SELECT Id FROM DD_Product_Category__c LIMIT 1];
        DD_Product__c orphan = DDTestDataFactory.createProduct(
            'Orphan Product', DDConstants.PLAN_FAMILY_PPO_CORE, DDConstants.NETWORK_PPO, cat.Id
        );
        insert orphan;

        Test.startTest();
        List<Decimal> maxes = DDProductCatalogService.getAvailableAnnualMaxes(orphan.Id, 25, false);
        Test.stopTest();

        System.assert(maxes.isEmpty(), 'No selling model means no annual max options');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // getAvailableOrthoOptions
    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    static void testGetAvailableOrthoOptions_ValidOrthoProduct_ReturnsOptions() {
        DD_Product__c product = [SELECT Id FROM DD_Product__c WHERE Product_Name__c = 'Advantage 200' LIMIT 1];

        Test.startTest();
        DDProductCatalogService.OrthoOptions opts =
            DDProductCatalogService.getAvailableOrthoOptions(product.Id, 10, false);
        Test.stopTest();

        System.assert(!opts.availableTypes.isEmpty(), 'Should return ortho types');
        System.assert(!opts.availableMaxes.isEmpty(), 'Should return ortho max amounts');
        System.assert(opts.availableTypes.contains('Child Only'), 'Should include Child Only type');
    }

    @IsTest
    static void testGetAvailableOrthoOptions_NoOrthoProduct_ThrowsException() {
        DD_Product__c noOrtho = [SELECT Id FROM DD_Product__c WHERE Product_Name__c = 'Core 100' LIMIT 1];

        Test.startTest();
        try {
            DDProductCatalogService.getAvailableOrthoOptions(noOrtho.Id, 10, false);
            System.assert(false, 'Product without ortho should throw DDValidationException');
        } catch (DDValidationException e) {
            System.assert(
                e.getMessage().containsIgnoreCase('orthodontia')
                    || e.getMessage().containsIgnoreCase('ortho'),
                'Error should mention orthodontia'
            );
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetAvailableOrthoOptions_BelowEnrollmentMinimum_ThrowsException() {
        DD_Product__c product = [SELECT Id FROM DD_Product__c WHERE Product_Name__c = 'Advantage 200' LIMIT 1];
        // MIN_ENROLLED_ORTHO = 5; pass 2
        Test.startTest();
        try {
            DDProductCatalogService.getAvailableOrthoOptions(product.Id, 2, false);
            System.assert(false, 'Enrollment count 2 is below ortho minimum of 5 — should throw');
        } catch (DDValidationException e) {
            System.assert(
                e.getMessage().containsIgnoreCase('minimum'),
                'Error should mention minimum enrollment'
            );
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetAvailableOrthoOptions_NullProductId_ThrowsException() {
        Test.startTest();
        try {
            DDProductCatalogService.getAvailableOrthoOptions(null, 10, false);
            System.assert(false, 'Null productId should throw DDValidationException');
        } catch (DDValidationException e) {
            System.assert(
                e.getMessage().containsIgnoreCase('productId'),
                'Error should mention productId'
            );
        }
        Test.stopTest();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // getProductDetails — smoke test (delegates to selector)
    // ─────────────────────────────────────────────────────────────────────────

    @IsTest
    static void testGetProductDetails_ValidProduct_ReturnsDetail() {
        DD_Product__c product = [SELECT Id FROM DD_Product__c WHERE Product_Name__c = 'Advantage 200' LIMIT 1];

        // Create coverage specs so the selector returns a populated detail
        DD_Coverage_Spec__c dnp = DDTestDataFactory.createCoverageSpec(
            product.Id, 'Diagnostic & Preventive', 'DNP', 100, 80
        );
        insert dnp;

        Test.startTest();
        DDPlanDesignSelector.DDProductDetail detail =
            DDProductCatalogService.getProductDetails(product.Id);
        Test.stopTest();

        System.assertNotEquals(null, detail, 'Product detail should not be null');
        System.assertNotEquals(null, detail.product, 'Product field should be populated');
        System.assert(!detail.coverageSpecs.isEmpty(), 'Coverage specs should be returned');
    }
}
