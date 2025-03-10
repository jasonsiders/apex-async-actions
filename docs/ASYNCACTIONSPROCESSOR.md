# The `AsyncActions.Processor` Interface

## Requirements

Creating your own `AsyncAction.Processor` is easy, but you must follow these requirements:

-   Must extend `AsyncActionJob` and implement the [abstract methods](#abstract-methods). Else, the class will not compile.
-   Must be an outer class. The framework uses the `AsyncApexJob` object to check for existing/pending queueable jobs. Its `ApexClass` field always displays the name of the _outer_ type, even if the Queueable job is an inner type. The framework will behave unpredictably if you use an inner class to extend `AsyncActionJob`.
-   Must create a [`AsyncActionProcessor__mdt`](/docs/PROCESSORSETTINGS.md) configuration record with a corresponding `Processor__c` value. This value should equal the value of your class's `Type.getName()` value, including namespace (if it has one). Without a corresponding metadata record, the class will never be run.

## Abstract Methods

### `Type getType()`

Returns the `Type` of the current Apex Class. This is used to identify `AsyncAction__c` and `AsyncActionProcessor__mdt` records that correspond with the current class. Example:

```java
global class MyProcessor extends AsyncActionJob {
    ...
    global override Type myType() {
        return MyProcessor.class;
    }
}
```

### `void process(List<AsyncAction__c> actions)`

The main processing method. Perform whatever processing logic you require against the list of action records. Example:

```java
global class MyProcessor extends AsyncActionJob {
    ...
    global override void process(List<AsyncAction__c> actions) {
        List<Task> tasks = new List<Task>();
        for (AsyncAction__c action : actions) {
            // Log a task against each Account
            Id accountId = (Id) action?.RelatedRecordId__c;
            Task task = new Task(WhatId = accountId, ...);
            tasks?.add(task);
            // Update the action record
            action.Status__c = AsyncActionJob.Status.COMPLETED.name();
        }
        insert tasks;
        update actions;
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

### The `Handle Async Action Failures` Invocable Method

! TODO !

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

## Best Practices

-   To avoid endless looping, remember to update each `AsyncAction__c` record with the results of the transaction. If the action succeeded, set the `Status__c` field to _"Completed"_. If the action failed, use the `AsyncActions.Failure` class to mark the action as failed. Read more about error handling [here](#error-handling).
-   Do not attempt to launch `AsyncActionJob` classes on your own, via the `System.enqueueJob()` method or by other means. The Async Action Framework handles all of the launching internally. It includes checks against limits, custom metadata configuration, and more. Bypassing these checks can lead to unexpected results and potentially compromise the integrity of the framework. Instead, use the `AsyncActionProcessor__mdt` to dictate when and if a job is launched. If necessary, you can use the `AsyncActionLauncher` class's `launch` method to safely launch a processor on your own.
-   Be careful when fetching `Id` values from `RelatedRecordId__c`, as well as custom data structures from `Data__c`. Always guard against unexpected inputs to avoid an unhandled exception.
