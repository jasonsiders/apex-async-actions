The `AsyncActionJobFinalizer` class implements the Finalizer pattern to provide last-resort error handling for async action processing jobs.

## Overview

`AsyncActionJobFinalizer` ensures that async actions are never lost due to uncaught exceptions in the processing pipeline. It serves as a safety net when normal error handling fails or system-level errors occur.

## Finalizer Pattern

The Finalizer pattern provides guaranteed execution of cleanup code, even when exceptions occur:

```apex
public class AsyncActionJobFinalizer implements Finalizer {
	private List<AsyncAction__c> actions;
	private AsyncActionProcessor__mdt settings;

	public AsyncActionJobFinalizer(List<AsyncAction__c> actions, AsyncActionProcessor__mdt settings) {
		this.actions = actions;
		this.settings = settings;
	}

	public void execute(FinalizerContext context) {
		// Handle any actions that weren't processed due to exceptions
	}
}
```

## Integration with AsyncActionJob

The finalizer is attached to every async action job:

```apex
public class AsyncActionJob implements Queueable {
	public void execute(QueueableContext context) {
		// Attach finalizer before processing
		System.attachFinalizer(new AsyncActionJobFinalizer(actions, settings));

		try {
			// Process actions normally
			processor.process(settings, actions);
		} catch (Exception e) {
			// Normal error handling
			new AsyncActions.Failure(settings).fail(actions, e);
		}
		// If any uncaught exceptions occur, finalizer will handle them
	}
}
```

## Error Recovery Logic

### System Exception Handling

When system-level exceptions occur that bypass normal error handling:

```apex
public void execute(FinalizerContext context) {
    if (context.getResult() == ParentJobResult.UNHANDLED_EXCEPTION) {
        Exception systemException = context.getException();

        // Mark actions for retry or failure based on exception type
        handleSystemException(actions, systemException);
    }
}
```

### Recovery Strategies

The finalizer implements different recovery strategies based on the exception:

```apex
private void handleSystemException(List<AsyncAction__c> actions, Exception e) {
    if (isRetryableException(e)) {
        // System timeout, resource limit - retry with backoff
        scheduleRetry(actions, calculateBackoffDelay());
    } else if (isConfigurationException(e)) {
        // Processor misconfiguration - mark as failed
        markActionsAsFailed(actions, 'Configuration error: ' + e.getMessage());
    } else {
        // Unknown system error - dead letter queue
        moveToDeadLetterQueue(actions, e);
    }
}
```

## Exception Classification

### Retryable Exceptions

System-level issues that may resolve on retry:

-   Governor limit exceptions (CPU time, DML limits)
-   Temporary resource unavailability
-   Network connectivity issues

### Non-Retryable Exceptions

Permanent system issues requiring intervention:

-   Invalid configuration
-   Security exceptions
-   Data corruption errors

### Unknown Exceptions

Unexpected system errors requiring manual review:

-   Platform bugs
-   Undocumented system behaviors
-   Complex cascading failures

## Audit and Logging

The finalizer maintains detailed audit trails:

```apex
public void execute(FinalizerContext context) {
    AsyncActionAuditLog__c auditLog = new AsyncActionAuditLog__c(
        ProcessorName__c = settings.DeveloperName,
        JobId__c = context.getAsyncApexJobId(),
        Exception__c = context.getException()?.getMessage(),
        ExceptionType__c = context.getException()?.getTypeName(),
        Result__c = context.getResult().name(),
        ActionsAffected__c = actions.size(),
        Timestamp__c = DateTime.now()
    );

    insert auditLog;
}
```

## Recovery Actions

### Retry Scheduling

```apex
private void scheduleRetry(List<AsyncAction__c> actions, Integer delaySeconds) {
    for (AsyncAction__c action : actions) {
        action.Status__c = 'Retry';
        action.NextRetryTime__c = DateTime.now().addSeconds(delaySeconds);
        action.RetryCount__c = (action.RetryCount__c ?? 0) + 1;
        action.ErrorMessage__c = 'System exception - scheduled for retry';
    }

    update actions;
}
```

### Dead Letter Queue

```apex
private void moveToDeadLetterQueue(List<AsyncAction__c> actions, Exception e) {
    List<AsyncActionDeadLetter__c> deadLetters = new List<AsyncActionDeadLetter__c>();

    for (AsyncAction__c action : actions) {
        deadLetters.add(new AsyncActionDeadLetter__c(
            OriginalActionId__c = action.Id,
            ProcessorName__c = action.ProcessorName__c,
            RecordId__c = action.RecordId__c,
            ActionData__c = action.ActionData__c,
            FailureReason__c = e.getMessage(),
            StackTrace__c = e.getStackTraceString(),
            CreatedDate = DateTime.now()
        ));

        action.Status__c = 'Dead_Letter';
        action.ErrorMessage__c = 'Moved to dead letter queue: ' + e.getMessage();
    }

    insert deadLetters;
    update actions;
}
```

## Monitoring and Alerting

### Finalizer Execution Monitoring

```apex
// Query finalizer executions
List<AsyncActionAuditLog__c> finalizerEvents = [
    SELECT ProcessorName__c, COUNT(Id) eventCount
    FROM AsyncActionAuditLog__c
    WHERE CreatedDate = LAST_N_DAYS:1
    AND Result__c = 'UNHANDLED_EXCEPTION'
    GROUP BY ProcessorName__c
];
```

### Alert Triggers

```apex
// Trigger alerts for frequent finalizer executions
for (AggregateResult result : finalizerEvents) {
    if ((Integer)result.get('eventCount') > 10) {
        sendAlert((String)result.get('ProcessorName__c'));
    }
}
```

## Best Practices

### Finalizer Design

1. **Keep it Simple** - Finalizers should do minimal work
2. **Avoid Complex Logic** - Don't introduce additional failure points
3. **Log Everything** - Comprehensive logging for debugging
4. **Fail Safe** - Ensure finalizer itself cannot fail

### Error Handling

1. **Classification** - Properly categorize exceptions for appropriate recovery
2. **Retry Limits** - Prevent infinite retry loops
3. **Dead Letter Queue** - Preserve data for manual recovery
4. **Monitoring** - Alert on finalizer executions

## Testing

### Test Finalizer Execution

```apex
@isTest
static void testFinalizerExecution() {
    // Create test data
    AsyncAction__c action = createTestAction();
    List<AsyncAction__c> actions = new List<AsyncAction__c>{ action };

    Test.startTest();

    // Simulate system exception
    AsyncActionJobFinalizer finalizer = new AsyncActionJobFinalizer(actions, settings);

    // Create mock finalizer context
    FinalizerContext mockContext = new MockFinalizerContext(
        ParentJobResult.UNHANDLED_EXCEPTION,
        new CalloutException('System timeout')
    );

    finalizer.execute(mockContext);

    Test.stopTest();

    // Verify recovery actions
    action = [SELECT Status__c, ErrorMessage__c FROM AsyncAction__c WHERE Id = :action.Id];
    System.assertEquals('Retry', action.Status__c);
}
```

## See Also

-   [AsyncActionJob Class](./AsyncActionJob-Class) - Main queueable job implementation
-   [Error Handling and Retry Logic](./Error-Handling-and-Retry-Logic) - Comprehensive error handling patterns
-   [Monitoring & Troubleshooting](./Monitoring-and-Troubleshooting) - Operational monitoring
