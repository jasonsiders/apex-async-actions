The `AsyncActions.RetryBehavior` enum defines the available retry strategies for failed async actions. Use this enum in conjunction with the [AsyncActions.Failure Class](./The-AsyncActions.Failure-Class).

```apex
try {
    // Processing logic
    processActions(actions);
} catch (Exception e) {
    // Use specific retry behavior
    new AsyncActions.Failure(settings, AsyncActions.RetryBehavior.ALLOW_RETRY)
        .fail(actions, e);
}
```

## Values

| Value          | Description                                                                                                                                                                                                                                                              |
| -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `ALLOW_RETRY`  | Allows the action to be retried according to the processor's retry configuration. Decrements the retry count on the Async Action record. Once a record has 0 retries remaining, a failure with ALLOW_RETRY will result in the record's status being updated to 'Failed'. |
| `KEEP_ALIVE`   | The retries won't be decremented, and the record will remain in 'Pending' status indefinitely. Exercise caution when using this option, as it could lead to actions perpetually remaining open.                                                                          |
| `SUDDEN_DEATH` | Immediately marks the action as permanently failed with no retry attempts.                                                                                                                                                                                               |
