The `AsyncActions.Status` enum defines the available status values for async action lifecycle management.

## Overview

This enum provides standardized status values used throughout the async actions framework to track the processing state of actions.

## Enum Values

### PENDING

Initial status when an async action is created but not yet processed.

**Characteristics:**

-   Default status for new actions
-   Indicates action is queued for processing
-   Triggers processing when conditions are met

### IN_PROGRESS

Status set when an action is currently being processed.

**Characteristics:**

-   Prevents duplicate processing
-   Indicates active processing state
-   Temporary status during execution

### COMPLETED

Status set when an action has been successfully processed.

**Characteristics:**

-   Final success status
-   No further processing required
-   Audit trail for completed work

### FAILED

Status set when an action has failed and cannot be retried.

**Characteristics:**

-   Final failure status
-   Error details logged
-   Requires manual intervention

### RETRY

Status set when an action has failed but will be retried.

**Characteristics:**

-   Temporary failure status
-   Will be reprocessed automatically
-   Retry count tracked separately

## Usage in Processors

```apex
// Setting status during processing
for (AsyncAction__c action : actions) {
    action.Status__c = AsyncActions.Status.IN_PROGRESS.name();

    try {
        // Process the action
        processAction(action);
        action.Status__c = AsyncActions.Status.COMPLETED.name();
    } catch (Exception e) {
        action.Status__c = AsyncActions.Status.FAILED.name();
    }
}
```

## Status Transitions

Valid status transitions:

-   PENDING → IN_PROGRESS
-   IN_PROGRESS → COMPLETED
-   IN_PROGRESS → FAILED
-   IN_PROGRESS → RETRY
-   RETRY → IN_PROGRESS
-   RETRY → FAILED

## Querying by Status

```apex
// Find pending actions
List<AsyncAction__c> pendingActions = [
    SELECT Id, Status__c
    FROM AsyncAction__c
    WHERE Status__c = :AsyncActions.Status.PENDING.name()
];

// Find failed actions needing attention
List<AsyncAction__c> failedActions = [
    SELECT Id, Status__c, ErrorMessage__c
    FROM AsyncAction__c
    WHERE Status__c = :AsyncActions.Status.FAILED.name()
];
```

## See Also

-   [AsyncActions Class](./AsyncActions-Class) - Parent class documentation
-   [AsyncAction Custom Object](./AsyncAction-Custom-Object) - Status field details
