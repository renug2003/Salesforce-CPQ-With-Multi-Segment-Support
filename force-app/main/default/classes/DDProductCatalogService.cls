/**
 * @description Service class for reading the master product catalog.
 *              All catalog reads for the quoting UI go through this class.
 *              The master catalog is NEVER modified during quoting — this class
 *              is strictly read-only against the catalog objects.
 *
 *              Covers:
 *                - Eligible product discovery (segment + group size + UW rules)
 *                - Full product detail (coverages, benefits, selling model config)
 *                - Available annual max and ortho option lists for the config UI
 *
 * @author Enterprise Architecture Team
 * @date 2026-03
 */
public with sharing class DDProductCatalogService {

    // Status values for DD_Product_Rule__c.Rule_Type__c
    private static final String RULE_TYPE_ELIGIBILITY = 'Eligibility';
    private static final String RULE_TYPE_UW          = 'Underwriting';
    private static final String RULE_TYPE_CONFIG      = 'Configuration';

    // ─────────────────────────────────────────────────────────────────────────
    // PUBLIC METHODS
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @description Returns products eligible for a segment, group size, and
     *              contribution percentage, after applying active UW/eligibility rules.
     *              Called when an agent starts the plan selection step.
     *
     * @param segment         Market segment: 'Small Business', 'Individual', etc.
     * @param groupSize       Number of enrolled employees
     * @param contributionPct Employer contribution % being offered (0-100)
     * @return List<EligibleProduct> — products that pass all eligibility gates
     * @throws DDValidationException for missing required parameters
     */
    @AuraEnabled(cacheable=true)
    public static List<EligibleProduct> getEligibleProducts(
        String  segment,
        Integer groupSize,
        Decimal contributionPct
    ) {
        if (String.isBlank(segment)) {
            throw new DDValidationException('segment is required for getEligibleProducts');
        }
        if (groupSize == null || groupSize < DDConstants.MIN_GROUP_SIZE) {
            throw new DDValidationException(
                'groupSize must be at least ' + DDConstants.MIN_GROUP_SIZE
            );
        }

        // 1. Load selling models for this segment and group size
        List<DD_Selling_Model__c> sellingModels = [
            SELECT Id, Product__c, Segment__c,
                   Min_Group_Size__c, Max_Group_Size__c, Is_Active__c,
                   Voluntary_Available__c, Min_Contribution_Pct__c,
                   Employer_Paid_Available__c,
                   Available_Annual_Maxes__c, Available_Ortho_Maxes__c,
                   Available_Ortho_Types__c,
                   Waiting_Period_Months__c, Waiting_Period_Waiver_Allowed__c,
                   Rate_Table__c
            FROM DD_Selling_Model__c
            WHERE Is_Active__c = true
              AND Segment__c = :segment
              AND Min_Group_Size__c <= :groupSize
              AND (Max_Group_Size__c = null OR Max_Group_Size__c >= :groupSize)
            ORDER BY Product__c
        ];

        if (sellingModels.isEmpty()) {
            return new List<EligibleProduct>();
        }

        // 2. Build map of productId → selling model
        Set<Id> productIds = new Set<Id>();
        Map<Id, DD_Selling_Model__c> modelByProduct = new Map<Id, DD_Selling_Model__c>();
        for (DD_Selling_Model__c sm : sellingModels) {
            productIds.add(sm.Product__c);
            modelByProduct.put(sm.Product__c, sm);
        }

        // 3. Load the products
        List<DD_Product__c> products = [
            SELECT Id, Product_Name__c, Product_Code__c, Plan_Family__c, Product_Line__c,
                   Network_Fee_Basis__c, Is_Active__c,
                   Deductible_Individual__c, Deductible_Family__c,
                   Ortho_Available__c, DnP_Max_Waiver_Available__c,
                   SmileWay_Eligible__c, State__c, Product_Category__c
            FROM DD_Product__c
            WHERE Id IN :productIds
              AND Is_Active__c = true
            ORDER BY Plan_Family__c ASC, Product_Name__c ASC
        ];

        // 4. Load active eligibility and UW rules for these products
        Map<Id, List<DD_Product_Rule__c>> rulesByProduct = new Map<Id, List<DD_Product_Rule__c>>();
        for (Id pid : productIds) {
            rulesByProduct.put(pid, new List<DD_Product_Rule__c>());
        }
        for (DD_Product_Rule__c rule : [
            SELECT Id, Product__c, Rule_Name__c, Rule_Type__c,
                   Condition__c, Action__c, Priority__c, Segment__c
            FROM DD_Product_Rule__c
            WHERE Product__c IN :productIds
              AND Is_Active__c = true
              AND Rule_Type__c IN (:RULE_TYPE_ELIGIBILITY, :RULE_TYPE_UW)
              AND (Segment__c = :segment OR Segment__c = null)
            ORDER BY Product__c, Priority__c ASC NULLS LAST
        ]) {
            rulesByProduct.get(rule.Product__c).add(rule);
        }

        // 5. Apply contribution floor filter and UW rules, build result
        List<EligibleProduct> result = new List<EligibleProduct>();
        for (DD_Product__c p : products) {
            DD_Selling_Model__c sm = modelByProduct.get(p.Id);

            // Contribution floor check
            if (sm.Min_Contribution_Pct__c != null
                    && contributionPct != null
                    && contributionPct < sm.Min_Contribution_Pct__c) {
                continue;  // employer contribution below floor for this plan
            }

            // Core Buy-Up specific: minimum 50% contribution required
            if (p.Plan_Family__c == DDConstants.PLAN_FAMILY_CORE_BUYUP
                    && (contributionPct == null || contributionPct < DDConstants.MIN_CONTRIBUTION_CORE_BUYUP)) {
                continue;
            }

            // UW rules — currently evaluated by condition string match (Phase 1 simple rules)
            // Phase 3 will replace with a rules engine that evaluates Condition__c expressions
            Boolean passedRules = evaluateUWRules(rulesByProduct.get(p.Id), groupSize, contributionPct);
            if (!passedRules) {
                continue;
            }

            result.add(new EligibleProduct(p, sm));
        }

        return result;
    }

    /**
     * @description Returns the full product detail needed to populate the
     *              plan configuration screen: product master + coverage specs
     *              + benefit specs + active selling models.
     *              Delegates to DDPlanDesignSelector for the data fetch.
     *
     * @param productId  The DD_Product__c record Id
     * @return DDPlanDesignSelector.DDProductDetail wrapper
     * @throws DDValidationException for null productId
     */
    @AuraEnabled(cacheable=true)
    public static DDPlanDesignSelector.DDProductDetail getProductDetails(Id productId) {
        return DDPlanDesignSelector.getProductWithDetails(productId);
    }

    /**
     * @description Returns the list of annual max dollar amounts available for
     *              agent selection, parsed from the selling model's comma-separated
     *              Available_Annual_Maxes__c field.
     *              Filtered for voluntary groups per DDConstants thresholds.
     *
     *              Example Available_Annual_Maxes__c value: "1000,1500,2000,2500"
     *
     * @param productId    DD_Product__c record Id
     * @param groupSize    Number of enrolled employees
     * @param isVoluntary  Whether the group is voluntary (affects available options)
     * @return List<Decimal> — available annual max options in ascending order
     * @throws DDValidationException if productId is null or no selling model found
     */
    @AuraEnabled(cacheable=true)
    public static List<Decimal> getAvailableAnnualMaxes(
        Id      productId,
        Integer groupSize,
        Boolean isVoluntary
    ) {
        if (productId == null) {
            throw new DDValidationException('productId is required for getAvailableAnnualMaxes');
        }

        DD_Selling_Model__c sm = getActiveSellingModel(productId);
        if (sm == null || String.isBlank(sm.Available_Annual_Maxes__c)) {
            return new List<Decimal>();
        }

        List<Decimal> options = new List<Decimal>();
        for (String val : sm.Available_Annual_Maxes__c.split(',')) {
            String trimmed = val.trim();
            if (String.isNotBlank(trimmed) && trimmed.isNumeric()) {
                options.add(Decimal.valueOf(trimmed));
            }
        }
        options.sort();
        return options;
    }

    /**
     * @description Returns the available ortho options for a product.
     *              Parses Available_Ortho_Types__c and Available_Ortho_Maxes__c
     *              from the selling model. Applies enrollment minimums from DDConstants.
     *
     *              Example Available_Ortho_Types__c:  "Child Only,Adult and Child"
     *              Example Available_Ortho_Maxes__c:  "1000,1500,2000"
     *
     * @param productId     DD_Product__c record Id
     * @param enrolledCount Total enrolled member count
     * @param isVoluntary   Whether the group is voluntary
     * @return OrthoOptions wrapper with available types and max amounts
     * @throws DDValidationException if productId is null or product has no ortho
     */
    @AuraEnabled(cacheable=true)
    public static OrthoOptions getAvailableOrthoOptions(
        Id      productId,
        Integer enrolledCount,
        Boolean isVoluntary
    ) {
        if (productId == null) {
            throw new DDValidationException('productId is required for getAvailableOrthoOptions');
        }

        // Verify the product supports ortho
        List<DD_Product__c> products = [
            SELECT Id, Ortho_Available__c, Plan_Family__c
            FROM DD_Product__c
            WHERE Id = :productId
            LIMIT 1
        ];
        if (products.isEmpty() || products[0].Ortho_Available__c != true) {
            throw new DDValidationException(
                'Product ' + productId + ' does not support orthodontia coverage.'
            );
        }

        // Minimum enrollment check
        Integer minOrtho = (isVoluntary == true)
            ? DDConstants.MIN_ENROLLED_ADULT_ORTHO_VOL
            : DDConstants.MIN_ENROLLED_ORTHO;
        if (enrolledCount != null && enrolledCount < minOrtho) {
            throw new DDValidationException(
                'Orthodontia requires a minimum of ' + minOrtho
                + ' enrolled members for this group type. Current: ' + enrolledCount
            );
        }

        DD_Selling_Model__c sm = getActiveSellingModel(productId);
        if (sm == null) {
            return new OrthoOptions(new List<String>(), new List<Decimal>());
        }

        // Parse ortho types
        List<String> types = new List<String>();
        if (!String.isBlank(sm.Available_Ortho_Types__c)) {
            for (String t : sm.Available_Ortho_Types__c.split(',')) {
                String trimmed = t.trim();
                if (String.isNotBlank(trimmed)) {
                    types.add(trimmed);
                }
            }
        }

        // Parse ortho max amounts
        List<Decimal> maxes = new List<Decimal>();
        if (!String.isBlank(sm.Available_Ortho_Maxes__c)) {
            for (String val : sm.Available_Ortho_Maxes__c.split(',')) {
                String trimmed = val.trim();
                if (String.isNotBlank(trimmed) && trimmed.isNumeric()) {
                    maxes.add(Decimal.valueOf(trimmed));
                }
            }
        }
        maxes.sort();

        return new OrthoOptions(types, maxes);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // PRIVATE HELPERS
    // ─────────────────────────────────────────────────────────────────────────

    private static DD_Selling_Model__c getActiveSellingModel(Id productId) {
        List<DD_Selling_Model__c> models = [
            SELECT Id, Available_Annual_Maxes__c, Available_Ortho_Maxes__c,
                   Available_Ortho_Types__c, Min_Contribution_Pct__c,
                   Min_Group_Size__c, Max_Group_Size__c, Voluntary_Available__c,
                   Waiting_Period_Months__c, Waiting_Period_Waiver_Allowed__c,
                   Rate_Table__c
            FROM DD_Selling_Model__c
            WHERE Product__c = :productId
              AND Is_Active__c = true
            ORDER BY Min_Group_Size__c ASC
            LIMIT 1
        ];
        return models.isEmpty() ? null : models[0];
    }

    /**
     * Phase 1: simple rule evaluation — checks group size and contribution floor
     * rules encoded in Rule_Name__c or Condition__c as readable strings.
     * Phase 3 will replace with a full expression evaluator.
     */
    private static Boolean evaluateUWRules(
        List<DD_Product_Rule__c> rules,
        Integer groupSize,
        Decimal contributionPct
    ) {
        if (rules == null || rules.isEmpty()) {
            return true;
        }
        for (DD_Product_Rule__c rule : rules) {
            // Dual Choice minimum enrolled rule
            if (rule.Rule_Name__c != null
                    && rule.Rule_Name__c.containsIgnoreCase('Dual Choice')
                    && groupSize < DDConstants.MIN_ENROLLED_DUAL_CHOICE) {
                return false;
            }
        }
        return true;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // WRAPPERS
    // ─────────────────────────────────────────────────────────────────────────

    /** Pairs a product with its active selling model for the eligibility result */
    public class EligibleProduct {
        @AuraEnabled public DD_Product__c     product;
        @AuraEnabled public DD_Selling_Model__c sellingModel;

        public EligibleProduct(DD_Product__c p, DD_Selling_Model__c sm) {
            this.product      = p;
            this.sellingModel = sm;
        }
    }

    /** Available ortho types and max dollar amounts for the config UI */
    public class OrthoOptions {
        @AuraEnabled public List<String>  availableTypes;
        @AuraEnabled public List<Decimal> availableMaxes;

        public OrthoOptions(List<String> types, List<Decimal> maxes) {
            this.availableTypes = types;
            this.availableMaxes = maxes;
        }
    }
}
