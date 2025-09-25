The `AsyncActions` class serves as the central namespace and entry point for the async actions framework. It provides utility methods for creating async actions and contains essential inner classes and interfaces, which are documented elsewhere in this wiki.

## Methods

### `initAction`

Creates a new AsyncAction\_\_c record configured with the specified processor settings and context information.

-   `AsyncAction__c initAction(AsyncActionProcessor__mdt settings, Id relatedRecordId, String data)`
-   `AsyncAction__c initAction(AsyncActionProcessor__mdt settings, SObject record, String data)`
-   `AsyncAction__c initAction(AsyncActionProcessor__mdt settings, Id relatedRecordId)`
-   `AsyncAction__c initAction(AsyncActionProcessor__mdt settings, SObject record)`
-   `AsyncAction__c initAction(AsyncActionProcessor__mdt settings)`

All overloads initialize the action with "Pending" status, set NextEligibleAt\_\_c to current time for immediate processing, and apply configuration from processor settings.

## Inner Types

This class contains several inner types that provide core framework functionality:

-   [AsyncActions.Failure](./The-AsyncActions.Failure-Class) - Standardized error handling and retry logic
-   [AsyncActions.Processor](./The-AsyncActions.Processor-Interface) - Interface that all processors must implement
-   [AsyncActions.RetryBehavior](./The-AsyncActions.RetryBehavior-Enum) - Enum defining retry behavior options
-   [AsyncActions.Status](./The-AsyncActions.Status-Enum) - Enum defining action status values
