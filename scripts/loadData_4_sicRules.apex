// ============================================================
// Delta Dental CPQ — Data Load Script 4 of 4
// Creates: SIC Mappings (57) + UW Rules (16) + Final Validation
// Run AFTER loadData_3_benefitSpecs.apex
// sf apex run --file scripts/loadData_4_sicRules.apex --target-org dd-salesforce-digitalinsurancecpq
// ============================================================

// ── SIC MAPPINGS (57) ─────────────────────────────────────────
List<DD_SIC_Mapping__c> sicMappings = new List<DD_SIC_Mapping__c>{
    new DD_SIC_Mapping__c(SIC_Start__c='0100',SIC_End__c='0760',Rate_Level__c='Level 1',Description__c='Agriculture Forestry Fishing',Eligible__c=true),
    new DD_SIC_Mapping__c(SIC_Start__c='0761',SIC_End__c='0783',Rate_Level__c='N/A',Description__c='Seasonal Employees - Farm Labor',Eligible__c=false),
    new DD_SIC_Mapping__c(SIC_Start__c='0784',SIC_End__c='0999',Rate_Level__c='Level 1',Description__c='Agriculture Forestry Fishing',Eligible__c=true),
    new DD_SIC_Mapping__c(SIC_Start__c='1000',SIC_End__c='1499',Rate_Level__c='Level 1',Description__c='Mining Oil and Gas Extraction',Eligible__c=true),
    new DD_SIC_Mapping__c(SIC_Start__c='1500',SIC_End__c='1799',Rate_Level__c='Level 1',Description__c='Construction Contractors',Eligible__c=true),
    new DD_SIC_Mapping__c(SIC_Start__c='2000',SIC_End__c='2699',Rate_Level__c='Level 1',Description__c='Manufacturing',Eligible__c=true),
    new DD_SIC_Mapping__c(SIC_Start__c='2700',SIC_End__c='2799',Rate_Level__c='Level 1',Description__c='Printing and Publishing',Eligible__c=true),
    new DD_SIC_Mapping__c(SIC_Start__c='2800',SIC_End__c='3910',Rate_Level__c='Level 1',Description__c='Manufacturing',Eligible__c=true),
    new DD_SIC_Mapping__c(SIC_Start__c='3911',SIC_End__c='3915',Rate_Level__c='Level 2',Description__c='Jewelry Manufacturing',Eligible__c=true),
    new DD_SIC_Mapping__c(SIC_Start__c='3916',SIC_End__c='3999',Rate_Level__c='Level 1',Description__c='Manufacturing',Eligible__c=true),
    new DD_SIC_Mapping__c(SIC_Start__c='4000',SIC_End__c='4799',Rate_Level__c='Level 1',Description__c='Transportation',Eligible__c=true),
    new DD_SIC_Mapping__c(SIC_Start__c='4800',SIC_End__c='4899',Rate_Level__c='Level 1',Description__c='Communication',Eligible__c=true),
    new DD_SIC_Mapping__c(SIC_Start__c='4900',SIC_End__c='4999',Rate_Level__c='Level 1',Description__c='Utilities',Eligible__c=true),
    new DD_SIC_Mapping__c(SIC_Start__c='5000',SIC_End__c='5199',Rate_Level__c='Level 1',Description__c='Wholesale Trade',Eligible__c=true),
    new DD_SIC_Mapping__c(SIC_Start__c='5200',SIC_End__c='5510',Rate_Level__c='Level 1',Description__c='Retail',Eligible__c=true),
    new DD_SIC_Mapping__c(SIC_Start__c='5511',SIC_End__c='5599',Rate_Level__c='Level 2',Description__c='Auto Dealerships',Eligible__c=true),
    new DD_SIC_Mapping__c(SIC_Start__c='5610',SIC_End__c='5699',Rate_Level__c='Level 1',Description__c='Retail Apparel',Eligible__c=true),
    new DD_SIC_Mapping__c(SIC_Start__c='5712',SIC_End__c='5736',Rate_Level__c='Level 1',Description__c='Retail Home Furnishings',Eligible__c=true),
    new DD_SIC_Mapping__c(SIC_Start__c='5800',SIC_End__c='5899',Rate_Level__c='Level 2',Description__c='Restaurants',Eligible__c=true),
    new DD_SIC_Mapping__c(SIC_Start__c='5912',SIC_End__c='5999',Rate_Level__c='Level 1',Description__c='Retail Other',Eligible__c=true),
    new DD_SIC_Mapping__c(SIC_Start__c='6000',SIC_End__c='6299',Rate_Level__c='Level 1',Description__c='Finance Banks Securities',Eligible__c=true),
    new DD_SIC_Mapping__c(SIC_Start__c='6300',SIC_End__c='6499',Rate_Level__c='Level 2',Description__c='Insurance Carriers Brokers',Eligible__c=true),
    new DD_SIC_Mapping__c(SIC_Start__c='6500',SIC_End__c='6799',Rate_Level__c='Level 2',Description__c='Real Estate',Eligible__c=true),
    new DD_SIC_Mapping__c(SIC_Start__c='7000',SIC_End__c='7099',Rate_Level__c='Level 2',Description__c='Hotels and Lodging',Eligible__c=true),
    new DD_SIC_Mapping__c(SIC_Start__c='7100',SIC_End__c='7220',Rate_Level__c='Level 1',Description__c='Services Laundry Personal',Eligible__c=true),
    new DD_SIC_Mapping__c(SIC_Start__c='7221',SIC_End__c='7221',Rate_Level__c='Level 2',Description__c='Photographic Studios Portrait',Eligible__c=true),
    new DD_SIC_Mapping__c(SIC_Start__c='7222',SIC_End__c='7230',Rate_Level__c='Level 1',Description__c='Services',Eligible__c=true),
    new DD_SIC_Mapping__c(SIC_Start__c='7231',SIC_End__c='7241',Rate_Level__c='N/A',Description__c='Beauty and Barber Shops',Eligible__c=false),
    new DD_SIC_Mapping__c(SIC_Start__c='7242',SIC_End__c='7290',Rate_Level__c='Level 1',Description__c='Services',Eligible__c=true),
    new DD_SIC_Mapping__c(SIC_Start__c='7291',SIC_End__c='7299',Rate_Level__c='Level 2',Description__c='Services Tax Return Misc',Eligible__c=true),
    new DD_SIC_Mapping__c(SIC_Start__c='7300',SIC_End__c='7318',Rate_Level__c='Level 1',Description__c='Services Advertising Misc',Eligible__c=true),
    new DD_SIC_Mapping__c(SIC_Start__c='7319',SIC_End__c='7319',Rate_Level__c='Level 2',Description__c='Services NEC',Eligible__c=true),
    new DD_SIC_Mapping__c(SIC_Start__c='7320',SIC_End__c='7360',Rate_Level__c='Level 1',Description__c='Services Computer Mailing',Eligible__c=true),
    new DD_SIC_Mapping__c(SIC_Start__c='7361',SIC_End__c='7363',Rate_Level__c='N/A',Description__c='Employment Agencies',Eligible__c=false),
    new DD_SIC_Mapping__c(SIC_Start__c='7364',SIC_End__c='7388',Rate_Level__c='Level 1',Description__c='Services Equipment Personnel',Eligible__c=true),
    new DD_SIC_Mapping__c(SIC_Start__c='7389',SIC_End__c='7389',Rate_Level__c='N/A',Description__c='Misc Business Services NEC',Eligible__c=false),
    new DD_SIC_Mapping__c(SIC_Start__c='7390',SIC_End__c='7630',Rate_Level__c='Level 1',Description__c='Services Misc',Eligible__c=true),
    new DD_SIC_Mapping__c(SIC_Start__c='7631',SIC_End__c='7631',Rate_Level__c='Level 2',Description__c='Watch Clock Jewelry Repair',Eligible__c=true),
    new DD_SIC_Mapping__c(SIC_Start__c='7632',SIC_End__c='7799',Rate_Level__c='Level 1',Description__c='Services Recreation',Eligible__c=true),
    new DD_SIC_Mapping__c(SIC_Start__c='7800',SIC_End__c='7999',Rate_Level__c='Level 2',Description__c='Amusement Recreation Entertainment',Eligible__c=true),
    new DD_SIC_Mapping__c(SIC_Start__c='8000',SIC_End__c='8059',Rate_Level__c='Level 2',Description__c='Medical Groups',Eligible__c=true),
    new DD_SIC_Mapping__c(SIC_Start__c='8062',SIC_End__c='8069',Rate_Level__c='Level 1',Description__c='Hospitals',Eligible__c=true),
    new DD_SIC_Mapping__c(SIC_Start__c='8021',SIC_End__c='8021',Rate_Level__c='N/A',Description__c='Dental Offices',Eligible__c=false),
    new DD_SIC_Mapping__c(SIC_Start__c='8071',SIC_End__c='8072',Rate_Level__c='N/A',Description__c='Dental Labs and Medical Labs',Eligible__c=false),
    new DD_SIC_Mapping__c(SIC_Start__c='8082',SIC_End__c='8099',Rate_Level__c='Level 2',Description__c='Medical Groups Other',Eligible__c=true),
    new DD_SIC_Mapping__c(SIC_Start__c='8100',SIC_End__c='8199',Rate_Level__c='Level 2',Description__c='Legal Services',Eligible__c=true),
    new DD_SIC_Mapping__c(SIC_Start__c='8200',SIC_End__c='8299',Rate_Level__c='Level 1',Description__c='Educational Services',Eligible__c=true),
    new DD_SIC_Mapping__c(SIC_Start__c='8300',SIC_End__c='8399',Rate_Level__c='Level 1',Description__c='Social Services',Eligible__c=true),
    new DD_SIC_Mapping__c(SIC_Start__c='8400',SIC_End__c='8499',Rate_Level__c='Level 1',Description__c='Museums Art Galleries',Eligible__c=true),
    new DD_SIC_Mapping__c(SIC_Start__c='8600',SIC_End__c='8699',Rate_Level__c='N/A',Description__c='Membership Organizations',Eligible__c=false),
    new DD_SIC_Mapping__c(SIC_Start__c='8700',SIC_End__c='8799',Rate_Level__c='Level 1',Description__c='Engineering Accounting Management',Eligible__c=true),
    new DD_SIC_Mapping__c(SIC_Start__c='8811',SIC_End__c='8811',Rate_Level__c='N/A',Description__c='Private Households',Eligible__c=false),
    new DD_SIC_Mapping__c(SIC_Start__c='8999',SIC_End__c='8999',Rate_Level__c='N/A',Description__c='Misc Services NEC',Eligible__c=false),
    new DD_SIC_Mapping__c(SIC_Start__c='9000',SIC_End__c='9720',Rate_Level__c='Level 1',Description__c='Public Administration',Eligible__c=true),
    new DD_SIC_Mapping__c(SIC_Start__c='9721',SIC_End__c='9721',Rate_Level__c='N/A',Description__c='International Affairs',Eligible__c=false),
    new DD_SIC_Mapping__c(SIC_Start__c='9722',SIC_End__c='9998',Rate_Level__c='Level 1',Description__c='Public Administration Other',Eligible__c=true),
    new DD_SIC_Mapping__c(SIC_Start__c='9999',SIC_End__c='9999',Rate_Level__c='Level 2',Description__c='Management Carve-out',Eligible__c=true)
};
insert sicMappings;

// ── UW RULES (16) ─────────────────────────────────────────────
List<DD_Product_Rule__c> uwRules = new List<DD_Product_Rule__c>{
    new DD_Product_Rule__c(Rule_Name__c='SIC Code Eligibility',Rule_Type__c='Eligibility',Condition__c='Account SIC Code in ineligible list',Action__c='Block quote with ineligible industry message',Priority__c=1,Is_Active__c=true,Segment__c='Small Business'),
    new DD_Product_Rule__c(Rule_Name__c='Rate Level Assignment',Rule_Type__c='Rating',Condition__c='SIC Code in Level 2 list',Action__c='Set Rate Level to Level 2 and use Level 2 rates',Priority__c=2,Is_Active__c=true,Segment__c='Small Business'),
    new DD_Product_Rule__c(Rule_Name__c='Minimum Group Size',Rule_Type__c='Eligibility',Condition__c='Eligible employees less than 2',Action__c='Block quote - minimum 2 eligible employees required',Priority__c=3,Is_Active__c=true,Segment__c='Small Business'),
    new DD_Product_Rule__c(Rule_Name__c='Deluxe 100 Size Restriction',Rule_Type__c='Eligibility',Condition__c='Plan is Deluxe 100 AND enrolled count less than 5',Action__c='Block Deluxe 100 - not available for groups of 2-4',Priority__c=4,Is_Active__c=true,Segment__c='Small Business'),
    new DD_Product_Rule__c(Rule_Name__c='Participation 100% Contribution',Rule_Type__c='Underwriting',Condition__c='Employer contribution 100% AND eligible employee not enrolled',Action__c='Block - all eligible must enroll when 100% employer paid',Priority__c=5,Is_Active__c=true,Segment__c='Small Business'),
    new DD_Product_Rule__c(Rule_Name__c='Participation 75-99%',Rule_Type__c='Underwriting',Condition__c='Contribution 75-99% AND enrolled less than MAX(75% eligible or 5)',Action__c='Warn - insufficient participation - pend for UW review',Priority__c=6,Is_Active__c=true,Segment__c='Small Business'),
    new DD_Product_Rule__c(Rule_Name__c='Participation 50-74%',Rule_Type__c='Underwriting',Condition__c='Contribution 50-74% AND enrolled less than MAX(50% eligible or 5)',Action__c='Warn - insufficient participation',Priority__c=7,Is_Active__c=true,Segment__c='Small Business'),
    new DD_Product_Rule__c(Rule_Name__c='Voluntary Minimum Enrollment',Rule_Type__c='Underwriting',Condition__c='Contribution less than 50% AND enrolled less than 5 (or 2 for 2-4 groups)',Action__c='Block voluntary plan if minimum not met',Priority__c=8,Is_Active__c=true,Segment__c='Small Business'),
    new DD_Product_Rule__c(Rule_Name__c='Annual Max Restriction Small/Vol',Rule_Type__c='Configuration',Condition__c='Group 2-4 employer-paid or voluntary 2-49 AND annual max exceeds limit',Action__c='Restrict annual max picklist to available values',Priority__c=9,Is_Active__c=true,Segment__c='Small Business'),
    new DD_Product_Rule__c(Rule_Name__c='Ortho Size Restriction',Rule_Type__c='Configuration',Condition__c='Ortho selected AND enrolled count less than 5',Action__c='Block orthodontics - not available for groups of 2-4',Priority__c=10,Is_Active__c=true,Segment__c='Small Business'),
    new DD_Product_Rule__c(Rule_Name__c='Adult Ortho Voluntary Block',Rule_Type__c='Configuration',Condition__c='Voluntary plan AND enrolled less than 50 AND adult ortho selected',Action__c='Block adult ortho - requires 50+ enrolled for voluntary',Priority__c=11,Is_Active__c=true,Segment__c='Small Business'),
    new DD_Product_Rule__c(Rule_Name__c='Dual Choice Minimum',Rule_Type__c='Eligibility',Condition__c='Dual choice selected AND enrolled count less than 5',Action__c='Block dual choice - requires 5+ enrolled employees',Priority__c=12,Is_Active__c=true,Segment__c='Small Business'),
    new DD_Product_Rule__c(Rule_Name__c='Dual Choice Min Per Plan',Rule_Type__c='Underwriting',Condition__c='Dual choice AND either plan has less than 2 enrolled',Action__c='Warn - minimum 2 enrolled per plan in dual choice',Priority__c=13,Is_Active__c=true,Segment__c='Small Business'),
    new DD_Product_Rule__c(Rule_Name__c='High Turnover Check',Rule_Type__c='Eligibility',Condition__c='Account turnover percentage greater than 20%',Action__c='Block - high turnover businesses ineligible',Priority__c=14,Is_Active__c=true,Segment__c='Small Business'),
    new DD_Product_Rule__c(Rule_Name__c='Dependent Relationship Rule',Rule_Type__c='Eligibility',Condition__c='Group size is 2 AND both are dependent relationship',Action__c='Block - group of 2 cannot be dependent relationship',Priority__c=15,Is_Active__c=true,Segment__c='Small Business'),
    new DD_Product_Rule__c(Rule_Name__c='Core BuyUp Contribution',Rule_Type__c='Configuration',Condition__c='Core/BuyUp AND employer contribution less than 50%',Action__c='Block - Core/Buy-Up requires minimum 50% contribution',Priority__c=16,Is_Active__c=true,Segment__c='Small Business')
};
insert uwRules;

// ── FINAL VALIDATION ──────────────────────────────────────────
System.debug('=== FINAL DATA LOAD VALIDATION ===');
System.debug('Catalog:        ' + [SELECT COUNT() FROM DD_Product_Catalog__c]  + ' (expected 1)');
System.debug('Categories:     ' + [SELECT COUNT() FROM DD_Product_Category__c] + ' (expected 3)');
System.debug('Products:       ' + [SELECT COUNT() FROM DD_Product__c]          + ' (expected 15)');
System.debug('Selling Models: ' + [SELECT COUNT() FROM DD_Selling_Model__c]    + ' (expected 15)');
System.debug('Coverage Specs: ' + [SELECT COUNT() FROM DD_Coverage_Spec__c]    + ' (expected 43)');
System.debug('Benefit Specs:  ' + [SELECT COUNT() FROM DD_Benefit_Spec__c]     + ' (expected 130)');
System.debug('SIC Mappings:   ' + [SELECT COUNT() FROM DD_SIC_Mapping__c]      + ' (expected 57)');
System.debug('UW Rules:       ' + [SELECT COUNT() FROM DD_Product_Rule__c]     + ' (expected 16)');
System.debug('=== LOAD COMPLETE ===');
