The `AsyncAction__c` object is the cornerstone of the async actions framework. Each record represents an individual work item to be processed asynchronously by the framework.

Async Action records serve as both the request and the audit trail for asynchronous operations. They track the status of requests throughout their lifecycle and provide context information to processor implementations.

## Purpose and Usage

The primary functions of Async Action records are:

1. **Work Queue Management** - Represent individual tasks waiting to be processed
2. **Context Storage** - Carry data and relationships needed by processors
3. **Status Tracking** - Monitor the progress of asynchronous operations
4. **Error Management** - Store error details and support retry logic
5. **Audit Trail** - Maintain a historical record of all async operations

## Lifecycle

Every Async Action follows a predictable lifecycle:

1. **Creation** - Record is created with "Pending" status
2. **Processing** - Framework queries eligible records and processes them
3. **Completion** - Record ends in one of four final states:
    - **Completed** - Successfully processed
    - **Failed** - Permanently failed (no retries remaining)
    - **Canceled** - Manually canceled
    - **Pending** - Still awaiting processing or retry

## Creating Async Action Records

While you can create Async Action records manually, the recommended approach is using the framework's utility methods:

### Using AsyncActions.initAction()

```apex
// Basic usage
AsyncActionProcessor__mdt settings = AsyncActionProcessor__mdt.getInstance('My_Processor');
AsyncAction__c action = AsyncActions.initAction(settings, recordId, jsonData);
insert action;

// Available overloads
AsyncActions.initAction(settings, recordId, data)      // Full parameters
AsyncActions.initAction(settings, record, data)       // SObject instead of Id
AsyncActions.initAction(settings, recordId)           // No custom data
AsyncActions.initAction(settings, record)             // SObject, no data
AsyncActions.initAction(settings)                     // No related record or data
```

### Using Invocable Actions

The framework includes Flow-compatible invocable actions:

-   **Init Async Action** - Creates new Async Action records
-   **Handle Async Action Failures** - Manages error scenarios

## Field Reference

| Field API Name       | Label               | Data Type      | Required | Description                                                                    |
| -------------------- | ------------------- | -------------- | -------- | ------------------------------------------------------------------------------ |
| `Name`               | Async Action Number | Auto Number    | Yes      | System-generated unique identifier (ASYNC-{00000000})                          |
| `ProcessorName__c`   | Processor Name      | Text(255)      | Yes      | DeveloperName of the AsyncActionProcessor\_\_mdt that will process this record |
| `Status__c`          | Status              | Picklist       | Yes      | Current processing status (Pending, Completed, Failed, Canceled)               |
| `RelatedRecordId__c` | Related Record Id   | Text(18)       | No       | Id of any Salesforce record related to this action                             |
| `RelatedRecord__c`   | Related Record      | Formula        | No       | Read-only hyperlink to the related record for UI display                       |
| `Data__c`            | Data                | Long Text Area | No       | Custom data structure (usually JSON) for processor context                     |
| `Error__c`           | Error               | Long Text Area | No       | Details about the most recent error, if any                                    |
| `Retries__c`         | Retries             | Number(18,0)   | No       | Number of retry attempts remaining before permanent failure                    |
| `NextEligibleAt__c`  | Next Eligible At    | DateTime       | Yes      | When this action becomes eligible for processing                               |
