This guide outlines best practices for building robust, efficient async action processors. Following these patterns will help you create processors that are maintainable, performant, and resilient.

## Fundamental Requirements

### Always Complete or Fail Actions

Every action must end the transaction with either a completed status or be handled by the failure mechanism. Actions left without status updates will remain in 'Pending' status indefinitely.

```apex
public void process(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions) {
    // ❌ Bad - Action status never updated
    for (AsyncAction__c action : actions) {
        processBusinessLogic(action);
        // Missing status update - action stays pending forever!
    }

    // ✅ Good - Every action gets a final status
    for (AsyncAction__c action : actions) {
        try {
            processBusinessLogic(action);
            action.Status__c = AsyncActions.Status.COMPLETED.name();
        } catch (Exception error) {
            new AsyncActions.Failure(settings).fail(action, error);
        }
    }
}
```

### Action List Management

Avoid modifying the original `actions` List parameter, as this may interfere with the framework's error detection. Instead, work with a copy or Map.

```apex
public void process(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions) {
    // ❌ Bad - Modifying the original list
    actions.remove(0);
    actions.add(someNewAction);

    // ✅ Good - Work with a Map for processing
    Map<Id, AsyncAction__c> actionMap = new Map<Id, AsyncAction__c>(actions);
    for (AsyncAction__c action : actionMap.values()) {
        // If an action isn't relevant, mark as failed and remove from map:
        if (action?.RelatedRecordId__c == null) {
            actionMap?.remove(action?.Id);
            new AsyncActions.Failure(settings, AsyncActions.RetryBehavior.SUDDEN_DEATH)
                .fail(action, 'Missing RelatedRecordId__c');
        }
    }
    // Now process any remaining valid actions:
    this.processValidActions(actionMap);
}
```

## Data Handling

### Data Validation

Validate input data early and fail gracefully for invalid data.

```apex
public void process(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions) {
    List<AsyncAction__c> validActions = new List<AsyncAction__c>();
    List<AsyncAction__c> invalidActions = new List<AsyncAction__c>();

    for (AsyncAction__c action : actions) {
        if (action.RelatedRecordId__c == null) {
            invalidActions.add(action);
        } else {
            validActions.add(action);
        }
    }

    // Fail invalid actions immediately with SUDDEN_DEATH
    if (!invalidActions.isEmpty()) {
        new AsyncActions.Failure(settings, AsyncActions.RetryBehavior.SUDDEN_DEATH)
            .fail(invalidActions, 'Missing required RelatedRecordId');
    }

    // Process valid actions
    if (!validActions.isEmpty()) {
        processValidActions(validActions);
    }
}
```

### Custom Data Usage

When using the Data\_\_c field, validate and parse JSON data safely.

```apex
private Map<String, Object> parseActionData(AsyncAction__c action) {
    if (String.isBlank(action.Data__c)) {
        return new Map<String, Object>();
    }

    try {
        return (Map<String, Object>) JSON.deserializeUntyped(action.Data__c);
    } catch (Exception error) {
        // Handle invalid JSON gracefully
        return new Map<String, Object>();
    }
}
```

### Avoid Manual AsyncAction DML

The framework automatically handles Async Action record updates at the end of each batch. For this reason, you do not need to perform DML on these records.

```apex
public void process(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions) {
    // ❌ Bad - Manual DML on AsyncAction records
    update actions;

    // ✅ Good - Only DML on business records
    List<Task> tasksToInsert = this.generateTasksFromActions(actions);
    insert tasksToInsert;
}
```

## Error Handling

### Basic Error Handling

Use the framework's built-in failure handling for consistent retry behavior.

```apex
public void process(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions) {
    try {
        // Your business logic here
        processActions(actions);
        // Mark successful actions as completed
        for (AsyncAction__c action : actions) {
            action.Status__c = 'Completed';
        }
    } catch (Exception error) {
        // Let the framework handle retries
        new AsyncActions.Failure(settings, AsyncActions.RetryBehavior.ALLOW_RETRY)
            .fail(actions, error);
    }
}
```

### Partial Success Handling

Handle scenarios where some actions succeed and others fail within the same batch using `allOrNone=false` DML operations.

```apex
public void process(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions) {
    List<SObject> recordsToInsert = new List<SObject>();
    for (AsyncAction__c action : actions) {
        SObject record = this.createRecordForAction(action);
        recordsToInsert.add(record);
    }
    List<Database.SaveResult> results = Database.insert(recordsToInsert, false);
    for (Integer i = 0; i < results.size(); i++) {
        AsyncAction__c action = actions[i];
        Database.SaveResult result = results[i];
        if (result?.isSuccess() == true) {
            action.Status__c = 'Completed';
        } else {
            List<Database.Error> errors = result.getErrors();
            new AsyncActions.Failure(settings).fail(action, errors);
        }
    }
}
```
