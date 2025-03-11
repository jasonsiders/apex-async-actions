# The `AsyncActionJob` Class

This apex class represents some kind of action to be performed asynchronously, against a collection of [`AsyncAction__c`](/docs/ASYNCACTIONOBJECT.md) records.

## Process Overview

The class handles the minutia of the framework, and leaves the actual actions to be processed up to the user to define, via the `AsyncActions.Processor` interface, and/or Flows.

Each time the `AsyncActionJob` Queueable is run, it follows this process:

1. Retrieves a `AsyncActionProcessor__mdt` configuration record with a matching `Processor__c` value, and checks if the configuration record's `Enabled__c` value. If this is not _true_, or a matching configuration record cannot found, then the job will abort.
2. Queries `AsyncAction__c` records with a `ProcessorName__c` value that matches the configuration record's DeveloperName, and are in _Pending_ status, and have a `NextEligibleAt__c` value in the past. Records are returned in order of its `NextEligibleAt__c` value, prioritizing older records first. This query is limited by the configuration record's `BatchSize__c`.
3. Creates a `AsyncActions.Processor` object, based on the `ProcessorType__c`:

- If "Apex", then the framework uses `Type.forName` to create the provided `Processor__c`.
- If "Flow", the framework creates a special `AsyncActionFlowProcessor`, which in turn dynamically generates the flow to be run.

4. The user-defined logic is run
5. The current `List<AsyncAction__c>` in memory are updated in the database.
6. The `System.Queueable` operation ceases. A `System.Finalizer` operation begins shortly after.
7. The finalizer checks if the Queueable job succeeded. If an unhandled exception was thrown, the finalizer logs the error and updates all `AsyncAction__c` records in the transaction to reflect the failure using `ALLOW_RETRY` logic.
8. The finalizer re-enqueues the current processor class if it has any remaining _Pending_ `AsyncAction__c` records with a `NextEligibleAt__c` value in the past.
