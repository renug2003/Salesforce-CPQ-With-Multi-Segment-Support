# Skill: Salesforce Custom Object Creation

## When to Use
Use this skill when creating or modifying custom object metadata XML files in the `force-app/main/default/objects/` directory.

## Directory Structure
Each custom object gets its own directory:
```
force-app/main/default/objects/DD_Plan_Design__c/
├── DD_Plan_Design__c.object-meta.xml          # Object definition
├── fields/
│   ├── Plan_Name__c.field-meta.xml            # Each field
│   ├── Plan_Family__c.field-meta.xml
│   └── ...
├── listViews/
│   └── All.listView-meta.xml
├── recordTypes/                                # If needed
└── validationRules/
    └── Require_Plan_Name.validationRule-meta.xml
```

## Object Definition Template
```xml
<?xml version="1.0" encoding="UTF-8"?>
<CustomObject xmlns="http://soap.sforce.com/2006/04/metadata">
    <actionOverrides>
        <actionName>View</actionName>
        <type>Default</type>
    </actionOverrides>
    <allowInChatterGroups>false</allowInChatterGroups>
    <compactLayoutAssignment>SYSTEM</compactLayoutAssignment>
    <deploymentStatus>Deployed</deploymentStatus>
    <description>Description of the object purpose in DD context</description>
    <enableActivities>true</enableActivities>
    <enableBulkApi>true</enableBulkApi>
    <enableEnhancedLookup>true</enableEnhancedLookup>
    <enableFeeds>false</enableFeeds>
    <enableHistory>true</enableHistory>
    <enableLicensing>false</enableLicensing>
    <enableReports>true</enableReports>
    <enableSearch>true</enableSearch>
    <enableSharing>true</enableSharing>
    <enableStreamingApi>true</enableStreamingApi>
    <label>Plan Design</label>
    <nameField>
        <displayFormat>PD-{00000}</displayFormat>
        <label>Plan Design ID</label>
        <type>AutoNumber</type>
    </nameField>
    <pluralLabel>Plan Designs</pluralLabel>
    <searchLayouts/>
    <sharingModel>ReadWrite</sharingModel>
    <visibility>Public</visibility>
</CustomObject>
```

## Field Templates

### Text Field
```xml
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>Plan_Name__c</fullName>
    <label>Plan Name</label>
    <type>Text</type>
    <length>255</length>
    <required>true</required>
    <unique>false</unique>
    <externalId>false</externalId>
    <description>Display name of the dental plan design</description>
    <inlineHelpText>e.g., Deluxe 100, Advantage 200, Core 201, DeltaCare 11A</inlineHelpText>
</CustomField>
```

### Picklist Field
```xml
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>Plan_Family__c</fullName>
    <label>Plan Family</label>
    <type>Picklist</type>
    <required>true</required>
    <description>Product family grouping for the plan</description>
    <valueSet>
        <restricted>true</restricted>
        <valueSetDefinition>
            <sorted>false</sorted>
            <value><fullName>PPO Deluxe</fullName><default>false</default><label>PPO Deluxe</label></value>
            <value><fullName>PPO Advantage</fullName><default>false</default><label>PPO Advantage</label></value>
            <value><fullName>PPO Core</fullName><default>false</default><label>PPO Core</label></value>
            <value><fullName>DeltaCare USA</fullName><default>false</default><label>DeltaCare USA</label></value>
            <value><fullName>Dual Choice</fullName><default>false</default><label>Dual Choice</label></value>
            <value><fullName>Core Buy-Up</fullName><default>false</default><label>Core Buy-Up</label></value>
            <value><fullName>Pediatric</fullName><default>false</default><label>Pediatric</label></value>
        </valueSetDefinition>
    </valueSet>
</CustomField>
```

### Currency Field
```xml
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>Deductible_Individual__c</fullName>
    <label>Individual Deductible</label>
    <type>Currency</type>
    <precision>18</precision>
    <scale>2</scale>
    <required>false</required>
    <description>Annual individual deductible amount</description>
    <inlineHelpText>Standard: $50 (adult) or $75 (pediatric). $0 for DHMO plans.</inlineHelpText>
</CustomField>
```

### Percent Field
```xml
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>DnP_Coinsurance_PPO__c</fullName>
    <label>D&amp;P Coinsurance (PPO)</label>
    <type>Percent</type>
    <precision>5</precision>
    <scale>0</scale>
    <required>false</required>
    <description>Plan pays percentage for Diagnostic and Preventive services at PPO dentists</description>
</CustomField>
```

### Lookup Field
```xml
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>Plan_Design__c</fullName>
    <label>Plan Design</label>
    <type>Lookup</type>
    <referenceTo>DD_Plan_Design__c</referenceTo>
    <relationshipLabel>Annual Max Options</relationshipLabel>
    <relationshipName>Annual_Max_Options</relationshipName>
    <required>false</required>
    <description>Parent plan design this option belongs to</description>
</CustomField>
```

### Master-Detail Field
```xml
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>Claim__c</fullName>
    <label>Claim</label>
    <type>MasterDetail</type>
    <referenceTo>DD_Claim__c</referenceTo>
    <relationshipLabel>Claim Lines</relationshipLabel>
    <relationshipName>Claim_Lines</relationshipName>
    <relationshipOrder>0</relationshipOrder>
    <reparentableMasterDetail>false</reparentableMasterDetail>
    <writeRequiresMasterRead>false</writeRequiresMasterRead>
    <description>Parent claim record</description>
</CustomField>
```

### Checkbox Field
```xml
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>Is_Active__c</fullName>
    <label>Active</label>
    <type>Checkbox</type>
    <defaultValue>true</defaultValue>
    <description>Whether this plan design is currently active and available for quoting</description>
</CustomField>
```

### Formula Field
```xml
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>Age_Out_Date__c</fullName>
    <label>Age-Out Date</label>
    <type>Date</type>
    <formula>DATE(YEAR(DOB__c) + 26, MONTH(DOB__c), 1) - 1</formula>
    <formulaTreatBlanksAs>BlankAsZero</formulaTreatBlanksAs>
    <description>Last day of month when dependent turns 26</description>
</CustomField>
```

## Naming Conventions
- Object API names: `DD_{EntityName}__c` (prefix DD_ for Delta Dental namespace)
- Field API names: `{FieldName}__c` (PascalCase with underscores)
- Relationship names: `{Related_Object_Plural}` (e.g., `Claim_Lines`)
- Auto-number format: Object-specific prefix (PD- for Plan Design, CL- for Claim, EN- for Enrollment)

## Validation Rule Template
```xml
<?xml version="1.0" encoding="UTF-8"?>
<ValidationRule xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>Require_Valid_Coinsurance</fullName>
    <active>true</active>
    <description>Coinsurance values must be between 0 and 100</description>
    <errorConditionFormula>DnP_Coinsurance_PPO__c &lt; 0 || DnP_Coinsurance_PPO__c &gt; 100</errorConditionFormula>
    <errorDisplayField>DnP_Coinsurance_PPO__c</errorDisplayField>
    <errorMessage>Coinsurance must be between 0% and 100%.</errorMessage>
</ValidationRule>
```

## Standard Object Extensions
When extending Account, Opportunity, Quote, etc., place field XMLs in:
```
force-app/main/default/objects/Account/fields/SIC_Code__c.field-meta.xml
force-app/main/default/objects/Opportunity/fields/Quote_Type__c.field-meta.xml
force-app/main/default/objects/Quote/fields/UW_Status__c.field-meta.xml
```
Do NOT create a new `.object-meta.xml` for standard objects — only add fields, validation rules, etc.
