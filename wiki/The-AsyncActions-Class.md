The `AsyncActions` class serves as the central namespace and entry point for the async actions framework. It provides utility methods for creating async actions and contains essential inner classes and interfaces, which are documented elsewhere in this wiki.

## Methods

### `groupByRecord`

Groups a processor's actions by their `RelatedRecordId__c`, into one [AsyncActions.RecordGroup](./The-AsyncActions.RecordGroup-Class) per record, keyed by the record's Id. Processors that act on one record per action can then query every record once, and give all actions for a record the same outcome.

- `Map<Id, AsyncActions.RecordGroup> groupByRecord(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions, AsyncActions.DuplicateBehavior behavior)`
- `Map<Id, AsyncActions.RecordGroup> groupByRecord(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions)`

An action whose `RelatedRecordId__c` is blank, or is text that is not a valid record Id, fails right away with `SUDDEN_DEATH`, since no retry could fix it, and joins no group. The rest of the batch is unaffected.

The two-parameter overload uses `GROUP_DUPLICATES`. See [AsyncActions.DuplicateBehavior](./The-AsyncActions.DuplicateBehavior-Enum) for when to fail duplicates instead.

### `initAction`

Creates a new AsyncAction\_\_c record configured with the specified processor settings and context information.

- `AsyncAction__c initAction(AsyncActionProcessor__mdt settings, Id relatedRecordId, String data)`
- `AsyncAction__c initAction(AsyncActionProcessor__mdt settings, SObject record, String data)`
- `AsyncAction__c initAction(AsyncActionProcessor__mdt settings, Id relatedRecordId)`
- `AsyncAction__c initAction(AsyncActionProcessor__mdt settings, SObject record)`
- `AsyncAction__c initAction(AsyncActionProcessor__mdt settings)`

All overloads initialize the action with "Pending" status, set NextEligibleAt\_\_c to current time for immediate processing, and apply configuration from processor settings.

## Inner Types

This class contains several inner types that provide core framework functionality:

- [AsyncActions.DuplicateBehavior](./The-AsyncActions.DuplicateBehavior-Enum) - Enum defining how groupByRecord handles duplicate actions
- [AsyncActions.Failure](./The-AsyncActions.Failure-Class) - Standardized error handling and retry logic
- [AsyncActions.Processor](./The-AsyncActions.Processor-Interface) - Interface that all processors must implement
- [AsyncActions.RecordGroup](./The-AsyncActions.RecordGroup-Class) - One record and its actions
- [AsyncActions.RetryBehavior](./The-AsyncActions.RetryBehavior-Enum) - Enum defining retry behavior options
- [AsyncActions.Status](./The-AsyncActions.Status-Enum) - Enum defining action status values
