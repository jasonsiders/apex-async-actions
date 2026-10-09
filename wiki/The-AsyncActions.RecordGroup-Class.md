The `AsyncActions.RecordGroup` inner class contains a record's Id and every action in the batch with that Id in `RelatedRecordId__c`. Each method acts on all of the group's actions, so they share one outcome.

Groups come from [AsyncActions.groupByRecord](./The-AsyncActions-Class#groupbyrecord), keyed by record Id. Actions with no related record share the group under the `null` key:

```apex
public void process(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions) {
    Map<Id, AsyncActions.RecordGroup> groups = AsyncActions.groupByRecord(settings, actions);
    Set<Id> accountIds = groups.keySet();
    Map<Id, Account> accounts = new Map<Id, Account>([SELECT Id FROM Account WHERE Id IN :accountIds]);
    for (AsyncActions.RecordGroup recordGroup : groups.values()) {
        Account account = accounts.get(recordGroup.getRecordId());
        if (account != null) {
            // ...work on the account, then:
            recordGroup.complete();
        } else {
            recordGroup.cancel();
        }
    }
}
```

`group` is a reserved word in Apex, so name the variable something else, such as `recordGroup`.

## Methods

### `cancel`

Marks the group's actions `Canceled`, as when the record no longer needs processing. Log the reason yourself, if you need one.

- `void cancel()`

### `complete`

Marks the group's actions `Completed`.

- `void complete()`

### `fail`

Fails the group's actions through [AsyncActions.Failure](./The-AsyncActions.Failure-Class) with `ALLOW_RETRY`, so they retry per the processor's settings.

- `void fail(Object error)`

### `getActions`

Returns a copy of the group's actions. Use it to read each action's `Data__c`.

- `List<AsyncAction__c> getActions()`

### `getRecordId`

Returns the Id of the record the actions name, or `null` for the group of actions with no related record.

- `Id getRecordId()`
