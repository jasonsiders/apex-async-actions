The `AsyncActionLauncher.Factory` inner class handles dynamic instantiation and validation of async action processors.

## Overview

The Factory class implements the Factory design pattern to create processor instances at runtime based on configuration metadata. It provides type-safe processor creation and validation.

## Methods

### createProcessor(String className)

Dynamically creates a processor instance from a class name.

**Parameters:**

-   `className` - Fully qualified name of the processor class

**Returns:** `AsyncActions.Processor` implementation

**Exceptions:**

-   `ProcessorException` - If class cannot be instantiated or doesn't implement interface

**Usage:**

```apex
try {
    AsyncActions.Processor processor = factory.createProcessor('MyProcessor');
    // Use processor instance
} catch (AsyncActionLauncher.ProcessorException e) {
    System.debug('Failed to create processor: ' + e.getMessage());
}
```

### createProcessor(AsyncActionProcessor\_\_mdt settings)

Creates a processor instance from metadata configuration.

**Parameters:**

-   `settings` - Processor configuration metadata

**Returns:** `AsyncActions.Processor` implementation

**Usage:**

```apex
AsyncActionProcessor__mdt settings = [
    SELECT Processor__c, ProcessorType__c
    FROM AsyncActionProcessor__mdt
    WHERE DeveloperName = 'My_Processor'
];

AsyncActions.Processor processor = factory.createProcessor(settings);
```

### validateProcessor(AsyncActions.Processor processor)

Validates that a processor instance meets framework requirements.

**Parameters:**

-   `processor` - Processor instance to validate

**Throws:**

-   `ProcessorException` - If processor fails validation

**Validation Checks:**

-   Implements `AsyncActions.Processor` interface
-   Has public no-argument constructor
-   Class is accessible from current context

## Processor Types

The factory supports different processor types:

### Apex Classes

```apex
// Configuration
ProcessorType__c = 'Apex'
Processor__c = 'MyApexProcessor'

// Factory creates instance
AsyncActions.Processor processor = Type.forName('MyApexProcessor').newInstance();
```

### Flow Processors

```apex
// Configuration
ProcessorType__c = 'Flow'
Processor__c = 'My_Flow_API_Name'

// Factory creates wrapper
AsyncActions.Processor processor = new AsyncActionFlowProcessor(settings);
```

## Error Handling

The factory provides detailed error information:

### ProcessorException

Custom exception type for processor creation failures.

**Common Scenarios:**

-   Class not found
-   Class doesn't implement required interface
-   No public no-argument constructor
-   Insufficient access permissions

**Example:**

```apex
try {
    AsyncActions.Processor processor = factory.createProcessor('InvalidClass');
} catch (AsyncActionLauncher.ProcessorException e) {
    // Log specific error details
    System.debug('Processor creation failed: ' + e.getMessage());
    System.debug('Caused by: ' + e.getCause());
}
```

## Security Considerations

The factory respects Salesforce security:

-   Only creates processors accessible to current user
-   Validates class permissions at runtime
-   Prevents instantiation of restricted classes

## Performance Optimization

-   **Class Caching** - Caches Type instances for reuse
-   **Lazy Loading** - Only loads classes when needed
-   **Validation Caching** - Remembers validation results

## See Also

-   [AsyncActionLauncher Class](./AsyncActionLauncher-Class) - Parent launcher class
-   [AsyncActions.Processor Interface](./AsyncActions.Processor-Interface) - Processor contract
-   [AsyncActionFlowProcessor Class](./AsyncActionFlowProcessor-Class) - Flow processor wrapper
