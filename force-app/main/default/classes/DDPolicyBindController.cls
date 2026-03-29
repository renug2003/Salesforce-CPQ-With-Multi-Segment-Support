public with sharing class DDPolicyBindController {

    public class BindResult {
        @AuraEnabled public Id       groupId;
        @AuraEnabled public String   groupNumber;
        @AuraEnabled public Id       policyId;
        @AuraEnabled public String   policyName;
        @AuraEnabled public List<Id> proposalIds;
    }

    /**
     * Accept all proposals, delegate policy creation to DDPolicyBindService,
     * then create the DD_Group__c record linking Account → Quote → Policy.
     */
    @AuraEnabled
    public static BindResult bindPolicy(Id quoteId, List<Id> proposalIds) {
        if (quoteId == null) throw new AuraHandledException('quoteId is required');

        Savepoint sp = Database.setSavepoint();
        try {
            // ── 1. Create policies via existing service (snapshot at bind) ───
            List<Id> policyIds = DDPolicyBindService.bindQuoteAll(quoteId);
            Id primaryPolicyId = policyIds[0];

            // ── 2. Load context for group record ─────────────────────────────
            Quote q = [
                SELECT Id, Name, OpportunityId,
                       Opportunity.AccountId,
                       Opportunity.Account.Name,
                       Opportunity.Account.Group_Size__c,
                       Opportunity.Account.SIC_Code__c,
                       Opportunity.Account.Market_Segment__c
                FROM Quote WHERE Id = :quoteId LIMIT 1
            ];

            DD_Quote_Plan_Config__c cfg = [
                SELECT Id, Total_Monthly_Premium__c
                FROM DD_Quote_Plan_Config__c
                WHERE Quote__c = :quoteId
                ORDER BY CreatedDate ASC LIMIT 1
            ];

            // Effective date comes from DD_Policy__c created by the service
            DD_Policy__c primaryPolicy = [
                SELECT Id, Name, Effective_Date__c
                FROM DD_Policy__c WHERE Id = :primaryPolicyId LIMIT 1
            ];
            Date effDate = primaryPolicy.Effective_Date__c != null
                ? primaryPolicy.Effective_Date__c
                : Date.today().toStartOfMonth().addMonths(1);

            // ── 3. Create Group record ────────────────────────────────────────
            DD_Group__c grp = new DD_Group__c(
                Name               = q.Opportunity.Account.Name + ' — Group',
                Account__c         = q.Opportunity.AccountId,
                Quote__c           = quoteId,
                Opportunity__c     = q.OpportunityId,
                Policy__c          = primaryPolicyId,
                Effective_Date__c  = effDate,
                Status__c          = 'Active',
                Group_Size__c      = q.Opportunity.Account.Group_Size__c != null
                                         ? (Integer)q.Opportunity.Account.Group_Size__c : null,
                SIC_Code__c        = q.Opportunity.Account.SIC_Code__c,
                Market_Segment__c  = q.Opportunity.Account.Market_Segment__c,
                Monthly_Premium__c = cfg.Total_Monthly_Premium__c
            );
            insert grp;

            // ── 4. Accept proposals ───────────────────────────────────────────
            if (proposalIds != null && !proposalIds.isEmpty()) {
                List<DD_Proposal__c> props = [
                    SELECT Id FROM DD_Proposal__c WHERE Id IN :proposalIds
                ];
                for (DD_Proposal__c p : props) p.Status__c = 'Accepted';
                update props;
            }

            // ── 5. Build result ───────────────────────────────────────────────
            grp = [SELECT Id, Group_Number__c FROM DD_Group__c WHERE Id = :grp.Id LIMIT 1];

            BindResult res    = new BindResult();
            res.groupId       = grp.Id;
            res.groupNumber   = grp.Group_Number__c;
            res.policyId      = primaryPolicy.Id;
            res.policyName    = primaryPolicy.Name;
            res.proposalIds   = proposalIds;
            return res;

        } catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Returns pre-bind summary data for the confirmation screen.
     */
    @AuraEnabled(cacheable=true)
    public static Map<String,Object> getBindSummary(Id quoteId) {
        if (quoteId == null) throw new AuraHandledException('quoteId is required');

        Quote q = [
            SELECT Id, Name, Status,
                   Opportunity.Account.Name,
                   Opportunity.Account.Group_Size__c,
                   Opportunity.Account.Market_Segment__c
            FROM Quote WHERE Id = :quoteId LIMIT 1
        ];

        List<Map<String,Object>> plans = new List<Map<String,Object>>();
        Decimal totalPremium = 0;
        for (DD_Quote_Plan_Config__c cfg : [
            SELECT Id, Product__r.Product_Name__c, Selected_Annual_Max__c,
                   Total_Monthly_Premium__c, Employer_Contribution_Pct__c
            FROM DD_Quote_Plan_Config__c WHERE Quote__c = :quoteId
        ]) {
            plans.add(new Map<String,Object>{
                'configId'     => cfg.Id,
                'planName'     => cfg.Product__r?.Product_Name__c,
                'annualMax'    => cfg.Selected_Annual_Max__c,
                'premium'      => cfg.Total_Monthly_Premium__c,
                'contribution' => cfg.Employer_Contribution_Pct__c
            });
            if (cfg.Total_Monthly_Premium__c != null) totalPremium += cfg.Total_Monthly_Premium__c;
        }

        List<Map<String,Object>> propList = new List<Map<String,Object>>();
        for (DD_Proposal__c p : [
            SELECT Id, Name, Status__c, Plan_Name__c
            FROM DD_Proposal__c WHERE Quote__c = :quoteId
        ]) {
            propList.add(new Map<String,Object>{
                'id' => p.Id, 'name' => p.Name,
                'status' => p.Status__c, 'plan' => p.Plan_Name__c
            });
        }

        return new Map<String,Object>{
            'quoteId'      => q.Id,
            'quoteName'    => q.Name,
            'quoteStatus'  => q.Status,
            'accountName'  => q.Opportunity?.Account?.Name,
            'groupSize'    => q.Opportunity?.Account?.Group_Size__c,
            'segment'      => q.Opportunity?.Account?.Market_Segment__c,
            'plans'        => plans,
            'proposals'    => propList,
            'totalPremium' => totalPremium
        };
    }
}
