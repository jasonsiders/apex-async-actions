The `AsyncActions.ActionGroups` inner class groups a processor's actions by their `RelatedRecordId__c`. Processors that act on one record per action can then query every record once, and give all actions for a record the same outcome.

```apex
public void process(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions) {
    AsyncActions.ActionGroups groups = new AsyncActions.ActionGroups(settings, actions);
    Set<Id> accountIds = groups.getRecordIds();
    Map<Id, Account> accounts = new Map<Id, Account>([SELECT Id FROM Account WHERE Id IN :accountIds]);
    for (Id accountId : accountIds) {
        if (accounts.containsKey(accountId)) {
            // ...work on the account, then:
            groups.complete(accountId);
        } else {
            groups.cancel(accountId);
        }
    }
}
```

## Constructors

Groups the actions as soon as they are passed in. An action whose `RelatedRecordId__c` is blank, or is text that is not a valid record Id, fails right away with `SUDDEN_DEATH`, since no retry could fix it. The rest of the batch is unaffected.

- `ActionGroups(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions, AsyncActions.DuplicateBehavior behavior)`
- `ActionGroups(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions)`

The two-parameter constructor uses `GROUP_DUPLICATES`. See [AsyncActions.DuplicateBehavior](./The-AsyncActions.DuplicateBehavior-Enum) for when to fail duplicates instead.

## Methods

Each method takes the Id of a related record and acts on every action for it. Ids outside the batch are ignored.

### `cancel`

Marks the record's actions `Canceled`, as when the record no longer needs processing. Log the reason yourself, if you need one.

- `void cancel(Id recordId)`

### `complete`

Marks the record's actions `Completed`.

- `void complete(Id recordId)`

### `fail`

Fails the record's actions through [AsyncActions.Failure](./The-AsyncActions.Failure-Class) with `ALLOW_RETRY`, so they retry per the processor's settings.

- `void fail(Id recordId, Object error)`

### `getActions`

Returns the record's actions, or an empty list for a record outside the batch. Use it to read each action's `Data__c`.

- `List<AsyncAction__c> getActions(Id recordId)`

### `getRecordIds`

Returns the related record Ids of the grouped actions, for one bulk query.

- `Set<Id> getRecordIds()`
