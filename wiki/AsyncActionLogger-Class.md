The `AsyncActionLogger` class provides a pluggable logging framework for the async actions framework with extensible adapter support.

## Overview

`AsyncActionLogger` is an abstract global class that provides centralized logging capabilities for async action processing. It uses a singleton pattern with an adapter interface to enable custom logging implementations while providing a default System.debug implementation.

## Static Methods

### `log(System.LoggingLevel level, Object logMessage)`

Logs a message at the specified logging level using the configured adapter.

**Parameters:**

-   `level` (System.LoggingLevel, required) - The logging level for the message
-   `logMessage` (Object, required) - The message or object to log

**Example:**

```apex
AsyncActionLogger.log(System.LoggingLevel.INFO, 'Processing batch started');
AsyncActionLogger.log(System.LoggingLevel.ERROR, 'Action processing failed: ' + exception.getMessage());
```

### `save()`

Saves/commits any pending log entries using the configured adapter. Some logging implementations may buffer log entries and require explicit commit/save operations.

**Example:**

```apex
// Process actions and log throughout
AsyncActionLogger.log(System.LoggingLevel.DEBUG, 'Starting action processing');
// ... processing logic ...
AsyncActionLogger.log(System.LoggingLevel.INFO, 'Processing completed');

// Commit all pending log entries
AsyncActionLogger.save();
```

## Configuration

The logger uses the singleton pattern to determine which logging adapter to use based on the `AsyncActionGlobalSetting__mdt.LoggerPlugin__c` field.

**Default Behavior:** If no custom adapter is configured or if the specified adapter is invalid, the framework uses the built-in `DefaultLogger` that writes to System.debug.

**Custom Adapter:** Specify the fully qualified API name of a class that implements `AsyncActionLogger.Adapter` in the global setting.

**Example Configuration:**

```apex
// In AsyncActionGlobalSetting__mdt
LoggerPlugin__c = 'MyCustomLogger'  // Must implement AsyncActionLogger.Adapter
```

## Adapter Interface

### `AsyncActionLogger.Adapter`

Global interface for custom logging implementations.

#### Methods

**`log(System.LoggingLevel level, Object logMessage)`**

Logs a message at the specified level.

**Parameters:**

-   `level` (System.LoggingLevel, required) - The logging level
-   `logMessage` (Object, required) - The message or object to log

**`save()`**

Saves/commits any pending log entries. Implementation depends on the logging adapter.

#### Custom Implementation Example

```apex
global class CustomDatabaseLogger implements AsyncActionLogger.Adapter {
	private List<AsyncActionLog__c> pendingLogs = new List<AsyncActionLog__c>();

	global void log(System.LoggingLevel level, Object logMessage) {
		pendingLogs.add(
			new AsyncActionLog__c(
				Level__c = level.name(),
				Message__c = String.valueOf(logMessage),
				Timestamp__c = DateTime.now()
			)
		);
	}

	global void save() {
		if (!pendingLogs.isEmpty()) {
			insert pendingLogs;
			pendingLogs.clear();
		}
	}
}
```

## Default Logger Implementation

The framework includes a built-in `DefaultLogger` that implements the Adapter interface using System.debug:

-   **log()** - Writes messages to Salesforce debug logs
-   **save()** - No-op since System.debug doesn't require explicit commits

## Usage Patterns

### Basic Logging

```apex
public class MyProcessor implements AsyncActions.Processor {
	public void process(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions) {
		AsyncActionLogger.log(System.LoggingLevel.INFO, 'Processing ' + actions.size() + ' actions');

		try {
			// Processing logic
			processActions(actions);
			AsyncActionLogger.log(System.LoggingLevel.DEBUG, 'Processing completed successfully');
		} catch (Exception e) {
			AsyncActionLogger.log(System.LoggingLevel.ERROR, 'Processing failed: ' + e.getMessage());
			throw e;
		} finally {
			AsyncActionLogger.save();
		}
	}
}
```

### Framework Integration

The logger is used throughout the framework components:

```apex
// AsyncActionJob uses it for job lifecycle logging
AsyncActionLogger.log(System.LoggingLevel.FINEST, processorName + ': launch() -> ' + jobId);

// AsyncActions.Failure uses it for error logging
AsyncActionLogger.log(System.LoggingLevel.ERROR, 'Async Action failed: ' + errorMessage);
```

## Testing Support

The logger includes test visibility modifiers for unit testing:

```apex
@isTest
static void testCustomLogger() {
    // The INSTANCE field is @TestVisible for testing scenarios
    AsyncActionLogger.log(System.LoggingLevel.INFO, 'Test message');
    AsyncActionLogger.save();

    // Verify behavior based on your custom adapter implementation
}
```

## Best Practices

### Choosing Log Levels

-   **DEBUG/FINEST** - Detailed diagnostic information
-   **INFO** - General informational messages
-   **WARN** - Warning conditions that don't stop processing
-   **ERROR** - Error conditions requiring attention

### Performance Considerations

-   Custom adapters should consider governor limits (DML, heap, etc.)
-   Use buffering and batch operations for high-volume scenarios
-   Consider async patterns for external system integration

### Error Handling

-   Custom adapters should handle errors gracefully
-   Invalid adapter configurations fall back to DefaultLogger
-   Test adapter implementations thoroughly

## See Also

-   [AsyncActionGlobalSetting Custom Metadata Type](./AsyncActionGlobalSetting-Custom-Metadata-Type) - Logger configuration
-   [Monitoring & Troubleshooting](./Monitoring-and-Troubleshooting) - Operational monitoring
-   [Best Practices](./Best-Practices) - Framework best practices
