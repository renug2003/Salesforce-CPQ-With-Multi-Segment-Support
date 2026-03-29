// ============================================================
// Delta Dental CPQ — Master Data Load Script
// Run: sf apex run --file scripts/loadData.apex --target-org <alias>
// ============================================================

// ── 1. CATALOG + CATEGORIES + RATE TABLE ────────────────────
DD_Product_Catalog__c catalog = new DD_Product_Catalog__c(
    Catalog_Name__c = 'Delta Dental 2025',
    Effective_Date__c = Date.newInstance(2025, 1, 1),
    Is_Active__c = true
);
insert catalog;

DD_Product_Category__c catPPO = new DD_Product_Category__c(
    Category_Name__c = 'PPO Plans', Product_Catalog__c = catalog.Id, Display_Order__c = 1);
DD_Product_Category__c catDHMO = new DD_Product_Category__c(
    Category_Name__c = 'DHMO Plans', Product_Catalog__c = catalog.Id, Display_Order__c = 2);
DD_Product_Category__c catPed = new DD_Product_Category__c(
    Category_Name__c = 'Pediatric Plans', Product_Catalog__c = catalog.Id, Display_Order__c = 3);
insert new List<DD_Product_Category__c>{ catPPO, catDHMO, catPed };

DD_Rate_Table__c rt = new DD_Rate_Table__c(
    Rate_Table_Name__c = 'SB 2025 Standard',
    Segment__c = 'Small Business',
    Effective_Date__c = Date.newInstance(2025, 1, 1),
    Is_Active__c = true
);
insert rt;

// ── 2. PRODUCTS ──────────────────────────────────────────────
List<DD_Product__c> products = new List<DD_Product__c>{
    new DD_Product__c(Product_Name__c='Deluxe 100',    Product_Code__c='DD-D100', Plan_Family__c='PPO Deluxe',    Network_Fee_Basis__c='PPO Plus Premier', Product_Line__c='DPPO', Product_Category__c=catPPO.Id,  Is_Active__c=true, Ortho_Available__c=true,  DnP_Max_Waiver_Available__c=true,  Deductible_Individual__c=50,  Deductible_Family__c=150, Min_Group_Size__c=5,  Max_Group_Size__c=99, State__c='CA'),
    new DD_Product__c(Product_Name__c='Deluxe 200',    Product_Code__c='DD-D200', Plan_Family__c='PPO Deluxe',    Network_Fee_Basis__c='PPO Plus Premier', Product_Line__c='DPPO', Product_Category__c=catPPO.Id,  Is_Active__c=true, Ortho_Available__c=true,  DnP_Max_Waiver_Available__c=true,  Deductible_Individual__c=50,  Deductible_Family__c=150, Min_Group_Size__c=2,  Max_Group_Size__c=99, State__c='CA'),
    new DD_Product__c(Product_Name__c='Deluxe 300',    Product_Code__c='DD-D300', Plan_Family__c='PPO Deluxe',    Network_Fee_Basis__c='PPO',              Product_Line__c='DPPO', Product_Category__c=catPPO.Id,  Is_Active__c=true, Ortho_Available__c=true,  DnP_Max_Waiver_Available__c=true,  Deductible_Individual__c=50,  Deductible_Family__c=150, Min_Group_Size__c=2,  Max_Group_Size__c=99, State__c='CA'),
    new DD_Product__c(Product_Name__c='Advantage 100', Product_Code__c='DD-A100', Plan_Family__c='PPO Advantage', Network_Fee_Basis__c='PPO Plus Premier', Product_Line__c='DPPO', Product_Category__c=catPPO.Id,  Is_Active__c=true, Ortho_Available__c=true,  DnP_Max_Waiver_Available__c=true,  Deductible_Individual__c=50,  Deductible_Family__c=150, Min_Group_Size__c=2,  Max_Group_Size__c=99, State__c='CA'),
    new DD_Product__c(Product_Name__c='Advantage 200', Product_Code__c='DD-A200', Plan_Family__c='PPO Advantage', Network_Fee_Basis__c='PPO Plus Premier', Product_Line__c='DPPO', Product_Category__c=catPPO.Id,  Is_Active__c=true, Ortho_Available__c=true,  DnP_Max_Waiver_Available__c=true,  Deductible_Individual__c=50,  Deductible_Family__c=150, Min_Group_Size__c=2,  Max_Group_Size__c=99, State__c='CA'),
    new DD_Product__c(Product_Name__c='Advantage 300', Product_Code__c='DD-A300', Plan_Family__c='PPO Advantage', Network_Fee_Basis__c='PPO Plus Premier', Product_Line__c='DPPO', Product_Category__c=catPPO.Id,  Is_Active__c=true, Ortho_Available__c=true,  DnP_Max_Waiver_Available__c=true,  Deductible_Individual__c=50,  Deductible_Family__c=150, Min_Group_Size__c=2,  Max_Group_Size__c=99, State__c='CA'),
    new DD_Product__c(Product_Name__c='Advantage 400', Product_Code__c='DD-A400', Plan_Family__c='PPO Advantage', Network_Fee_Basis__c='PPO',              Product_Line__c='DPPO', Product_Category__c=catPPO.Id,  Is_Active__c=true, Ortho_Available__c=true,  DnP_Max_Waiver_Available__c=true,  Deductible_Individual__c=50,  Deductible_Family__c=150, Min_Group_Size__c=2,  Max_Group_Size__c=99, State__c='CA'),
    new DD_Product__c(Product_Name__c='Core 100',      Product_Code__c='DD-C100', Plan_Family__c='PPO Core',      Network_Fee_Basis__c='PPO',              Product_Line__c='DPPO', Product_Category__c=catPPO.Id,  Is_Active__c=true, Ortho_Available__c=false, DnP_Max_Waiver_Available__c=false, Deductible_Individual__c=50,  Deductible_Family__c=150, Min_Group_Size__c=2,  Max_Group_Size__c=99, State__c='CA'),
    new DD_Product__c(Product_Name__c='Core 201',      Product_Code__c='DD-C201', Plan_Family__c='PPO Core',      Network_Fee_Basis__c='PPO',              Product_Line__c='DPPO', Product_Category__c=catPPO.Id,  Is_Active__c=true, Ortho_Available__c=false, DnP_Max_Waiver_Available__c=false, Deductible_Individual__c=50,  Deductible_Family__c=150, Min_Group_Size__c=2,  Max_Group_Size__c=99, State__c='CA'),
    new DD_Product__c(Product_Name__c='DeltaCare USA 11A',             Product_Code__c='DD-H11A', Plan_Family__c='DeltaCare USA', Network_Fee_Basis__c='DeltaCare USA', Product_Line__c='DHMO', Product_Category__c=catDHMO.Id, Is_Active__c=true, Ortho_Available__c=true,  DnP_Max_Waiver_Available__c=false, Deductible_Individual__c=0, Deductible_Family__c=0, Min_Group_Size__c=2, Max_Group_Size__c=99, State__c='CA'),
    new DD_Product__c(Product_Name__c='DeltaCare USA 15B',             Product_Code__c='DD-H15B', Plan_Family__c='DeltaCare USA', Network_Fee_Basis__c='DeltaCare USA', Product_Line__c='DHMO', Product_Category__c=catDHMO.Id, Is_Active__c=true, Ortho_Available__c=true,  DnP_Max_Waiver_Available__c=false, Deductible_Individual__c=0, Deductible_Family__c=0, Min_Group_Size__c=2, Max_Group_Size__c=99, State__c='CA'),
    new DD_Product__c(Product_Name__c='DeltaCare USA 17B',             Product_Code__c='DD-H17B', Plan_Family__c='DeltaCare USA', Network_Fee_Basis__c='DeltaCare USA', Product_Line__c='DHMO', Product_Category__c=catDHMO.Id, Is_Active__c=true, Ortho_Available__c=true,  DnP_Max_Waiver_Available__c=false, Deductible_Individual__c=0, Deductible_Family__c=0, Min_Group_Size__c=2, Max_Group_Size__c=99, State__c='CA'),
    new DD_Product__c(Product_Name__c='Children\'s Dental PPO',        Product_Code__c='DD-CPPO', Plan_Family__c='Pediatric',     Network_Fee_Basis__c='PPO',          Product_Line__c='DPPO', Product_Category__c=catPed.Id,  Is_Active__c=true, Ortho_Available__c=true,  DnP_Max_Waiver_Available__c=false, Deductible_Individual__c=75,  Deductible_Family__c=150, Min_Group_Size__c=2, Max_Group_Size__c=99, State__c='CA'),
    new DD_Product__c(Product_Name__c='Family Dental PPO',             Product_Code__c='DD-FPPO', Plan_Family__c='Pediatric',     Network_Fee_Basis__c='PPO',          Product_Line__c='DPPO', Product_Category__c=catPed.Id,  Is_Active__c=true, Ortho_Available__c=true,  DnP_Max_Waiver_Available__c=false, Deductible_Individual__c=50,  Deductible_Family__c=150, Min_Group_Size__c=2, Max_Group_Size__c=99, State__c='CA'),
    new DD_Product__c(Product_Name__c='DeltaCare USA Children\'s DHMO',Product_Code__c='DD-CDHM', Plan_Family__c='Pediatric',     Network_Fee_Basis__c='DeltaCare USA', Product_Line__c='DHMO', Product_Category__c=catPed.Id,  Is_Active__c=true, Ortho_Available__c=true,  DnP_Max_Waiver_Available__c=false, Deductible_Individual__c=0, Deductible_Family__c=0,   Min_Group_Size__c=2, Max_Group_Size__c=99, State__c='CA')
};
insert products;

Map<String, Id> prodMap = new Map<String, Id>();
for (DD_Product__c p : products) { prodMap.put(p.Product_Name__c, p.Id); }

// ── 3. SELLING MODELS ─────────────────────────────────────────
// Annual maxes and ortho options aggregated from CSVs
Map<String, String> annualMaxes = new Map<String, String>{
    'Deluxe 100'    => '1500,2000,2500,3000',
    'Deluxe 200'    => '1500,2000,2500,3000',
    'Deluxe 300'    => '1500,2000,2500,3000',
    'Advantage 100' => '1000,1500,2000,2500',
    'Advantage 200' => '1000,1500,2000,2500,3000',
    'Advantage 300' => '1000,1500,2000,2500',
    'Advantage 400' => '1000,1500,2000,2500,3000',
    'Core 100'      => '1000,1500',
    'Core 201'      => '750'
};
Map<String, String> orthoTypes = new Map<String, String>{
    'Deluxe 100'    => 'Child Only,Child and Adult',
    'Deluxe 200'    => 'Child Only,Child and Adult',
    'Deluxe 300'    => 'Child Only,Child and Adult',
    'Advantage 100' => 'Child Only',
    'Advantage 200' => 'Child Only,Child and Adult',
    'Advantage 300' => 'Child Only',
    'Advantage 400' => 'Child Only,Child and Adult'
};
Map<String, String> orthoMaxes = new Map<String, String>{
    'Deluxe 100'    => '1500',
    'Deluxe 200'    => '1500',
    'Deluxe 300'    => '1500',
    'Advantage 100' => '1000,1500',
    'Advantage 200' => '1000,1500',
    'Advantage 300' => '1000,1500',
    'Advantage 400' => '1000,1500'
};

List<DD_Selling_Model__c> sellingModels = new List<DD_Selling_Model__c>();
for (DD_Product__c p : products) {
    sellingModels.add(new DD_Selling_Model__c(
        Product__c               = p.Id,
        Segment__c               = 'Small Business',
        Min_Group_Size__c        = p.Min_Group_Size__c,
        Max_Group_Size__c        = p.Max_Group_Size__c,
        Rate_Table__c            = rt.Id,
        Min_Contribution_Pct__c  = 50,
        Is_Active__c             = true,
        Employer_Paid_Available__c = true,
        Voluntary_Available__c   = true,
        Available_Annual_Maxes__c = annualMaxes.get(p.Product_Name__c),
        Available_Ortho_Types__c  = orthoTypes.get(p.Product_Name__c),
        Available_Ortho_Maxes__c  = orthoMaxes.get(p.Product_Name__c)
    ));
}
insert sellingModels;

// ── 4. COVERAGE SPECS (43) ───────────────────────────────────
List<DD_Coverage_Spec__c> coverageSpecs = new List<DD_Coverage_Spec__c>();
// PPO products: Deluxe 100/200/300 have 5 specs; Advantage 100-400 have 5 specs; Core 100/201 have 4 specs
// Spec builder: product name, coverage name, code, display order, coinsPPO, coinsNonPPO, dedApplies, countsToMax, isOptional, reqPreauth
List<Object[]> specData = new List<Object[]>{
    new Object[]{'Deluxe 100','Diagnostic and Preventive','DNP',1,100,100,false,true,false,false},
    new Object[]{'Deluxe 100','Basic','BAS',2,100,80,true,true,false,false},
    new Object[]{'Deluxe 100','Endodontics Periodontics Oral Surgery','EPO',3,100,80,true,true,false,false},
    new Object[]{'Deluxe 100','Major','MAJ',4,60,50,true,true,false,false},
    new Object[]{'Deluxe 100','Orthodontia','ORT',5,50,50,true,false,true,true},
    new Object[]{'Deluxe 200','Diagnostic and Preventive','DNP',1,100,100,false,true,false,false},
    new Object[]{'Deluxe 200','Basic','BAS',2,90,80,true,true,false,false},
    new Object[]{'Deluxe 200','Endodontics Periodontics Oral Surgery','EPO',3,90,80,true,true,false,false},
    new Object[]{'Deluxe 200','Major','MAJ',4,60,50,true,true,false,false},
    new Object[]{'Deluxe 200','Orthodontia','ORT',5,50,50,true,false,true,true},
    new Object[]{'Deluxe 300','Diagnostic and Preventive','DNP',1,100,100,false,true,false,false},
    new Object[]{'Deluxe 300','Basic','BAS',2,90,80,true,true,false,false},
    new Object[]{'Deluxe 300','Endodontics Periodontics Oral Surgery','EPO',3,90,80,true,true,false,false},
    new Object[]{'Deluxe 300','Major','MAJ',4,60,50,true,true,false,false},
    new Object[]{'Deluxe 300','Orthodontia','ORT',5,50,50,true,false,true,true},
    new Object[]{'Advantage 100','Diagnostic and Preventive','DNP',1,100,100,false,true,false,false},
    new Object[]{'Advantage 100','Basic','BAS',2,80,80,true,true,false,false},
    new Object[]{'Advantage 100','Endodontics Periodontics Oral Surgery','EPO',3,80,80,true,true,false,false},
    new Object[]{'Advantage 100','Major','MAJ',4,60,50,true,true,false,false},
    new Object[]{'Advantage 100','Orthodontia','ORT',5,50,50,true,false,true,true},
    new Object[]{'Advantage 200','Diagnostic and Preventive','DNP',1,100,100,false,true,false,false},
    new Object[]{'Advantage 200','Basic','BAS',2,80,80,true,true,false,false},
    new Object[]{'Advantage 200','Endodontics Periodontics Oral Surgery','EPO',3,80,80,true,true,false,false},
    new Object[]{'Advantage 200','Major','MAJ',4,50,50,true,true,false,false},
    new Object[]{'Advantage 200','Orthodontia','ORT',5,50,50,true,false,true,true},
    new Object[]{'Advantage 300','Diagnostic and Preventive','DNP',1,100,80,false,true,false,false},
    new Object[]{'Advantage 300','Basic','BAS',2,80,60,true,true,false,false},
    new Object[]{'Advantage 300','Endodontics Periodontics Oral Surgery','EPO',3,80,60,true,true,false,false},
    new Object[]{'Advantage 300','Major','MAJ',4,50,50,true,true,false,false},
    new Object[]{'Advantage 300','Orthodontia','ORT',5,50,50,true,false,true,true},
    new Object[]{'Advantage 400','Diagnostic and Preventive','DNP',1,100,100,false,true,false,false},
    new Object[]{'Advantage 400','Basic','BAS',2,80,80,true,true,false,false},
    new Object[]{'Advantage 400','Endodontics Periodontics Oral Surgery','EPO',3,80,80,true,true,false,false},
    new Object[]{'Advantage 400','Major','MAJ',4,50,50,true,true,false,false},
    new Object[]{'Advantage 400','Orthodontia','ORT',5,50,50,true,false,true,true},
    new Object[]{'Core 100','Diagnostic and Preventive','DNP',1,100,100,false,true,false,false},
    new Object[]{'Core 100','Basic','BAS',2,80,80,true,true,false,false},
    new Object[]{'Core 100','Endodontics Periodontics Oral Surgery','EPO',3,50,50,true,true,false,false},
    new Object[]{'Core 100','Major','MAJ',4,50,50,true,true,false,false},
    new Object[]{'Core 201','Diagnostic and Preventive','DNP',1,100,100,false,true,false,false},
    new Object[]{'Core 201','Basic','BAS',2,80,80,true,true,false,false},
    new Object[]{'Core 201','Endodontics Periodontics Oral Surgery','EPO',3,0,0,true,true,false,false},
    new Object[]{'Core 201','Major','MAJ',4,0,0,true,true,false,false}
};
for (Object[] row : specData) {
    coverageSpecs.add(new DD_Coverage_Spec__c(
        Product__c            = prodMap.get((String)row[0]),
        Coverage_Name__c      = (String)row[1],
        Coverage_Code__c      = (String)row[2],
        Display_Order__c      = (Integer)row[3],
        Coinsurance_PPO__c    = (Decimal)row[4],
        Coinsurance_NonPPO__c = (Decimal)row[5],
        Deductible_Applies__c = (Boolean)row[6],
        Counts_Toward_Max__c  = (Boolean)row[7],
        Is_Optional__c        = (Boolean)row[8],
        Requires_Preauth__c   = (Boolean)row[9]
    ));
}
insert coverageSpecs;

// Build map of Deluxe 100 coverage specs by name for benefit spec linking
Map<String, Id> d100SpecMap = new Map<String, Id>();
for (DD_Coverage_Spec__c cs : coverageSpecs) {
    if (cs.Product__c == prodMap.get('Deluxe 100')) {
        d100SpecMap.put(cs.Coverage_Name__c, cs.Id);
    }
}

// ── 5. BENEFIT SPECS (130) — linked to Deluxe 100 coverage specs ──
// Cols: coverageName, cdtCode, cdtDesc, freqLimit(null=no limit), freqPeriod(null=no period), ageMin, ageMax, toothSpec, quadSpec, preauth, notes, copay11A, copay15B, copay17B
// Note: "Per 3 Months" is not a valid picklist value — nulled out
List<Object[]> bsData = new List<Object[]>{
    // Diagnostic and Preventive (48)
    new Object[]{'Diagnostic and Preventive','D0120','Periodic oral evaluation - established patient',1,'Per 6 Months',0,999,false,false,false,'Per provider',null,null,null},
    new Object[]{'Diagnostic and Preventive','D0140','Limited oral evaluation - problem focused',1,'Per Lifetime',0,999,false,false,false,'Per patient per provider',null,null,null},
    new Object[]{'Diagnostic and Preventive','D0145','Oral evaluation patient under 3 and counseling with caregiver',1,'Per Lifetime',0,3,false,false,false,null,null,null,null},
    new Object[]{'Diagnostic and Preventive','D0150','Comprehensive oral evaluation - new or established patient',1,'Per Lifetime',0,999,false,false,false,'Per patient per provider',null,null,null},
    new Object[]{'Diagnostic and Preventive','D0160','Detailed and extensive oral evaluation - problem focused',1,'Per Lifetime',0,999,false,false,false,'Per patient per provider; by report',null,null,null},
    new Object[]{'Diagnostic and Preventive','D0170','Re-evaluation - limited problem focused',null,null,0,999,false,false,false,'Max 12 in 12 months; not post-op',null,null,null},
    new Object[]{'Diagnostic and Preventive','D0171','Re-evaluation - post-operative office visit',null,null,0,999,false,false,false,null,null,null,null},
    new Object[]{'Diagnostic and Preventive','D0180','Comprehensive periodontal evaluation',1,'Per Lifetime',0,999,false,false,false,'New or established patient',null,null,null},
    new Object[]{'Diagnostic and Preventive','D0210','Intraoral - complete series of radiographic images',1,'Per 36 Months',0,999,false,false,false,'Per provider',null,null,null},
    new Object[]{'Diagnostic and Preventive','D0220','Intraoral - periapical first radiographic image',20,'Per 12 Months',0,999,false,false,false,'Combined D0220+D0230 max 20 per 12 mo per provider',null,null,null},
    new Object[]{'Diagnostic and Preventive','D0230','Intraoral - periapical each additional radiographic image',20,'Per 12 Months',0,999,false,false,false,'Combined D0220+D0230 max 20 per 12 mo per provider',null,null,null},
    new Object[]{'Diagnostic and Preventive','D0240','Intraoral - occlusal radiographic image',2,'Per 6 Months',0,999,false,false,false,'Per provider',null,null,null},
    new Object[]{'Diagnostic and Preventive','D0250','Extra-oral 2D projection radiographic image',1,'Per Date of Service',0,999,false,false,false,null,null,null,null},
    new Object[]{'Diagnostic and Preventive','D0251','Extra-oral posterior dental radiographic image',4,'Per Date of Service',0,999,false,false,false,null,null,null,null},
    new Object[]{'Diagnostic and Preventive','D0270','Bitewing - single radiographic image',1,'Per Date of Service',0,999,false,false,false,null,null,null,null},
    new Object[]{'Diagnostic and Preventive','D0272','Bitewings - two radiographic images',1,'Per 6 Months',0,999,false,false,false,'Per provider',null,null,null},
    new Object[]{'Diagnostic and Preventive','D0273','Bitewings - three radiographic images',1,'Per 6 Months',0,999,false,false,false,null,null,null,null},
    new Object[]{'Diagnostic and Preventive','D0274','Bitewings - four radiographic images',1,'Per 6 Months',10,999,false,false,false,'Per provider; age 10+',null,null,null},
    new Object[]{'Diagnostic and Preventive','D0277','Vertical bitewings - 7 to 8 radiographic images',4,'Per Calendar Year',0,999,false,false,false,null,null,null,null},
    new Object[]{'Diagnostic and Preventive','D0330','Panoramic radiographic image',1,'Per 36 Months',0,999,false,false,false,'Per provider',null,null,null},
    new Object[]{'Diagnostic and Preventive','D0340','2D cephalometric radiographic image',2,'Per 12 Months',0,999,false,false,false,'Per provider',null,null,null},
    new Object[]{'Diagnostic and Preventive','D0350','2D oral/facial photographic image',4,'Per Date of Service',0,999,false,false,false,null,null,null,null},
    new Object[]{'Diagnostic and Preventive','D0460','Pulp vitality tests',null,null,0,999,false,false,false,'Included in fee for diagnostic/restorative/endo; not separately payable',null,null,null},
    new Object[]{'Diagnostic and Preventive','D0470','Diagnostic casts',1,'Per Lifetime',0,999,false,false,false,'Per provider; for ortho eval only',null,null,null},
    new Object[]{'Diagnostic and Preventive','D0601','Caries risk assessment - low risk',1,'Per 12 Months',0,999,false,false,false,'One D0601/D0602/D0603 per 12 mo',null,null,null},
    new Object[]{'Diagnostic and Preventive','D0602','Caries risk assessment - moderate risk',1,'Per 12 Months',0,999,false,false,false,'One D0601/D0602/D0603 per 12 mo',null,null,null},
    new Object[]{'Diagnostic and Preventive','D0603','Caries risk assessment - high risk',1,'Per 12 Months',0,999,false,false,false,'One D0601/D0602/D0603 per 12 mo',null,null,null},
    new Object[]{'Diagnostic and Preventive','D0999','Unspecified diagnostic procedure by report',null,null,0,999,false,false,false,'By report',null,null,null},
    new Object[]{'Diagnostic and Preventive','D1110','Prophylaxis - adult',1,'Per 6 Months',0,999,false,false,false,null,5,null,null},
    new Object[]{'Diagnostic and Preventive','D1120','Prophylaxis - child',1,'Per 6 Months',0,999,false,false,false,null,5,null,null},
    new Object[]{'Diagnostic and Preventive','D1206','Topical application of fluoride varnish',1,'Per 6 Months',0,19,false,false,false,'Frequency applies toward D1208',null,null,null},
    new Object[]{'Diagnostic and Preventive','D1208','Topical application of fluoride - excluding varnish',1,'Per 6 Months',0,19,false,false,false,'Frequency applies toward D1206',null,null,null},
    new Object[]{'Diagnostic and Preventive','D1310','Nutritional counseling for control of dental disease',null,null,0,999,false,false,false,null,null,null,null},
    new Object[]{'Diagnostic and Preventive','D1320','Tobacco counseling for prevention of oral disease',null,null,0,999,false,false,false,'Not separately payable',null,null,null},
    new Object[]{'Diagnostic and Preventive','D1330','Oral hygiene instructions',null,null,0,999,false,false,false,'Not separately payable',null,null,null},
    new Object[]{'Diagnostic and Preventive','D1351','Sealant - per tooth',1,'Per 36 Months',0,999,true,false,false,'Per provider; permanent molars without caries or restorations on occlusal',10,15,17},
    new Object[]{'Diagnostic and Preventive','D1352','Preventive resin restoration - moderate to high caries risk',1,'Per 36 Months',0,999,true,false,false,'Per provider; permanent tooth',null,null,null},
    new Object[]{'Diagnostic and Preventive','D1353','Sealant repair - per tooth',null,null,0,999,true,false,false,null,null,null,null},
    new Object[]{'Diagnostic and Preventive','D1354','Application of caries arresting medicament - per tooth',1,'Per 6 Months',0,999,true,false,false,'When high caries risk assessment',null,null,null},
    new Object[]{'Diagnostic and Preventive','D1510','Space maintainer - fixed unilateral per quadrant',1,'Per Lifetime',0,17,false,true,false,'Per quadrant; through age 17',null,null,null},
    new Object[]{'Diagnostic and Preventive','D1516','Space maintainer - fixed bilateral maxillary',1,'Per Lifetime',0,17,false,false,false,'Per arch; through age 17',null,null,null},
    new Object[]{'Diagnostic and Preventive','D1517','Space maintainer - fixed bilateral mandibular',1,'Per Lifetime',0,17,false,false,false,'Per arch; through age 17',null,null,null},
    new Object[]{'Diagnostic and Preventive','D1520','Space maintainer - removable unilateral per quadrant',1,'Per Lifetime',0,17,false,true,false,'Per quadrant; through age 17',null,null,null},
    new Object[]{'Diagnostic and Preventive','D1575','Distal shoe space maintainer - fixed unilateral',1,'Per Lifetime',0,8,false,true,false,'Per quadrant; under age 9',null,null,null},
    new Object[]{'Diagnostic and Preventive','D4346','Scaling in presence of generalized moderate or severe gingival inflammation',1,'Per 6 Months',0,999,false,false,false,'Full mouth; after oral evaluation',null,null,null},
    new Object[]{'Diagnostic and Preventive','D9310','Consultation - diagnostic service by other dentist',null,null,0,999,false,false,false,null,null,null,null},
    new Object[]{'Diagnostic and Preventive','D9995','Teledentistry - synchronous',null,null,0,999,false,false,false,'Inclusive in overall patient management; not separately payable',null,null,null},
    new Object[]{'Diagnostic and Preventive','D9996','Teledentistry - asynchronous',null,null,0,999,false,false,false,'Inclusive in overall patient management; not separately payable',null,null,null},
    // Basic (28)
    new Object[]{'Basic','D2140','Amalgam - one surface primary or permanent',1,'Per 12 Months',0,999,true,false,false,'Primary teeth 12mo; permanent 36mo',null,8,17},
    new Object[]{'Basic','D2150','Amalgam - two surfaces primary or permanent',1,'Per 12 Months',0,999,true,false,false,'Primary teeth 12mo; permanent 36mo',null,8,17},
    new Object[]{'Basic','D2160','Amalgam - three surfaces primary or permanent',1,'Per 12 Months',0,999,true,false,false,'Primary teeth 12mo; permanent 36mo',null,8,17},
    new Object[]{'Basic','D2161','Amalgam - four or more surfaces primary or permanent',1,'Per 12 Months',0,999,true,false,false,'Primary teeth 12mo; permanent 36mo',null,8,17},
    new Object[]{'Basic','D2330','Resin-based composite - one surface anterior',1,'Per 12 Months',0,999,true,false,false,'Primary teeth 12mo; permanent 36mo',null,22,22},
    new Object[]{'Basic','D2331','Resin-based composite - two surfaces anterior',1,'Per 12 Months',0,999,true,false,false,'Primary teeth 12mo; permanent 36mo',null,22,22},
    new Object[]{'Basic','D2332','Resin-based composite - three surfaces anterior',1,'Per 12 Months',0,999,true,false,false,'Primary teeth 12mo; permanent 36mo',null,22,22},
    new Object[]{'Basic','D2335','Resin-based composite - four or more surfaces anterior',1,'Per 12 Months',0,999,true,false,false,'Primary teeth 12mo; permanent 36mo',null,22,22},
    new Object[]{'Basic','D2390','Resin-based composite crown anterior',1,'Per 12 Months',0,999,true,false,false,'Primary teeth 12mo; permanent 36mo',null,null,null},
    new Object[]{'Basic','D2391','Resin-based composite - one surface posterior',1,'Per 12 Months',0,999,true,false,false,'Primary teeth 12mo; permanent 36mo',55,65,47},
    new Object[]{'Basic','D2392','Resin-based composite - two surfaces posterior',1,'Per 12 Months',0,999,true,false,false,'Primary teeth 12mo; permanent 36mo',55,65,47},
    new Object[]{'Basic','D2393','Resin-based composite - three surfaces posterior',1,'Per 12 Months',0,999,true,false,false,'Primary teeth 12mo; permanent 36mo',55,65,47},
    new Object[]{'Basic','D2394','Resin-based composite - four or more surfaces posterior',1,'Per 12 Months',0,999,true,false,false,'Primary teeth 12mo; permanent 36mo',55,65,47},
    new Object[]{'Basic','D2920','Re-cement or re-bond crown',1,'Per 12 Months',0,999,true,false,false,'Per provider',null,null,null},
    new Object[]{'Basic','D2929','Prefabricated porcelain/ceramic crown - primary tooth',1,'Per 12 Months',0,999,true,false,false,null,null,null,null},
    new Object[]{'Basic','D2930','Prefabricated stainless steel crown - primary tooth',1,'Per 12 Months',0,999,true,false,false,null,null,null,null},
    new Object[]{'Basic','D2931','Prefabricated stainless steel crown - permanent tooth',1,'Per 36 Months',0,999,true,false,false,null,null,null,null},
    new Object[]{'Basic','D2940','Protective restoration',1,'Per 6 Months',0,999,true,false,false,'Per tooth per provider; when definitive tx not same DOS',null,null,null},
    new Object[]{'Basic','D2950','Core buildup including any pins',1,'Per Lifetime',0,999,true,false,false,null,15,80,105},
    new Object[]{'Basic','D2951','Pin retention - per tooth in addition to restoration',1,'Per Lifetime',0,999,true,false,false,'Permanent teeth only',null,null,null},
    new Object[]{'Basic','D2952','Post and core in addition to crown indirectly fabricated',1,'Per Lifetime',0,999,true,false,false,'Per tooth',null,null,null},
    new Object[]{'Basic','D2954','Prefabricated post and core in addition to crown',1,'Per Lifetime',0,999,true,false,false,'Per tooth',null,null,null},
    new Object[]{'Basic','D4355','Full mouth debridement',null,null,13,999,false,false,false,'Included in periodontal procedures fee; not separately payable',null,null,null},
    new Object[]{'Basic','D4910','Periodontal maintenance',null,null,13,999,false,false,false,'Only in 24 months following last SRP; age 13+',15,45,78},
    new Object[]{'Basic','D9110','Palliative treatment of dental pain',1,'Per Date of Service',0,999,false,false,false,'Per provider regardless of teeth/areas treated',null,null,null},
    new Object[]{'Basic','D9210','Local anesthesia not in conjunction with operative',1,'Per Date of Service',0,999,false,false,false,'Per provider',null,null,null},
    new Object[]{'Basic','D9222','Deep sedation/general anesthesia - first 15 min',null,null,0,999,false,false,false,'For covered oral surgery or selected endo/perio surgical',null,null,null},
    new Object[]{'Basic','D9230','Inhalation of nitrous oxide/analgesia anxiolysis',null,null,0,999,false,false,false,null,null,null,null},
    // Endodontics Periodontics Oral Surgery (18)
    new Object[]{'Endodontics Periodontics Oral Surgery','D3110','Pulp cap - direct',null,null,0,999,true,false,false,'Excluding final restoration',null,null,null},
    new Object[]{'Endodontics Periodontics Oral Surgery','D3120','Pulp cap - indirect',null,null,0,999,true,false,false,'Excluding final restoration',null,null,null},
    new Object[]{'Endodontics Periodontics Oral Surgery','D3220','Therapeutic pulpotomy',1,'Per Lifetime',0,999,true,false,false,'Primary teeth only; once per tooth',null,null,null},
    new Object[]{'Endodontics Periodontics Oral Surgery','D3310','Endodontic therapy anterior tooth',1,'Per Lifetime',0,999,true,false,false,'Excluding final restoration; retreatment processed as D3346',55,125,330},
    new Object[]{'Endodontics Periodontics Oral Surgery','D3320','Endodontic therapy premolar tooth',1,'Per Lifetime',0,999,true,false,false,'Excluding final restoration; retreatment as D3347',null,null,null},
    new Object[]{'Endodontics Periodontics Oral Surgery','D3330','Endodontic therapy molar tooth',1,'Per Lifetime',0,999,true,false,false,'Excluding final restoration; retreatment as D3348',250,365,530},
    new Object[]{'Endodontics Periodontics Oral Surgery','D3346','Retreatment of previous root canal therapy - anterior',null,null,0,999,true,false,false,null,null,null,null},
    new Object[]{'Endodontics Periodontics Oral Surgery','D3347','Retreatment of previous root canal therapy - premolar',null,null,0,999,true,false,false,null,null,null,null},
    new Object[]{'Endodontics Periodontics Oral Surgery','D3348','Retreatment of previous root canal therapy - molar',null,null,0,999,true,false,false,null,null,null,null},
    new Object[]{'Endodontics Periodontics Oral Surgery','D3410','Apicoectomy - anterior',null,null,0,999,true,false,false,'Retreatment within 24mo by same provider is part of original',null,null,null},
    new Object[]{'Endodontics Periodontics Oral Surgery','D3421','Apicoectomy - premolar first root',null,null,0,999,true,false,false,null,null,null,null},
    new Object[]{'Endodontics Periodontics Oral Surgery','D3425','Apicoectomy - molar first root',null,null,0,999,true,false,false,null,null,null,null},
    new Object[]{'Endodontics Periodontics Oral Surgery','D4210','Gingivectomy or gingivoplasty - 4+ contiguous teeth per quad',1,'Per 36 Months',13,999,false,true,false,'Per quadrant; age 13+',280,385,595},
    new Object[]{'Endodontics Periodontics Oral Surgery','D4211','Gingivectomy or gingivoplasty - 1 to 3 teeth per quad',1,'Per 36 Months',13,999,false,true,false,'Per quadrant; age 13+',null,null,null},
    new Object[]{'Endodontics Periodontics Oral Surgery','D4260','Osseous surgery - 4+ contiguous teeth per quadrant',1,'Per 36 Months',13,999,false,true,false,'Per quadrant; age 13+; includes flap',280,385,595},
    new Object[]{'Endodontics Periodontics Oral Surgery','D4261','Osseous surgery - 1 to 3 teeth per quadrant',1,'Per 36 Months',13,999,false,true,false,'Per quadrant; age 13+',null,null,null},
    new Object[]{'Endodontics Periodontics Oral Surgery','D4341','Periodontal scaling and root planing - 4+ teeth per quad',1,'Per 24 Months',13,999,false,true,false,'Per quadrant; age 13+',25,60,115},
    new Object[]{'Endodontics Periodontics Oral Surgery','D4342','Periodontal scaling and root planing - 1 to 3 teeth per quad',1,'Per 24 Months',13,999,false,true,false,'Per quadrant; age 13+',null,null,null},
    // Major (26)
    new Object[]{'Major','D2710','Crown - resin-based composite indirect',1,'Per 60 Months',13,999,true,false,false,'Age 13+',null,null,null},
    new Object[]{'Major','D2740','Crown - porcelain/ceramic',1,'Per 60 Months',13,999,true,false,false,'Age 13+',240,395,470},
    new Object[]{'Major','D2751','Crown - porcelain fused to predominantly base metal',1,'Per 60 Months',13,999,true,false,false,'Age 13+',240,395,470},
    new Object[]{'Major','D2791','Crown - full cast predominantly base metal',1,'Per 60 Months',13,999,true,false,false,'Age 13+',210,395,480},
    new Object[]{'Major','D5110','Complete denture - maxillary',1,'Per 60 Months',0,999,false,false,false,null,145,365,575},
    new Object[]{'Major','D5120','Complete denture - mandibular',1,'Per 60 Months',0,999,false,false,false,null,145,365,575},
    new Object[]{'Major','D5130','Immediate denture - maxillary',1,'Per Lifetime',0,999,false,false,false,null,null,null,null},
    new Object[]{'Major','D5140','Immediate denture - mandibular',1,'Per Lifetime',0,999,false,false,false,null,null,null,null},
    new Object[]{'Major','D5211','Maxillary partial denture - resin base',1,'Per 60 Months',0,999,false,false,false,null,160,395,670},
    new Object[]{'Major','D5213','Maxillary partial denture - cast metal framework',1,'Per 60 Months',0,999,false,false,false,null,160,395,670},
    new Object[]{'Major','D5214','Mandibular partial denture - cast metal framework',1,'Per 60 Months',0,999,false,false,false,null,160,395,670},
    new Object[]{'Major','D6010','Surgical placement of implant body - endosteal',null,null,0,999,true,false,true,'Requires medical necessity documentation and prior auth',null,null,null},
    new Object[]{'Major','D6040','Surgical placement - eposteal implant',null,null,0,999,true,false,true,'Requires prior authorization',null,null,null},
    new Object[]{'Major','D6065','Implant supported porcelain/ceramic crown',null,null,0,999,true,false,true,null,null,null,null},
    new Object[]{'Major','D6245','Pontic - porcelain/ceramic',1,'Per 60 Months',13,999,true,false,true,'Age 13+; fixed bridges require prior auth',null,null,null},
    new Object[]{'Major','D6751','Retainer crown - porcelain fused to predominantly base metal',1,'Per 60 Months',13,999,true,false,true,'Age 13+',null,null,null},
    new Object[]{'Major','D7111','Extraction coronal remnants - primary tooth',null,null,0,999,true,false,false,null,null,null,null},
    new Object[]{'Major','D7140','Extraction erupted tooth or exposed root',1,'Per Lifetime',0,999,true,false,false,'Elevation and/or forceps removal',5,14,53},
    new Object[]{'Major','D7210','Extraction erupted tooth requiring removal of bone',1,'Per Lifetime',0,999,true,false,false,'Including mucoperiosteal flap if indicated',5,14,53},
    new Object[]{'Major','D7220','Removal of impacted tooth - soft tissue',null,null,0,999,true,false,false,null,null,null,null},
    new Object[]{'Major','D7230','Removal of impacted tooth - partially bony',null,null,0,999,true,false,false,null,null,null,null},
    new Object[]{'Major','D7240','Removal of impacted tooth - completely bony',null,null,0,999,true,false,false,null,null,90,230},
    new Object[]{'Major','D7241','Removal of impacted tooth - completely bony with complications',null,null,0,999,true,false,false,null,null,null,null},
    new Object[]{'Major','D9950','Occlusion analysis - mounted case',1,'Per 12 Months',13,999,false,false,false,'For diagnosed TMJ; age 13+; permanent dentition',null,null,null},
    new Object[]{'Major','D9951','Occlusal adjustment - limited',1,'Per 12 Months',13,999,false,false,false,'Age 13+',null,null,null},
    new Object[]{'Major','D9952','Occlusal adjustment - complete',1,'Per 12 Months',13,999,false,false,false,'Age 13+',null,null,null},
    // Orthodontia (10)
    new Object[]{'Orthodontia','D8080','Comprehensive orthodontic treatment of adolescent dentition',1,'Per Lifetime',0,19,false,false,true,'Once per patient per phase; requires prior auth; HLD score >=26',1700,1900,1750},
    new Object[]{'Orthodontia','D8210','Removable appliance therapy',1,'Per Lifetime',6,12,false,false,true,'Once per patient ages 6-12',null,null,null},
    new Object[]{'Orthodontia','D8220','Fixed appliance therapy',1,'Per Lifetime',6,12,false,false,true,'Once per patient ages 6-12',null,null,null},
    new Object[]{'Orthodontia','D8660','Pre-orthodontic treatment examination',6,'Per Lifetime',0,999,false,false,false,'Once every 3 months; max 6 lifetime',null,null,null},
    new Object[]{'Orthodontia','D8670','Periodic orthodontic treatment visit',null,null,0,999,false,false,false,'Once per calendar quarter',null,null,null},
    new Object[]{'Orthodontia','D8680','Orthodontic retention - removal of appliances and retainers',1,'Per Lifetime',0,999,false,false,false,'Once per arch per authorized phase',null,null,null},
    new Object[]{'Orthodontia','D8696','Repair of orthodontic appliance - maxillary',1,'Per Lifetime',0,999,false,false,false,'Once per appliance',null,null,null},
    new Object[]{'Orthodontia','D8697','Repair of orthodontic appliance - mandibular',1,'Per Lifetime',0,999,false,false,false,'Once per appliance',null,null,null},
    new Object[]{'Orthodontia','D8703','Replacement of lost or broken retainer - maxillary',1,'Per Lifetime',0,999,false,false,false,'Once per arch; within 24mo of retention',null,null,null},
    new Object[]{'Orthodontia','D8704','Replacement of lost or broken retainer - mandibular',1,'Per Lifetime',0,999,false,false,false,'Once per arch; within 24mo of retention',null,null,null}
};

List<DD_Benefit_Spec__c> benefitSpecs = new List<DD_Benefit_Spec__c>();
for (Object[] row : bsData) {
    DD_Benefit_Spec__c bs = new DD_Benefit_Spec__c(
        Coverage_Spec__c    = d100SpecMap.get((String)row[0]),
        CDT_Code__c         = (String)row[1],
        CDT_Description__c  = (String)row[2],
        Frequency_Limit__c  = (Integer)row[3],
        Frequency_Period__c = (String)row[4],
        Age_Min__c          = (Integer)row[5],
        Age_Max__c          = (Integer)row[6],
        Tooth_Specific__c   = (Boolean)row[7],
        Quadrant_Specific__c= (Boolean)row[8],
        Requires_Preauth__c = (Boolean)row[9],
        Notes__c            = (String)row[10],
        DHMO_Copay_11A__c   = (Decimal)row[11],
        DHMO_Copay_15B__c   = (Decimal)row[12],
        DHMO_Copay_17B__c   = (Decimal)row[13]
    );
    benefitSpecs.add(bs);
}
insert benefitSpecs;

// ── 6. SIC MAPPINGS (57) ──────────────────────────────────────
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

// ── 7. UW RULES (16) ─────────────────────────────────────────
// Category mapping: Eligibility→Eligibility, Rating→Rating, Plan Eligibility→Eligibility,
//                   Participation→Underwriting, Plan Configuration→Configuration
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

// ── 8. VALIDATION ─────────────────────────────────────────────
System.debug('=== DATA LOAD VALIDATION ===');
System.debug('Products:       ' + [SELECT COUNT() FROM DD_Product__c] + ' (expected 15)');
System.debug('Coverage Specs: ' + [SELECT COUNT() FROM DD_Coverage_Spec__c] + ' (expected 43)');
System.debug('Benefit Specs:  ' + [SELECT COUNT() FROM DD_Benefit_Spec__c] + ' (expected 130)');
System.debug('Selling Models: ' + [SELECT COUNT() FROM DD_Selling_Model__c] + ' (expected 15)');
System.debug('SIC Mappings:   ' + [SELECT COUNT() FROM DD_SIC_Mapping__c] + ' (expected 57)');
System.debug('UW Rules:       ' + [SELECT COUNT() FROM DD_Product_Rule__c] + ' (expected 16)');
System.debug('Catalog:        ' + [SELECT COUNT() FROM DD_Product_Catalog__c] + ' (expected 1)');
System.debug('Categories:     ' + [SELECT COUNT() FROM DD_Product_Category__c] + ' (expected 3)');
System.debug('=== END VALIDATION ===');
