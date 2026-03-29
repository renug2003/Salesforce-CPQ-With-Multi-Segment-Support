/**
 * @description Wrapper class for rating calculation results returned by DDRatingEngineService.
 *              One DDRatingResult is produced per DD_Quote_Plan_Config__c that was rated.
 *              Exposed via @AuraEnabled so LWC components can bind directly to its fields.
 * @author Enterprise Architecture Team
 * @date 2026-03
 */
public class DDRatingResult {

    /** The config record that was rated */
    @AuraEnabled public Id configId;

    /** Product name for display */
    @AuraEnabled public String productName;

    /** 'Level 1' or 'Level 2' — drives which rate table was used */
    @AuraEnabled public String rateLevel;

    /** Sum of (monthlyRate × enrolledCount) across all tiers */
    @AuraEnabled public Decimal totalMonthlyPremium;

    /** Employer's portion of totalMonthlyPremium */
    @AuraEnabled public Decimal employerShare;

    /** Employee's average portion per enrolled member */
    @AuraEnabled public Decimal employeeShare;

    /** Total enrolled headcount across all tiers */
    @AuraEnabled public Integer totalEnrolledCount;

    /** Per-tier breakdown */
    @AuraEnabled public List<TierRate> tierRates;

    /** ISO-8601 timestamp of when this result was calculated */
    @AuraEnabled public String calculatedAt;

    public DDRatingResult() {
        this.tierRates        = new List<TierRate>();
        this.totalMonthlyPremium = 0;
        this.employerShare    = 0;
        this.employeeShare    = 0;
        this.totalEnrolledCount = 0;
        this.calculatedAt     = String.valueOf(System.now());
    }

    // ─────────────────────────────────────────────────────────────────────────
    // INNER CLASS — per-tier rate breakdown
    // ─────────────────────────────────────────────────────────────────────────

    public class TierRate {
        /** EE / ES / EC / EF */
        @AuraEnabled public String  tier;

        /** Number of enrolled members in this tier */
        @AuraEnabled public Integer enrolledCount;

        /** Per-member monthly rate (base rate × annual max factor) */
        @AuraEnabled public Decimal monthlyRate;

        /** enrolledCount × monthlyRate */
        @AuraEnabled public Decimal monthlyPremium;

        /** Employer portion of monthlyPremium */
        @AuraEnabled public Decimal employerShare;

        /** Employee portion of monthlyPremium */
        @AuraEnabled public Decimal employeeShare;

        public TierRate(String tier, Integer enrolledCount, Decimal monthlyRate) {
            this.tier          = tier;
            this.enrolledCount = enrolledCount;
            this.monthlyRate   = monthlyRate.setScale(2, RoundingMode.HALF_UP);
            this.monthlyPremium = (this.monthlyRate * enrolledCount).setScale(2, RoundingMode.HALF_UP);
            this.employerShare = 0;
            this.employeeShare = 0;
        }
    }
}
