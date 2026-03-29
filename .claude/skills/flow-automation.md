# Skill: Salesforce Flow Automation

## When to Use
Use this skill when creating Flow metadata in `force-app/main/default/flows/`.

## Flow Catalog for DD Platform

| Flow Name | Type | Trigger | Purpose |
|-----------|------|---------|---------|
| DD_Quote_Rating_Engine | Autolaunched | Called from LWC/Screen Flow | Executes rating service for a quote |
| DD_SIC_Eligibility_Check | Record-Triggered (Before) | Account.SIC_Code__c change | Validates SIC eligibility, sets rate level |
| DD_Enrollment_Processor | Record-Triggered (After Insert) | DD_Enrollment__c created | Validates eligibility, applies waiting periods |
| DD_Dependent_Age_Out | Scheduled (Daily) | Midnight CT | Terminates dependents aging out at 26 |
| DD_Renewal_Generator | Scheduled (90 days before anniversary) | Daily 2 AM | Creates renewal opportunity and quote |
| DD_Billing_Generator | Scheduled (Monthly) | 1st of month | Generates monthly billing statements |
| DD_Claim_Auto_Adjudicate | Record-Triggered (After Insert) | DD_Claim__c.Status = Received | Executes adjudication pipeline |
| DD_COBRA_Notification | Record-Triggered (After Update) | Employment termination | Generates COBRA election notice |
| DD_Welcome_Kit | Record-Triggered (After Update) | DD_Policy__c.Status = Active | Sends welcome packets |
| DD_Quote_Approval | Approval Process | Quote submitted | Routes through UW approval matrix |

## Flow Metadata XML Template (Autolaunched)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Flow xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>62.0</apiVersion>
    <description>Executes the rating engine for a Delta Dental quote</description>
    <interviewLabel>DD Quote Rating Engine {!$Flow.CurrentDateTime}</interviewLabel>
    <label>DD Quote Rating Engine</label>
    <processMetadataValues>
        <name>BuilderType</name>
        <value><stringValue>LightningFlowBuilder</stringValue></value>
    </processMetadataValues>
    <processType>AutoLaunchedFlow</processType>
    <runInMode>SystemModeWithoutSharing</runInMode>
    <start>
        <locationX>50</locationX>
        <locationY>0</locationY>
        <connector>
            <targetReference>Invoke_Rating_Engine</targetReference>
        </connector>
    </start>
    <status>Active</status>
    <!-- Variables, Actions, Decisions follow -->
</Flow>
```

## Record-Triggered Flow Template

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Flow xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>62.0</apiVersion>
    <description>Validates enrollment eligibility and applies waiting period rules</description>
    <label>DD Enrollment Processor</label>
    <processType>AutoLaunchedFlow</processType>
    <start>
        <locationX>50</locationX>
        <locationY>0</locationY>
        <object>DD_Enrollment__c</object>
        <recordTriggerType>Create</recordTriggerType>
        <triggerType>RecordAfterSave</triggerType>
        <connector>
            <targetReference>Check_Eligibility</targetReference>
        </connector>
    </start>
    <status>Active</status>
</Flow>
```

## Scheduled Flow Template

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Flow xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>62.0</apiVersion>
    <description>Scans for dependents aging out at 26 and terminates coverage</description>
    <label>DD Dependent Age Out</label>
    <processType>AutoLaunchedFlow</processType>
    <start>
        <locationX>50</locationX>
        <locationY>0</locationY>
        <scheduledPaths>
            <name>Daily_Run</name>
            <connector>
                <targetReference>Get_Aging_Out_Dependents</targetReference>
            </connector>
            <label>Daily Run</label>
            <offsetNumber>0</offsetNumber>
            <offsetUnit>Days</offsetUnit>
            <timeSource>RecordField</timeSource>
        </scheduledPaths>
    </start>
    <status>Active</status>
</Flow>
```

## Best Practices

1. **Prefer Apex Invocable Actions** over complex flow logic for business rules
2. **Use Invocable Methods** with `@InvocableMethod` for flow-callable Apex
3. **One trigger flow per object per timing** (Before Insert, After Insert, etc.)
4. **Use subflows** to keep flows manageable (< 50 elements per flow)
5. **Always include fault paths** for error handling
6. **Use custom labels** for all user-facing text in screen flows

## Invocable Method Pattern

```apex
/**
 * @description Flow-callable action to execute the rating engine
 */
public with sharing class DDRatingEngineAction {

    @InvocableMethod(
        label='Calculate Group Rate'
        description='Executes the DD rating engine for a quote'
        category='Delta Dental'
    )
    public static List<DDRatingResult> calculateRate(List<RatingRequest> requests) {
        List<DDRatingResult> results = new List<DDRatingResult>();
        for (RatingRequest req : requests) {
            results.add(DDRatingEngineService.calculateGroupRate(req.quoteId));
        }
        return results;
    }

    public class RatingRequest {
        @InvocableVariable(required=true label='Quote ID')
        public Id quoteId;
    }
}
```
