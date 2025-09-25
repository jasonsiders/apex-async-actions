Comprehensive guide to error handling and retry logic patterns in the async actions framework.

## Overview

The framework handles errors in several layers. You should perform your own business logic/error handling within your processor class/flow. Uncaught exceptions will be handled automatically by the framework.

## Retry Behaviors

The framework provides the `AsyncActions.RetryBehavior` enum to control how failures are handled:

### ALLOW_RETRY

Automatically retries failed actions up to configured limits.

**Example:**

```apex
try {
    // Your business logic
    processAction(action);
    action.Status__c = 'Completed';
} catch (Exception e) {
    new AsyncActions.Failure(settings, AsyncActions.RetryBehavior.ALLOW_RETRY)
        .fail(actions, e);
}
```

### KEEP_ALIVE

Actions never fail permanently and continue retrying indefinitely.

**Example:**

```apex
try {
    // Your business logic
    processAction(action);
    action.Status__c = 'Completed';
} catch (Exception e) {
    new AsyncActions.Failure(settings, AsyncActions.RetryBehavior.KEEP_ALIVE)
        .fail(actions, e);
}
```

### SUDDEN_DEATH

Actions fail immediately with no retries.

**Example:**

```apex
try {
    // Your business logic
    processAction(action);
    action.Status__c = 'Completed';
} catch (SecurityException e) {
    // Immediately fail for security violations
    new AsyncActions.Failure(settings, AsyncActions.RetryBehavior.SUDDEN_DEATH)
        .fail(actions, e);
}
```

## See Also

-   [AsyncActions.RetryBehavior Enum](./AsyncActions.RetryBehavior-Enum) - Detailed retry behavior documentation
-   [AsyncActions.Failure Class](./AsyncActions.Failure-Class) - Error handling implementation
-   [Best Practices](./Best-Practices) - Framework best practices
