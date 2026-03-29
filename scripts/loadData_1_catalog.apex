// ============================================================
// Delta Dental CPQ — Data Load Script 1 of 4
// Creates: Catalog, Categories, Rate Table, Products, Selling Models
// Run FIRST before other loadData scripts
// sf apex run --file scripts/loadData_1_catalog.apex --target-org dd-salesforce-digitalinsurancecpq
// ============================================================

// ── 1. CATALOG + CATEGORIES + RATE TABLE ────────────────────
DD_Product_Catalog__c catalog = new DD_Product_Catalog__c(
    Catalog_Name__c = 'Delta Dental 2025',
    Effective_Date__c = Date.newInstance(2025, 1, 1),
    Status__c = 'Active'
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
    Table_Name__c = 'SB 2025 Standard',
    Segment__c = 'Small Business',
    Rate_Level__c = 'All',
    Effective_Date__c = Date.newInstance(2025, 1, 1),
    Status__c = 'Active'
);
insert rt;

// ── 2. PRODUCTS (15) ─────────────────────────────────────────
List<DD_Product__c> products = new List<DD_Product__c>{
    new DD_Product__c(Product_Name__c='Deluxe 100',    Product_Code__c='DD-D100', Plan_Family__c='PPO Deluxe',    Network_Fee_Basis__c='PPO Plus Premier', Product_Line__c='DPPO', Product_Category__c=catPPO.Id,  Is_Active__c=true, Ortho_Available__c=true,  DnP_Max_Waiver_Available__c=true,  Deductible_Individual__c=50,  Deductible_Family__c=150, State__c='CA'),
    new DD_Product__c(Product_Name__c='Deluxe 200',    Product_Code__c='DD-D200', Plan_Family__c='PPO Deluxe',    Network_Fee_Basis__c='PPO Plus Premier', Product_Line__c='DPPO', Product_Category__c=catPPO.Id,  Is_Active__c=true, Ortho_Available__c=true,  DnP_Max_Waiver_Available__c=true,  Deductible_Individual__c=50,  Deductible_Family__c=150, State__c='CA'),
    new DD_Product__c(Product_Name__c='Deluxe 300',    Product_Code__c='DD-D300', Plan_Family__c='PPO Deluxe',    Network_Fee_Basis__c='PPO',              Product_Line__c='DPPO', Product_Category__c=catPPO.Id,  Is_Active__c=true, Ortho_Available__c=true,  DnP_Max_Waiver_Available__c=true,  Deductible_Individual__c=50,  Deductible_Family__c=150, State__c='CA'),
    new DD_Product__c(Product_Name__c='Advantage 100', Product_Code__c='DD-A100', Plan_Family__c='PPO Advantage', Network_Fee_Basis__c='PPO Plus Premier', Product_Line__c='DPPO', Product_Category__c=catPPO.Id,  Is_Active__c=true, Ortho_Available__c=true,  DnP_Max_Waiver_Available__c=true,  Deductible_Individual__c=50,  Deductible_Family__c=150, State__c='CA'),
    new DD_Product__c(Product_Name__c='Advantage 200', Product_Code__c='DD-A200', Plan_Family__c='PPO Advantage', Network_Fee_Basis__c='PPO Plus Premier', Product_Line__c='DPPO', Product_Category__c=catPPO.Id,  Is_Active__c=true, Ortho_Available__c=true,  DnP_Max_Waiver_Available__c=true,  Deductible_Individual__c=50,  Deductible_Family__c=150, State__c='CA'),
    new DD_Product__c(Product_Name__c='Advantage 300', Product_Code__c='DD-A300', Plan_Family__c='PPO Advantage', Network_Fee_Basis__c='PPO Plus Premier', Product_Line__c='DPPO', Product_Category__c=catPPO.Id,  Is_Active__c=true, Ortho_Available__c=true,  DnP_Max_Waiver_Available__c=true,  Deductible_Individual__c=50,  Deductible_Family__c=150, State__c='CA'),
    new DD_Product__c(Product_Name__c='Advantage 400', Product_Code__c='DD-A400', Plan_Family__c='PPO Advantage', Network_Fee_Basis__c='PPO',              Product_Line__c='DPPO', Product_Category__c=catPPO.Id,  Is_Active__c=true, Ortho_Available__c=true,  DnP_Max_Waiver_Available__c=true,  Deductible_Individual__c=50,  Deductible_Family__c=150, State__c='CA'),
    new DD_Product__c(Product_Name__c='Core 100',      Product_Code__c='DD-C100', Plan_Family__c='PPO Core',      Network_Fee_Basis__c='PPO',              Product_Line__c='DPPO', Product_Category__c=catPPO.Id,  Is_Active__c=true, Ortho_Available__c=false, DnP_Max_Waiver_Available__c=false, Deductible_Individual__c=50,  Deductible_Family__c=150, State__c='CA'),
    new DD_Product__c(Product_Name__c='Core 201',      Product_Code__c='DD-C201', Plan_Family__c='PPO Core',      Network_Fee_Basis__c='PPO',              Product_Line__c='DPPO', Product_Category__c=catPPO.Id,  Is_Active__c=true, Ortho_Available__c=false, DnP_Max_Waiver_Available__c=false, Deductible_Individual__c=50,  Deductible_Family__c=150, State__c='CA'),
    new DD_Product__c(Product_Name__c='DeltaCare USA 11A',             Product_Code__c='DD-H11A', Plan_Family__c='DeltaCare USA', Network_Fee_Basis__c='DeltaCare USA', Product_Line__c='DHMO', Product_Category__c=catDHMO.Id, Is_Active__c=true, Ortho_Available__c=true,  DnP_Max_Waiver_Available__c=false, Deductible_Individual__c=0, Deductible_Family__c=0, State__c='CA'),
    new DD_Product__c(Product_Name__c='DeltaCare USA 15B',             Product_Code__c='DD-H15B', Plan_Family__c='DeltaCare USA', Network_Fee_Basis__c='DeltaCare USA', Product_Line__c='DHMO', Product_Category__c=catDHMO.Id, Is_Active__c=true, Ortho_Available__c=true,  DnP_Max_Waiver_Available__c=false, Deductible_Individual__c=0, Deductible_Family__c=0, State__c='CA'),
    new DD_Product__c(Product_Name__c='DeltaCare USA 17B',             Product_Code__c='DD-H17B', Plan_Family__c='DeltaCare USA', Network_Fee_Basis__c='DeltaCare USA', Product_Line__c='DHMO', Product_Category__c=catDHMO.Id, Is_Active__c=true, Ortho_Available__c=true,  DnP_Max_Waiver_Available__c=false, Deductible_Individual__c=0, Deductible_Family__c=0, State__c='CA'),
    new DD_Product__c(Product_Name__c='Children\'s Dental PPO',        Product_Code__c='DD-CPPO', Plan_Family__c='Pediatric',     Network_Fee_Basis__c='PPO',          Product_Line__c='DPPO', Product_Category__c=catPed.Id,  Is_Active__c=true, Ortho_Available__c=true,  DnP_Max_Waiver_Available__c=false, Deductible_Individual__c=75,  Deductible_Family__c=150, State__c='CA'),
    new DD_Product__c(Product_Name__c='Family Dental PPO',             Product_Code__c='DD-FPPO', Plan_Family__c='Pediatric',     Network_Fee_Basis__c='PPO',          Product_Line__c='DPPO', Product_Category__c=catPed.Id,  Is_Active__c=true, Ortho_Available__c=true,  DnP_Max_Waiver_Available__c=false, Deductible_Individual__c=50,  Deductible_Family__c=150, State__c='CA'),
    new DD_Product__c(Product_Name__c='DeltaCare USA Children\'s DHMO',Product_Code__c='DD-CDHM', Plan_Family__c='Pediatric',     Network_Fee_Basis__c='DeltaCare USA', Product_Line__c='DHMO', Product_Category__c=catPed.Id,  Is_Active__c=true, Ortho_Available__c=true,  DnP_Max_Waiver_Available__c=false, Deductible_Individual__c=0, Deductible_Family__c=0, State__c='CA')
};
insert products;

// ── 3. SELLING MODELS (15) ────────────────────────────────────
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

Map<String, Integer> minSizes = new Map<String, Integer>{
    'Deluxe 100' => 5, 'Deluxe 200' => 2, 'Deluxe 300' => 2,
    'Advantage 100' => 2, 'Advantage 200' => 2, 'Advantage 300' => 2, 'Advantage 400' => 2,
    'Core 100' => 2, 'Core 201' => 2, 'DeltaCare USA 11A' => 2, 'DeltaCare USA 15B' => 2,
    'DeltaCare USA 17B' => 2, 'Children\'s Dental PPO' => 2, 'Family Dental PPO' => 2,
    'DeltaCare USA Children\'s DHMO' => 2
};
List<DD_Selling_Model__c> sellingModels = new List<DD_Selling_Model__c>();
for (DD_Product__c p : products) {
    sellingModels.add(new DD_Selling_Model__c(
        Product__c               = p.Id,
        Segment__c               = 'Small Business',
        Min_Group_Size__c        = minSizes.get(p.Product_Name__c) != null ? minSizes.get(p.Product_Name__c) : 2,
        Max_Group_Size__c        = 99,
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

System.debug('Script 1 complete: '
    + [SELECT COUNT() FROM DD_Product__c] + ' products, '
    + [SELECT COUNT() FROM DD_Selling_Model__c] + ' selling models');
