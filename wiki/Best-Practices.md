This guide outlines essential best practices for working effectively with the async actions framework.

## Processor Implementation

### Action Status Management

Make sure each action results in one of these two outcomes. Failure to do so will cause actions to stay stuck in 'Pending' status.

-   **Success**: `action.Status__c = 'Completed'`
-   **Failed**: Use `AsyncActions.Failure` class to mark failed actions

### DML Operations

Use `allOrNone=false` in DML operations and mark corresponding actions as failed, instead of bulk failing all actions:

```apex
Database.SaveResult[] results = Database.update(recordsToUpdate, false);
for (Integer i = 0; i < results.size(); i++) {
    if (!results[i].isSuccess()) {
        AsyncAction__c failedAction = actions[i];
        new AsyncActions.Failure(settings).fail(new List<AsyncAction__c>{failedAction},
            new DmlException('Update failed: ' + results[i].getErrors()));
    } else {
        actions[i].Status__c = 'Completed';
    }
}
```

## User Context Considerations

Remember user context (Automated Process user). Your processors run under the system context of the Automated Process user, which may have different permissions and field access than the original user who triggered the action.

## Performance Optimization

### Batch Size Tuning

Performance-tune your batch sizes to the context of each action. For example, an action making callouts for each record would have a max of 100, to avoid per-transaction callout limits.

### Data Context

Use the `RelatedRecordId__c` and `Data__c` fields to provide context for your action:

```apex
// When creating actions
String customData = JSON.serialize(new Map<String, Object>{
    'priority' => 'high',
    'additionalInfo' => 'special processing required'
});
AsyncAction__c action = AsyncActions.initAction(settings, recordId, customData);
```

## Error Handling

Use `Retries__c` and the `RetryBehavior` enum to customize your error handling:

```apex
try {
    processAction(action);
    action.Status__c = 'Completed';
} catch (Exception e) {
    new AsyncActions.Failure(settings, AsyncActions.RetryBehavior.ALLOW_RETRY)
        .fail(actions, e);
}
```

## See Also

-   [Error Handling and Retry Logic](./Error-Handling-and-Retry-Logic) - Comprehensive error handling patterns
-   [Core Concepts](./Core-Concepts) - Framework architecture overview
-   [Creating Your First Processor](./Creating-Your-First-Processor) - Implementation guide
