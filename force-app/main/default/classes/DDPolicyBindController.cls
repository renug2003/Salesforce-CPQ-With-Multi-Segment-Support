public with sharing class DDPolicyBindController {

    public class BindResult {
        @AuraEnabled public Id       groupId;
        @AuraEnabled public String   groupNumber;
        @AuraEnabled public Id       policyId;
        @AuraEnabled public String   policyName;
    }

    /**
     * Binds accepted proposals only:
     *   - Marks acceptedProposalIds → Accepted, rejectedProposalIds → Rejected
     *   - Delegates policy creation to DDPolicyBindService for accepted configs only
     *   - Creates ONE DD_Group__c linked to the quote
     *   - Accepts the Quote if ≥1 proposal accepted
     */
    @AuraEnabled
    public static BindResult bindPolicy(Id quoteId,
                                        List<Id> acceptedProposalIds,
                                        List<Id> rejectedProposalIds) {
        if (quoteId == null) throw new AuraHandledException('quoteId is required');
        if (acceptedProposalIds == null || acceptedProposalIds.isEmpty())
            throw new AuraHandledException('At least one proposal must be accepted.');

        Savepoint sp = Database.setSavepoint();
        try {
            // ── Load quote context ────────────────────────────────────────────
            Quote q = [
                SELECT Id, Name, OpportunityId,
                       Opportunity.AccountId,
                       Opportunity.Account.Name,
                       Opportunity.Account.Group_Size__c,
                       Opportunity.Account.SIC_Code__c,
                       Opportunity.Account.Market_Segment__c
                FROM Quote WHERE Id = :quoteId LIMIT 1
            ];

            // ── Get configs linked to accepted proposals ───────────────────────
            List<DD_Proposal__c> acceptedProps = [
                SELECT Id, Quote_Plan_Config__c
                FROM DD_Proposal__c
                WHERE Id IN :acceptedProposalIds
            ];
            Set<Id> acceptedConfigIds = new Set<Id>();
            for (DD_Proposal__c p : acceptedProps) {
                if (p.Quote_Plan_Config__c != null) acceptedConfigIds.add(p.Quote_Plan_Config__c);
            }

            // ── Create policies for accepted configs via service ───────────────
            List<Id> policyIds = DDPolicyBindService.bindQuoteAll(quoteId, acceptedConfigIds);
            Id primaryPolicyId = policyIds[0];

            // ── Load policy effective date ─────────────────────────────────────
            DD_Policy__c primaryPolicy = [
                SELECT Id, Name, Effective_Date__c, Monthly_Premium__c
                FROM DD_Policy__c WHERE Id = :primaryPolicyId LIMIT 1
            ];
            Date effDate = primaryPolicy.Effective_Date__c != null
                ? primaryPolicy.Effective_Date__c
                : Date.today().toStartOfMonth().addMonths(1);

            // ── Total premium from rate results (stamp may not exist on old data)
            Decimal totalPremium = 0;
            for (AggregateResult ar : [
                SELECT SUM(Monthly_Premium__c) total
                FROM DD_Quote_Rate_Result__c
                WHERE Quote_Plan_Config__c IN :acceptedConfigIds
            ]) {
                totalPremium = ar.get('total') != null ? (Decimal)ar.get('total') : 0;
            }

            // ── Create ONE Group for this quote ───────────────────────────────
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
                Monthly_Premium__c = totalPremium
            );
            insert grp;

            // ── Accept quote ──────────────────────────────────────────────────
            update new Quote(Id = quoteId, Status = 'Accepted');

            // ── Update proposal statuses ──────────────────────────────────────
            List<DD_Proposal__c> toUpdate = new List<DD_Proposal__c>();
            for (Id pid : acceptedProposalIds)
                toUpdate.add(new DD_Proposal__c(Id = pid, Status__c = 'Accepted'));
            if (rejectedProposalIds != null) {
                for (Id pid : rejectedProposalIds)
                    toUpdate.add(new DD_Proposal__c(Id = pid, Status__c = 'Rejected'));
            }
            if (!toUpdate.isEmpty()) update toUpdate;

            // ── Re-query group number ─────────────────────────────────────────
            grp = [SELECT Id, Group_Number__c FROM DD_Group__c WHERE Id = :grp.Id LIMIT 1];

            BindResult res  = new BindResult();
            res.groupId     = grp.Id;
            res.groupNumber = grp.Group_Number__c;
            res.policyId    = primaryPolicy.Id;
            res.policyName  = primaryPolicy.Name;
            return res;

        } catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Summary for the confirmation screen.
     * Sums premium directly from DD_Quote_Rate_Result__c so $0 never shows
     * even if Total_Monthly_Premium__c wasn't stamped on older records.
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

        // Load configs + sum their rate results for accurate premium
        List<DD_Quote_Plan_Config__c> configs = [
            SELECT Id, Product__r.Product_Name__c, Selected_Annual_Max__c,
                   Employer_Contribution_Pct__c
            FROM DD_Quote_Plan_Config__c WHERE Quote__c = :quoteId
        ];
        Set<Id> configIds = new Set<Id>();
        for (DD_Quote_Plan_Config__c c : configs) configIds.add(c.Id);

        Map<Id,Decimal> premiumByConfig = new Map<Id,Decimal>();
        for (AggregateResult ar : [
            SELECT Quote_Plan_Config__c configId, SUM(Monthly_Premium__c) total
            FROM DD_Quote_Rate_Result__c
            WHERE Quote_Plan_Config__c IN :configIds
            GROUP BY Quote_Plan_Config__c
        ]) {
            premiumByConfig.put(
                (Id)ar.get('configId'),
                ar.get('total') != null ? (Decimal)ar.get('total') : 0
            );
        }

        Decimal totalPremium = 0;
        List<Map<String,Object>> plans = new List<Map<String,Object>>();
        for (DD_Quote_Plan_Config__c cfg : configs) {
            Decimal p = premiumByConfig.containsKey(cfg.Id) ? premiumByConfig.get(cfg.Id) : 0;
            totalPremium += p;
            plans.add(new Map<String,Object>{
                'configId'     => cfg.Id,
                'planName'     => cfg.Product__r?.Product_Name__c,
                'annualMax'    => cfg.Selected_Annual_Max__c,
                'premium'      => p,
                'contribution' => cfg.Employer_Contribution_Pct__c
            });
        }

        // Load proposals with their linked config so the UI can show plan name
        List<Map<String,Object>> propList = new List<Map<String,Object>>();
        for (DD_Proposal__c p : [
            SELECT Id, Name, Status__c, Plan_Name__c, Quote_Plan_Config__c
            FROM DD_Proposal__c WHERE Quote__c = :quoteId
            ORDER BY CreatedDate ASC
        ]) {
            Decimal propPremium = premiumByConfig.containsKey(p.Quote_Plan_Config__c)
                ? premiumByConfig.get(p.Quote_Plan_Config__c) : 0;
            propList.add(new Map<String,Object>{
                'id'       => p.Id,
                'name'     => p.Name,
                'status'   => p.Status__c,
                'plan'     => p.Plan_Name__c,
                'premium'  => propPremium,
                'configId' => p.Quote_Plan_Config__c
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
