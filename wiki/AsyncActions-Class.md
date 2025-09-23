The `AsyncActions` class serves as the central namespace and entry point for the async actions framework. It provides utility methods for creating async actions and contains essential inner classes and interfaces.

## Overview

As an abstract global class, `AsyncActions` acts as a pseudo-namespace providing a organized location for all framework types and methods. It's the primary class developers interact with when creating async actions.

## Static Methods

### `initAction` Method Overloads

The framework provides multiple overloads of the `initAction` method to accommodate different use cases:

#### `initAction(AsyncActionProcessor__mdt settings, Id relatedRecordId, String data)`

Creates a new AsyncAction\_\_c record with full parameter specification.

**Parameters:**

-   `settings` (AsyncActionProcessor\_\_mdt, required) - The processor configuration that will handle this action
-   `relatedRecordId` (Id, optional) - The Id of a Salesforce record related to this action
-   `data` (String, optional) - Custom data structure (typically JSON) for processor context

**Returns:** AsyncAction\_\_c - A new async action record (not yet inserted)

**Example:**

```apex
AsyncActionProcessor__mdt settings = AsyncActionProcessor__mdt.getInstance('Account_Processor');
AsyncAction__c action = AsyncActions.initAction(settings, accountId, JSON.serialize(customData));
insert action;
```

#### `initAction(AsyncActionProcessor__mdt settings, SObject record, String data)`

Creates a new AsyncAction\_\_c record using an SObject reference instead of an Id.

**Parameters:**

-   `settings` (AsyncActionProcessor\_\_mdt, required) - The processor configuration
-   `record` (SObject, optional) - The Salesforce record related to this action
-   `data` (String, optional) - Custom data structure for processor context

**Returns:** AsyncAction\_\_c - A new async action record (not yet inserted)

**Example:**

```apex
Account myAccount = [SELECT Id FROM Account LIMIT 1];
AsyncAction__c action = AsyncActions.initAction(settings, myAccount, jsonData);
```

#### `initAction(AsyncActionProcessor__mdt settings, Id relatedRecordId)`

Creates a new AsyncAction\_\_c record with a related record but no custom data.

**Parameters:**

-   `settings` (AsyncActionProcessor\_\_mdt, required) - The processor configuration
-   `relatedRecordId` (Id, optional) - The Id of a related Salesforce record

**Returns:** AsyncAction\_\_c - A new async action record (not yet inserted)

**Example:**

```apex
AsyncAction__c action = AsyncActions.initAction(settings, contactId);
```

#### `initAction(AsyncActionProcessor__mdt settings, SObject record)`

Creates a new AsyncAction\_\_c record with an SObject reference but no custom data.

**Parameters:**

-   `settings` (AsyncActionProcessor\_\_mdt, required) - The processor configuration
-   `record` (SObject, optional) - The Salesforce record related to this action

**Returns:** AsyncAction\_\_c - A new async action record (not yet inserted)

**Example:**

```apex
Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
AsyncAction__c action = AsyncActions.initAction(settings, opp);
```

#### `initAction(AsyncActionProcessor__mdt settings)`

Creates a new AsyncAction\_\_c record with only processor settings (no related record or data).

**Parameters:**

-   `settings` (AsyncActionProcessor\_\_mdt, required) - The processor configuration

**Returns:** AsyncAction\_\_c - A new async action record (not yet inserted)

**Example:**

```apex
// For processors that don't need specific record context
AsyncAction__c action = AsyncActions.initAction(settings);
```

### Common Initialization Behavior

All `initAction` methods:

1. **Set Default Values** - Populate required fields with appropriate defaults
2. **Apply Configuration** - Use processor settings for retries and other parameters
3. **Set Status** - Initialize with "Pending" status
4. **Set Timing** - Set NextEligibleAt\_\_c to current time for immediate processing
5. **Validate Settings** - Ensure processor configuration is provided

## Inner Classes and Interfaces

### `AsyncActions.Failure` Class

Handles error scenarios and retry logic for async actions.

#### Constructors

**`Failure(AsyncActionProcessor__mdt settings, AsyncActions.RetryBehavior behavior)`**

Creates a failure handler with specific retry behavior.

**Parameters:**

-   `settings` (AsyncActionProcessor\_\_mdt, required) - Processor configuration containing retry settings
-   `behavior` (AsyncActions.RetryBehavior, required) - How this failure should be handled

**`Failure(AsyncActionProcessor__mdt settings)`**

Creates a failure handler with default ALLOW_RETRY behavior.

**Parameters:**

-   `settings` (AsyncActionProcessor\_\_mdt, required) - Processor configuration

#### Methods

**`fail(List<AsyncAction__c> actions, Object error)`**

Marks multiple actions as failed and applies retry logic.

**Parameters:**

-   `actions` (List<AsyncAction\_\_c>, required) - Actions that failed
-   `error` (Object, required) - Error information (Exception, String, etc.)

**`fail(AsyncAction__c action, Object error)`**

Marks a single action as failed and applies retry logic.

**Parameters:**

-   `action` (AsyncAction\_\_c, required) - Action that failed
-   `error` (Object, required) - Error information

**Example Usage:**

```apex
public void process(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions) {
    try {
        // Your processing logic
        performOperations(actions);
        // Mark successful actions as completed
        for (AsyncAction__c action : actions) {
            action.Status__c = 'Completed';
        }
    } catch (Exception e) {
        // Handle failures with retry logic
        new AsyncActions.Failure(settings, AsyncActions.RetryBehavior.ALLOW_RETRY)
            .fail(actions, e);
    }
}
```

### `AsyncActions.Processor` Interface

Defines the contract that all Apex processor implementations must follow.

#### Methods

**`process(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions)`**

The main processing method that contains your business logic.

**Parameters:**

-   `settings` (AsyncActionProcessor\_\_mdt, required) - Configuration for this processor
-   `actions` (List<AsyncAction\_\_c>, required) - Batch of actions to process

**Implementation Requirements:**

1. **Public Constructor** - Must have a public no-argument constructor
2. **Update Status** - Set action.Status\_\_c to 'Completed' for successful operations
3. **Handle Errors** - Use AsyncActions.Failure for error scenarios
4. **Bulk Processing** - Design for processing multiple actions efficiently

**Example Implementation:**

```apex
public class MyProcessor implements AsyncActions.Processor {
	public void process(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions) {
		for (AsyncAction__c action : actions) {
			try {
				// Your business logic here
				processIndividualAction(action);
				action.Status__c = 'Completed';
			} catch (Exception e) {
				new AsyncActions.Failure(settings).fail(action, e);
			}
		}
	}
}
```

## Enums

### `AsyncActions.RetryBehavior`

Controls how failed actions are handled by the `Failure` class.

**Values:**

**`ALLOW_RETRY`** (default)

-   Actions retry until retry count is exhausted
-   Then marked as "Failed" permanently
-   Most common behavior for recoverable errors

**`KEEP_ALIVE`**

-   Actions never fail permanently
-   Continue retrying indefinitely
-   Use with caution - can create infinite loops

**`SUDDEN_DEATH`**

-   Actions fail immediately without retries
-   Ignore configured retry count
-   Use for unrecoverable errors

**Example Usage:**

```apex
// Different retry behaviors for different error types
try {
    callExternalAPI();
} catch (CalloutException e) {
    // Network issues - allow retries
    new AsyncActions.Failure(settings, AsyncActions.RetryBehavior.ALLOW_RETRY)
        .fail(actions, e);
} catch (SecurityException e) {
    // Security issues - fail immediately
    new AsyncActions.Failure(settings, AsyncActions.RetryBehavior.SUDDEN_DEATH)
        .fail(actions, e);
}
```

### `AsyncActions.Status`

Provides type-safe access to AsyncAction\_\_c status values.

**Values:**

-   `AsyncActions.Status.Pending` - Action awaiting processing
-   `AsyncActions.Status.Completed` - Action successfully processed
-   `AsyncActions.Status.Failed` - Action failed permanently
-   `AsyncActions.Status.Canceled` - Action manually canceled

**Example Usage:**

```apex
// Type-safe status assignment
action.Status__c = AsyncActions.Status.Completed.name();

// Status checking
if (action.Status__c == AsyncActions.Status.Pending.name()) {
    // Action is pending
}
```

## Usage Patterns

### Basic Action Creation

```apex
// Get processor configuration
AsyncActionProcessor__mdt settings = AsyncActionProcessor__mdt.getInstance('My_Processor');

// Create action
AsyncAction__c action = AsyncActions.initAction(settings, recordId, customData);

// Insert to trigger processing
insert action;
```

### Bulk Action Creation

```apex
List<AsyncAction__c> actions = new List<AsyncAction__c>();
AsyncActionProcessor__mdt settings = AsyncActionProcessor__mdt.getInstance('Bulk_Processor');

for (Id recordId : recordIds) {
    actions.add(AsyncActions.initAction(settings, recordId));
}

// Bulk insert for efficiency
insert actions;
```

### Error Handling in Processors

```apex
public class RobustProcessor implements AsyncActions.Processor {
	public void process(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions) {
		// Group operations for efficiency
		List<SObject> recordsToInsert = new List<SObject>();

		for (AsyncAction__c action : actions) {
			try {
				// Build operation
				SObject record = buildRecord(action);
				recordsToInsert.add(record);
			} catch (Exception e) {
				// Individual action failure
				new AsyncActions.Failure(settings).fail(action, e);
			}
		}

		// Bulk DML operation
		List<Database.SaveResult> results = Database.insert(recordsToInsert, false);

		// Handle bulk operation results
		Integer index = 0;
		for (AsyncAction__c action : actions) {
			if (action.Status__c != AsyncActions.Status.Failed.name()) {
				Database.SaveResult result = results[index];
				if (result.isSuccess()) {
					action.Status__c = AsyncActions.Status.Completed.name();
				} else {
					String error = result.getErrors()[0].getMessage();
					new AsyncActions.Failure(settings).fail(action, error);
				}
				index++;
			}
		}
	}
}
```

## Best Practices

### Action Creation

1. **Always Use initAction** - Don't manually construct AsyncAction\_\_c records
2. **Validate Settings** - Ensure processor configuration exists before creating actions
3. **Bulk Insert** - Create multiple actions in a single DML operation when possible
4. **Data Validation** - Validate custom data before serialization

### Processor Implementation

1. **Bulk Design** - Always design for processing multiple actions
2. **Proper Error Handling** - Use AsyncActions.Failure for consistent error management
3. **Status Management** - Always update action status appropriately
4. **Defensive Programming** - Handle null values and unexpected data gracefully

### Error Handling

1. **Choose Appropriate Behavior** - Select retry behavior based on error type
2. **Meaningful Messages** - Provide specific error messages for troubleshooting
3. **Log Strategically** - Use framework logging for operational visibility
4. **Monitor Patterns** - Watch for recurring errors that indicate systemic issues

## See Also

-   [Creating-Your-First-Processor](./Creating-Your-First-Processor) - Step-by-step processor development
-   [Core-Concepts](./Core-Concepts) - Framework architecture and patterns
