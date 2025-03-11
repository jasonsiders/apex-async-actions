# The `AsyncActions.Processor` Interface

This interface defines the logic to be performed inside of an `AsyncActionJob` queueable.

The interface has just one method:

```java
void process(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions)
```

This method should contain the main processing logic for your Async Action. The framework provides you with the `AsyncActionProcessor__mdt` configuration record that drives the process, as well as the current batch of `AsyncAction__c` records to process.

Implementers are expected to do the following inside of this method:

1. Perform your desired operation against the given records.
2. If the operation succeeds, set the `AsyncAction__c.Status__c` to "Completed"
3. To handle any failures, pass the corresponding `AsyncAction__c` records to the `AsyncActions.Failure` class's `fail` method. See [**Error Handling**](#error-handling) for more information.

:rotating_light: **IMPORTANT:** In addition to implementing the interface method, callers are expected to expose a public, 0-argument constructor. The framework needs this to be able to dynamically construct the instance, using `Type.forName`.

Example:

```java
public class MyProcessor implements AsyncActions.Processor {
    ...
    public void process(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions) {
        // For each Async Action, log a task against each Account
        List<Task> tasks = new List<Task>();
        for (AsyncAction__c action : actions) {
            Id accountId = (Id) action?.RelatedRecordId__c;
            Task task = new Task(WhatId = accountId, ...);
            tasks?.add(task);
        }
        // Insert the tasks and inspect the results
        List<Database.SaveResult> results = Database.insert(tasks, false);
        for (Integer i = 0; i < results?.size(); i++) {
            AsyncAction__c action = actions?.get(i);
            Database.SaveResult result = results?.get(i);
            if (result?.isSuccess() == false) {
                // Error - process the failure
                Database.Error error = result?.getErrors()?.get(0);
                new AsyncActions.Failure(settings)?.fail(action, error);
            } else {
                // Success! Mark as completed
                action.Status__c = AsyncActionJob.Status.COMPLETED.name();
            }
        }
        // The framework will automatically update the actions
        // no need to use "update actions;" here
    }
}
```

## Error Handling

The framework will handle any uncaught errors that happen during the `process()` method, by marking all `AsyncAction__c` records in the transaction is _"Failed"_, unless it can be retried. But what if you want to only fail a portion of the `AsyncAction__c` records, or customize the error behavior?

For this, you will need to use the `AsyncActions.Failure` class in your implementation:

### The `AsyncActions.Failure` Class

This class is responsible for handling errors, according to the defined retry behavior for a given action, as well as the needs of the processor itself.

Start by generating an `AsyncActions.Failure` object. The constructor accepts these parameters:

-   `AsyncActionProcessor__mdt`: (Required) The current processor settings object.
-   `AsyncActions.RetryBehavior`: (Optional) Enumerates how any errors will be handled. Values:
    -   `ALLOW_RETRY` (default): Actions will be retried, until their _Retries_ value is 0. Then, their _Status_ will be set to "Failed".
    -   `KEEP_ALIVE`: Actions will never be marked as failed; they will remain in "Pending" _Status_. Exercise caution when using this behavior.
    -   `SUDDEN_DEATH`: Actions will be marked as "Failed", regardless of the number of _Retries_ remaining.

Once the object is created, use the `fail` method to mark specific record(s) as failed for a specific reason. The `fail` method accepts these parameters:

-   `List<AsyncAction__c>` or `AsyncAction__c`: The record(s) to be marked as failed
-   `Object error`: The error message responsible for the failure.

Examples:

```java
public void process(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions) {
    try {
        HttpRequest request = this.buildRequest();
        HttpResponse response = new Http().send(request);
        ...
    } catch (System.CalloutException error) {
        // Mark all actions as instant-fail!
        new AsyncActions.Failure(settings, AsyncActions.RetryBehavior.SUDDEN_DEATH)?.fail(actions, error);
    }
}
```

```java
public void process(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions) {
    List<Account> accounts = this.getAccounts(actions);
    List<Database.SaveResult> saveResults = Database.insert(accounts, false);
    for (Integer i = 0; i < saveResults?.size(); i++) {
        if (saveResult?.isSuccess() == false) {
            AsyncAction__c action = actions?.get(i);
            List<Database.Error> errors = saveResult?.getErrors();
            new AsyncActions.Failure(settings)?.fail(action, errors);
        }
    }
}
```

More examples can be found in the [`/example-app`](/example-app/) directory.

### The `Handle Async Action Failures` Invocable Method

This invocable method exposes the same [`AsyncActions.Failure`](#the-asyncactionsfailure-class) class logic to flows.

The invocable accepts the following inputs:

-   `AsyncAction action`: (Required) The Async Action record to process.
-   `String developerName`: (Required) The DeveloperName of the `AsyncActionsProcessor__mdt` record responsible for processing the action.
-   `String errorMessage`: (Required) The error message/reason for failure. Ex., `{!$Flow.FaultMessage}`, or your own custom error.
-   `String retryBehaviorName`: (Optional) An `AsyncActions.RetryBehavior` enum value, and dictates how the method will handle errors. Defaults to "ALLOW_RETRY" if left blank.

## Best Practices

-   To avoid endless looping, remember to update each `AsyncAction__c` record with the results of the transaction. If the action succeeded, set the `Status__c` field to _"Completed"_. If the action failed, use the `AsyncActions.Failure` class to mark the action as failed. Read more about error handling [here](#error-handling).
-   Be careful when fetching `Id` values from `RelatedRecordId__c`, as well as custom data structures from `Data__c`. Always guard against unexpected inputs to avoid an unhandled exception.
