/**
 * @description Service class implementing the "snapshot at bind" principle.
 *
 *              When an agent accepts a quote, this service freezes all configured
 *              values into DD_Policy__c and DD_Policy_Coverage__c records that are
 *              permanently independent of the master catalog.  After bind:
 *                • DD_Policy__c holds the frozen annual max, deductibles, premium,
 *                  ortho type, and effective/anniversary dates.
 *                • DD_Policy_Coverage__c holds frozen coinsurance values for every
 *                  coverage category — resolved using the inheritance chain:
 *                  DD_Quote_Coverage_Config__c override → DD_Coverage_Spec__c master default.
 *                • The master catalog objects (DD_Product__c, DD_Coverage_Spec__c,
 *                  DD_Benefit_Spec__c) are NEVER modified by this service.
 *
 *              Transactions: the entire bind runs in one Apex transaction.  A
 *              Savepoint is set at entry so any DML failure rolls back completely —
 *              the quote is never left in a partially-bound state.
 *
 *              Multi-plan support: one Quote may have multiple DD_Quote_Plan_Config__c
 *              records (e.g. Dual Choice PPO + DHMO).  Each config produces one
 *              DD_Policy__c.  The method returns the ID of the primary (first) policy
 *              and also exposes bindQuoteAll() for callers that need all policy IDs.
 *
 * @author Enterprise Architecture Team
 * @date 2026-03
 */
public with sharing class DDPolicyBindService {

    // ─────────────────────────────────────────────────────────────────────────
    // PUBLIC METHODS
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @description Snapshots the configured quote into policy records.
     *              Returns the ID of the primary (first) DD_Policy__c created.
     *              For Dual Choice groups that produce two policies, use bindQuoteAll().
     *
     * @param quoteId  The standard Quote record Id
     * @return Id of the primary DD_Policy__c
     * @throws DDValidationException if the quote is not ready to bind (not rated / not approved)
     * @throws DDRatingException     if no rate results exist to source the monthly premium
     */
    public static Id bindQuote(Id quoteId) {
        List<Id> policyIds = bindQuoteAll(quoteId);
        return policyIds[0];
    }

    /**
     * @description Snapshots all plan configs on the quote into policy records.
     *              Use this for Dual Choice groups where two policies are created.
     *
     * @param quoteId  The standard Quote record Id
     * @return List<Id> — one DD_Policy__c Id per DD_Quote_Plan_Config__c on the quote
     * @throws DDValidationException if the quote is not ready to bind
     * @throws DDRatingException     if rate results are missing
     */
    public static List<Id> bindQuoteAll(Id quoteId) {
        return bindQuoteAll(quoteId, null);
    }

    /** Overload — only binds configs in the provided set (null = all configs) */
    public static List<Id> bindQuoteAll(Id quoteId, Set<Id> configIdFilter) {
        if (quoteId == null) {
            throw new DDValidationException('quoteId is required for bindQuote');
        }

        Savepoint sp = Database.setSavepoint();
        try {
            return executeBindTransaction(quoteId, configIdFilter);
        } catch (Exception e) {
            Database.rollback(sp);
            if (e instanceof DDValidationException || e instanceof DDRatingException) throw e;
            throw new DDRatingException(
                'Policy bind failed and was rolled back. Cause: ' + e.getMessage()
            );
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // PRIVATE — TRANSACTION BODY
    // ─────────────────────────────────────────────────────────────────────────

    private static List<Id> executeBindTransaction(Id quoteId, Set<Id> configIdFilter) {

        // ── STEP 1: Load DD_Quote_Plan_Config__c records for this quote ───────
        // If configIdFilter is provided, only bind those configs (accepted proposals)
        //    Include subqueries for:
        //      • Coverage_Configs__r — agent overrides to coinsurance values
        //      • Rate_Results__r     — calculated monthly premium per tier
        //    Include parent lookups for:
        //      • Product__r          — master defaults (deductibles, plan family)
        //      • Quote__r            — effective date and account reference
        List<DD_Quote_Plan_Config__c> configs = [
            SELECT Id, Config_Status__c,
                   Product__c,
                   Product__r.Plan_Family__c,
                   Product__r.Deductible_Individual__c,
                   Product__r.Deductible_Family__c,
                   Selling_Model__c,
                   Selected_Annual_Max__c,
                   Selected_Ortho_Type__c,
                   Selected_Ortho_Max__c,
                   Employer_Contribution_Pct__c,
                   Contribution_Dollar__c,
                   Contribution_Type__c,
                   DnP_Waiver_Selected__c,
                   Waiting_Period_Waived__c,
                   Rate_Guarantee_Months__c,
                   Custom_Deductible_Individual__c,
                   Custom_Deductible_Family__c,
                   Quote__c,
                   Quote__r.Effective_Date__c,
                   Quote__r.Opportunity.AccountId,
                   (
                       SELECT Id, Coverage_Spec__c, Is_Excluded__c,
                              Override_Coinsurance_PPO__c, Override_Coinsurance_NonPPO__c
                       FROM Coverage_Configs__r
                   ),
                   (
                       SELECT Id, Rate_Tier__c, Monthly_Premium__c,
                              Employer_Share__c, Employee_Share__c, Enrolled_Count__c
                       FROM Rate_Results__r
                   )
            FROM DD_Quote_Plan_Config__c
            WHERE Quote__c = :quoteId
            ORDER BY CreatedDate ASC
        ];

        // Filter to accepted configs only when a filter set is provided
        if (configIdFilter != null && !configIdFilter.isEmpty()) {
            List<DD_Quote_Plan_Config__c> filtered = new List<DD_Quote_Plan_Config__c>();
            for (DD_Quote_Plan_Config__c c : configs) {
                if (configIdFilter.contains(c.Id)) filtered.add(c);
            }
            configs = filtered;
        }

        if (configs.isEmpty()) {
            throw new DDValidationException(
                'No Quote Plan Configs found for Quote ' + quoteId
                + '. Select at least one plan before binding.'
            );
        }

        // Guard: all configs must be in Rated or Configured status before bind
        List<String> notRated = new List<String>();
        for (DD_Quote_Plan_Config__c c : configs) {
            if (c.Config_Status__c != 'Rated' && c.Config_Status__c != 'Configured') {
                notRated.add(c.Product__r.Plan_Family__c + ' (status: ' + c.Config_Status__c + ')');
            }
        }
        if (!notRated.isEmpty()) {
            throw new DDValidationException(
                'The following plans must be rated before binding: '
                + String.join(notRated, ', ')
                + '. Run Calculate Rates and retry.'
            );
        }

        // ── STEP 2: Load DD_Quote_Coverage_Config__c overrides (already in subquery) ──
        //    Build a two-level map: configId → coverageSpecId → override record
        //    This gives O(1) lookup during the coverage snapshot loop.
        Map<Id, Map<Id, DD_Quote_Coverage_Config__c>> overridesByConfig =
            buildOverrideMap(configs);

        // ── Load master DD_Coverage_Spec__c for all products ─────────────────
        Set<Id> productIds = new Set<Id>();
        for (DD_Quote_Plan_Config__c c : configs) {
            productIds.add(c.Product__c);
        }

        Map<Id, List<DD_Coverage_Spec__c>> masterCoveragesByProduct =
            loadMasterCoverages(productIds);

        // ── Resolve the shared Account ID and effective date ──────────────────
        Id     accountId     = configs[0].Quote__r?.Opportunity?.AccountId;
        Date   effectiveDate = resolveEffectiveDate(configs[0].Quote__r?.Effective_Date__c);
        Date   anniversaryDate = effectiveDate.addYears(1);

        if (accountId == null) {
            throw new DDValidationException(
                'Quote must be linked to an Opportunity with an Account before binding.'
            );
        }

        // ── STEP 3: Create DD_Policy__c records (one per config) ─────────────
        List<DD_Policy__c> policies = new List<DD_Policy__c>();
        for (DD_Quote_Plan_Config__c config : configs) {
            policies.add(buildPolicyRecord(
                config, accountId, effectiveDate, anniversaryDate
            ));
        }
        insert policies;  // after this, every policy has an Id

        // ── STEP 4: Create DD_Policy_Coverage__c records ──────────────────────
        //    For each policy/config pair, iterate the master coverage specs.
        //    Apply override resolution:
        //      • If DD_Quote_Coverage_Config__c.Is_Excluded__c = true → skip
        //      • Coinsurance PPO/NonPPO → override value if set, else master default
        //      • Deductible_Applies__c  → always from master (no override field)
        List<DD_Policy_Coverage__c> allCoverages = new List<DD_Policy_Coverage__c>();

        for (Integer i = 0; i < configs.size(); i++) {
            DD_Quote_Plan_Config__c config = configs[i];
            DD_Policy__c            policy = policies[i];

            Map<Id, DD_Quote_Coverage_Config__c> overridesForConfig =
                overridesByConfig.containsKey(config.Id)
                    ? overridesByConfig.get(config.Id)
                    : new Map<Id, DD_Quote_Coverage_Config__c>();

            List<DD_Coverage_Spec__c> masterCoverages =
                masterCoveragesByProduct.containsKey(config.Product__c)
                    ? masterCoveragesByProduct.get(config.Product__c)
                    : new List<DD_Coverage_Spec__c>();

            for (DD_Coverage_Spec__c masterSpec : masterCoverages) {
                // Check if this coverage has a quote-level override
                DD_Quote_Coverage_Config__c coverageOverride =
                    overridesForConfig.containsKey(masterSpec.Id)
                        ? overridesForConfig.get(masterSpec.Id)
                        : null;

                // Skip excluded coverages (agent explicitly removed them)
                if (coverageOverride != null && coverageOverride.Is_Excluded__c == true) {
                    continue;
                }

                allCoverages.add(buildPolicyCoverageRecord(policy.Id, masterSpec, coverageOverride));
            }
        }

        if (!allCoverages.isEmpty()) {
            insert allCoverages;
        }

        // ── STEP 5: Update Quote.Status to Accepted ───────────────────────────
        //    Salesforce standard Quote.Status picklist includes 'Accepted' by default.
        update new Quote(Id = quoteId, Status = 'Accepted');

        // ── STEP 6: Update all config statuses to Approved ───────────────────
        List<DD_Quote_Plan_Config__c> statusUpdates = new List<DD_Quote_Plan_Config__c>();
        for (DD_Quote_Plan_Config__c c : configs) {
            statusUpdates.add(new DD_Quote_Plan_Config__c(
                Id               = c.Id,
                Config_Status__c = 'Approved'
            ));
        }
        update statusUpdates;

        // ── STEP 7: Return policy IDs ─────────────────────────────────────────
        List<Id> policyIds = new List<Id>();
        for (DD_Policy__c p : policies) {
            policyIds.add(p.Id);
        }
        return policyIds;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // PRIVATE BUILDERS
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Constructs the frozen DD_Policy__c record from the config snapshot.
     *
     * Deductible resolution (most-specific wins):
     *   1. Custom_Deductible_Individual/Family__c on config (agent override)
     *   2. Product__r.Deductible_Individual/Family__c (master default)
     *
     * Monthly premium: sum of all Rate_Results__r.Monthly_Premium__c.
     * If no rate results exist the premium is left null — caller must rate first.
     */
    private static DD_Policy__c buildPolicyRecord(
        DD_Quote_Plan_Config__c config,
        Id                      accountId,
        Date                    effectiveDate,
        Date                    anniversaryDate
    ) {
        // Sum all tier premiums from the rate results subquery
        Decimal totalMonthlyPremium = 0;
        if (config.Rate_Results__r != null) {
            for (DD_Quote_Rate_Result__c rr : config.Rate_Results__r) {
                if (rr.Monthly_Premium__c != null) {
                    totalMonthlyPremium += rr.Monthly_Premium__c;
                }
            }
        }
        if (totalMonthlyPremium == 0 && config.Config_Status__c == 'Rated') {
            throw new DDRatingException(
                'Rate results are missing for product ' + config.Product__c
                + '. Recalculate rates before binding.'
            );
        }

        // Deductible: use agent override if set, else fall back to product master
        Decimal deductibleIndividual = config.Custom_Deductible_Individual__c != null
            ? config.Custom_Deductible_Individual__c
            : config.Product__r.Deductible_Individual__c;

        Decimal deductibleFamily = config.Custom_Deductible_Family__c != null
            ? config.Custom_Deductible_Family__c
            : config.Product__r.Deductible_Family__c;

        return new DD_Policy__c(
            Account__c            = accountId,
            Product__c            = config.Product__c,
            Quote__c              = config.Quote__c,
            Quote_Plan_Config__c  = config.Id,
            Status__c             = DDConstants.STATUS_ACTIVE,
            Effective_Date__c     = effectiveDate,
            Anniversary_Date__c   = anniversaryDate,
            Term_Date__c          = anniversaryDate.addDays(-1),  // one day before next anniversary
            Annual_Max__c         = config.Selected_Annual_Max__c,
            Ortho_Type__c         = config.Selected_Ortho_Type__c,
            Deductible_Individual__c = deductibleIndividual,
            Deductible_Family__c     = deductibleFamily,
            Monthly_Premium__c       = totalMonthlyPremium.setScale(2, RoundingMode.HALF_UP)
        );
    }

    /**
     * Constructs a frozen DD_Policy_Coverage__c record using the inheritance chain:
     *   Override value (if set on DD_Quote_Coverage_Config__c)
     *     → Master default (from DD_Coverage_Spec__c)
     *
     * Deductible_Applies__c always comes from the master spec — there is no
     * override field for this on DD_Quote_Coverage_Config__c by design.
     */
    private static DD_Policy_Coverage__c buildPolicyCoverageRecord(
        Id                          policyId,
        DD_Coverage_Spec__c         masterSpec,
        DD_Quote_Coverage_Config__c coverageOverride
    ) {
        Decimal coinsurancePPO    = masterSpec.Coinsurance_PPO__c;
        Decimal coinsuranceNonPPO = masterSpec.Coinsurance_NonPPO__c;

        if (coverageOverride != null) {
            // Only apply the override value when it has been explicitly set
            // (null on the override record means "inherit from master")
            if (coverageOverride.Override_Coinsurance_PPO__c != null) {
                coinsurancePPO = coverageOverride.Override_Coinsurance_PPO__c;
            }
            if (coverageOverride.Override_Coinsurance_NonPPO__c != null) {
                coinsuranceNonPPO = coverageOverride.Override_Coinsurance_NonPPO__c;
            }
        }

        return new DD_Policy_Coverage__c(
            Policy__c             = policyId,
            Coverage_Spec__c      = masterSpec.Id,        // traceability link to master
            Coinsurance_PPO__c    = coinsurancePPO,
            Coinsurance_NonPPO__c = coinsuranceNonPPO,
            Deductible_Applies__c = masterSpec.Deductible_Applies__c  // always from master
        );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // PRIVATE HELPERS
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Builds a two-level map: configId → coverageSpecId → DD_Quote_Coverage_Config__c.
     * Sourced entirely from the Coverage_Configs__r subquery already loaded in STEP 1,
     * so no additional SOQL is consumed here.
     */
    private static Map<Id, Map<Id, DD_Quote_Coverage_Config__c>> buildOverrideMap(
        List<DD_Quote_Plan_Config__c> configs
    ) {
        Map<Id, Map<Id, DD_Quote_Coverage_Config__c>> result =
            new Map<Id, Map<Id, DD_Quote_Coverage_Config__c>>();

        for (DD_Quote_Plan_Config__c config : configs) {
            Map<Id, DD_Quote_Coverage_Config__c> bySpec =
                new Map<Id, DD_Quote_Coverage_Config__c>();

            if (config.Coverage_Configs__r != null) {
                for (DD_Quote_Coverage_Config__c ccc : config.Coverage_Configs__r) {
                    if (ccc.Coverage_Spec__c != null) {
                        bySpec.put(ccc.Coverage_Spec__c, ccc);
                    }
                }
            }
            result.put(config.Id, bySpec);
        }
        return result;
    }

    /**
     * Loads DD_Coverage_Spec__c master records for a set of products.
     * Returns a map of productId → ordered list of coverage specs.
     * Delegates to DDCoverageSpecSelector for the bulk query.
     */
    private static Map<Id, List<DD_Coverage_Spec__c>> loadMasterCoverages(Set<Id> productIds) {
        return DDCoverageSpecSelector.getCoveragesByProducts(productIds);
    }

    /**
     * Resolves the policy effective date.
     * Uses the Quote's EffectiveDate if set; defaults to the 1st of the following month
     * so the policy never starts in the past due to a missing date.
     */
    private static Date resolveEffectiveDate(Date quoteEffectiveDate) {
        if (quoteEffectiveDate != null && quoteEffectiveDate >= Date.today()) {
            return quoteEffectiveDate;
        }
        // Default: 1st of next month
        Date today = Date.today();
        return Date.newInstance(today.year(), today.month(), 1).addMonths(1);
    }
}
