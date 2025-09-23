The `AsyncActions.Processor` interface defines the contract that all async action processors must implement.

## Overview

This global interface provides the standard method signature that processor implementations must follow. Both Apex classes and Flow processors (via wrapper) implement this interface.

## Interface Definition

```apex
global interface Processor {
	void process(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions);
}
```

## Method Requirements

### process(AsyncActionProcessor**mdt settings, List<AsyncAction**c> actions)

The main processing method that all processors must implement.

**Parameters:**

-   `settings` - Processor configuration from custom metadata
-   `actions` - List of async actions to process (bulkified)

**Responsibilities:**

-   Process the provided actions according to business logic
-   Update action status fields appropriately
-   Handle errors using the Failure class
-   Support bulk processing patterns

## Implementation Examples

### Basic Processor

```apex
global class MyProcessor implements AsyncActions.Processor {
	global void process(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions) {
		for (AsyncAction__c action : actions) {
			try {
				// Your business logic here
				processAction(action);
				action.Status__c = 'Completed';
			} catch (Exception e) {
				new AsyncActions.Failure(settings).fail(new List<AsyncAction__c>{ action }, e);
			}
		}
	}
}
```

### Bulk-Optimized Processor

```apex
global class BulkProcessor implements AsyncActions.Processor {
	global void process(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions) {
		try {
			// Bulk processing logic
			List<SObject> recordsToUpdate = new List<SObject>();

			for (AsyncAction__c action : actions) {
				// Build bulk operations
				recordsToUpdate.add(buildRecord(action));
				action.Status__c = 'Completed';
			}

			// Perform bulk DML
			update recordsToUpdate;
		} catch (Exception e) {
			new AsyncActions.Failure(settings).fail(actions, e);
		}
	}
}
```

## Best Practices

1. **Always handle exceptions** using the Failure class
2. **Support bulk operations** for governor limit efficiency
3. **Update action status** to reflect processing results
4. **Use selective SOQL** when querying related data
5. **Implement proper logging** for troubleshooting

## See Also

-   [AsyncActions Class](./AsyncActions-Class) - Parent class documentation
-   [Creating Your First Processor](./Creating-Your-First-Processor) - Implementation tutorial
