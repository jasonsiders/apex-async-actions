The `AsyncActions.Status` enum defines the available status values for async action lifecycle management. You can use this to provide type-safety against the Status picklist values; otherwise, there isn't any protection against accidental values which might cause an action to fail (ex., 'Complete' instead of 'Completed', or 'Error'/'Fail' instead of 'Failed').

## Overview

This enum provides standardized status values used throughout the async actions framework to track the processing state of actions.

## Enum Values

| Value         | Description                                                                                           |
| ------------- | ----------------------------------------------------------------------------------------------------- |
| **PENDING**   | Initial status when an async action is created but not yet processed. Default status for new actions. |
| **COMPLETED** | Status set when an action has been successfully processed. Final success status.                      |
| **FAILED**    | Status set when an action has failed and cannot be retried. Final failure status.                     |
| **CANCELED**  | Status set when an action has been manually canceled. No further processing will occur.               |

## Usage in Tests

```apex
@IsTest
static void shouldProcessActions() {
    // Create test processor and actions
    AsyncActionProcessor__mdt settings = AsyncActionTestUtils.createProcessor('TestProcessor');
    AsyncAction__c action = AsyncActions.initAction(settings, null, 'test data');
    insert action;

    Test.startTest();
    // Process the action
    MyProcessor processor = new MyProcessor();
    processor.process(settings, new List<AsyncAction__c>{action});
    Test.stopTest();

    // Verify the action was completed
    action = [SELECT Status__c FROM AsyncAction__c WHERE Id = :action.Id];
    Assert.areEqual(AsyncActions.Status.COMPLETED.name(), action?.Status__c, 'Wrong Status');
}
```

## See Also

-   [AsyncActions Class](./AsyncActions-Class) - Parent class documentation
-   [AsyncAction Custom Object](./AsyncAction-Custom-Object) - Status field details
