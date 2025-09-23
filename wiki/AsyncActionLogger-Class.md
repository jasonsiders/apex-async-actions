The `AsyncActionLogger` class provides centralized logging capabilities for the async actions framework.

## Overview

`AsyncActionLogger` offers structured logging for async action processing, enabling detailed audit trails, debugging support, and operational monitoring across all framework components.

## Features

-   **Structured Logging** - Consistent log format across all components
-   **Configurable Levels** - Support for DEBUG, INFO, WARN, ERROR log levels
-   **Context Preservation** - Maintains processing context and correlation IDs
-   **Performance Tracking** - Built-in timing and performance metrics
-   **Integration Support** - Hooks for external logging systems

## Log Levels

### DEBUG

Detailed diagnostic information for troubleshooting:

```apex
AsyncActionLogger.debug('Processing action: ' + action.Id, action);
```

### INFO

General informational messages about processing:

```apex
AsyncActionLogger.info('Completed batch processing: ' + actions.size() + ' actions');
```

### WARN

Warning conditions that don't stop processing:

```apex
AsyncActionLogger.warn('Retry limit approaching for action: ' + action.Id);
```

### ERROR

Error conditions requiring attention:

```apex
AsyncActionLogger.error('Failed to process action: ' + action.Id, exception);
```

## Logging Context

### Action Context

Automatically captures action-specific context:

```apex
AsyncActionLogger.setContext(action);
AsyncActionLogger.info('Processing started'); // Includes action ID, processor, etc.
```

### Processor Context

Maintains processor-level context:

```apex
AsyncActionLogger.setProcessorContext(settings);
AsyncActionLogger.debug('Processor configuration loaded');
```

### Correlation IDs

Track related operations across multiple jobs:

```apex
String correlationId = AsyncActionLogger.generateCorrelationId();
AsyncActionLogger.setCorrelationId(correlationId);
```

## Configuration

### Log Level Configuration

Configure logging levels via custom metadata:

```apex
// AsyncActionLoggerSettings__mdt
LogLevel__c = 'INFO'
EnableDebugMode__c = false
MaxLogRetention__c = 30  // days
```

### Output Destinations

```apex
// System debug logs (default)
AsyncActionLogger.enableSystemDebug(true);

// Custom object logging
AsyncActionLogger.enableDatabaseLogging(true);

// External system integration
AsyncActionLogger.setExternalLoggerEndpoint('https://logs.company.com/api');
```

## Performance Monitoring

### Execution Timing

```apex
AsyncActionLogger.Timer timer = AsyncActionLogger.startTimer('process_batch');
try {
    // Processing logic
    processor.process(settings, actions);
    timer.success();
} catch (Exception e) {
    timer.failure(e);
    throw e;
}
```

### Metrics Collection

```apex
// Track processing metrics
AsyncActionLogger.incrementCounter('actions_processed', actions.size());
AsyncActionLogger.recordMetric('batch_size', actions.size());
AsyncActionLogger.recordMetric('processing_time_ms', timer.getElapsedTime());
```

## Structured Logging Format

### Standard Log Entry

```json
{
	"timestamp": "2024-01-15T10:30:00.000Z",
	"level": "INFO",
	"message": "Processing batch completed",
	"context": {
		"actionId": "a0X...",
		"processorName": "Data_Sync_Processor",
		"correlationId": "batch-12345",
		"userId": "005...",
		"orgId": "00D..."
	},
	"metrics": {
		"actionsProcessed": 25,
		"processingTimeMs": 1500,
		"retryCount": 2
	}
}
```

### Error Log Entry

```json
{
	"timestamp": "2024-01-15T10:30:00.000Z",
	"level": "ERROR",
	"message": "Action processing failed",
	"exception": {
		"type": "CalloutException",
		"message": "Connection timeout",
		"stackTrace": "...",
		"cause": "..."
	},
	"context": {
		"actionId": "a0X...",
		"processorName": "API_Processor",
		"retryCount": 3,
		"maxRetries": 3
	}
}
```

## Integration Examples

### Custom Object Logging

```apex
public class DatabaseLoggerIntegration {
	public static void writeLog(AsyncActionLogger.LogEntry entry) {
		AsyncActionLog__c logRecord = new AsyncActionLog__c(
			Level__c = entry.level,
			Message__c = entry.message,
			ActionId__c = entry.context.get('actionId'),
			ProcessorName__c = entry.context.get('processorName'),
			Timestamp__c = entry.timestamp,
			Context__c = JSON.serialize(entry.context)
		);

		insert logRecord;
	}
}
```

### External System Integration

```apex
public class ExternalLoggerIntegration {
	@future(callout=true)
	public static void sendToExternalLogger(String logData) {
		HttpRequest req = new HttpRequest();
		req.setEndpoint('https://logs.company.com/api/ingest');
		req.setMethod('POST');
		req.setHeader('Content-Type', 'application/json');
		req.setBody(logData);

		Http http = new Http();
		HttpResponse res = http.send(req);
	}
}
```

## Query and Analysis

### Query Recent Logs

```apex
List<AsyncActionLog__c> recentErrors = [
    SELECT Message__c, ActionId__c, ProcessorName__c, Timestamp__c
    FROM AsyncActionLog__c
    WHERE Level__c = 'ERROR'
    AND Timestamp__c = LAST_N_DAYS:7
    ORDER BY Timestamp__c DESC
];
```

### Aggregate Error Analysis

```apex
List<AggregateResult> errorsByProcessor = [
    SELECT ProcessorName__c, COUNT(Id) errorCount
    FROM AsyncActionLog__c
    WHERE Level__c = 'ERROR'
    AND Timestamp__c = LAST_N_DAYS:1
    GROUP BY ProcessorName__c
    ORDER BY COUNT(Id) DESC
];
```

## Performance Considerations

### Log Volume Management

-   Use appropriate log levels to control volume
-   Implement log rotation and cleanup
-   Consider async logging for high-volume scenarios

### Governor Limit Impact

-   Database logging counts against DML limits
-   External callouts require future methods
-   System debug logs have built-in limits

## Testing Support

### Test Log Verification

```apex
@isTest
static void testLogging() {
    AsyncActionLogger.enableTestMode();

    Test.startTest();
    AsyncActionLogger.info('Test message');
    Test.stopTest();

    List<AsyncActionLogger.LogEntry> logs = AsyncActionLogger.getTestLogs();
    System.assertEquals(1, logs.size());
    System.assertEquals('INFO', logs[0].level);
    System.assertEquals('Test message', logs[0].message);
}
```

## See Also

-   [Monitoring & Troubleshooting](./Monitoring-and-Troubleshooting) - Operational monitoring
-   [Best Practices](./Best-Practices) - Logging best practices
-   [AsyncActionProcessor Custom Metadata Type](./AsyncActionProcessor-Custom-Metadata-Type) - Configuration options
