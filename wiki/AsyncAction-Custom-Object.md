The `AsyncAction__c` object is the cornerstone of the async actions framework. Each record represents an individual work item to be processed asynchronously by the framework.

## Overview

AsyncAction records serve as both the request and the audit trail for asynchronous operations. They track the status of requests throughout their lifecycle and provide context information to processor implementations.

## Purpose and Usage

The primary functions of AsyncAction records are:

1. **Work Queue Management** - Represent individual tasks waiting to be processed
2. **Context Storage** - Carry data and relationships needed by processors
3. **Status Tracking** - Monitor the progress of asynchronous operations
4. **Error Management** - Store error details and support retry logic
5. **Audit Trail** - Maintain a historical record of all async operations

## Lifecycle

Every AsyncAction follows a predictable lifecycle:

1. **Creation** - Record is created with "Pending" status
2. **Processing** - Framework queries eligible records and processes them
3. **Completion** - Record ends in one of four final states:
    - **Completed** - Successfully processed
    - **Failed** - Permanently failed (no retries remaining)
    - **Canceled** - Manually canceled
    - **Pending** - Still awaiting processing or retry

## Creating AsyncAction Records

While you can create AsyncAction records manually, the recommended approach is using the framework's utility methods:

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

-   **Init Async Action** - Creates new AsyncAction records
-   **Handle Async Action Failures** - Manages error scenarios

## Field Reference

| Field API Name       | Label               | Data Type      | Required | Description                                                                    | Details                                               |
| -------------------- | ------------------- | -------------- | -------- | ------------------------------------------------------------------------------ | ----------------------------------------------------- |
| `Name`               | Async Action Number | Auto Number    | Yes      | System-generated unique identifier (ASYNC-{00000000})                          | Read-only system field                                |
| `ProcessorName__c`   | Processor Name      | Text(255)      | Yes      | DeveloperName of the AsyncActionProcessor\_\_mdt that will process this record | Must match active processor metadata; case-sensitive  |
| `Status__c`          | Status              | Picklist       | Yes      | Current processing status (Pending, Completed, Failed, Canceled)               | Controlled picklist values                            |
| `RelatedRecordId__c` | Related Record Id   | Text(18)       | No       | Id of any Salesforce record related to this action                             | Can be any 15 or 18-character Salesforce Id           |
| `RelatedRecord__c`   | Related Record      | Formula        | No       | Read-only hyperlink to the related record for UI display                       | Automatically populated based on RelatedRecordId\_\_c |
| `Data__c`            | Data                | Long Text Area | No       | Custom data structure (usually JSON) for processor context                     | Store serialized data; keep under 128KB               |
| `Error__c`           | Error               | Long Text Area | No       | Details about the most recent error, if any                                    | Populated automatically by framework on failures      |
| `Retries__c`         | Retries             | Number(18,0)   | No       | Number of retry attempts remaining before permanent failure                    | Decremented on each retry attempt                     |
| `NextEligibleAt__c`  | Next Eligible At    | DateTime       | Yes      | When this action becomes eligible for processing                               | Controls retry timing; set by framework               |

## Querying AsyncAction Records

### Common Query Patterns

```apex
// Find all pending actions for a specific processor
List<AsyncAction__c> pendingActions = [
    SELECT Id, ProcessorName__c, RelatedRecordId__c, Data__c
    FROM AsyncAction__c
    WHERE Status__c = 'Pending'
      AND ProcessorName__c = 'My_Processor'
];

// Find actions related to specific records
List<AsyncAction__c> relatedActions = [
    SELECT Id, Status__c, Error__c, CreatedDate
    FROM AsyncAction__c
    WHERE RelatedRecordId__c IN :recordIds
];

// Find recent failed actions for troubleshooting
List<AsyncAction__c> failedActions = [
    SELECT Id, ProcessorName__c, Error__c, RelatedRecordId__c
    FROM AsyncAction__c
    WHERE Status__c = 'Failed'
      AND CreatedDate >= LAST_N_DAYS:7
];
```

## Related Components

-   [AsyncActionProcessor Custom Metadata Type](./AsyncActionProcessor-Custom-Metadata-Type) - Processor configuration
-   [AsyncActions Class](./AsyncActions-Class) - Framework utilities
-   [Monitoring and Troubleshooting](./Monitoring-and-Troubleshooting) - Operations guide

## See Also

-   [Creating Your First Processor](./Creating-Your-First-Processor) - Implementation tutorial
-   [Core Concepts](./Core-Concepts) - Framework architecture overview
