# Skill: Apex Test Class Development

## When to Use
Use this skill when creating test classes for any Apex code.

## Requirements
- Minimum 90% code coverage per class
- Test positive, negative, and bulk scenarios
- Use `@TestSetup` for shared test data
- Never rely on existing org data — create all test data
- Test with `System.runAs()` for different user profiles

## Test Class Template

```apex
/**
 * @description Test class for DDRatingEngineService
 */
@IsTest
private class DDRatingEngineServiceTest {

    @TestSetup
    static void setupTestData() {
        // Create test account (employer group)
        Account group = DDTestDataFactory.createGroupAccount('Test Corp', '7372', 25);
        insert group;

        // Create plan designs
        List<DD_Plan_Design__c> plans = DDTestDataFactory.createAllPlanDesigns();
        insert plans;

        // Create rate table entries
        List<PricebookEntry> rates = DDTestDataFactory.createRateEntries(plans[0].Id);
        // ... additional setup
    }

    @IsTest
    static void testCalculateGroupRate_PPOAdvantage_Success() {
        // Arrange
        Account group = [SELECT Id FROM Account WHERE Name = 'Test Corp' LIMIT 1];
        DD_Plan_Design__c plan = [SELECT Id FROM DD_Plan_Design__c WHERE Plan_Name__c = 'Advantage 200' LIMIT 1];
        Quote testQuote = DDTestDataFactory.createQuoteWithLineItems(group.Id, plan.Id);

        // Act
        Test.startTest();
        DDRatingResult result = DDRatingEngineService.calculateGroupRate(testQuote.Id);
        Test.stopTest();

        // Assert
        System.assertNotEquals(null, result, 'Rating result should not be null');
        System.assert(result.totalMonthlyPremium > 0, 'Total premium should be positive');
        System.assertEquals(4, result.tierRates.size(), 'Should have 4 tier rates');
    }

    @IsTest
    static void testCalculateGroupRate_IneligibleSIC_ThrowsException() {
        // Arrange — use ineligible SIC code (dental office)
        Account group = DDTestDataFactory.createGroupAccount('Dental Office', '8021', 5);
        insert group;

        // Act & Assert
        Test.startTest();
        try {
            DDRatingEngineService.calculateGroupRate(group.Id);
            System.assert(false, 'Should have thrown DDRatingException');
        } catch (DDRatingException e) {
            System.assert(e.getMessage().contains('ineligible'), 'Error should mention ineligibility');
        }
        Test.stopTest();
    }

    @IsTest
    static void testCalculateGroupRate_BulkCensus() {
        // Test with 200+ census records for bulkification
        Account group = [SELECT Id FROM Account WHERE Name = 'Test Corp' LIMIT 1];
        List<DD_Census__c> census = DDTestDataFactory.createBulkCensus(group.Id, 200);
        insert census;

        Test.startTest();
        // Execute rating with large census
        Test.stopTest();

        // Assert performance and accuracy
    }
}
```

## Test Data Factory

```apex
/**
 * @description Factory class for creating test data across all DD objects
 */
@IsTest
public class DDTestDataFactory {

    public static Account createGroupAccount(String name, String sicCode, Integer groupSize) {
        return new Account(
            Name = name,
            SIC_Code__c = sicCode,
            Group_Size__c = groupSize,
            Industry_Rate_Level__c = 'Level 1',
            BillingState = 'CA',
            BillingPostalCode = '90210',
            DD_Group_Number__c = 'TEST-' + String.valueOf(Math.random()).substring(2, 8),
            Market_Segment__c = 'Small Business'
        );
    }

    public static DD_Plan_Design__c createPlanDesign(String name, String family, String network) {
        return new DD_Plan_Design__c(
            Plan_Name__c = name,
            Plan_Family__c = family,
            Network_Fee_Basis__c = network,
            DnP_Coinsurance_PPO__c = 100,
            Basic_Coinsurance_PPO__c = 80,
            Endo_Perio_OS_Coinsurance_PPO__c = 80,
            Major_Coinsurance_PPO__c = 50,
            Deductible_Individual__c = 50,
            Deductible_Family__c = 150,
            Is_Active__c = true,
            Min_Group_Size__c = 2
        );
    }

    public static List<DD_Plan_Design__c> createAllPlanDesigns() {
        List<DD_Plan_Design__c> plans = new List<DD_Plan_Design__c>();
        plans.add(createPlanDesign('Deluxe 100', 'PPO Deluxe', 'PPO Plus Premier'));
        plans.add(createPlanDesign('Advantage 200', 'PPO Advantage', 'PPO Plus Premier'));
        plans.add(createPlanDesign('Core 100', 'PPO Core', 'PPO'));
        plans.add(createPlanDesign('Core 201', 'PPO Core', 'PPO'));
        plans.add(createPlanDesign('DeltaCare 11A', 'DeltaCare USA', 'DeltaCare USA'));
        // Set Core 201 specifics
        plans[3].Endo_Perio_OS_Coinsurance_PPO__c = 0;
        plans[3].Major_Coinsurance_PPO__c = 0;
        return plans;
    }

    public static List<DD_Census__c> createBulkCensus(Id accountId, Integer count) {
        List<DD_Census__c> census = new List<DD_Census__c>();
        for (Integer i = 0; i < count; i++) {
            census.add(new DD_Census__c(
                Account__c = accountId,
                Employee_Name__c = 'Employee ' + i,
                DOB__c = Date.today().addYears(-30 - Math.mod(i, 35)),
                Gender__c = Math.mod(i, 2) == 0 ? 'M' : 'F',
                Zip_Code__c = '9' + String.valueOf(1000 + Math.mod(i, 9000)),
                Hire_Date__c = Date.today().addMonths(-12 - Math.mod(i, 60)),
                Enrollment_Tier__c = new List<String>{'EE','ES','EC','EF'}[Math.mod(i, 4)],
                Status__c = 'Active'
            ));
        }
        return census;
    }

    public static DD_Claim__c createClaim(Id memberId, Id providerId, Date dos) {
        return new DD_Claim__c(
            Member__c = memberId,
            Provider__c = providerId,
            Date_of_Service__c = dos,
            Claim_Type__c = 'Professional',
            Status__c = 'Received',
            Total_Charged__c = 500.00
        );
    }

    public static DD_Claim_Line__c createClaimLine(Id claimId, String cdtCode, Decimal charged) {
        return new DD_Claim_Line__c(
            Claim__c = claimId,
            CDT_Code__c = cdtCode,
            Charged_Amount__c = charged,
            Tooth_Number__c = '14',
            Surface__c = 'MO'
        );
    }
}
```

## Test Naming Convention
- `test{MethodName}_{Scenario}_{ExpectedResult}`
- Examples:
  - `testCalculateGroupRate_PPOAdvantage_Success`
  - `testCalculateGroupRate_IneligibleSIC_ThrowsException`
  - `testValidateEnrollment_DuplicateEnrollment_BlocksInsert`
  - `testAdjudicateClaim_FrequencyExceeded_DeniesLine`
