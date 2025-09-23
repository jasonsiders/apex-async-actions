The `AsyncActionLauncher` class provides utilities for manually launching async action processing jobs.

## Overview

`AsyncActionLauncher` offers programmatic control over async action job execution, allowing developers to trigger processing outside of the automatic scheduling system.

## Static Methods

### launch(String processorName)

Launches processing for all pending actions of a specific processor.

**Parameters:**

-   `processorName` - DeveloperName of the AsyncActionProcessor\_\_mdt record

**Returns:** ID of the queued job

**Usage:**

```apex
// Launch all pending actions for a specific processor
Id jobId = AsyncActionLauncher.launch('My_Processor');
```

### launch(String processorName, List<AsyncAction\_\_c> actions)

Launches processing for specific async actions.

**Parameters:**

-   `processorName` - DeveloperName of the processor
-   `actions` - Specific actions to process

**Returns:** ID of the queued job

**Usage:**

```apex
// Process specific actions
List<AsyncAction__c> specificActions = [
    SELECT Id FROM AsyncAction__c
    WHERE Status__c = 'Pending' AND Priority__c = 'High'
];
Id jobId = AsyncActionLauncher.launch('My_Processor', specificActions);
```

### launchImmediate(String processorName)

Launches processing synchronously in the current transaction.

**Parameters:**

-   `processorName` - DeveloperName of the processor

**Usage:**

```apex
// Process actions immediately (testing scenarios)
AsyncActionLauncher.launchImmediate('My_Processor');
```

## Use Cases

### Manual Processing

Trigger processing for specific scenarios:

```apex
// After data import, process all related actions
AsyncActionLauncher.launch('Data_Validation_Processor');
```

### Priority Processing

Handle high-priority actions immediately:

```apex
List<AsyncAction__c> urgentActions = [
    SELECT Id FROM AsyncAction__c
    WHERE Priority__c = 'Urgent' AND Status__c = 'Pending'
];

if (!urgentActions.isEmpty()) {
    AsyncActionLauncher.launch('Priority_Processor', urgentActions);
}
```

### Testing Support

Process actions synchronously in tests:

```apex
@isTest
static void testProcessor() {
    // Create test actions
    AsyncAction__c action = AsyncActions.initAction(settings, recordId);
    insert action;

    Test.startTest();
    AsyncActionLauncher.launchImmediate('Test_Processor');
    Test.stopTest();

    // Verify results
}
```

## Factory Pattern

The launcher uses an inner `Factory` class for processor instantiation:

### AsyncActionLauncher.Factory

Handles dynamic processor creation and validation.

**Methods:**

-   `createProcessor(String className)` - Instantiates processor by class name
-   `validateProcessor(AsyncActions.Processor processor)` - Validates processor implementation

## Error Handling

The launcher includes robust error handling:

-   Validates processor configuration exists
-   Checks processor is enabled
-   Verifies processor class can be instantiated
-   Handles job queue limits gracefully

## Governor Limit Considerations

-   Respects maximum queueable job limits
-   Validates concurrent job restrictions
-   Provides meaningful error messages for limit violations

## See Also

-   [AsyncActionJob Class](./AsyncActionJob-Class) - The queueable implementation
-   [AsyncActions Class](./AsyncActions-Class) - Core framework utilities
-   [AsyncActionProcessor Custom Metadata Type](./AsyncActionProcessor-Custom-Metadata-Type) - Processor configuration
