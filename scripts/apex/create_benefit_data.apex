/**
 * Creates DD_Coverage_Spec__c + DD_Benefit_Spec__c master records for every
 * active DD_Product__c plan, and upserts Product2 / PricebookEntry records
 * so the standard Quote line-item list shows the selected plan.
 *
 * Run with:  sf apex run --file scripts/apex/create_benefit_data.apex
 */

// ── 1. Common CDT code maps by coverage category ─────────────────────────────

// D&P procedure codes
List<Map<String,Object>> dnpCodes = new List<Map<String,Object>>{
    new Map<String,Object>{ 'code'=>'D0120','desc'=>'Periodic Oral Evaluation','freq'=>2,'period'=>'Per Calendar Year' },
    new Map<String,Object>{ 'code'=>'D0140','desc'=>'Limited Oral Evaluation','freq'=>2,'period'=>'Per Calendar Year' },
    new Map<String,Object>{ 'code'=>'D0150','desc'=>'Comprehensive Oral Evaluation','freq'=>1,'period'=>'Per Lifetime' },
    new Map<String,Object>{ 'code'=>'D0210','desc'=>'Full Mouth / Panoramic X-Rays','freq'=>1,'period'=>'Per 12 Months' },
    new Map<String,Object>{ 'code'=>'D0220','desc'=>'Periapical X-Ray — First Image','freq'=>2,'period'=>'Per Calendar Year' },
    new Map<String,Object>{ 'code'=>'D0270','desc'=>'Bitewing X-Ray — Single Image','freq'=>null,'period'=>null },
    new Map<String,Object>{ 'code'=>'D0274','desc'=>'Bitewing X-Rays — Four Images','freq'=>1,'period'=>'Per Calendar Year' },
    new Map<String,Object>{ 'code'=>'D0330','desc'=>'Panoramic Radiographic Image','freq'=>1,'period'=>'Per 12 Months' },
    new Map<String,Object>{ 'code'=>'D1110','desc'=>'Prophylaxis — Adult Cleaning','freq'=>2,'period'=>'Per Calendar Year' },
    new Map<String,Object>{ 'code'=>'D1120','desc'=>'Prophylaxis — Child Cleaning','freq'=>2,'period'=>'Per Calendar Year' },
    new Map<String,Object>{ 'code'=>'D1206','desc'=>'Topical Fluoride Varnish','freq'=>2,'period'=>'Per Calendar Year' },
    new Map<String,Object>{ 'code'=>'D1351','desc'=>'Sealant — Per Tooth','freq'=>1,'period'=>'Per 12 Months' }
};

// Basic procedure codes
List<Map<String,Object>> basicCodes = new List<Map<String,Object>>{
    new Map<String,Object>{ 'code'=>'D2140','desc'=>'Amalgam Restoration — 1 Surface','freq'=>null,'period'=>null },
    new Map<String,Object>{ 'code'=>'D2150','desc'=>'Amalgam Restoration — 2 Surfaces','freq'=>null,'period'=>null },
    new Map<String,Object>{ 'code'=>'D2160','desc'=>'Amalgam Restoration — 3 Surfaces','freq'=>null,'period'=>null },
    new Map<String,Object>{ 'code'=>'D2391','desc'=>'Resin Composite — 1 Surface, Posterior','freq'=>null,'period'=>null },
    new Map<String,Object>{ 'code'=>'D2392','desc'=>'Resin Composite — 2 Surfaces, Posterior','freq'=>null,'period'=>null },
    new Map<String,Object>{ 'code'=>'D2393','desc'=>'Resin Composite — 3 Surfaces, Posterior','freq'=>null,'period'=>null },
    new Map<String,Object>{ 'code'=>'D2330','desc'=>'Resin Composite — 1 Surface, Anterior','freq'=>null,'period'=>null },
    new Map<String,Object>{ 'code'=>'D7110','desc'=>'Extraction — Erupted Tooth / Exposed Root','freq'=>null,'period'=>null },
    new Map<String,Object>{ 'code'=>'D7140','desc'=>'Extraction — Erupted Tooth (Simple)','freq'=>null,'period'=>null }
};

// Endo / Perio / Oral Surgery codes
List<Map<String,Object>> endoCodes = new List<Map<String,Object>>{
    new Map<String,Object>{ 'code'=>'D3310','desc'=>'Endodontic Therapy — Anterior Tooth','freq'=>null,'period'=>null },
    new Map<String,Object>{ 'code'=>'D3320','desc'=>'Endodontic Therapy — Premolar Tooth','freq'=>null,'period'=>null },
    new Map<String,Object>{ 'code'=>'D3330','desc'=>'Endodontic Therapy — Molar Tooth','freq'=>null,'period'=>null },
    new Map<String,Object>{ 'code'=>'D4210','desc'=>'Gingivectomy — 4 or More Teeth Per Quadrant','freq'=>null,'period'=>null },
    new Map<String,Object>{ 'code'=>'D4240','desc'=>'Gingival Flap — 4 or More Teeth Per Quadrant','freq'=>null,'period'=>null },
    new Map<String,Object>{ 'code'=>'D4341','desc'=>'Periodontal Scaling & Root Planing — 4+ Teeth Per Quad','freq'=>null,'period'=>null },
    new Map<String,Object>{ 'code'=>'D4910','desc'=>'Periodontal Maintenance','freq'=>2,'period'=>'Per Calendar Year' },
    new Map<String,Object>{ 'code'=>'D7210','desc'=>'Extraction — Erupted Tooth Requiring Elevation of Flap','freq'=>null,'period'=>null },
    new Map<String,Object>{ 'code'=>'D7240','desc'=>'Removal of Impacted Tooth — Completely Bony','freq'=>null,'period'=>null }
};

// Major procedure codes
List<Map<String,Object>> majorCodes = new List<Map<String,Object>>{
    new Map<String,Object>{ 'code'=>'D2710','desc'=>'Crown — Resin-Based Composite (Indirect)','freq'=>null,'period'=>null },
    new Map<String,Object>{ 'code'=>'D2712','desc'=>'Crown — ¾ Resin-Based Composite (Indirect)','freq'=>null,'period'=>null },
    new Map<String,Object>{ 'code'=>'D2740','desc'=>'Crown — Porcelain / Ceramic Substrate','freq'=>null,'period'=>null },
    new Map<String,Object>{ 'code'=>'D2750','desc'=>'Crown — Porcelain Fused to High Noble Metal','freq'=>null,'period'=>null },
    new Map<String,Object>{ 'code'=>'D2751','desc'=>'Crown — Porcelain Fused to Predominantly Base Metal','freq'=>null,'period'=>null },
    new Map<String,Object>{ 'code'=>'D5110','desc'=>'Complete Denture — Maxillary','freq'=>null,'period'=>null },
    new Map<String,Object>{ 'code'=>'D5120','desc'=>'Complete Denture — Mandibular','freq'=>null,'period'=>null },
    new Map<String,Object>{ 'code'=>'D5213','desc'=>'Maxillary Partial Denture — Cast Metal Framework','freq'=>null,'period'=>null },
    new Map<String,Object>{ 'code'=>'D6010','desc'=>'Endosteal Implant Body — Titanium','freq'=>null,'period'=>null },
    new Map<String,Object>{ 'code'=>'D6240','desc'=>'Pontic — Porcelain Fused to High Noble Metal','freq'=>null,'period'=>null }
};

// Ortho procedure codes
List<Map<String,Object>> orthoCodes = new List<Map<String,Object>>{
    new Map<String,Object>{ 'code'=>'D8080','desc'=>'Comprehensive Orthodontic Treatment — Adolescent Dentition','freq'=>1,'period'=>'Per Lifetime' },
    new Map<String,Object>{ 'code'=>'D8090','desc'=>'Comprehensive Orthodontic Treatment — Adult Dentition','freq'=>1,'period'=>'Per Lifetime' },
    new Map<String,Object>{ 'code'=>'D8660','desc'=>'Pre-Orthodontic Examination','freq'=>null,'period'=>null }
};

// ── 2. Load all active products ───────────────────────────────────────────────

List<DD_Product__c> products = [
    SELECT Id, Product_Name__c, Product_Code__c, Plan_Family__c,
           Ortho_Available__c, Network_Fee_Basis__c, Is_Active__c
    FROM DD_Product__c
    WHERE Is_Active__c = true
    ORDER BY Plan_Family__c, Product_Name__c
];

System.debug('Found ' + products.size() + ' active products');

// ── 3. Delete existing coverage/benefit specs (clean slate) ───────────────────

Set<Id> productIds = new Map<Id,DD_Product__c>(products).keySet();

// Delete child benefit specs first (cascade not automatic for custom objects)
List<DD_Benefit_Spec__c> existingBenefits = [
    SELECT Id FROM DD_Benefit_Spec__c
    WHERE Coverage_Spec__r.Product__c IN :productIds
];
if (!existingBenefits.isEmpty()) {
    delete existingBenefits;
    System.debug('Deleted ' + existingBenefits.size() + ' existing benefit specs');
}

List<DD_Coverage_Spec__c> existingSpecs = [
    SELECT Id FROM DD_Coverage_Spec__c
    WHERE Product__c IN :productIds
];
if (!existingSpecs.isEmpty()) {
    delete existingSpecs;
    System.debug('Deleted ' + existingSpecs.size() + ' existing coverage specs');
}

// ── 4. Build coverage specs and benefit specs per product ─────────────────────

List<DD_Coverage_Spec__c> allSpecs   = new List<DD_Coverage_Spec__c>();
List<DD_Benefit_Spec__c>  allBenefits = new List<DD_Benefit_Spec__c>();

for (DD_Product__c p : products) {
    Boolean isDHMO   = p.Plan_Family__c != null && p.Plan_Family__c.containsIgnoreCase('DeltaCare');
    Boolean isDeluxe = p.Product_Name__c != null && p.Product_Name__c.containsIgnoreCase('Deluxe');
    Boolean isAdv    = p.Product_Name__c != null && p.Product_Name__c.containsIgnoreCase('Advantage');
    Boolean isCore   = p.Product_Name__c != null && p.Product_Name__c.containsIgnoreCase('Core');

    // Coinsurance: [D&P PPO, D&P NonPPO, Basic PPO, Basic NonPPO, Endo PPO, Endo NonPPO, Major PPO, Major NonPPO]
    Decimal dnpPPO, dnpNon, basicPPO, basicNon, endoPPO, endoNon, majorPPO, majorNon;
    if (isDHMO) {
        dnpPPO=100; dnpNon=100; basicPPO=80; basicNon=80; endoPPO=80; endoNon=80; majorPPO=50; majorNon=50;
    } else if (isDeluxe) {
        dnpPPO=100; dnpNon=100; basicPPO=80; basicNon=80; endoPPO=80; endoNon=80; majorPPO=50; majorNon=50;
    } else if (isAdv) {
        dnpPPO=100; dnpNon=80;  basicPPO=80; basicNon=60; endoPPO=80; endoNon=60; majorPPO=50; majorNon=40;
    } else if (isCore) {
        dnpPPO=100; dnpNon=70;  basicPPO=70; basicNon=50; endoPPO=70; endoNon=50; majorPPO=40; majorNon=30;
    } else {
        dnpPPO=100; dnpNon=80;  basicPPO=80; basicNon=60; endoPPO=80; endoNon=60; majorPPO=50; majorNon=40;
    }

    // Create coverage specs
    DD_Coverage_Spec__c dnpSpec = new DD_Coverage_Spec__c(
        Product__c           = p.Id,
        Coverage_Name__c     = 'Diagnostic & Preventive',
        Coverage_Code__c     = 'DNP',
        Coinsurance_PPO__c   = dnpPPO,
        Coinsurance_NonPPO__c= dnpNon,
        Deductible_Applies__c= false,
        Display_Order__c     = 1
    );
    DD_Coverage_Spec__c basicSpec = new DD_Coverage_Spec__c(
        Product__c           = p.Id,
        Coverage_Name__c     = 'Basic Services',
        Coverage_Code__c     = 'BASIC',
        Coinsurance_PPO__c   = basicPPO,
        Coinsurance_NonPPO__c= basicNon,
        Deductible_Applies__c= true,
        Display_Order__c     = 2
    );
    DD_Coverage_Spec__c endoSpec = new DD_Coverage_Spec__c(
        Product__c           = p.Id,
        Coverage_Name__c     = 'Endodontics, Periodontics & Oral Surgery',
        Coverage_Code__c     = 'ENDO',
        Coinsurance_PPO__c   = endoPPO,
        Coinsurance_NonPPO__c= endoNon,
        Deductible_Applies__c= true,
        Display_Order__c     = 3
    );
    DD_Coverage_Spec__c majorSpec = new DD_Coverage_Spec__c(
        Product__c           = p.Id,
        Coverage_Name__c     = 'Major Services',
        Coverage_Code__c     = 'MAJOR',
        Coinsurance_PPO__c   = majorPPO,
        Coinsurance_NonPPO__c= majorNon,
        Deductible_Applies__c= true,
        Display_Order__c     = 4
    );

    allSpecs.add(dnpSpec);
    allSpecs.add(basicSpec);
    allSpecs.add(endoSpec);
    allSpecs.add(majorSpec);

    if (p.Ortho_Available__c) {
        DD_Coverage_Spec__c orthoSpec = new DD_Coverage_Spec__c(
            Product__c           = p.Id,
            Coverage_Name__c     = 'Orthodontia',
            Coverage_Code__c     = 'ORTHO',
            Coinsurance_PPO__c   = 50,
            Coinsurance_NonPPO__c= 50,
            Deductible_Applies__c= false,
            Display_Order__c     = 5
        );
        allSpecs.add(orthoSpec);
    }
}

insert allSpecs;
System.debug('Inserted ' + allSpecs.size() + ' coverage specs');

// ── 5. Build benefit specs linked to each coverage spec ───────────────────────

for (DD_Coverage_Spec__c spec : allSpecs) {
    List<Map<String,Object>> codes;
    if (spec.Coverage_Code__c == 'DNP')   codes = dnpCodes;
    else if (spec.Coverage_Code__c == 'BASIC')  codes = basicCodes;
    else if (spec.Coverage_Code__c == 'ENDO')   codes = endoCodes;
    else if (spec.Coverage_Code__c == 'MAJOR')  codes = majorCodes;
    else if (spec.Coverage_Code__c == 'ORTHO')  codes = orthoCodes;
    else continue;

    for (Map<String,Object> cd : codes) {
        DD_Benefit_Spec__c b = new DD_Benefit_Spec__c(
            Coverage_Spec__c  = spec.Id,
            CDT_Code__c       = (String) cd.get('code'),
            CDT_Description__c= (String) cd.get('desc')
        );
        if (cd.get('freq') != null) {
            b.Frequency_Limit__c  = (Integer) cd.get('freq');
            b.Frequency_Period__c = (String)  cd.get('period');
        }
        allBenefits.add(b);
    }
}

insert allBenefits;
System.debug('Inserted ' + allBenefits.size() + ' benefit specs');

// ── 6. Upsert Product2 + PricebookEntry for each plan ────────────────────────
// This enables the standard Quote Line Items related list to show selected plans.

Id stdPbId = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1].Id;

// Load existing Product2 records by ProductCode to avoid duplicates
Map<String, Product2> existingP2 = new Map<String, Product2>();
for (Product2 p2 : [SELECT Id, ProductCode FROM Product2 WHERE ProductCode LIKE 'DD-%']) {
    existingP2.put(p2.ProductCode, p2);
}

List<Product2> p2ToInsert  = new List<Product2>();
List<Product2> p2ToUpdate  = new List<Product2>();

// Reload products (we already have them)
for (DD_Product__c p : products) {
    String pCode = 'DD-' + (p.Product_Code__c != null ? p.Product_Code__c : p.Id.to15());
    if (existingP2.containsKey(pCode)) {
        Product2 ex = existingP2.get(pCode);
        ex.Name        = p.Product_Name__c;
        ex.Family      = p.Plan_Family__c;
        ex.IsActive    = true;
        p2ToUpdate.add(ex);
    } else {
        p2ToInsert.add(new Product2(
            Name        = p.Product_Name__c,
            ProductCode = pCode,
            Family      = p.Plan_Family__c,
            IsActive    = true,
            Description = 'Delta Dental ' + p.Plan_Family__c + ' dental plan'
        ));
    }
}
if (!p2ToInsert.isEmpty()) insert p2ToInsert;
if (!p2ToUpdate.isEmpty()) update p2ToUpdate;

// Reload all DD- Product2 records
Map<String, Product2> allP2ByCode = new Map<String, Product2>();
for (Product2 p2 : [SELECT Id, ProductCode FROM Product2 WHERE ProductCode LIKE 'DD-%']) {
    allP2ByCode.put(p2.ProductCode, p2);
}

// Upsert PricebookEntry records (UnitPrice = 0; actual pricing via rate tables)
Map<Id, PricebookEntry> existingPbe = new Map<Id, PricebookEntry>();
for (PricebookEntry pbe : [
    SELECT Id, Product2Id FROM PricebookEntry
    WHERE Pricebook2Id = :stdPbId AND Product2.ProductCode LIKE 'DD-%'
]) {
    existingPbe.put(pbe.Product2Id, pbe);
}

List<PricebookEntry> pbeToInsert = new List<PricebookEntry>();
for (DD_Product__c p : products) {
    String pCode = 'DD-' + (p.Product_Code__c != null ? p.Product_Code__c : p.Id.to15());
    Product2 p2 = allP2ByCode.get(pCode);
    if (p2 == null) continue;
    if (!existingPbe.containsKey(p2.Id)) {
        pbeToInsert.add(new PricebookEntry(
            Pricebook2Id = stdPbId,
            Product2Id   = p2.Id,
            UnitPrice    = 0,
            IsActive     = true
        ));
    }
}
if (!pbeToInsert.isEmpty()) insert pbeToInsert;

System.debug('Product2 + PricebookEntry upsert complete');
System.debug('=== create_benefit_data.apex COMPLETE ===');
