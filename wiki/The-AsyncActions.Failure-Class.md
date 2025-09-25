The `AsyncActions.Failure` inner class provides standardized error handling and retry logic for async action processors.

## Constructors

### `Failure(AsyncActionProcessor__mdt settings, AsyncActions.RetryBehavior behavior)`

Creates a new Failure handler with specific processor settings and retry behavior.

**Parameters:**

-   `settings` - The processor configuration metadata
-   `behavior` - The retry behavior to apply when handling failures

### `Failure(AsyncActionProcessor__mdt settings)`

Creates a new Failure handler with specific processor settings and default ALLOW_RETRY behavior.

**Parameters:**

-   `settings` - The processor configuration metadata

## Methods

### `fail`

Marks the provided async actions as failed and handles retry logic according to the specified retry behavior. All failures are automatically logged through the framework's logging system.

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

The Failure class works with the [AsyncActions.RetryBehavior](./The-AsyncActions.RetryBehavior-Enum) enum:

| Behavior       | Description                                              |
| -------------- | -------------------------------------------------------- |
| `ALLOW_RETRY`  | Decrements retry count and reschedules if retries remain |
| `KEEP_ALIVE`   | Keeps actions in pending status for indefinite retries   |
| `SUDDEN_DEATH` | Marks as permanently failed, no retries                  |
