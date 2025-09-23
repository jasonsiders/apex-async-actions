The `AsyncActions.RetryBehavior` enum defines the available retry strategies for failed async actions.

## Overview

This enum provides standardized retry behavior options that control how the framework handles failed async actions. The behavior is configured in the `AsyncActionProcessor__mdt` metadata.

## Enum Values

### ALLOW_RETRY

Allows the action to be retried according to the processor's retry configuration.

**Behavior:**

-   Increments the retry count
-   Reschedules processing if under the retry limit
-   Marks as failed if retry limit exceeded

**Use Cases:**

-   Temporary network issues
-   Transient system errors
-   Resource availability problems

### KEEP_ALIVE

Marks the action as failed but keeps it available for manual intervention.

**Behavior:**

-   Sets status to failed
-   Does not increment retry count
-   Preserves record for later processing

**Use Cases:**

-   Data validation errors requiring correction
-   Business rule violations needing review
-   Configuration issues requiring admin attention

### SUDDEN_DEATH

Immediately marks the action as permanently failed with no retry attempts.

**Behavior:**

-   Sets status to permanently failed
-   No further processing attempts
-   Logs error for audit purposes

**Use Cases:**

-   Permanent data corruption
-   Security violations
-   Unrecoverable system errors

## Usage in Processors

```apex
try {
    // Processing logic
    processActions(actions);
} catch (Exception e) {
    // The retry behavior is determined by processor configuration
    new AsyncActions.Failure(settings).fail(actions, e);
}
```

## Configuration

Set the retry behavior in your `AsyncActionProcessor__mdt` record:

```
RetryBehavior__c = 'ALLOW_RETRY'  // or 'KEEP_ALIVE' or 'SUDDEN_DEATH'
```

## See Also

-   [AsyncActions Class](./AsyncActions-Class) - Parent class documentation
-   [AsyncActions.Failure Class](./AsyncActions.Failure-Class) - Error handling implementation
-   [Error Handling & Retry Logic](./Error-Handling-and-Retry-Logic) - Comprehensive retry patterns
