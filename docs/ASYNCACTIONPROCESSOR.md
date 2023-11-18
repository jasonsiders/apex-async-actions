# The `AsyncActionProcessor` Class

This apex class represents some kind of action to be performed asynchronously, against a collection of [`AsyncAction__c`](/docs/ASYNCACTIONOBJECT.md) records.

## Process Overview

The abstract class handles the minutia of the framework, and leaves the actual actions to be processed up to the user to define, via the `process(List<AsyncAction__c> actions)` abstract method. Each time the `AsyncActionProcessor` Queueable is run, it follows this process:

1. Retrieves a `AsyncActionProcessor__mdt` configuration record with a matching `ProcessorClass__c` value, and checks if the configuration record's `Enabled__c` value. If this is not _true_, or a matching configuration record cannot found, then the job will abort.
2. Queries `AsyncAction__c` records with a matching `ProcessorClass__c` value, are in _Pending_ status, and have a `Scheduled__c` value in the past. Records are returned in order of its `Scheduled__c` value, prioritizing older records first. This query is limited by the configuration record's `BatchSize__c`.
3. The user-defined `process(List<AsyncAction__c> actions)` method runs.
4. Any logs incurred by the transaction to this point are committed.
5. The `System.Queueable` operation ceases. A `System.Finalizer` operation begins shortly after.
6. The finalizer checks if the Queueable job succeeded. If an unhandled exception was thrown, the finalizer logs the error and updates all `AsyncAction__c` records in the transaction to reflect the failure using `ALLOW_RETRY` logic.
7. The finalizer re-enqueues the current processor class if it has any remaining _Pending_ `AsyncAction__c` records with a `Scheduled__c` value in the past.

## Requirements

Creating your own `AsyncActionProcessor` is easy, but you must follow these requirements:

-   Must extend `AsyncActionProcessor` and implement the [abstract methods](#abstract-methods). Else, the class will not compile.
-   Must be an outer class. The framework uses the `AsyncApexJob` object to check for existing/pending queueable jobs. Its `ApexClass` field always displays the name of the _outer_ type, even if the Queueable job is an inner type. The framework will behave unpredictably if you use an inner class to extend `AsyncActionProcessor`.
-   Must create a [`AsyncActionProcessor__mdt`](/docs/PROCESSORSETTINGS.md) configuration record with a corresponding `ProcessorClass__c` value. This value should equal the value of your class's `Type.getName()` value, including namespace (if it has one). Without a corresponding metadata record, the class will never be run.

## Abstract Methods

### `Type getType()`

Returns the `Type` of the current Apex Class. This is used to identify `AsyncAction__c` and `AsyncActionProcessor__mdt` records that correspond with the current class. Example:

```java
global class MyProcessor extends AsyncActionProcessor {
    ...
    global override Type myType() {
        return MyProcessor.class;
    }
}
```

### `void process(List<AsyncAction__c> actions)`

The main processing method. Perform whatever processing logic you require against the list of action records. Example:

```java
global class MyProcessor extends AsyncActionProcessor {
    ...
    global override void process(List<AsyncAction__c> actions) {
        List<Task> tasks = new List<Task>();
        for (AsyncAction__c action : actions) {
            // Log a task against each Account
            Id accountId = (Id) action?.RelatedRecordId__c;
            Task task = new Task(WhatId = accountId, ...);
            tasks?.add(task);
            // Update the action record
            action.Status__c = AsyncActionProcessor.Status.COMPLETED.name();
        }
        insert tasks;
        update actions;
    }
}
```

## Error Handling

The framework will handle any uncaught errors that happen during the `process()` method, by marking all `AsyncAction__c` records in the transaction is _"Failed"_, unless it can be retried. But what if you want to only fail a portion of the `AsyncAction__c` records, or customize the error behavior?

For this, you will need to use the `fail()` method in your `process()` implementation:

#### fail(AsyncAction\_\_c> action(s), AsyncActionProcessor.RetryBehavior behavior, Object error)

-   `action(s)`: A `AsyncAction__c` or `List<AsyncAction__c>` record(s) which failed processing.
-   `behavior`: An enum value which dictates how the failures will be processed:
    -   `ALLOW_RETRY`: If the record has a positive `Retries__c` value, it will be decremented, and the record will remain in _Pending_ Status, and the record will be rescheduled X mins in the future, according to the `AsyncActionProcessor__mdt.RetryInterval__c`. However, if the record does **not** have a positive `Retries__c` value, its Status will be updated to _Failed_, and the record will no longer be eligible to be processed.
    -   `KEEP_ALIVE`: Regardless of the number of `Retries__c`, the record will remain in _Pending_ Status and be retired in the future. The number of `Retries__c` will not be decremented. Use this for a trivial failures; ex., after hitting API rate limits.
    -   `SUDDEN_DEATH`: Regardless of the number of `Retries__c`, the record's Status will be updated to _Failed_, and the record will no longer be eligible to be processed.
-   `error`: An Object representing the error (ex., an `Exception` or `String` error message). This error object will be logged against the action record.

Examples:

```
global override void process(List<AsyncAction__c> actions) {
    try {
        HttpRequest request = this.buildRequest();
        HttpResponse response = new Http().send(request);
        ...
    } catch (System.CalloutException ex) {
        // Mark all actions as instant-fail!
        this.fail(actions, AsyncActionProcessor.RetryBehavior.SUDDEN_DEATH, ex);
        update actions;
    }
}
```

```
global override void process(List<AsyncAction__c> actions) {
    List<Account> accounts = this.getAccounts(actions);
    List<Database.SaveResult> saveResults = Database.insert(accounts, false);
    for (Integer i = 0; i < saveResults?.size(); i++) {
        if (saveResult?.isSuccess() == false) {
            AsyncAction__c action = actions[i];
            this.fail(
                action,
                AsyncActionProcessor.RetryBehavior.ALLOW_RETRY,
                saveResult?.getErrors()
            );
        }
    }
    ...
    update actions;
}
```

## Best Practices

-   To avoid endless looping, remember to update each `AsyncAction__c` record with the results of the transaction. If the action succeeded, set the `Status__c` field to _"Completed"_. If the action failed, use the `fail()` method to mark the action as failed. Read more about error handling [here](#error-handling).
-   Do not attempt to launch `AsyncActionProcessor` classes on your own, via the `System.enqueueJob()` method or by other means. The Async Action Framework handles all of the launching internally. It includes checks against limits, custom metadata configuration, and more. Bypassing these checks can lead to unexpected results and potentially compromise the integrity of the framework. Instead, use the `AsyncActionProcessor__mdt` to dictate when and if a job is launched. If necessary, you can use the `AsyncActionLauncher.launchJobs(List<AsyncActionProcessor__mdt> configs, Id currentJobId)` method to safely launch a processor on your own.
-   Be careful when fetching `Id` values from `RelatedRecordId__c`, as well as custom data structures from `Data__c`. Always guard against unexpected inputs to avoid an unhandled exception.
