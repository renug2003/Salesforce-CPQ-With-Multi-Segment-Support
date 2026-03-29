/**
 * @description Visualforce controller for the DDProposalPDF page.
 *              Fetches all data needed to render a dental insurance proposal PDF
 *              for a given DD_Proposal__c record.
 *
 * @author Enterprise Architecture Team
 * @date 2026-03
 */
public with sharing class DDProposalPDFController {

    public DD_Proposal__c           proposal         { get; private set; }
    public List<RateRow>            rateRows         { get; private set; }
    public List<CoverageRow>        coverageRows     { get; private set; }
    public Decimal                  totalPremium     { get; private set; }
    public String                   proposalDate     { get; private set; }
    public String                   totalPremiumFmt  { get; private set; }

    /** Flattened rate result row for the PDF tier table */
    public class RateRow {
        public String  tier          { get; set; }
        public Integer enrolled      { get; set; }
        public String  monthlyRate   { get; set; }
        public String  monthlyPremium { get; set; }
        public String  employerShare { get; set; }
        public String  employeeShare { get; set; }
    }

    /** Coverage category row for the benefits summary table */
    public class CoverageRow {
        public String  coverageName     { get; set; }
        public String  ppoPct           { get; set; }
        public String  nonPpoPct        { get; set; }
        public Boolean deductibleApplies { get; set; }
    }

    public DDProposalPDFController() {
        this.rateRows     = new List<RateRow>();
        this.coverageRows = new List<CoverageRow>();
        this.proposalDate = Date.today().format();

        Id proposalId = ApexPages.currentPage().getParameters().get('id');
        if (proposalId == null) return;

        // ── Load proposal with all related fields ─────────────────────────────
        List<DD_Proposal__c> proposals = [
            SELECT Id, Name, Effective_Date__c, Status__c, Plan_Name__c,
                   Opportunity__c,
                   Opportunity__r.Name,
                   Opportunity__r.Account.Name,
                   Opportunity__r.Account.Industry,
                   Opportunity__r.Account.BillingStreet,
                   Opportunity__r.Account.BillingCity,
                   Opportunity__r.Account.BillingState,
                   Opportunity__r.Account.BillingPostalCode,
                   Opportunity__r.Account.Phone,
                   Opportunity__r.Account.Group_Size__c,
                   Opportunity__r.Account.SIC_Code__c,
                   Opportunity__r.Account.Market_Segment__c,
                   Quote__c, Quote__r.Name,
                   Quote_Plan_Config__c,
                   Quote_Plan_Config__r.Product__c,
                   Quote_Plan_Config__r.Product__r.Product_Name__c,
                   Quote_Plan_Config__r.Product__r.Network_Fee_Basis__c,
                   Quote_Plan_Config__r.Product__r.Deductible_Individual__c,
                   Quote_Plan_Config__r.Product__r.Deductible_Family__c,
                   Quote_Plan_Config__r.Product__r.Ortho_Available__c,
                   Quote_Plan_Config__r.Selected_Annual_Max__c,
                   Quote_Plan_Config__r.Selected_Ortho_Type__c,
                   Quote_Plan_Config__r.Selected_Ortho_Max__c,
                   Quote_Plan_Config__r.DnP_Waiver_Selected__c,
                   Quote_Plan_Config__r.Employer_Contribution_Pct__c,
                   Quote_Plan_Config__r.Waiting_Period_Waived__c,
                   Quote_Plan_Config__r.Rate_Guarantee_Months__c
            FROM DD_Proposal__c
            WHERE Id = :proposalId
            LIMIT 1
        ];
        if (proposals.isEmpty()) return;
        this.proposal = proposals[0];

        // ── Rate results ──────────────────────────────────────────────────────
        Decimal total = 0;
        if (this.proposal.Quote_Plan_Config__c != null) {
            for (DD_Quote_Rate_Result__c rr : [
                SELECT Rate_Tier__c, Monthly_Rate__c, Enrolled_Count__c,
                       Monthly_Premium__c, Employer_Share__c, Employee_Share__c
                FROM DD_Quote_Rate_Result__c
                WHERE Quote_Plan_Config__c = :this.proposal.Quote_Plan_Config__c
                ORDER BY Rate_Tier__c ASC
            ]) {
                RateRow row       = new RateRow();
                row.tier          = rr.Rate_Tier__c;
                row.enrolled      = rr.Enrolled_Count__c != null ? Integer.valueOf(rr.Enrolled_Count__c) : 0;
                row.monthlyRate   = formatCurrency(rr.Monthly_Rate__c);
                row.monthlyPremium = formatCurrency(rr.Monthly_Premium__c);
                row.employerShare = formatCurrency(rr.Employer_Share__c);
                row.employeeShare = formatCurrency(rr.Employee_Share__c);
                if (rr.Monthly_Premium__c != null) total += rr.Monthly_Premium__c;
                this.rateRows.add(row);
            }

            // ── Coverage specs ────────────────────────────────────────────────
            Id productId = this.proposal.Quote_Plan_Config__r.Product__c;
            if (productId != null) {
                for (DD_Coverage_Spec__c spec : [
                    SELECT Coverage_Name__c, Coinsurance_PPO__c, Coinsurance_NonPPO__c,
                           Deductible_Applies__c
                    FROM DD_Coverage_Spec__c
                    WHERE Product__c = :productId
                    ORDER BY Display_Order__c ASC NULLS LAST, Coverage_Name__c ASC
                ]) {
                    CoverageRow cr    = new CoverageRow();
                    cr.coverageName   = spec.Coverage_Name__c;
                    cr.ppoPct         = spec.Coinsurance_PPO__c != null
                                            ? String.valueOf(spec.Coinsurance_PPO__c.intValue()) + '%' : 'N/A';
                    cr.nonPpoPct      = spec.Coinsurance_NonPPO__c != null
                                            ? String.valueOf(spec.Coinsurance_NonPPO__c.intValue()) + '%' : 'N/A';
                    cr.deductibleApplies = spec.Deductible_Applies__c;
                    this.coverageRows.add(cr);
                }
            }
        }
        this.totalPremium    = total;
        this.totalPremiumFmt = formatCurrency(total);
    }

    private static String formatCurrency(Decimal val) {
        if (val == null) return '$0.00';
        return '$' + val.setScale(2).toPlainString()
            .replaceAll('(\\d)(?=(\\d{3})+\\.)', '$1,');
    }
}
