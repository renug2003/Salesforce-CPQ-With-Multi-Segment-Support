// ============================================================
// Delta Dental CPQ — Rate Entries Data Load
// Creates DD_Rate_Entry__c records (4 tiers × 15 products = 60 rows)
// linked to the 'SB 2025 Standard' rate table.
//
// Run: sf apex run --file scripts/loadData_5_rateEntries.apex --target-org <alias>
//
// Base rates priced at $1,500 annual max (PPO) / copay-based (DHMO).
// The rating engine applies a sqrt adjustment factor for other annual max selections.
// ============================================================

// Find the active Small Business rate table
// Field is Table_Name__c in deployed org (not Rate_Table_Name__c)
DD_Rate_Table__c rt = [
    SELECT Id, Table_Name__c
    FROM DD_Rate_Table__c
    WHERE Segment__c = 'Small Business'
    ORDER BY Effective_Date__c DESC
    LIMIT 1
];

// Load all active products — map by Product_Code__c for reliable lookup
Map<String, Id> prodIdByCode = new Map<String, Id>();
for (DD_Product__c p : [
    SELECT Id, Product_Code__c
    FROM DD_Product__c
    WHERE Is_Active__c = true
]) {
    prodIdByCode.put(p.Product_Code__c, p.Id);
}

// Delete any existing rate entries for this rate table to allow clean reload
delete [SELECT Id FROM DD_Rate_Entry__c WHERE Rate_Table__c = :rt.Id];

// ── Rate data: { productCode, EE, ES, EC, EF } ─────────────────────
// Rates are monthly per-member premiums at the $1,500 PPO / $0 DHMO base.
// PPO Deluxe series (higher coinsurance, richer benefits)
// PPO Advantage series (competitive mid-market)
// PPO Core series (entry-level, no ortho)
// DHMO series (copay-based, lowest premium)
// Pediatric series

List<Object[]> rateData = new List<Object[]>{
    // code,       EE,     ES,     EC,     EF
    new Object[]{'DD-D100', 26.50,  53.00,  58.30,  74.20 },  // Deluxe 100
    new Object[]{'DD-D200', 31.20,  62.40,  68.64,  87.36 },  // Deluxe 200
    new Object[]{'DD-D300', 36.80,  73.60,  80.96, 103.04 },  // Deluxe 300
    new Object[]{'DD-A100', 24.10,  48.20,  53.02,  67.48 },  // Advantage 100
    new Object[]{'DD-A200', 28.90,  57.80,  63.58,  80.92 },  // Advantage 200
    new Object[]{'DD-A300', 34.50,  69.00,  75.90,  96.60 },  // Advantage 300
    new Object[]{'DD-A400', 42.00,  84.00,  92.40, 117.60 },  // Advantage 400
    new Object[]{'DD-C100', 19.80,  39.60,  43.56,  55.44 },  // Core 100
    new Object[]{'DD-C201', 22.50,  45.00,  49.50,  63.00 },  // Core 201
    new Object[]{'DD-H11A', 14.50,  29.00,  31.90,  40.60 },  // DeltaCare USA 11A
    new Object[]{'DD-H15B', 16.80,  33.60,  36.96,  47.04 },  // DeltaCare USA 15B
    new Object[]{'DD-H17B', 18.90,  37.80,  41.58,  52.92 },  // DeltaCare USA 17B
    new Object[]{'DD-CPPO', 12.00,  24.00,  26.40,  33.60 },  // Children's Dental PPO
    new Object[]{'DD-FPPO', 29.50,  59.00,  64.90,  82.60 },  // Family Dental PPO
    new Object[]{'DD-CDHM', 10.50,  21.00,  23.10,  29.40 }   // DeltaCare USA Children's DHMO
};

List<String> tiers = new List<String>{ 'EE', 'ES', 'EC', 'EF' };

List<DD_Rate_Entry__c> toInsert = new List<DD_Rate_Entry__c>();

for (Object[] row : rateData) {
    String code = (String) row[0];
    Id prodId = prodIdByCode.get(code);
    if (prodId == null) {
        System.debug('WARNING: product not found for code ' + code + ' — skipping');
        continue;
    }

    List<Decimal> tierRates = new List<Decimal>{
        (Decimal) row[1],   // EE
        (Decimal) row[2],   // ES
        (Decimal) row[3],   // EC
        (Decimal) row[4]    // EF
    };

    for (Integer i = 0; i < tiers.size(); i++) {
        toInsert.add(new DD_Rate_Entry__c(
            Rate_Table__c  = rt.Id,
            Product__c     = prodId,
            Rate_Tier__c   = tiers[i],
            Monthly_Rate__c = tierRates[i],
            Region__c      = 'CA'
        ));
    }
}

insert toInsert;
System.debug('SUCCESS: Inserted ' + toInsert.size() + ' DD_Rate_Entry__c records for '
    + (toInsert.size() / 4) + ' products.');
