The `AsyncActions.DuplicateBehavior` enum sets what [AsyncActions.ActionGroups](./The-AsyncActions.ActionGroups-Class) does when two actions in a batch name the same record.

```apex
AsyncActions.ActionGroups groups = new AsyncActions.ActionGroups(
    settings,
    actions,
    AsyncActions.DuplicateBehavior.FAIL_DUPLICATES
);
```

## Values

| Value              | Description                                                                                                                                                                                  |
| ------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `GROUP_DUPLICATES` | The default. Every action for the record joins one group and gets the same outcome. Use it when an action means only "process this record".                                                  |
| `FAIL_DUPLICATES`  | Keeps the first action for the record, and fails the rest with `SUDDEN_DEATH`. Use it when actions for one record store different `Data__c`, since grouping would treat them as one request. |
