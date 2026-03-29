/**
 * @description Rating engine service for Delta Dental group premium calculations.
 *              Executes the full 11-step rating pipeline for one or more
 *              DD_Quote_Plan_Config__c records on a Quote.
 *
 *              Pipeline (per config):
 *                Step 1  — Load DD_Quote_Plan_Config__c with product and selling model
 *                Step 2  — Validate SIC eligibility via DDSICValidationService
 *                Step 3  — Determine rate level (Level 1 / Level 2)
 *                Step 4  — Load active census from DD_Census__c
 *                Step 5  — Look up base rates from DD_Rate_Entry__c
 *                Step 6  — Calculate per-tier rates (EE / ES / EC / EF)
 *                Step 7  — Apply annual max factor adjustment
 *                Step 8  — Calculate group composite premium
 *                Step 9  — Calculate employer / employee splits
 *                Step 10 — Delete stale DD_Quote_Rate_Result__c records
 *                Step 11 — Insert fresh DD_Quote_Rate_Result__c records
 *
 *              Annual max factor (Step 7):
 *                Base rates are priced at a $1,500 annual max (PPO) / $1,000 (DHMO).
 *                A scale factor is applied for higher/lower selections using a
 *                square-root model (diminishing-returns curve). Replace with an
 *                explicit rate factor table in Phase 3 for large groups.
 *
 * @author Enterprise Architecture Team
 * @date 2026-03
 */
public with sharing class DDRatingEngineService {

    // Base annual max assumptions baked into rate entries
    private static final Decimal BASE_ANNUAL_MAX_PPO  = 1500;
    private static final Decimal BASE_ANNUAL_MAX_DHMO = 0;    // DHMO = copay-based, no annual max factor

    // ─────────────────────────────────────────────────────────────────────────
    // PUBLIC METHODS
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @description Runs the full rating pipeline for all plan configs on a Quote.
     *              Writes results to DD_Quote_Rate_Result__c (delete-then-insert).
     *
     * @param quoteId  The standard Quote record Id
     * @return List<DDRatingResult> — one result per DD_Quote_Plan_Config__c on the quote
     * @throws DDRatingException   if rate table entries are missing for a product
     * @throws DDValidationException if SIC code is ineligible
     */
    public static List<DDRatingResult> calculateRate(Id quoteId) {
        if (quoteId == null) {
            throw new DDRatingException('quoteId is required for calculateRate');
        }

        // ── STEP 1: Load all configs for this quote with related data ─────────
        List<DD_Quote_Plan_Config__c> configs = [
            SELECT Id, Config_Status__c,
                   Product__c,
                   Product__r.Product_Name__c,
                   Product__r.Plan_Family__c,
                   Product__r.Network_Fee_Basis__c,
                   Selling_Model__c,
                   Selling_Model__r.Rate_Table__c,
                   Selling_Model__r.Min_Contribution_Pct__c,
                   Selling_Model__r.Segment__c,
                   Selling_Model__r.Waiting_Period_Waiver_Allowed__c,
                   Selected_Annual_Max__c,
                   Selected_Ortho_Type__c,
                   Selected_Ortho_Max__c,
                   Employer_Contribution_Pct__c,
                   Contribution_Dollar__c,
                   Contribution_Type__c,
                   DnP_Waiver_Selected__c,
                   Waiting_Period_Waived__c,
                   Rate_Guarantee_Months__c,
                   Quote__c,
                   Quote__r.Opportunity.AccountId,
                   Quote__r.Opportunity.Account.SIC_Code__c
            FROM DD_Quote_Plan_Config__c
            WHERE Quote__c = :quoteId
        ];

        if (configs.isEmpty()) {
            throw new DDRatingException(
                'No Quote Plan Configs found for Quote ' + quoteId
                + '. Add at least one plan before calculating rates.'
            );
        }

        // Extract shared context from the first config (same account for all)
        String   sicCode   = configs[0].Quote__r?.Opportunity?.Account?.SIC_Code__c;
        Id       accountId = configs[0].Quote__r?.Opportunity?.AccountId;

        // ── STEP 2: Validate SIC eligibility ─────────────────────────────────
        DDSICValidationService.validateEligibility(sicCode);

        // ── STEP 3: Determine rate level ──────────────────────────────────────
        String rateLevel = DDSICValidationService.getRateLevel(sicCode);

        // ── STEP 4: Load active census ────────────────────────────────────────
        List<DD_Census__c> census = [
            SELECT Id, Enrollment_Tier__c, Status__c
            FROM DD_Census__c
            WHERE Account__c = :accountId
              AND Status__c = :DDConstants.STATUS_ACTIVE
        ];

        // Count enrolled members per tier
        Map<String, Integer> enrolledByTier = countByTier(census);

        // ── STEPS 5-11: Rate each config ──────────────────────────────────────
        List<DDRatingResult> results = new List<DDRatingResult>();

        // Collect config IDs for bulk delete of old results
        Set<Id> configIds = new Set<Id>();
        for (DD_Quote_Plan_Config__c c : configs) {
            configIds.add(c.Id);
        }

        // ── STEP 10: Delete stale rate results (bulk before inserting new) ────
        delete [
            SELECT Id
            FROM DD_Quote_Rate_Result__c
            WHERE Quote_Plan_Config__c IN :configIds
        ];

        List<DD_Quote_Rate_Result__c> allNewResults = new List<DD_Quote_Rate_Result__c>();

        for (DD_Quote_Plan_Config__c config : configs) {

            // ── STEP 5: Look up base rates from DD_Rate_Entry__c ─────────────
            Id rateTableId = config.Selling_Model__r?.Rate_Table__c;
            if (rateTableId == null) {
                throw new DDRatingException(
                    'No rate table linked to selling model for product: '
                    + config.Product__r.Product_Name__c
                    + '. Assign a Rate_Table__c to the selling model before rating.'
                );
            }

            List<DD_Rate_Entry__c> rateEntries = [
                SELECT Rate_Tier__c, Monthly_Rate__c, Region__c
                FROM DD_Rate_Entry__c
                WHERE Rate_Table__c = :rateTableId
                  AND Product__c    = :config.Product__c
                ORDER BY Rate_Tier__c
            ];

            if (rateEntries.isEmpty()) {
                throw new DDRatingException(
                    'No rate entries found for product "' + config.Product__r.Product_Name__c
                    + '" in rate table ' + rateTableId
                    + '. Load rate data before calculating.'
                );
            }

            // Build tier → base rate map
            Map<String, Decimal> baseRateByTier = new Map<String, Decimal>();
            for (DD_Rate_Entry__c re : rateEntries) {
                baseRateByTier.put(re.Rate_Tier__c, re.Monthly_Rate__c);
            }

            // ── STEP 7: Annual max factor ─────────────────────────────────────
            Decimal annualMaxFactor = calculateAnnualMaxFactor(
                config.Selected_Annual_Max__c,
                config.Product__r.Plan_Family__c
            );

            // ── STEP 6 + 8: Calculate per-tier rates and composite premium ────
            DDRatingResult result = new DDRatingResult();
            result.configId    = config.Id;
            result.productName = config.Product__r.Product_Name__c;
            result.rateLevel   = rateLevel;

            Decimal totalPremium    = 0;
            Integer totalEnrolled   = 0;
            Map<String, Decimal> adjustedRateByTier = new Map<String, Decimal>();

            for (String tier : DDConstants.ALL_TIERS) {
                Integer enrolled  = enrolledByTier.containsKey(tier) ? enrolledByTier.get(tier) : 0;
                Decimal baseRate  = baseRateByTier.containsKey(tier) ? baseRateByTier.get(tier) : 0;
                Decimal adjRate   = (baseRate * annualMaxFactor).setScale(2, RoundingMode.HALF_UP);

                adjustedRateByTier.put(tier, adjRate);

                DDRatingResult.TierRate tr = new DDRatingResult.TierRate(tier, enrolled, adjRate);
                totalPremium  += tr.monthlyPremium;
                totalEnrolled += enrolled;
                result.tierRates.add(tr);
            }

            result.totalMonthlyPremium = totalPremium.setScale(2, RoundingMode.HALF_UP);
            result.totalEnrolledCount  = totalEnrolled;

            // ── STEP 9: Employer / employee splits ───────────────────────────
            applySplits(result, config);

            results.add(result);

            // ── STEP 11: Build new DD_Quote_Rate_Result__c records ───────────
            for (DDRatingResult.TierRate tr : result.tierRates) {
                allNewResults.add(new DD_Quote_Rate_Result__c(
                    Quote_Plan_Config__c = config.Id,
                    Rate_Tier__c         = tr.tier,
                    Monthly_Rate__c      = tr.monthlyRate,
                    Enrolled_Count__c    = tr.enrolledCount,
                    Monthly_Premium__c   = tr.monthlyPremium,
                    Employer_Share__c    = tr.employerShare,
                    Employee_Share__c    = tr.employeeShare,
                    Rate_Factors_JSON__c = buildFactorJSON(annualMaxFactor, rateLevel, config)
                ));
            }
        }

        // ── STEP 11: Insert all new results in one DML statement ──────────────
        if (!allNewResults.isEmpty()) {
            insert allNewResults;
        }

        // Update config statuses to Rated and stamp total premium
        Map<Id,Decimal> premiumByConfig = new Map<Id,Decimal>();
        for (DDRatingResult r : results) {
            premiumByConfig.put(r.configId, r.totalMonthlyPremium);
        }
        List<DD_Quote_Plan_Config__c> statusUpdates = new List<DD_Quote_Plan_Config__c>();
        for (DD_Quote_Plan_Config__c c : configs) {
            statusUpdates.add(new DD_Quote_Plan_Config__c(
                Id = c.Id,
                Config_Status__c = 'Rated',
                Total_Monthly_Premium__c = premiumByConfig.get(c.Id)
            ));
        }
        update statusUpdates;

        return results;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // PRIVATE HELPERS
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Groups census records by enrollment tier and counts enrolled members.
     * Only Active members are included (filtered in the SOQL above).
     */
    private static Map<String, Integer> countByTier(List<DD_Census__c> census) {
        Map<String, Integer> counts = new Map<String, Integer>{
            DDConstants.TIER_EE => 0,
            DDConstants.TIER_ES => 0,
            DDConstants.TIER_EC => 0,
            DDConstants.TIER_EF => 0
        };
        for (DD_Census__c c : census) {
            if (counts.containsKey(c.Enrollment_Tier__c)) {
                counts.put(c.Enrollment_Tier__c, counts.get(c.Enrollment_Tier__c) + 1);
            }
        }
        return counts;
    }

    /**
     * Calculates a scale factor for the selected annual max relative to the
     * base annual max baked into the rate table.
     *
     * Model: factor = sqrt(selectedMax / baseMax)
     *   — Captures diminishing return: doubling the max doesn't double the cost.
     *   — Factor is capped at [0.5, 2.0] to prevent extreme values.
     *   — DHMO plans are copay-based and do not use an annual max factor (factor = 1.0).
     *
     * Phase 3 extension: replace with DD_Rate_Factor__c lookup table keyed on
     * product, annual max bucket, and segment for large group experience rating.
     */
    private static Decimal calculateAnnualMaxFactor(Decimal selectedMax, String planFamily) {
        // DHMO and DeltaCare USA plans are copay-based — no annual max factor
        if (planFamily == DDConstants.PLAN_FAMILY_DHMO) {
            return 1.0;
        }

        if (selectedMax == null || selectedMax <= 0) {
            return 1.0;
        }

        Decimal baseMax = BASE_ANNUAL_MAX_PPO;
        Decimal ratio   = selectedMax / baseMax;
        Decimal factor  = Math.sqrt(ratio.doubleValue());

        // Cap factor between 0.5 and 2.0
        factor = factor < 0.5 ? 0.5 : (factor > 2.0 ? 2.0 : factor);
        return factor.setScale(4, RoundingMode.HALF_UP);
    }

    /**
     * Applies employer/employee contribution splits to both the result summary
     * and each individual TierRate.
     */
    private static void applySplits(DDRatingResult result, DD_Quote_Plan_Config__c config) {
        Decimal totalPremium = result.totalMonthlyPremium;
        Decimal employerTotal;

        if (config.Contribution_Type__c == 'Dollar Amount'
                && config.Contribution_Dollar__c != null) {
            // Dollar amount: employer pays a fixed $ per enrolled member per month
            employerTotal = (config.Contribution_Dollar__c * result.totalEnrolledCount)
                                .setScale(2, RoundingMode.HALF_UP);
            employerTotal = employerTotal > totalPremium ? totalPremium : employerTotal;
        } else {
            // Percentage (default): employer pays a % of total monthly premium
            Decimal pct = (config.Employer_Contribution_Pct__c != null)
                ? config.Employer_Contribution_Pct__c
                : 0;
            employerTotal = (totalPremium * pct / 100).setScale(2, RoundingMode.HALF_UP);
        }

        Decimal employeeTotal = (totalPremium - employerTotal).setScale(2, RoundingMode.HALF_UP);
        result.employerShare  = employerTotal;
        result.employeeShare  = result.totalEnrolledCount > 0
            ? (employeeTotal / result.totalEnrolledCount).setScale(2, RoundingMode.HALF_UP)
            : 0;

        // Distribute splits proportionally to each tier
        if (totalPremium > 0) {
            for (DDRatingResult.TierRate tr : result.tierRates) {
                Decimal proportion = tr.monthlyPremium / totalPremium;
                tr.employerShare   = (employerTotal * proportion).setScale(2, RoundingMode.HALF_UP);
                tr.employeeShare   = (tr.monthlyPremium - tr.employerShare).setScale(2, RoundingMode.HALF_UP);
            }
        }
    }

    /** Serialises key rating factors for audit trail storage in Rate_Factors_JSON__c */
    private static String buildFactorJSON(
        Decimal annualMaxFactor,
        String  rateLevel,
        DD_Quote_Plan_Config__c config
    ) {
        Map<String, Object> factors = new Map<String, Object>{
            'annualMaxFactor'  => annualMaxFactor,
            'rateLevel'        => rateLevel,
            'selectedAnnualMax' => config.Selected_Annual_Max__c,
            'contributionType' => config.Contribution_Type__c,
            'contributionPct'  => config.Employer_Contribution_Pct__c,
            'dnpWaiver'        => config.DnP_Waiver_Selected__c,
            'waitingPeriodWaived' => config.Waiting_Period_Waived__c,
            'ratedAt'          => String.valueOf(System.now())
        };
        return JSON.serialize(factors);
    }
}
