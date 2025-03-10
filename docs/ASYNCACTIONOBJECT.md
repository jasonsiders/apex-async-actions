# The `AsyncAction__c` Custom Object

Records of this object represent an request to be processed by the framework. The `AsyncActionProcessor__mdt` responsible for processing an action is listed in the `ProcessorName__c` field.

The record's primary function is to track the status of asynchronous requests to the framework. Async Action records are always created in _Pending_ Status, but throughout its lifecycle these records may be retried a number of times, before being _Completed_ or _Failed_. They can also be manually _Canceled_ in the UI.

An `AsyncActionJob` will only run if there are `AsyncAction__c` records with a matching `ProcessorName__c`, with a `Status__c` of _Pending_, and a `NextEligibleAt__c` value in the past.

## Creating Async Actions

The `AsyncActions` class includes methods which let you easily create an Async Action for the given processor class:

#### `initAction(AsyncActionProcessor__mdt settings, [Id relatedRecordId], [String data])`

-   `settings`: (Required) The `AsyncActionProcessor__mdt` responsible for processing the current action.
-   `relatedRecordId`: (Optional) The Id of the record to store in the `RelatedRecordId__c` field
-   `data`: (Optional) A serialized data structure to store in the `Data__c` field. If this value is not provided, will default to `null`.

## Providing Context to Processors

The Async Action record can also be used to store contextual information about a specific request. How this information is used may vary depending on the processor class.

Developers can use the `RelatedRecordId__c` field to link the Async Action to any SObject record. For example, they may use it to store an `Account` Id, and use an `AsyncActionJob` class to create Opportunity for those Accounts:

```java
public void process(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions) {
    List<Opportunity> opps = new List<Opportunity>();
    for (AsyncAction__c action : actions) {
        Id accountId = (Id) action?.RelatedRecordId__c;
        Opportunity opp = new Opportunity(AccountId = accountId);
        // Other details omitted for brevity
        opps?.add(opp);
        // Success!
        action.Status__c = 'Completed';
    }
    insert opps;
}
```

Developers can also use the `Data__c` field to store custom data structures that give granular detail about a request. What this data structure looks like, and how it is used is up to you, and able to be customized on a per-class basis. To use a similar example from above:

```java
public void process(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions) {
    List<Opportunity> opps = new List<Opportunity>();
    for (AsyncAction__c action : actions) {
        // Deserialize the Data__c field into its expected form
        // OppInfo - custom wrapper class, details omitted for brevity
        OppInfo oppInfo = (OppInfo) JSON.deserialize(action?.Data__c, OppInfo.class);
        // Create an Opportunity
        Id accountId = (Id) action?.RelatedRecordId__c;
        Opportunity opp = new Opportunity(AccountId = accountId);
        opp.Amount = oppInfo?.amount;
        opp.RecordTypeId = oppInfo?.recordTypeId;
        opp.Status = oppInfo?.status;
        opps?.add(opp);
        // Success!
        action.Status__c = 'Completed';
    }
    insert opps;
}
```

## Fields

![The Async Action Custom Object](/media/sample_async_action.png)

-   **Data** (Text): A serialized custom data structure used to provide additional context about the action to be used by the processor class. Its use may vary. See [Providing Context to Processors](#providing-context-to-processors) for more.
-   **Error** (Text): Details about the last error that the Action encountered, if any.
-   **Next Eligible At**: The Date/Time that the action is eligible to be processed. The framework will only process records that have a _Next Eligible At_ value in the past.
-   **Processor Name**: The `DeveloperName` of a `AsyncActionProcessor__mdt` record which is responsible for processing the current Async Action record.
-   **Related Record** and **Related Record Id**: `RelatedRecordId__c` stores the Id of a Salesforce record which is closely related to the request. `RelatedRecord__c` is a read-only formula field which displays a link to the record in question, for use in the UI.
-   **Retries**: Indicates the number of times that the record may be retried, if allowed. If a record has 0 retries, any failures to that record will cause the Status to change to _Failed_. This does not apply to custom [error handling](/docs/ASYNCACTIONPROCESSOR.md#error-handling).
-   **Status**: Indicates the status of the current request. Possible values include `Pending`, `Completed`, `Failed`, or `Canceled`. The framework will only process records that are _Pending_.
