/**
 * @description Apex controller for the ddQuoteBuilder LWC.
 *              Acts as the single façade between the multi-step quote wizard
 *              and the underlying service layer. Every method is intentionally
 *              thin — validation and business logic live in the services.
 *
 * @author Enterprise Architecture Team
 * @date 2026-03
 */
public with sharing class DDQuoteBuilderController {

    // ─────────────────────────────────────────────────────────────────────────
    // WRAPPER CLASSES (returned to LWC)
    // ─────────────────────────────────────────────────────────────────────────

    /** Account + Opportunity context data for the two-column quote creator UI */
    public class AccountOppWrapper {
        @AuraEnabled public Id      accountId;
        @AuraEnabled public String  accountName;
        @AuraEnabled public String  industry;
        @AuraEnabled public String  billingStreet;
        @AuraEnabled public String  billingCity;
        @AuraEnabled public String  billingState;
        @AuraEnabled public String  billingPostalCode;
        @AuraEnabled public String  phone;
        @AuraEnabled public String  website;
        @AuraEnabled public String  sicCode;
        @AuraEnabled public Integer groupSize;
        @AuraEnabled public String  segment;
        @AuraEnabled public String  groupNumber;
        @AuraEnabled public Id      oppId;
        @AuraEnabled public String  oppName;
        @AuraEnabled public String  quoteStatus;
    }

    /** Lightweight result for a created proposal record */
    public class ProposalResult {
        @AuraEnabled public Id     proposalId;
        @AuraEnabled public String proposalName;
        @AuraEnabled public Id     contentDocumentId;
        public ProposalResult(Id pid, String pname, Id cdId) {
            this.proposalId        = pid;
            this.proposalName      = pname;
            this.contentDocumentId = cdId;
        }
    }

    public class GroupInfoWrapper {
        @AuraEnabled public String  accountName;
        @AuraEnabled public String  sicCode;
        @AuraEnabled public Integer groupSize;
        @AuraEnabled public String  segment;
        @AuraEnabled public String  groupNumber;
        @AuraEnabled public Id      accountId;
    }

    public class SICResult {
        @AuraEnabled public Boolean eligible;
        @AuraEnabled public String  rateLevel;
        @AuraEnabled public String  message;
    }

    public class CensusWrapper {
        @AuraEnabled public List<DD_Census__c> records;
        @AuraEnabled public Integer eeCount;
        @AuraEnabled public Integer esCount;
        @AuraEnabled public Integer ecCount;
        @AuraEnabled public Integer efCount;
        @AuraEnabled public Integer totalEnrolled;
        public CensusWrapper() {
            this.records      = new List<DD_Census__c>();
            this.eeCount      = 0; this.esCount = 0;
            this.ecCount      = 0; this.efCount = 0;
            this.totalEnrolled = 0;
        }
    }

    public class ComboOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        public ComboOption(String label, String value) {
            this.label = label; this.value = value;
        }
    }

    public class PlanConfigWrapper {
        @AuraEnabled public Id      quoteId;
        @AuraEnabled public Id      configId;
        @AuraEnabled public Decimal selectedAnnualMax;
        @AuraEnabled public String  selectedOrthoType;
        @AuraEnabled public Decimal selectedOrthoMax;
        @AuraEnabled public Boolean dnpWaiverSelected;
        @AuraEnabled public Boolean waitingPeriodWaived;
        @AuraEnabled public Decimal contributionPct;
        @AuraEnabled public String  configStatus;
        @AuraEnabled public Boolean orthoAvailable;
        @AuraEnabled public Decimal minContributionPct;
        @AuraEnabled public List<ComboOption> annualMaxOptions;
        @AuraEnabled public List<ComboOption> orthoTypeOptions;
        @AuraEnabled public List<ComboOption> orthoMaxOptions;
        @AuraEnabled public String  productName;
        @AuraEnabled public String  networkName;
        @AuraEnabled public Decimal customDeductibleInd;
        @AuraEnabled public Decimal customDeductibleFam;
        @AuraEnabled public Id      productId;
    }

    /**
     * @description Input class for manual census entry from the LWC.
     *              Each field maps 1:1 to DD_Census__c fields.
     */
    public class CensusEntryInput {
        @AuraEnabled public String employeeName;
        @AuraEnabled public String enrollmentTier;
        @AuraEnabled public String gender;
        @AuraEnabled public String dob;      // String — LWC sends YYYY-MM-DD; parsed below
        @AuraEnabled public String hireDate; // String — LWC sends YYYY-MM-DD; parsed below
        @AuraEnabled public String zipCode;
    }

    /**
     * @description Top-level wrapper returned by getProductBenefits.
     *              Contains all coverage specs with their nested benefit specs.
     */
    public class PlanBenefitsWrapper {
        @AuraEnabled public String              productName;
        @AuraEnabled public List<CoverageSpecDisplay> coverageSpecs;
        public PlanBenefitsWrapper() {
            this.coverageSpecs = new List<CoverageSpecDisplay>();
        }
    }

    /**
     * @description Display wrapper for a single DD_Coverage_Spec__c record,
     *              including its child benefit specs.
     */
    public class CoverageSpecDisplay {
        @AuraEnabled public String              coverageName;
        @AuraEnabled public Decimal             coinsurancePPO;
        @AuraEnabled public Decimal             coinsuranceNonPPO;
        @AuraEnabled public Boolean             deductibleApplies;
        @AuraEnabled public Integer             displayOrder;
        @AuraEnabled public List<BenefitSpecDisplay> benefits;
        public CoverageSpecDisplay() {
            this.benefits = new List<BenefitSpecDisplay>();
        }
    }

    /**
     * @description Display wrapper for a single DD_Benefit_Spec__c record.
     */
    public class BenefitSpecDisplay {
        @AuraEnabled public String  cdtCode;
        @AuraEnabled public String  cdtDescription;
        @AuraEnabled public Decimal frequencyLimit;
        @AuraEnabled public String  frequencyPeriod;
        @AuraEnabled public Decimal ageMin;
        @AuraEnabled public Decimal ageMax;
        @AuraEnabled public String  notes;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // ACCOUNT ACTION — Create Quote Opportunity (called from ddNewQuoteAction)
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Validates that the Account meets Small Business quoting criteria, then
     * creates a linked Opportunity and returns its Id.
     *
     * Eligibility:
     *   - Market_Segment__c = 'Small Business'
     *   - Group_Size__c between 2 and 99 (inclusive)
     *
     * Throws AuraHandledException with a user-friendly message if ineligible.
     */
    @AuraEnabled
    public static Id createQuoteOpportunity(Id accountId) {
        if (accountId == null) {
            throw new AuraHandledException('accountId is required');
        }

        Account acct = [
            SELECT Id, Name, Industry, Market_Segment__c, Group_Size__c, SIC_Code__c
            FROM Account
            WHERE Id = :accountId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        // ── Eligibility gate ──────────────────────────────────────────────────
        if (acct.Market_Segment__c != DDConstants.SEGMENT_SMALL_BUSINESS) {
            throw new AuraHandledException(
                'This account is not eligible for Small Business quoting. ' +
                'Market Segment must be "Small Business" (current: ' +
                (String.isBlank(acct.Market_Segment__c) ? 'not set' : acct.Market_Segment__c) + ').'
            );
        }
        Integer grpSize = acct.Group_Size__c != null ? Integer.valueOf(acct.Group_Size__c) : 0;
        if (grpSize < 2 || grpSize > 99) {
            throw new AuraHandledException(
                'Group size must be between 2 and 99 for Small Business quoting ' +
                '(current: ' + grpSize + ').'
            );
        }

        // ── Create Opportunity ────────────────────────────────────────────────
        String industryPart = String.isNotBlank(acct.Industry) ? (' — ' + acct.Industry) : '';
        String oppName = acct.Name + industryPart + ' — Quote ' + Date.today().year();

        Id pbId = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1].Id;
        Opportunity opp = new Opportunity(
            Name              = oppName,
            AccountId         = accountId,
            StageName         = 'Qualification',
            CloseDate         = Date.today().addDays(30),
            Pricebook2Id      = pbId
        );
        insert opp;
        return opp.Id;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // STEP 1 — Group Info
    // ─────────────────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static GroupInfoWrapper getGroupInfo(Id opportunityId) {
        if (opportunityId == null) {
            throw new AuraHandledException('opportunityId is required');
        }
        Opportunity opp = [
            SELECT Id, Name, AccountId,
                   Account.Name,
                   Account.SIC_Code__c,
                   Account.Group_Size__c,
                   Account.Market_Segment__c,
                   Account.DD_Group_Number__c
            FROM Opportunity
            WHERE Id = :opportunityId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        GroupInfoWrapper w = new GroupInfoWrapper();
        w.accountName = opp.Account.Name;
        w.sicCode     = opp.Account.SIC_Code__c;
        w.groupSize   = opp.Account.Group_Size__c != null
                            ? Integer.valueOf(opp.Account.Group_Size__c) : 0;
        w.segment     = String.isNotBlank(opp.Account.Market_Segment__c)
                            ? opp.Account.Market_Segment__c
                            : DDConstants.SEGMENT_SMALL_BUSINESS;
        w.groupNumber = opp.Account.DD_Group_Number__c;
        w.accountId   = opp.AccountId;
        return w;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // STEP 1 — SIC Validation
    // ─────────────────────────────────────────────────────────────────────────

    @AuraEnabled
    public static SICResult validateSIC(String sicCode) {
        SICResult r = new SICResult();
        try {
            DDSICValidationService.validateEligibility(sicCode);
            r.eligible  = true;
            r.rateLevel = DDSICValidationService.getRateLevel(sicCode);
            r.message   = 'SIC ' + sicCode + ' is eligible — ' + r.rateLevel;
        } catch (DDValidationException e) {
            r.eligible  = false;
            r.rateLevel = 'N/A';
            r.message   = e.getMessage();
        }
        return r;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // STEP 1 (Census) — Get existing census records
    // ─────────────────────────────────────────────────────────────────────────

    @AuraEnabled
    public static CensusWrapper getCensusData(Id accountId) {
        if (accountId == null) {
            throw new AuraHandledException('accountId is required');
        }
        CensusWrapper w = new CensusWrapper();
        w.records = [
            SELECT Id, Name, Employee_Name__c, Enrollment_Tier__c,
                   Status__c, DOB__c, Hire_Date__c, Zip_Code__c
            FROM DD_Census__c
            WHERE Account__c = :accountId
            ORDER BY Employee_Name__c ASC
        ];
        for (DD_Census__c c : w.records) {
            if (c.Status__c != DDConstants.STATUS_ACTIVE) continue;
            String tier = c.Enrollment_Tier__c;
            if      (tier == 'EE') w.eeCount++;
            else if (tier == 'ES') w.esCount++;
            else if (tier == 'EC') w.ecCount++;
            else if (tier == 'EF') w.efCount++;
            w.totalEnrolled++;
        }
        return w;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // STEP 1 (Census) — Save manual census entries
    // Deletes all existing census for the account, then inserts the new rows.
    // ─────────────────────────────────────────────────────────────────────────

    @AuraEnabled
    public static void saveCensusEntries(Id accountId, String entriesJson) {
        if (accountId == null) {
            throw new AuraHandledException('accountId is required');
        }
        List<CensusEntryInput> entries = new List<CensusEntryInput>();
        if (String.isNotBlank(entriesJson)) {
            entries = (List<CensusEntryInput>) JSON.deserialize(
                entriesJson, List<CensusEntryInput>.class
            );
        }

        // Delete existing census records for this account
        List<DD_Census__c> existing = [
            SELECT Id
            FROM DD_Census__c
            WHERE Account__c = :accountId
        ];
        if (!existing.isEmpty()) {
            delete existing;
        }

        // Build and insert new records
        List<DD_Census__c> toInsert = new List<DD_Census__c>();
        for (CensusEntryInput entry : entries) {
            DD_Census__c rec = new DD_Census__c(
                Account__c         = accountId,
                Employee_Name__c   = entry.employeeName,
                Enrollment_Tier__c = entry.enrollmentTier,
                Gender__c          = entry.gender,
                DOB__c             = String.isNotBlank(entry.dob)      ? Date.valueOf(entry.dob)      : null,
                Hire_Date__c       = String.isNotBlank(entry.hireDate) ? Date.valueOf(entry.hireDate) : null,
                Zip_Code__c        = entry.zipCode,
                Status__c          = DDConstants.STATUS_ACTIVE
            );
            toInsert.add(rec);
        }
        if (!toInsert.isEmpty()) {
            insert toInsert;
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // STEP 2 — Plan Selection
    // DDProductCatalogService.getEligibleProducts is already @AuraEnabled(cacheable=true)
    // and can be imported directly by the LWC. No wrapper needed.
    // ─────────────────────────────────────────────────────────────────────────

    // ─────────────────────────────────────────────────────────────────────────
    // STEP 2→4 — Create Quote + Config from plan selection
    // ─────────────────────────────────────────────────────────────────────────

    @AuraEnabled
    public static PlanConfigWrapper initAndSelectPlan(
        Id opportunityId,
        Id productId,
        Id sellingModelId
    ) {
        if (opportunityId == null || productId == null || sellingModelId == null) {
            throw new AuraHandledException('opportunityId, productId, and sellingModelId are required');
        }

        // Find or create a Draft Quote for this Opportunity
        List<Quote> existing = [
            SELECT Id FROM Quote
            WHERE OpportunityId = :opportunityId AND Status = 'Draft'
            LIMIT 1
        ];
        Id quoteId;
        if (!existing.isEmpty()) {
            quoteId = existing[0].Id;
        } else {
            String oppName = [SELECT Name FROM Opportunity WHERE Id = :opportunityId LIMIT 1].Name;
            Id pbId = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1].Id;
            Quote q = new Quote(
                Name          = oppName + ' — DD Quote',
                OpportunityId = opportunityId,
                Pricebook2Id  = pbId,
                Status        = 'Draft'
            );
            insert q;
            quoteId = q.Id;
        }

        // Create config with catalog defaults (idempotent).
        // createConfigFromDefaults may return a partial record (only Id + Config_Status__c)
        // when the config already exists. Re-query to ensure all wrapper fields are populated.
        DD_Quote_Plan_Config__c config =
            DDQuoteConfigService.createConfigFromDefaults(quoteId, productId, sellingModelId);
        config = [
            SELECT Id, Config_Status__c,
                   Selected_Annual_Max__c, Selected_Ortho_Type__c, Selected_Ortho_Max__c,
                   DnP_Waiver_Selected__c, Waiting_Period_Waived__c,
                   Employer_Contribution_Pct__c,
                   Custom_Deductible_Individual__c, Custom_Deductible_Family__c
            FROM DD_Quote_Plan_Config__c
            WHERE Id = :config.Id
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        // Load selling model and product for option building
        DD_Selling_Model__c sm = [
            SELECT Min_Contribution_Pct__c, Available_Annual_Maxes__c,
                   Available_Ortho_Types__c, Available_Ortho_Maxes__c
            FROM DD_Selling_Model__c
            WHERE Id = :sellingModelId
            LIMIT 1
        ];
        DD_Product__c prod = [
            SELECT Product_Name__c, Network_Fee_Basis__c, Ortho_Available__c, Product_Code__c
            FROM DD_Product__c
            WHERE Id = :productId
            LIMIT 1
        ];

        // ── Create or update QuoteLineItem so standard related list shows the plan ──
        String p2Code = 'DD-' + (prod.Product_Code__c != null ? prod.Product_Code__c
                                                               : productId.to15());
        List<Product2> p2List = [
            SELECT Id FROM Product2 WHERE ProductCode = :p2Code AND IsActive = true LIMIT 1
        ];
        if (!p2List.isEmpty()) {
            Id p2Id = p2List[0].Id;
            Id pbId2 = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1].Id;
            List<PricebookEntry> pbeList = [
                SELECT Id FROM PricebookEntry
                WHERE Product2Id = :p2Id AND Pricebook2Id = :pbId2 AND IsActive = true LIMIT 1
            ];
            if (!pbeList.isEmpty()) {
                // Only create the line item if one doesn't already exist for this product
                List<QuoteLineItem> existingQli = [
                    SELECT Id FROM QuoteLineItem
                    WHERE QuoteId = :quoteId AND PricebookEntryId = :pbeList[0].Id LIMIT 1
                ];
                if (existingQli.isEmpty()) {
                    insert new QuoteLineItem(
                        QuoteId         = quoteId,
                        PricebookEntryId= pbeList[0].Id,
                        Quantity        = 1,
                        UnitPrice       = 0,
                        Description     = prod.Product_Name__c
                    );
                }
            }
        }

        PlanConfigWrapper w = new PlanConfigWrapper();
        w.quoteId             = quoteId;
        w.configId            = config.Id;
        w.selectedAnnualMax   = config.Selected_Annual_Max__c;
        w.selectedOrthoType   = config.Selected_Ortho_Type__c;
        w.selectedOrthoMax    = config.Selected_Ortho_Max__c;
        w.dnpWaiverSelected   = config.DnP_Waiver_Selected__c;
        w.waitingPeriodWaived = config.Waiting_Period_Waived__c;
        w.contributionPct     = config.Employer_Contribution_Pct__c;
        w.configStatus        = config.Config_Status__c;
        w.orthoAvailable      = prod.Ortho_Available__c;
        w.minContributionPct  = sm.Min_Contribution_Pct__c;
        w.productName         = prod.Product_Name__c;
        w.networkName         = prod.Network_Fee_Basis__c;
        w.annualMaxOptions    = buildDecimalOptions(sm.Available_Annual_Maxes__c);
        w.orthoTypeOptions    = buildStringOptions(sm.Available_Ortho_Types__c);
        w.orthoMaxOptions     = buildDecimalOptions(sm.Available_Ortho_Maxes__c);
        w.customDeductibleInd = config.Custom_Deductible_Individual__c;
        w.customDeductibleFam = config.Custom_Deductible_Family__c;
        w.productId           = productId;
        return w;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // STEP 3 — Get Product Benefits (Coverage Specs + Benefit Specs)
    // ─────────────────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static PlanBenefitsWrapper getProductBenefits(Id productId) {
        if (productId == null) {
            throw new AuraHandledException('productId is required');
        }

        DD_Product__c prod = [
            SELECT Id, Product_Name__c
            FROM DD_Product__c
            WHERE Id = :productId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        List<DD_Coverage_Spec__c> specs = [
            SELECT Id, Coverage_Name__c, Coinsurance_PPO__c, Coinsurance_NonPPO__c,
                   Deductible_Applies__c, Display_Order__c,
                   (SELECT CDT_Code__c, CDT_Description__c, Frequency_Limit__c,
                           Frequency_Period__c, Age_Min__c, Age_Max__c, Notes__c
                    FROM Benefit_Specs__r
                    ORDER BY CDT_Code__c ASC)
            FROM DD_Coverage_Spec__c
            WHERE Product__c = :productId
            WITH SECURITY_ENFORCED
            ORDER BY Display_Order__c ASC NULLS LAST, Coverage_Name__c ASC
        ];

        PlanBenefitsWrapper wrapper = new PlanBenefitsWrapper();
        wrapper.productName = prod.Product_Name__c;

        for (DD_Coverage_Spec__c spec : specs) {
            CoverageSpecDisplay csd = new CoverageSpecDisplay();
            csd.coverageName      = spec.Coverage_Name__c;
            csd.coinsurancePPO    = spec.Coinsurance_PPO__c;
            csd.coinsuranceNonPPO = spec.Coinsurance_NonPPO__c;
            csd.deductibleApplies = spec.Deductible_Applies__c;
            csd.displayOrder      = spec.Display_Order__c != null
                                        ? Integer.valueOf(spec.Display_Order__c) : null;

            if (spec.Benefit_Specs__r != null) {
                for (DD_Benefit_Spec__c ben : spec.Benefit_Specs__r) {
                    BenefitSpecDisplay bsd = new BenefitSpecDisplay();
                    bsd.cdtCode        = ben.CDT_Code__c;
                    bsd.cdtDescription = ben.CDT_Description__c;
                    bsd.frequencyLimit = ben.Frequency_Limit__c;
                    bsd.frequencyPeriod= ben.Frequency_Period__c;
                    bsd.ageMin         = ben.Age_Min__c;
                    bsd.ageMax         = ben.Age_Max__c;
                    bsd.notes          = ben.Notes__c;
                    csd.benefits.add(bsd);
                }
            }
            wrapper.coverageSpecs.add(csd);
        }

        return wrapper;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // STEP 4 — Save Config Changes
    // ─────────────────────────────────────────────────────────────────────────

    @AuraEnabled
    public static void updatePlanConfig(
        Id      configId,
        Decimal annualMax,
        Boolean orthoEnabled,
        String  orthoType,
        Decimal orthoMax,
        Boolean dnpWaiver,
        Decimal contributionPct,
        Boolean waitingPeriodWaived,
        Decimal customDeductibleInd,
        Decimal customDeductibleFam
    ) {
        if (configId == null) throw new AuraHandledException('configId is required');

        // Query the existing record to retrieve relationship fields required by validateConfig
        DD_Quote_Plan_Config__c existing = [
            SELECT Id, Selling_Model__c, Product__c, Config_Status__c
            FROM DD_Quote_Plan_Config__c
            WHERE Id = :configId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        DD_Quote_Plan_Config__c config = new DD_Quote_Plan_Config__c(
            Id                              = configId,
            Selling_Model__c               = existing.Selling_Model__c,
            Product__c                     = existing.Product__c,
            Config_Status__c               = existing.Config_Status__c,
            Selected_Annual_Max__c          = annualMax,
            Selected_Ortho_Type__c          = (orthoEnabled == true) ? orthoType : null,
            Selected_Ortho_Max__c           = (orthoEnabled == true) ? orthoMax  : null,
            DnP_Waiver_Selected__c          = dnpWaiver,
            Employer_Contribution_Pct__c    = contributionPct,
            Waiting_Period_Waived__c        = waitingPeriodWaived,
            Custom_Deductible_Individual__c = customDeductibleInd,
            Custom_Deductible_Family__c     = customDeductibleFam
        );
        try {
            DDQuoteConfigService.updateConfig(config);
        } catch (DDValidationException e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // STEP 5 — Calculate Rates
    // ─────────────────────────────────────────────────────────────────────────

    @AuraEnabled
    public static List<DDRatingResult> calculateRates(Id quoteId) {
        if (quoteId == null) throw new AuraHandledException('quoteId is required');
        try {
            return DDRatingEngineService.calculateRate(quoteId);
        } catch (DDRatingException e) {
            throw new AuraHandledException(e.getMessage());
        } catch (DDValidationException e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // STEP 6 — Submit Quote
    // ─────────────────────────────────────────────────────────────────────────

    @AuraEnabled
    public static void submitQuote(Id quoteId) {
        if (quoteId == null) throw new AuraHandledException('quoteId is required');
        Quote q = new Quote(Id = quoteId, Status = 'Presented');
        update q;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // ACCOUNT QUOTE CREATOR — Context + Proposals
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Returns Account and Opportunity details for the left-column context panel
     * in the ddAccountQuoteCreator LWC.
     */
    @AuraEnabled(cacheable=true)
    public static AccountOppWrapper getOppAndAccountDetails(Id oppId) {
        if (oppId == null) throw new AuraHandledException('oppId is required');

        Opportunity opp = [
            SELECT Id, Name, StageName,
                   AccountId,
                   Account.Name, Account.Industry,
                   Account.BillingStreet, Account.BillingCity,
                   Account.BillingState, Account.BillingPostalCode,
                   Account.Phone, Account.Website,
                   Account.SIC_Code__c, Account.Group_Size__c,
                   Account.Market_Segment__c, Account.DD_Group_Number__c
            FROM Opportunity
            WHERE Id = :oppId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        // Look up any existing Draft quote status
        List<Quote> quotes = [
            SELECT Status FROM Quote
            WHERE OpportunityId = :oppId AND Status = 'Draft'
            LIMIT 1
        ];

        AccountOppWrapper w    = new AccountOppWrapper();
        w.accountId            = opp.AccountId;
        w.accountName          = opp.Account.Name;
        w.industry             = opp.Account.Industry;
        w.billingStreet        = opp.Account.BillingStreet;
        w.billingCity          = opp.Account.BillingCity;
        w.billingState         = opp.Account.BillingState;
        w.billingPostalCode    = opp.Account.BillingPostalCode;
        w.phone                = opp.Account.Phone;
        w.website              = opp.Account.Website;
        w.sicCode              = opp.Account.SIC_Code__c;
        w.groupSize            = opp.Account.Group_Size__c != null
                                     ? Integer.valueOf(opp.Account.Group_Size__c) : 0;
        w.segment              = String.isNotBlank(opp.Account.Market_Segment__c)
                                     ? opp.Account.Market_Segment__c
                                     : DDConstants.SEGMENT_SMALL_BUSINESS;
        w.groupNumber          = opp.Account.DD_Group_Number__c;
        w.oppId                = opp.Id;
        w.oppName              = opp.Name;
        w.quoteStatus          = quotes.isEmpty() ? 'Draft' : quotes[0].Status;
        return w;
    }

    /**
     * Creates one DD_Proposal__c per selected plan configuration, linked to
     * the Quote and the parent Opportunity. Returns the list of new Proposal Ids.
     */
    @AuraEnabled
    public static List<Id> createProposals(
        Id            quoteId,
        List<Id>      planConfigIds,
        String        effectiveDateStr
    ) {
        if (quoteId == null)        throw new AuraHandledException('quoteId is required');
        if (planConfigIds == null || planConfigIds.isEmpty())
            throw new AuraHandledException('planConfigIds must not be empty');
        if (String.isBlank(effectiveDateStr))
            throw new AuraHandledException('effectiveDateStr is required');

        Date effectiveDate = Date.valueOf(effectiveDateStr);

        // Get the OpportunityId from the Quote
        Quote q = [SELECT Id, OpportunityId FROM Quote WHERE Id = :quoteId LIMIT 1];

        // Get plan names for labelling
        Map<Id, DD_Quote_Plan_Config__c> configMap = new Map<Id, DD_Quote_Plan_Config__c>([
            SELECT Id, Product__r.Product_Name__c
            FROM DD_Quote_Plan_Config__c
            WHERE Id IN :planConfigIds
        ]);

        List<DD_Proposal__c> proposals = new List<DD_Proposal__c>();
        for (Id configId : planConfigIds) {
            String planName = configMap.containsKey(configId)
                ? configMap.get(configId).Product__r.Product_Name__c
                : 'Plan';
            proposals.add(new DD_Proposal__c(
                Opportunity__c       = q.OpportunityId,
                Quote__c             = quoteId,
                Quote_Plan_Config__c = configId,
                Effective_Date__c    = effectiveDate,
                Status__c            = 'Draft',
                Plan_Name__c         = planName
            ));
        }
        insert proposals;

        List<Id> ids = new List<Id>();
        for (DD_Proposal__c p : proposals) ids.add(p.Id);
        return ids;
    }

    /**
     * Receives a base64-encoded PDF generated client-side by jsPDF,
     * stores it as a Salesforce File (ContentVersion), links it to the
     * Proposal and its Quote, and returns the ContentDocumentId.
     *
     * Called from the ddAccountQuoteCreator LWC after jsPDF finishes rendering.
     */
    @AuraEnabled
    public static Id saveProposalPDF(Id proposalId, String base64Pdf, String fileName) {
        if (proposalId == null)  throw new AuraHandledException('proposalId is required');
        if (String.isBlank(base64Pdf)) throw new AuraHandledException('base64Pdf is required');

        DD_Proposal__c proposal = [
            SELECT Id, Name, Quote__c
            FROM DD_Proposal__c
            WHERE Id = :proposalId
            LIMIT 1
        ];

        String safeName = String.isNotBlank(fileName) ? fileName
                          : ('DeltaDental_Proposal_' + proposal.Name + '.pdf');

        // Decode base64 → binary blob
        Blob pdfBlob = EncodingUtil.base64Decode(base64Pdf);

        // Store as a Salesforce File (ContentVersion)
        ContentVersion cv = new ContentVersion(
            Title          = safeName,
            PathOnClient   = safeName,
            VersionData    = pdfBlob,
            IsMajorVersion = true
        );
        insert cv;

        // Re-query to get the auto-created ContentDocumentId
        cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
        Id cdId = cv.ContentDocumentId;

        // Link to the Proposal record
        List<ContentDocumentLink> links = new List<ContentDocumentLink>{
            new ContentDocumentLink(
                ContentDocumentId = cdId,
                LinkedEntityId    = proposalId,
                ShareType         = 'V',
                Visibility        = 'AllUsers'
            )
        };
        // Also link to the Quote so it appears on the Quote's Files related list
        if (proposal.Quote__c != null) {
            links.add(new ContentDocumentLink(
                ContentDocumentId = cdId,
                LinkedEntityId    = proposal.Quote__c,
                ShareType         = 'V',
                Visibility        = 'AllUsers'
            ));
        }
        insert links;

        // Stamp the ContentDocumentId on the Proposal for easy retrieval
        update new DD_Proposal__c(Id = proposalId, PDF_Content_Document_Id__c = cdId);

        return cdId;
    }

    /**
     * Returns all data needed by the client-side jsPDF generator for a proposal.
     */
    @AuraEnabled
    public static Map<String, Object> getProposalPDFData(Id proposalId) {
        if (proposalId == null) throw new AuraHandledException('proposalId is required');

        DD_Proposal__c proposal = [
            SELECT Id, Name, Effective_Date__c, Status__c, Plan_Name__c,
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
                   Quote__r.Name,
                   Quote_Plan_Config__r.Product__r.Product_Name__c,
                   Quote_Plan_Config__r.Product__r.Network_Fee_Basis__c,
                   Quote_Plan_Config__r.Product__r.Deductible_Individual__c,
                   Quote_Plan_Config__r.Product__r.Deductible_Family__c,
                   Quote_Plan_Config__r.Selected_Annual_Max__c,
                   Quote_Plan_Config__r.Selected_Ortho_Type__c,
                   Quote_Plan_Config__r.Selected_Ortho_Max__c,
                   Quote_Plan_Config__r.DnP_Waiver_Selected__c,
                   Quote_Plan_Config__r.Employer_Contribution_Pct__c,
                   Quote_Plan_Config__r.Waiting_Period_Waived__c,
                   Quote_Plan_Config__r.Rate_Guarantee_Months__c,
                   Quote_Plan_Config__c
            FROM DD_Proposal__c
            WHERE Id = :proposalId
            LIMIT 1
        ];

        // Rate results
        List<Map<String,Object>> rates = new List<Map<String,Object>>();
        Decimal totalPremium = 0;
        for (DD_Quote_Rate_Result__c rr : [
            SELECT Rate_Tier__c, Monthly_Rate__c, Enrolled_Count__c,
                   Monthly_Premium__c, Employer_Share__c, Employee_Share__c
            FROM DD_Quote_Rate_Result__c
            WHERE Quote_Plan_Config__c = :proposal.Quote_Plan_Config__c
            ORDER BY Rate_Tier__c ASC
        ]) {
            Map<String,Object> row = new Map<String,Object>{
                'tier'           => rr.Rate_Tier__c,
                'enrolled'       => rr.Enrolled_Count__c,
                'monthlyRate'    => rr.Monthly_Rate__c,
                'monthlyPremium' => rr.Monthly_Premium__c,
                'employerShare'  => rr.Employer_Share__c,
                'employeeShare'  => rr.Employee_Share__c
            };
            if (rr.Monthly_Premium__c != null) totalPremium += rr.Monthly_Premium__c;
            rates.add(row);
        }

        // Coverage specs
        List<Map<String,Object>> coverage = new List<Map<String,Object>>();
        Id productId = proposal.Quote_Plan_Config__r?.Product__c;
        if (productId != null) {
            for (DD_Coverage_Spec__c spec : [
                SELECT Coverage_Name__c, Coinsurance_PPO__c, Coinsurance_NonPPO__c, Deductible_Applies__c
                FROM DD_Coverage_Spec__c
                WHERE Product__c = :productId
                ORDER BY Display_Order__c ASC NULLS LAST
            ]) {
                coverage.add(new Map<String,Object>{
                    'name'             => spec.Coverage_Name__c,
                    'ppoPct'           => spec.Coinsurance_PPO__c,
                    'nonPpoPct'        => spec.Coinsurance_NonPPO__c,
                    'deductibleApplies'=> spec.Deductible_Applies__c
                });
            }
        }

        // Flatten proposal into a plain map for easy JS access
        Map<String,Object> result = new Map<String,Object>{
            'proposalName'      => proposal.Name,
            'planName'          => proposal.Plan_Name__c,
            'effectiveDate'     => proposal.Effective_Date__c != null
                                       ? proposal.Effective_Date__c.format() : '',
            'accountName'       => proposal.Opportunity__r?.Account?.Name,
            'industry'          => proposal.Opportunity__r?.Account?.Industry,
            'street'            => proposal.Opportunity__r?.Account?.BillingStreet,
            'city'              => proposal.Opportunity__r?.Account?.BillingCity,
            'state'             => proposal.Opportunity__r?.Account?.BillingState,
            'zip'               => proposal.Opportunity__r?.Account?.BillingPostalCode,
            'phone'             => proposal.Opportunity__r?.Account?.Phone,
            'groupSize'         => proposal.Opportunity__r?.Account?.Group_Size__c,
            'sicCode'           => proposal.Opportunity__r?.Account?.SIC_Code__c,
            'segment'           => proposal.Opportunity__r?.Account?.Market_Segment__c,
            'quoteName'         => proposal.Quote__r?.Name,
            'networkName'       => proposal.Quote_Plan_Config__r?.Product__r?.Network_Fee_Basis__c,
            'annualMax'         => proposal.Quote_Plan_Config__r?.Selected_Annual_Max__c,
            'deductibleInd'     => proposal.Quote_Plan_Config__r?.Product__r?.Deductible_Individual__c,
            'deductibleFam'     => proposal.Quote_Plan_Config__r?.Product__r?.Deductible_Family__c,
            'orthoType'         => proposal.Quote_Plan_Config__r?.Selected_Ortho_Type__c,
            'orthoMax'          => proposal.Quote_Plan_Config__r?.Selected_Ortho_Max__c,
            'dnpWaiver'         => proposal.Quote_Plan_Config__r?.DnP_Waiver_Selected__c,
            'contributionPct'   => proposal.Quote_Plan_Config__r?.Employer_Contribution_Pct__c,
            'waitingPeriodWaived'=> proposal.Quote_Plan_Config__r?.Waiting_Period_Waived__c,
            'rateGuarantee'     => proposal.Quote_Plan_Config__r?.Rate_Guarantee_Months__c,
            'totalPremium'      => totalPremium,
            'rates'             => rates,
            'coverage'          => coverage,
            'proposalDate'      => Date.today().format()
        };
        return result;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // PRIVATE HELPERS
    // ─────────────────────────────────────────────────────────────────────────

    private static List<ComboOption> buildDecimalOptions(String csv) {
        List<ComboOption> opts = new List<ComboOption>();
        if (String.isBlank(csv)) return opts;
        for (String v : csv.split(',')) {
            String trimmed = v.trim();
            opts.add(new ComboOption('$' + trimmed, trimmed));
        }
        return opts;
    }

    private static List<ComboOption> buildStringOptions(String csv) {
        List<ComboOption> opts = new List<ComboOption>();
        if (String.isBlank(csv)) return opts;
        for (String v : csv.split(',')) {
            String trimmed = v.trim();
            opts.add(new ComboOption(trimmed, trimmed));
        }
        return opts;
    }
}
