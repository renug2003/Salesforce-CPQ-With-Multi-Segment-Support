// ============================================================
// Delta Dental CPQ — Data Load Script 2 of 4
// Creates: Coverage Specs (43 records)
// Run AFTER loadData_1_catalog.apex
// sf apex run --file scripts/loadData_2_coverageSpecs.apex --target-org dd-salesforce-digitalinsurancecpq
// ============================================================

// Query products inserted by script 1
Map<String, Id> prodMap = new Map<String, Id>();
for (DD_Product__c p : [SELECT Id, Product_Name__c FROM DD_Product__c WHERE Product_Code__c LIKE 'DD-%']) {
    prodMap.put(p.Product_Name__c, p.Id);
}
System.debug('Found ' + prodMap.size() + ' products');

// ── COVERAGE SPECS (43) ───────────────────────────────────────
// Cols: productName, coverageName, code, displayOrder, coinsPPO, coinsNonPPO, dedApplies, countsToMax, isOptional, reqPreauth
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

List<DD_Coverage_Spec__c> coverageSpecs = new List<DD_Coverage_Spec__c>();
for (Object[] row : specData) {
    Id prodId = prodMap.get((String)row[0]);
    if (prodId == null) { System.debug('WARN: no product found for ' + row[0]); continue; }
    coverageSpecs.add(new DD_Coverage_Spec__c(
        Product__c            = prodId,
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

System.debug('Script 2 complete: ' + [SELECT COUNT() FROM DD_Coverage_Spec__c] + ' coverage specs (expected 43)');
