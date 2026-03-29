// ============================================================
// Delta Dental CPQ — Data Load Script 3 of 4
// Creates: Benefit Specs (130 records) on Deluxe 100 coverage specs
// Run AFTER loadData_2_coverageSpecs.apex
// sf apex run --file scripts/loadData_3_benefitSpecs.apex --target-org dd-salesforce-digitalinsurancecpq
// ============================================================

// Query Deluxe 100 coverage specs by name
Id deluxe100Id = [SELECT Id FROM DD_Product__c WHERE Product_Code__c = 'DD-D100' LIMIT 1].Id;
Map<String, Id> d100SpecMap = new Map<String, Id>();
for (DD_Coverage_Spec__c cs : [SELECT Id, Coverage_Name__c FROM DD_Coverage_Spec__c WHERE Product__c = :deluxe100Id]) {
    d100SpecMap.put(cs.Coverage_Name__c, cs.Id);
}
System.debug('Found ' + d100SpecMap.size() + ' Deluxe 100 coverage specs: ' + d100SpecMap.keySet());

// ── BENEFIT SPECS (130) ───────────────────────────────────────
// Cols: coverageName, cdtCode, cdtDesc, freqLimit, freqPeriod, ageMin, ageMax, toothSpec, quadSpec, preauth, notes, copay11A, copay15B, copay17B
// Note: "Per 3 Months" is not a valid picklist — nulled out for D0170, D4910, D8670
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
    Id specId = d100SpecMap.get((String)row[0]);
    if (specId == null) { System.debug('WARN: no coverage spec for ' + row[0]); continue; }
    benefitSpecs.add(new DD_Benefit_Spec__c(
        Coverage_Spec__c    = specId,
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
    ));
}
insert benefitSpecs;

System.debug('Script 3 complete: ' + [SELECT COUNT() FROM DD_Benefit_Spec__c] + ' benefit specs (expected 130)');
