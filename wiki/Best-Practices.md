Comprehensive guide to best practices for designing, implementing, and maintaining async action processors in production environments.

## Overview

Following established best practices ensures reliable, performant, and maintainable async action implementations. This guide covers architecture decisions, coding standards, testing strategies, and operational considerations.

## Processor Design Principles

### Single Responsibility

Each processor should have one clear purpose:

```apex
// ✅ GOOD - Single responsibility
public class EmailNotificationProcessor implements AsyncActions.Processor {
    public void process(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions) {
        for (AsyncAction__c action : actions) {
            sendEmailNotification(action);
        }
    }
}

// ❌ BAD - Multiple responsibilities
public class MultiPurposeProcessor implements AsyncActions.Processor {
    public void process(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions) {
        for (AsyncAction__c action : actions) {
            sendEmail(action);          // Email responsibility
            updateInventory(action);    // Inventory responsibility
            generateReport(action);     // Reporting responsibility
        }
    }
}
```

### Bulk Processing Design

Always design for bulk operations:

```apex
// ✅ GOOD - Bulk-aware design
public class BulkAwareProcessor implements AsyncActions.Processor {
	public void process(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions) {
		// Collect all records to update
		Map<Id, Contact> contactsToUpdate = new Map<Id, Contact>();
		List<EmailMessage> emailsToSend = new List<EmailMessage>();

		for (AsyncAction__c action : actions) {
			// Prepare bulk updates
			Contact contact = prepareContactUpdate(action);
			contactsToUpdate.put(contact.Id, contact);

			// Prepare bulk emails
			EmailMessage email = prepareEmail(action);
			emailsToSend.add(email);
		}

		// Execute bulk operations
		update contactsToUpdate.values();
		sendBulkEmails(emailsToSend);
	}
}
```

### Idempotent Operations

Ensure processors can safely retry operations:

```apex
public class IdempotentProcessor implements AsyncActions.Processor {
	public void process(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions) {
		for (AsyncAction__c action : actions) {
			// Check if already processed
			if (isAlreadyProcessed(action)) {
				action.Status__c = 'Completed';
				continue;
			}

			try {
				performOperation(action);
				recordProcessingComplete(action);
				action.Status__c = 'Completed';
			} catch (Exception e) {
				new AsyncActions.Failure(settings).fail(new List<AsyncAction__c>{ action }, e);
			}
		}
	}

	private Boolean isAlreadyProcessed(AsyncAction__c action) {
		// Check external system or tracking record
		return [SELECT COUNT() FROM ProcessingLog__c WHERE ActionId__c = :action.Id] > 0;
	}
}
```

## Error Handling Best Practices

### Graceful Degradation

Handle individual failures without stopping batch processing:

```apex
public class ResilientProcessor implements AsyncActions.Processor {
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
			new AsyncActions.Failure(settings)
				.fail(failedActions, new AsyncActionException('Batch processing failures'));
		}
	}
}
```

### Specific Exception Handling

Implement targeted error handling for different scenarios:

```apex
public class SpecificErrorHandlingProcessor implements AsyncActions.Processor {
	public void process(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions) {
		for (AsyncAction__c action : actions) {
			try {
				processAction(action);
				action.Status__c = 'Completed';
			} catch (CalloutException e) {
				// Network issues - retry with exponential backoff
				handleNetworkError(action, e, settings);
			} catch (DmlException e) {
				// Data issues - likely permanent, don't retry
				handleDataError(action, e, settings);
			} catch (System.LimitException e) {
				// Governor limits - retry with smaller batch
				handleLimitError(action, e, settings);
			} catch (Exception e) {
				// Unknown error - log and mark for manual review
				handleUnknownError(action, e, settings);
			}
		}
	}
}
```

## Performance Optimization

### Efficient SOQL Patterns

Minimize queries and maximize selectivity:

```apex
// ✅ GOOD - Selective querying with minimal queries
public class EfficientQueryProcessor implements AsyncActions.Processor {
    public void process(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions) {
        // Collect all record IDs
        Set<Id> recordIds = new Set<Id>();
        for (AsyncAction__c action : actions) {
            recordIds.add(action.RecordId__c);
        }

        // Single selective query
        Map<Id, Account> accounts = new Map<Id, Account>([
            SELECT Id, Name, Type, BillingCity
            FROM Account
            WHERE Id IN :recordIds
            AND Type = 'Customer'  // Selective filter
        ]);

        // Process with cached data
        for (AsyncAction__c action : actions) {
            Account account = accounts.get(action.RecordId__c);
            if (account != null) {
                processAccount(action, account);
            }
        }
    }
}

// ❌ BAD - Query in loop
public class InefficientQueryProcessor implements AsyncActions.Processor {
    public void process(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions) {
        for (AsyncAction__c action : actions) {
            // Query in loop - very inefficient
            Account account = [SELECT Id, Name FROM Account WHERE Id = :action.RecordId__c];
            processAccount(action, account);
        }
    }
}
```

### Governor Limit Management

Stay within Salesforce limits:

```apex
public class LimitAwareProcessor implements AsyncActions.Processor {
	private static final Integer MAX_DML_OPERATIONS = 150;
	private static final Integer MAX_SOQL_QUERIES = 100;

	public void process(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions) {
		List<SObject> recordsToUpdate = new List<SObject>();

		for (AsyncAction__c action : actions) {
			// Check limits before processing
			if (Limits.getDmlStatements() >= MAX_DML_OPERATIONS) {
				// Schedule remaining actions for next job
				scheduleRemainingActions(actions, actions.indexOf(action));
				break;
			}

			SObject recordToUpdate = processAction(action);
			if (recordToUpdate != null) {
				recordsToUpdate.add(recordToUpdate);

				// Batch DML operations
				if (recordsToUpdate.size() >= 200) {
					update recordsToUpdate;
					recordsToUpdate.clear();
				}
			}
		}

		// Final DML
		if (!recordsToUpdate.isEmpty()) {
			update recordsToUpdate;
		}
	}
}
```

## Configuration Best Practices

### Settings-Driven Behavior

Use metadata for configuration:

```apex
public class ConfigurableProcessor implements AsyncActions.Processor {
	public void process(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions) {
		// Read configuration from settings
		Integer batchSize = (Integer) settings.BatchSize__c;
		Boolean enableLogging = settings.EnableLogging__c;
		String apiEndpoint = settings.ApiEndpoint__c;

		if (enableLogging) {
			logProcessingStart(actions.size());
		}

		// Process in configured batch sizes
		for (Integer i = 0; i < actions.size(); i += batchSize) {
			Integer endIndex = Math.min(i + batchSize, actions.size());
			List<AsyncAction__c> batch = actions.subList(i, endIndex);
			processBatch(batch, apiEndpoint);
		}
	}
}
```

### Environment-Specific Configuration

Handle different environments:

```apex
public class EnvironmentAwareProcessor implements AsyncActions.Processor {
	public void process(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions) {
		String environment = getEnvironment();
		String endpoint = getEndpointForEnvironment(environment, settings);
		Integer timeoutMs = getTimeoutForEnvironment(environment);

		for (AsyncAction__c action : actions) {
			makeCallout(action, endpoint, timeoutMs);
		}
	}

	private String getEnvironment() {
		// Determine environment (sandbox, production, etc.)
		Organization org = [SELECT IsSandbox FROM Organization LIMIT 1];
		return org.IsSandbox ? 'sandbox' : 'production';
	}

	private String getEndpointForEnvironment(String env, AsyncActionProcessor__mdt settings) {
		return env == 'production' ? settings.ProductionEndpoint__c : settings.SandboxEndpoint__c;
	}
}
```

## Testing Best Practices

### Comprehensive Test Coverage

Test all scenarios including edge cases:

```apex
@isTest
public class ComprehensiveProcessorTest {
	@isTest
	static void testSuccessfulProcessing() {
		// Test normal processing flow
		AsyncActionProcessor__mdt settings = createTestSettings();
		List<AsyncAction__c> actions = createTestActions(5);

		Test.startTest();
		new MyProcessor().process(settings, actions);
		Test.stopTest();

		// Verify successful processing
		for (AsyncAction__c action : [SELECT Status__c FROM AsyncAction__c WHERE Id IN :actions]) {
			System.assertEquals('Completed', action.Status__c);
		}
	}

	@isTest
	static void testErrorHandling() {
		// Test error scenarios
		AsyncActionProcessor__mdt settings = createTestSettings();
		List<AsyncAction__c> actions = createInvalidTestActions(3);

		Test.startTest();
		new MyProcessor().process(settings, actions);
		Test.stopTest();

		// Verify error handling
		for (AsyncAction__c action : [SELECT Status__c, ErrorMessage__c FROM AsyncAction__c WHERE Id IN :actions]) {
			System.assertEquals('Failed', action.Status__c);
			System.assertNotEquals(null, action.ErrorMessage__c);
		}
	}

	@isTest
	static void testBulkProcessing() {
		// Test with large data volumes
		AsyncActionProcessor__mdt settings = createTestSettings();
		List<AsyncAction__c> actions = createTestActions(200);

		Test.startTest();
		new MyProcessor().process(settings, actions);
		Test.stopTest();

		// Verify bulk processing efficiency
		System.assertLess(Limits.getDmlStatements(), 10, 'Should use bulk DML');
		System.assertLess(Limits.getQueries(), 5, 'Should minimize SOQL');
	}

	@isTest
	static void testGovernorLimits() {
		// Test limit handling
		AsyncActionProcessor__mdt settings = createTestSettings();
		List<AsyncAction__c> actions = createTestActions(1000);

		Test.startTest();
		new MyProcessor().process(settings, actions);
		Test.stopTest();

		// Should complete without limit exceptions
		// Verify proper limit handling
	}
}
```

### Mock External Dependencies

Isolate tests from external systems:

```apex
@isTest
public class MockedProcessorTest {
	@isTest
	static void testWithMockedCallout() {
		// Set mock callout response
		Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

		AsyncActionProcessor__mdt settings = createTestSettings();
		List<AsyncAction__c> actions = createTestActions(3);

		Test.startTest();
		new CalloutProcessor().process(settings, actions);
		Test.stopTest();

		// Verify processing without actual callouts
		for (AsyncAction__c action : [SELECT Status__c FROM AsyncAction__c WHERE Id IN :actions]) {
			System.assertEquals('Completed', action.Status__c);
		}
	}

	private class MockHttpResponseGenerator implements HttpCalloutMock {
		public HttpResponse respond(HttpRequest req) {
			HttpResponse res = new HttpResponse();
			res.setStatusCode(200);
			res.setBody('{"status": "success"}');
			return res;
		}
	}
}
```

## Security Best Practices

### Data Access Security

Respect object and field-level security:

```apex
public class SecurityAwareProcessor implements AsyncActions.Processor {
	public void process(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions) {
		// Verify user has access to target objects
		if (!Schema.getGlobalDescribe().get('Contact').getDescribe().isAccessible()) {
			throw new AsyncActionException('Insufficient access to Contact object');
		}

		for (AsyncAction__c action : actions) {
			// Use WITH SECURITY_ENFORCED where appropriate
			List<Contact> contacts = [
				SELECT Id, Name, Email
				FROM Contact
				WHERE Id = :action.RecordId__c
				WITH SECURITY_ENFORCED
			];

			if (!contacts.isEmpty()) {
				processContact(action, contacts[0]);
			}
		}
	}
}
```

### Sensitive Data Handling

Protect sensitive information:

```apex
public class SecureDataProcessor implements AsyncActions.Processor {
	public void process(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions) {
		for (AsyncAction__c action : actions) {
			try {
				// Parse action data securely
				Map<String, Object> actionData = parseActionData(action.ActionData__c);

				// Sanitize sensitive fields
				sanitizeSensitiveData(actionData);

				// Process with sanitized data
				processSecureAction(action, actionData);

				action.Status__c = 'Completed';
				// Don't store sensitive data in error messages
				action.ErrorMessage__c = null;
			} catch (Exception e) {
				action.Status__c = 'Failed';
				// Sanitize error messages
				action.ErrorMessage__c = sanitizeErrorMessage(e.getMessage());
			}
		}
	}

	private Map<String, Object> sanitizeSensitiveData(Map<String, Object> data) {
		// Remove or mask sensitive fields
		if (data.containsKey('ssn')) {
			data.put('ssn', maskSSN((String) data.get('ssn')));
		}
		return data;
	}
}
```

## Monitoring and Observability

### Built-in Logging

Include comprehensive logging:

```apex
public class ObservableProcessor implements AsyncActions.Processor {
	public void process(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions) {
		System.debug('Starting processing: ' + actions.size() + ' actions for ' + settings.DeveloperName);

		Integer successCount = 0;
		Integer errorCount = 0;

		for (AsyncAction__c action : actions) {
			try {
				System.debug('Processing action: ' + action.Id);
				processAction(action);
				successCount++;
				System.debug('Successfully processed action: ' + action.Id);
			} catch (Exception e) {
				errorCount++;
				System.debug('Failed to process action: ' + action.Id + ' - ' + e.getMessage());
				new AsyncActions.Failure(settings).fail(new List<AsyncAction__c>{ action }, e);
			}
		}

		System.debug('Processing complete. Success: ' + successCount + ', Errors: ' + errorCount);
	}
}
```

### Performance Metrics

Track processing performance:

```apex
public class MetricsAwareProcessor implements AsyncActions.Processor {
	public void process(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions) {
		Long startTime = System.currentTimeMillis();
		Integer startCpu = Limits.getCpuTime();

		try {
			// Main processing logic
			processActions(actions);

			// Record success metrics
			recordMetrics(
				settings.DeveloperName,
				actions.size(),
				System.currentTimeMillis() - startTime,
				Limits.getCpuTime() - startCpu,
				'SUCCESS'
			);
		} catch (Exception e) {
			// Record failure metrics
			recordMetrics(
				settings.DeveloperName,
				actions.size(),
				System.currentTimeMillis() - startTime,
				Limits.getCpuTime() - startCpu,
				'FAILURE'
			);
			throw e;
		}
	}

	private void recordMetrics(String processor, Integer actionCount, Long wallTime, Integer cpuTime, String status) {
		ProcessorMetrics__c metrics = new ProcessorMetrics__c(
			ProcessorName__c = processor,
			ActionCount__c = actionCount,
			WallClockTimeMs__c = wallTime,
			CpuTimeMs__c = cpuTime,
			Status__c = status,
			Timestamp__c = DateTime.now()
		);
		insert metrics;
	}
}
```

## Documentation Best Practices

### Code Documentation

Document complex logic and business rules:

```apex
/**
 * Processes customer onboarding actions by creating welcome emails,
 * setting up default preferences, and scheduling follow-up tasks.
 *
 * Retry Behavior: ALLOW_RETRY (network timeouts are common)
 * Batch Size: 50 (balances throughput with email limits)
 * Dependencies: EmailService, UserPreferenceService
 */
public class CustomerOnboardingProcessor implements AsyncActions.Processor {
	/**
	 * Processes a batch of customer onboarding actions.
	 * Each action should contain customer ID in RecordId__c.
	 *
	 * @param settings Processor configuration including email templates
	 * @param actions List of customer onboarding actions to process
	 */
	public void process(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions) {
		// Implementation
	}

	/**
	 * Sends welcome email using configured template.
	 * Handles email delivery failures gracefully.
	 *
	 * @param customerId The customer to send welcome email to
	 * @param templateId Email template from processor settings
	 * @return true if email sent successfully
	 */
	private Boolean sendWelcomeEmail(Id customerId, Id templateId) {
		// Implementation
	}
}
```

## Deployment Best Practices

### Incremental Rollout

Deploy processors incrementally:

```apex
public class FeatureFlaggedProcessor implements AsyncActions.Processor {
	public void process(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions) {
		// Check feature flag
		if (!FeatureManagement.checkPermission('New_Processor_Feature')) {
			// Fall back to old logic
			legacyProcess(settings, actions);
			return;
		}

		// New processing logic
		enhancedProcess(settings, actions);
	}
}
```

### Backward Compatibility

Maintain compatibility during updates:

```apex
public class BackwardCompatibleProcessor implements AsyncActions.Processor {
	public void process(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions) {
		for (AsyncAction__c action : actions) {
			// Handle both old and new data formats
			if (isNewFormat(action.ActionData__c)) {
				processNewFormat(action);
			} else {
				processLegacyFormat(action);
			}
		}
	}

	private Boolean isNewFormat(String actionData) {
		// Detect data format version
		return actionData != null && actionData.contains('"version"');
	}
}
```

## See Also

-   [Creating Your First Processor](./Creating-Your-First-Processor) - Implementation tutorial
-   [Error Handling and Retry Logic](./Error-Handling-and-Retry-Logic) - Error handling patterns
-   [Plugin Framework](./Plugin-Framework) - Extensibility patterns
-   [Monitoring & Troubleshooting](./Monitoring-and-Troubleshooting) - Operational guidance
