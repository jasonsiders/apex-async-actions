The async actions framework provides a plugin system for extending logging capabilities through the `AsyncActionLogger.Adapter` interface.

## Overview

The framework includes a pluggable logging system that allows you to implement custom logging adapters and integrate them via the `AsyncActionGlobalSetting__mdt` configuration.

## Creating a Logger Plugin

### Implement the Adapter Interface

Create a class that implements `AsyncActionLogger.Adapter`:

```apex
global class MyLoggerAdapter extends AsyncActionLogger.Adapter {
	global override void log(System.LoggingLevel level, Object logMessage) {
		// Your custom logging implementation
		String message = String.valueOf(logMessage);

		// Example: Write to custom logging system
		writeToCustomLogger(level, message);
	}

	private void writeToCustomLogger(System.LoggingLevel level, String message) {
		// Implementation specific to your logging system
	}
}
```

### Configure the Plugin

Hook your plugin into the framework via the `AsyncActionGlobalSetting__mdt` record:

1. Navigate to **Setup → Custom Metadata Types → Async Action Global Setting → Manage Records**
2. Edit the default record (or create one if none exists)
3. Set the **Logger Plugin** field to your class name: `MyLoggerAdapter`

## Example: Nebula Logger Integration

Here's an example integrating with the popular Nebula Logger framework:

```apex
global class NebulaLoggerAdapter extends AsyncActionLogger.Adapter {
	global override void log(System.LoggingLevel level, Object logMessage) {
		String message = String.valueOf(logMessage);

		// Use Nebula Logger's static methods
		switch on level {
			when ERROR {
				Logger.error(message);
			}
			when WARN {
				Logger.warn(message);
			}
			when INFO {
				Logger.info(message);
			}
			when DEBUG {
				Logger.debug(message);
			}
		}

		// Save the log entries
		Logger.saveLog();
	}
}
```

## Configuration

The framework uses the `AsyncActionGlobalSetting__mdt` record to determine which logger plugin to use:

| Field             | Description                                                             |
| ----------------- | ----------------------------------------------------------------------- |
| **Logger Plugin** | The name of your adapter class implementing `AsyncActionLogger.Adapter` |

## Default Behavior

If no plugin is configured, the framework uses the built-in `System.debug()` logging.

## See Also

-   [AsyncActionLogger Class](./AsyncActionLogger-Class) - Core logging framework
-   [AsyncActionGlobalSetting Custom Metadata Type](./AsyncActionGlobalSetting-Custom-Metadata-Type) - Configuration details
