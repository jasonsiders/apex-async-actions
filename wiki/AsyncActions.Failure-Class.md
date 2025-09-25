The `AsyncActions.Failure` inner class provides standardized error handling and retry logic for async action processors.

## Overview

The `Failure` class encapsulates error handling patterns and retry behaviors for failed async actions. It provides methods to mark actions as failed while respecting configured retry policies.

## Methods

### `fail`

Marks the provided async actions as failed and handles retry logic according to the specified retry behavior.

**Parameters:**

-   `settings` - The processor configuration metadata
-   `actions` - List of actions that failed during processing
-   `error` - The exception that caused the failure

**Usage:**

```apex
try {
    // Processing logic that might fail
    processRecords(actions);
} catch (Exception e) {
    new AsyncActions.Failure(settings, AsyncActions.RetryBehavior.ALLOW_RETRY)
        .fail(actions, e);
    return;
}
```

## Retry Behaviors

The Failure class works with the `AsyncActions.RetryBehavior` enum:

-   **ALLOW_RETRY** - Decrements retry count and reschedules if retries remain
-   **KEEP_ALIVE** - Keeps actions in pending status for indefinite retries
-   **SUDDEN_DEATH** - Marks as permanently failed, no retries

## Error Logging

All failures are automatically logged through the framework's logging system. Only the supplied error message is logged along with basic action information.

## See Also

-   [AsyncActions Class](./AsyncActions-Class) - Parent class documentation
-   [Error Handling & Retry Logic](./Error-Handling-and-Retry-Logic) - Comprehensive retry patterns
