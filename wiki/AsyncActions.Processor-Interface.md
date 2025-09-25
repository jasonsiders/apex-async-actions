The `AsyncActions.Processor` interface defines the contract that all async action processors must implement.

## Overview

This global interface provides the standard method signature that processor implementations must follow. Both Apex classes and Flow processors (via wrapper) implement this interface.

## Interface Definition

```apex
global interface Processor {
	void process(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions);
}
```

## Methods

### `process`

The main processing method that all processors must implement.

**Parameters:**

-   `settings` - Processor configuration from custom metadata
-   `actions` - List of async actions to process (bulkified)

**Responsibilities:**

-   Process the provided actions according to business logic
-   Update action status fields appropriately
-   Handle errors using the Failure class
-   Support bulk processing patterns

## See Also

-   [AsyncActions Class](./AsyncActions-Class) - Parent class documentation
-   [Creating Your First Processor](./Creating-Your-First-Processor) - Implementation tutorial
