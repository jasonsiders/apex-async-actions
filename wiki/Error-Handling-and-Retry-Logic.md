Comprehensive guide to error handling and retry logic patterns in the async actions framework.

## Overview

The async actions framework provides robust error handling and configurable retry mechanisms to ensure reliable processing even in the face of transient failures and system errors.

## Error Handling Architecture

### Multi-Layer Error Handling

1. **Processor Level** - Business logic error handling
2. **Framework Level** - System error recovery
3. **Finalizer Level** - Last-resort error capture

### Error Classification

-   **Transient Errors** - Temporary issues that may resolve on retry
-   **Permanent Errors** - Issues requiring manual intervention
-   **System Errors** - Platform-level failures

## Retry Behaviors

### ALLOW_RETRY

Automatically retries failed actions up to configured limits.

**Configuration:**

```
RetryBehavior__c = 'ALLOW_RETRY'
Retries__c = 3
RetryInterval__c = 300  // 5 minutes
```

**Use Cases:**

-   Network timeouts
-   Temporary resource unavailability
-   Rate limiting responses

**Example:**

```apex
public void process(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions) {
    for (AsyncAction__c action : actions) {
        try {
            callExternalService(action);
            action.Status__c = 'Completed';
        } catch (CalloutException e) {
            // Framework will retry automatically
            new AsyncActions.Failure(settings).fail(new List<AsyncAction__c>{ action }, e);
        }
    }
}
```

### KEEP_ALIVE

Marks actions as failed but preserves them for manual review.

**Configuration:**

```
RetryBehavior__c = 'KEEP_ALIVE'
```

**Use Cases:**

-   Data validation errors
-   Business rule violations
-   Configuration issues

**Example:**

```apex
try {
    validateBusinessRules(action);
    processAction(action);
} catch (ValidationException e) {
    // Requires manual intervention
    new AsyncActions.Failure(settings).fail(new List<AsyncAction__c>{ action }, e);
}
```

### SUDDEN_DEATH

Immediately marks actions as permanently failed.

**Configuration:**

```
RetryBehavior__c = 'SUDDEN_DEATH'
```

**Use Cases:**

-   Security violations
-   Unrecoverable data corruption
-   System-level errors

## Error Handling Patterns

### Graceful Degradation

```apex
public void process(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions) {
    List<AsyncAction__c> successfulActions = new List<AsyncAction__c>();
    List<AsyncAction__c> failedActions = new List<AsyncAction__c>();

    for (AsyncAction__c action : actions) {
        try {
            processAction(action);
            action.Status__c = 'Completed';
            successfulActions.add(action);
        } catch (Exception e) {
            action.Status__c = 'Failed';
            action.ErrorMessage__c = e.getMessage();
            failedActions.add(action);
        }
    }

    // Update successful actions
    if (!successfulActions.isEmpty()) {
        update successfulActions;
    }

    // Handle failures appropriately
    if (!failedActions.isEmpty()) {
        new AsyncActions.Failure(settings).fail(failedActions,
            new AsyncActionException('Batch processing failures'));
    }
}
```

### Circuit Breaker Pattern

```apex
public class CircuitBreakerProcessor implements AsyncActions.Processor {
	private static Integer failureCount = 0;
	private static DateTime lastFailureTime;
	private static final Integer FAILURE_THRESHOLD = 5;
	private static final Integer CIRCUIT_TIMEOUT = 300; // 5 minutes

	public void process(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions) {
		if (isCircuitOpen()) {
			// Circuit is open, fail fast
			new AsyncActions.Failure(settings).fail(actions, new AsyncActionException('Circuit breaker is open'));
			return;
		}

		try {
			processActions(actions);
			resetCircuit();
		} catch (Exception e) {
			recordFailure();
			new AsyncActions.Failure(settings).fail(actions, e);
		}
	}

	private Boolean isCircuitOpen() {
		return failureCount >= FAILURE_THRESHOLD && lastFailureTime.addSeconds(CIRCUIT_TIMEOUT) > DateTime.now();
	}
}
```

## Error Recovery Strategies

### Retry with Exponential Backoff

```apex
public class ExponentialBackoffProcessor implements AsyncActions.Processor {
	public void process(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions) {
		for (AsyncAction__c action : actions) {
			Integer retryDelay = calculateBackoffDelay(action.RetryCount__c);

			if (action.NextRetryTime__c != null && action.NextRetryTime__c > DateTime.now()) {
				// Not time to retry yet, skip this action
				continue;
			}

			try {
				processAction(action);
				action.Status__c = 'Completed';
			} catch (Exception e) {
				action.NextRetryTime__c = DateTime.now().addSeconds(retryDelay);
				new AsyncActions.Failure(settings).fail(new List<AsyncAction__c>{ action }, e);
			}
		}
	}

	private Integer calculateBackoffDelay(Decimal retryCount) {
		return (Integer) Math.pow(2, retryCount) * 60; // 1m, 2m, 4m, 8m...
	}
}
```

### Dead Letter Queue Pattern

```apex
public void process(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions) {
    for (AsyncAction__c action : actions) {
        try {
            processAction(action);
        } catch (Exception e) {
            if (action.RetryCount__c >= settings.Retries__c) {
                // Move to dead letter queue
                createDeadLetterRecord(action, e);
                action.Status__c = 'Dead_Letter';
            } else {
                new AsyncActions.Failure(settings).fail(new List<AsyncAction__c>{ action }, e);
            }
        }
    }
}
```

## Monitoring and Alerting

### Error Rate Monitoring

```apex
public class ErrorRateMonitor {
    public static void checkErrorRate(String processorName) {
        List<AggregateResult> results = [
            SELECT COUNT(Id) total,
                   COUNT_DISTINCT(CASE WHEN Status__c = 'Failed' THEN Id END) failures
            FROM AsyncAction__c
            WHERE ProcessorName__c = :processorName
            AND CreatedDate = LAST_N_DAYS:1
        ];

        Decimal errorRate = (Decimal) results[0].get('failures') /
                           (Decimal) results[0].get('total');

        if (errorRate > 0.1) { // 10% threshold
            sendAlert(processorName, errorRate);
        }
    }
}
```

### Custom Error Logging

```apex
public class CustomErrorLogger {
	public static void logError(AsyncAction__c action, Exception e, String context) {
		Error_Log__c errorLog = new Error_Log__c(
			AsyncAction__c = action.Id,
			ErrorMessage__c = e.getMessage(),
			StackTrace__c = e.getStackTraceString(),
			Context__c = context,
			ProcessorName__c = action.ProcessorName__c,
			Timestamp__c = DateTime.now()
		);

		insert errorLog;
	}
}
```

## Testing Error Scenarios

### Simulating Failures

```apex
@isTest
static void testRetryLogic() {
    // Configure processor with retry behavior
    AsyncActionProcessor__mdt settings = createTestSettings();
    settings.RetryBehavior__c = 'ALLOW_RETRY';
    settings.Retries__c = 2;

    AsyncAction__c action = AsyncActions.initAction(settings, testRecordId);
    insert action;

    Test.startTest();

    // First attempt - should fail and retry
    MockFailureProcessor.shouldFail = true;
    AsyncActionLauncher.launchImmediate('Test_Processor');

    // Verify retry was scheduled
    action = [SELECT Status__c, RetryCount__c FROM AsyncAction__c WHERE Id = :action.Id];
    System.assertEquals('Retry', action.Status__c);
    System.assertEquals(1, action.RetryCount__c);

    // Second attempt - should succeed
    MockFailureProcessor.shouldFail = false;
    AsyncActionLauncher.launchImmediate('Test_Processor');

    Test.stopTest();

    // Verify final success
    action = [SELECT Status__c FROM AsyncAction__c WHERE Id = :action.Id];
    System.assertEquals('Completed', action.Status__c);
}
```

## Best Practices

1. **Design for Failure** - Assume operations will fail and plan accordingly
2. **Fail Fast** - Detect permanent errors quickly to avoid wasted retries
3. **Log Strategically** - Capture enough detail for troubleshooting without overwhelming logs
4. **Monitor Actively** - Set up alerts for error rate thresholds
5. **Test Error Paths** - Include failure scenarios in your test coverage

## See Also

-   [AsyncActions.Failure Class](./AsyncActions.Failure-Class) - Failure handling implementation
-   [AsyncActions.RetryBehavior Enum](./AsyncActions.RetryBehavior-Enum) - Retry behavior options
-   [Monitoring & Troubleshooting](./Monitoring-and-Troubleshooting) - Operational guidance
