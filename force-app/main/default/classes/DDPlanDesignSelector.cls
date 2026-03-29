/**
 * @description Selector class for DD_Product__c (root product / plan design master).
 *              All SOQL against DD_Product__c is centralised here.
 *              Never write ad-hoc product queries outside this class.
 * @author Enterprise Architecture Team
 * @date 2026-03
 */
public with sharing class DDPlanDesignSelector {

    // ─────────────────────────────────────────────────────────────────────────
    // PUBLIC METHODS
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @description Returns all active products ordered by plan family then name.
     *              Cacheable — safe to call from LWC wire adapters.
     * @return List of active DD_Product__c records
     */
    @AuraEnabled(cacheable=true)
    public static List<DD_Product__c> getActivePlans() {
        return [
            SELECT Id, Product_Name__c, Product_Code__c, Plan_Family__c, Product_Line__c,
                   Network_Fee_Basis__c, Is_Active__c,
                   Deductible_Individual__c, Deductible_Family__c,
                   Ortho_Available__c, DnP_Max_Waiver_Available__c,
                   SmileWay_Eligible__c, State__c, Product_Category__c
            FROM DD_Product__c
            WHERE Is_Active__c = true
            ORDER BY Plan_Family__c ASC, Product_Name__c ASC
        ];
    }

    /**
     * @description Returns products eligible for a given segment/group size,
     *              filtered via the DD_Selling_Model__c junction.
     *              Cacheable — safe to call from LWC wire adapters.
     * @param segment     Market segment, e.g. 'Small Business'
     * @param groupSize   Number of enrolled employees
     * @param isVoluntary Whether this is a voluntary (employee-paid) group
     * @return List of eligible DD_Product__c records
     */
    @AuraEnabled(cacheable=true)
    public static List<DD_Product__c> getEligiblePlans(
        String segment,
        Integer groupSize,
        Boolean isVoluntary
    ) {
        if (String.isBlank(segment) || groupSize == null) {
            throw new DDValidationException('segment and groupSize are required for getEligiblePlans');
        }

        // Collect product IDs via selling-model eligibility filter.
        // Voluntary filter is applied conditionally — cannot use bind-variable
        // comparisons like :isVoluntary = false in SOQL WHERE clauses.
        List<DD_Selling_Model__c> sellingModels;
        if (isVoluntary == true) {
            sellingModels = [
                SELECT Product__c
                FROM DD_Selling_Model__c
                WHERE Is_Active__c = true
                  AND Segment__c = :segment
                  AND Min_Group_Size__c <= :groupSize
                  AND (Max_Group_Size__c = null OR Max_Group_Size__c >= :groupSize)
                  AND Voluntary_Available__c = true
                ORDER BY Product__c
            ];
        } else {
            sellingModels = [
                SELECT Product__c
                FROM DD_Selling_Model__c
                WHERE Is_Active__c = true
                  AND Segment__c = :segment
                  AND Min_Group_Size__c <= :groupSize
                  AND (Max_Group_Size__c = null OR Max_Group_Size__c >= :groupSize)
                ORDER BY Product__c
            ];
        }

        if (sellingModels.isEmpty()) {
            return new List<DD_Product__c>();
        }

        Set<Id> eligibleProductIds = new Set<Id>();
        for (DD_Selling_Model__c m : sellingModels) {
            eligibleProductIds.add(m.Product__c);
        }

        return [
            SELECT Id, Product_Name__c, Product_Code__c, Plan_Family__c, Product_Line__c,
                   Network_Fee_Basis__c, Is_Active__c,
                   Deductible_Individual__c, Deductible_Family__c,
                   Ortho_Available__c, DnP_Max_Waiver_Available__c,
                   SmileWay_Eligible__c, State__c, Product_Category__c
            FROM DD_Product__c
            WHERE Id IN :eligibleProductIds
              AND Is_Active__c = true
            ORDER BY Plan_Family__c ASC, Product_Name__c ASC
        ];
    }

    /**
     * @description Returns a single product with its child coverage specs,
     *              benefit specs (via separate query — SOQL does not support
     *              three-level subquery nesting), and active selling models.
     *              Cacheable — safe to call from LWC wire adapters.
     * @param productId  The DD_Product__c record Id
     * @return DDProductDetail wrapper containing the product and all related data
     */
    @AuraEnabled(cacheable=true)
    public static DDProductDetail getProductWithDetails(Id productId) {
        if (productId == null) {
            throw new DDValidationException('productId is required for getProductWithDetails');
        }

        // 1. Product + coverage specs + selling models in one query
        DD_Product__c product = [
            SELECT Id, Product_Name__c, Product_Code__c, Plan_Family__c, Product_Line__c,
                   Network_Fee_Basis__c, Is_Active__c,
                   Deductible_Individual__c, Deductible_Family__c,
                   Ortho_Available__c, DnP_Max_Waiver_Available__c,
                   SmileWay_Eligible__c, State__c, Product_Category__c,
                   (
                       SELECT Id, Coverage_Name__c, Coverage_Code__c, Display_Order__c,
                              Coinsurance_PPO__c, Coinsurance_NonPPO__c,
                              Deductible_Applies__c, Counts_Toward_Max__c,
                              Is_Optional__c, Requires_Preauth__c
                       FROM Coverage_Specs__r
                       ORDER BY Display_Order__c ASC NULLS LAST
                   ),
                   (
                       SELECT Id, Segment__c, Min_Group_Size__c, Max_Group_Size__c,
                              Is_Active__c, Voluntary_Available__c,
                              Min_Contribution_Pct__c, Employer_Paid_Available__c,
                              Available_Annual_Maxes__c, Available_Ortho_Maxes__c,
                              Available_Ortho_Types__c, Waiting_Period_Categories__c,
                              Waiting_Period_Months__c, Waiting_Period_Waiver_Allowed__c
                       FROM Selling_Models__r
                       WHERE Is_Active__c = true
                   )
            FROM DD_Product__c
            WHERE Id = :productId
            LIMIT 1
        ];

        // 2. Benefit specs — separate query since SOQL does not allow 3-level nesting
        Set<Id> coverageSpecIds = new Set<Id>();
        for (DD_Coverage_Spec__c cs : product.Coverage_Specs__r) {
            coverageSpecIds.add(cs.Id);
        }

        Map<Id, List<DD_Benefit_Spec__c>> benefitsBySpec = new Map<Id, List<DD_Benefit_Spec__c>>();
        for (Id csId : coverageSpecIds) {
            benefitsBySpec.put(csId, new List<DD_Benefit_Spec__c>());
        }

        for (DD_Benefit_Spec__c b : [
            SELECT Id, CDT_Code__c, CDT_Description__c, Coverage_Spec__c,
                   Frequency_Limit__c, Frequency_Period__c,
                   Age_Min__c, Age_Max__c,
                   Tooth_Specific__c, Quadrant_Specific__c, Requires_Preauth__c,
                   DHMO_Copay_11A__c, DHMO_Copay_15B__c, DHMO_Copay_17B__c,
                   Notes__c
            FROM DD_Benefit_Spec__c
            WHERE Coverage_Spec__c IN :coverageSpecIds
            ORDER BY CDT_Code__c ASC
        ]) {
            benefitsBySpec.get(b.Coverage_Spec__c).add(b);
        }

        return new DDProductDetail(product, benefitsBySpec);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // WRAPPER
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @description Wrapper returned by getProductWithDetails.
     *              Carries the product, its coverage specs (from the subquery),
     *              and a map of coverage-spec-id → benefit specs.
     */
    public class DDProductDetail {
        @AuraEnabled public DD_Product__c product;
        @AuraEnabled public List<DD_Coverage_Spec__c> coverageSpecs;
        @AuraEnabled public Map<Id, List<DD_Benefit_Spec__c>> benefitsBySpecId;

        public DDProductDetail(
            DD_Product__c prod,
            Map<Id, List<DD_Benefit_Spec__c>> benefitsMap
        ) {
            this.product          = prod;
            this.coverageSpecs    = prod.Coverage_Specs__r;
            this.benefitsBySpecId = benefitsMap;
        }
    }
}
