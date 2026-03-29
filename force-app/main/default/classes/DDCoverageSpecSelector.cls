/**
 * @description Selector class for DD_Coverage_Spec__c.
 *              All SOQL against DD_Coverage_Spec__c is centralised here.
 *              Coverage specs define the coinsurance, deductible, and benefit
 *              categories for a master product — they are read-only during quoting.
 * @author Enterprise Architecture Team
 * @date 2026-03
 */
public with sharing class DDCoverageSpecSelector {

    // ─────────────────────────────────────────────────────────────────────────
    // PUBLIC METHODS
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @description Returns all coverage specs for a product, ordered by Display_Order__c.
     *              Cacheable — safe to call from LWC wire adapters.
     * @param productId  The parent DD_Product__c record Id
     * @return Ordered list of DD_Coverage_Spec__c records
     */
    @AuraEnabled(cacheable=true)
    public static List<DD_Coverage_Spec__c> getCoveragesByProduct(Id productId) {
        if (productId == null) {
            throw new DDValidationException('productId is required for getCoveragesByProduct');
        }

        return [
            SELECT Id, Coverage_Name__c, Coverage_Code__c, Display_Order__c,
                   Product__c,
                   Coinsurance_PPO__c, Coinsurance_NonPPO__c,
                   Deductible_Applies__c, Counts_Toward_Max__c,
                   Is_Optional__c, Requires_Preauth__c
            FROM DD_Coverage_Spec__c
            WHERE Product__c = :productId
            ORDER BY Display_Order__c ASC NULLS LAST
        ];
    }

    /**
     * @description Returns a single coverage spec with its child benefit specs
     *              (CDT-code-level benefit definitions), ordered by CDT code.
     *              Cacheable — safe to call from LWC wire adapters.
     * @param coverageSpecId  The DD_Coverage_Spec__c record Id
     * @return The coverage spec record with a populated Benefit_Specs__r subquery
     */
    @AuraEnabled(cacheable=true)
    public static DD_Coverage_Spec__c getCoverageWithBenefits(Id coverageSpecId) {
        if (coverageSpecId == null) {
            throw new DDValidationException('coverageSpecId is required for getCoverageWithBenefits');
        }

        return [
            SELECT Id, Coverage_Name__c, Coverage_Code__c, Display_Order__c,
                   Product__c,
                   Coinsurance_PPO__c, Coinsurance_NonPPO__c,
                   Deductible_Applies__c, Counts_Toward_Max__c,
                   Is_Optional__c, Requires_Preauth__c,
                   (
                       SELECT Id, CDT_Code__c, CDT_Description__c, Coverage_Spec__c,
                              Frequency_Limit__c, Frequency_Period__c,
                              Age_Min__c, Age_Max__c,
                              Tooth_Specific__c, Quadrant_Specific__c, Requires_Preauth__c,
                              DHMO_Copay_11A__c, DHMO_Copay_15B__c, DHMO_Copay_17B__c,
                              Notes__c
                       FROM Benefit_Specs__r
                       ORDER BY CDT_Code__c ASC
                   )
            FROM DD_Coverage_Spec__c
            WHERE Id = :coverageSpecId
            LIMIT 1
        ];
    }

    /**
     * @description Returns all coverage specs for a set of products in one query.
     *              Use this when displaying a comparison table across multiple plans.
     * @param productIds  Set of DD_Product__c Ids
     * @return Map of productId → ordered list of coverage specs
     */
    public static Map<Id, List<DD_Coverage_Spec__c>> getCoveragesByProducts(Set<Id> productIds) {
        if (productIds == null || productIds.isEmpty()) {
            return new Map<Id, List<DD_Coverage_Spec__c>>();
        }

        Map<Id, List<DD_Coverage_Spec__c>> result = new Map<Id, List<DD_Coverage_Spec__c>>();
        for (Id pid : productIds) {
            result.put(pid, new List<DD_Coverage_Spec__c>());
        }

        for (DD_Coverage_Spec__c cs : [
            SELECT Id, Coverage_Name__c, Coverage_Code__c, Display_Order__c,
                   Product__c,
                   Coinsurance_PPO__c, Coinsurance_NonPPO__c,
                   Deductible_Applies__c, Counts_Toward_Max__c,
                   Is_Optional__c, Requires_Preauth__c
            FROM DD_Coverage_Spec__c
            WHERE Product__c IN :productIds
            ORDER BY Product__c, Display_Order__c ASC NULLS LAST
        ]) {
            result.get(cs.Product__c).add(cs);
        }

        return result;
    }
}
