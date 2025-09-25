The `AsyncActions.Failure` inner class provides standardized error handling and retry logic for async action processors.

## Constructors

Creates a new Failure handler with processor settings and retry behavior configuration. The single-parameter constructor uses default `ALLOW_RETRY` behavior.

-   `Failure(AsyncActionProcessor__mdt settings, AsyncActions.RetryBehavior behavior)`
-   `Failure(AsyncActionProcessor__mdt settings)`

## Methods

### `fail`

Marks the provided async actions as failed and handles retry logic according to the specified retry behavior.

-   `void fail(List<AsyncAction__c> actions, Object error)`
-   `void fail(AsyncAction__c action, Object error)`

All failures are automatically logged through the framework's logging system.

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

The Failure class works with the [AsyncActions.RetryBehavior](./The-AsyncActions.RetryBehavior-Enum) enum:

| Behavior       | Description                                              |
| -------------- | -------------------------------------------------------- |
| `ALLOW_RETRY`  | Decrements retry count and reschedules if retries remain |
| `KEEP_ALIVE`   | Keeps actions in pending status for indefinite retries   |
| `SUDDEN_DEATH` | Marks as permanently failed, no retries                  |
