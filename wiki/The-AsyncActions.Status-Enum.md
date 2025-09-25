The `AsyncActions.Status` enum defines the available status values for async action lifecycle management. You can use this to provide type-safety against the Status picklist values; otherwise, there isn't any protection against accidental values which might cause an action to fail (ex., 'Complete' instead of 'Completed', or 'Error'/'Fail' instead of 'Failed').

## Enum Values

| Value       | Description                                                                                           |
| ----------- | ----------------------------------------------------------------------------------------------------- |
| `PENDING`   | Initial status when an async action is created but not yet processed. Default status for new actions. |
| `COMPLETED` | Status set when an action has been successfully processed. Final success status.                      |
| `FAILED`    | Status set when an action has failed and cannot be retried. Final failure status.                     |
| `CANCELED`  | Status set when an action has been manually canceled. No further processing will occur.               |

## Usage

```apex
// In a test - Verify the action was completed
action = [SELECT Status__c FROM AsyncAction__c WHERE Id = :action.Id];
Assert.areEqual(AsyncActions.Status.COMPLETED.name(), action?.Status__c, 'Wrong Status');
```
