The `AsyncActions.Failure` inner class provides standardized error handling and retry logic for async action processors.

## Overview

The `Failure` class encapsulates error handling patterns and retry behaviors for failed async actions. It provides methods to mark actions as failed while respecting configured retry policies.

## Methods

### fail(AsyncActionProcessor**mdt settings, List<AsyncAction**c> actions, Exception error)

Marks the provided async actions as failed and handles retry logic according to the processor configuration.

**Parameters:**

-   `settings` - The processor configuration containing retry behavior
-   `actions` - List of actions that failed during processing
-   `error` - The exception that caused the failure

**Usage:**

```apex
try {
    // Processing logic that might fail
    processRecords(actions);
} catch (Exception e) {
    new AsyncActions.Failure(settings).fail(actions, e);
    return;
}
```

## Retry Behaviors

The Failure class respects the `RetryBehavior__c` field from the processor configuration:

-   **ALLOW_RETRY** - Increments retry count and reschedules if under limit
-   **KEEP_ALIVE** - Marks as failed but keeps record for manual intervention
-   **SUDDEN_DEATH** - Marks as permanently failed, no retries

## Error Logging

All failures are automatically logged through the framework's logging system, including:

-   Exception message and stack trace
-   Action IDs and related record information
-   Processor configuration details
-   Retry attempt information

## See Also

-   [AsyncActions Class](./AsyncActions-Class) - Parent class documentation
-   [Error Handling & Retry Logic](./Error-Handling-and-Retry-Logic) - Comprehensive retry patterns
