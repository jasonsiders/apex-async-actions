This tutorial walks you through creating a complete async action processor from start to finish. We'll build a processor that creates follow-up tasks for accounts, demonstrating common patterns and best practices.

## Scenario

Let's create an "Account Follow-up Processor" that:

-   Creates a follow-up task for each account
-   Uses custom data to set task priorities and subjects
-   Handles errors gracefully with retry logic
-   Demonstrates both success and failure scenarios

## Step 1: Create the Processor Class

Create a new Apex class called `AccountFollowupProcessor`:

```apex
public class AccountFollowupProcessor implements AsyncActions.Processor {
	public void process(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions) {
		// Collect all account IDs from the actions
		Set<Id> accountIds = new Set<Id>();
		for (AsyncAction__c action : actions) {
			if (action.RelatedRecordId__c != null) {
				accountIds.add(action.RelatedRecordId__c);
			}
		}

		// Query account information we need
		Map<Id, Account> accountMap = new Map<Id, Account>(
			[
				SELECT Id, Name, OwnerId
				FROM Account
				WHERE Id IN :accountIds
			]
		);

		// Process each action
		List<Task> tasksToInsert = new List<Task>();
		for (AsyncAction__c action : actions) {
			try {
				Task newTask = this.createTaskForAction(action, accountMap);
				if (newTask != null) {
					tasksToInsert.add(newTask);
					action.Status__c = 'Completed';
				}
			} catch (Exception error) {
				// Handle individual action failures
				new AsyncActions.Failure(settings).fail(action, 'Failed to create task: ' + error.getMessage());
			}
		}

		// Insert all tasks at once for efficiency
		if (!tasksToInsert.isEmpty()) {
			List<Database.SaveResult> results = Database.insert(tasksToInsert, false);
			this.handleInsertResults(results, actions, settings);
		}
	}

	private Task createTaskForAction(AsyncAction__c action, Map<Id, Account> accountMap) {
		Id accountId = action.RelatedRecordId__c;
		Account account = accountMap.get(accountId);

		if (account == null) {
			throw new IllegalArgumentException('Account not found: ' + accountId);
		}

		// Parse custom data if provided
		FollowupData followupData = this.parseFollowupData(action.Data__c);

		// Create the task
		Task followupTask = new Task();
		followupTask.WhatId = accountId;
		followupTask.OwnerId = account.OwnerId;
		followupTask.Subject = followupData.subject.replace('{AccountName}', account.Name);
		followupTask.Priority = followupData.priority;
		followupTask.Status = 'Not Started';
		followupTask.ActivityDate = Date.today().addDays(followupData.daysFromNow);

		return followupTask;
	}

	private FollowupData parseFollowupData(String dataJson) {
		FollowupData data = new FollowupData();

		if (String.isNotBlank(dataJson)) {
			try {
				Map<String, Object> dataMap = (Map<String, Object>) JSON.deserializeUntyped(dataJson);
				data.subject = (String) dataMap.get('subject');
				data.priority = (String) dataMap.get('priority');
				data.daysFromNow = (Integer) dataMap.get('daysFromNow');
			} catch (Exception e) {
				// Use defaults if JSON parsing fails
				System.debug('Failed to parse action data, using defaults: ' + e.getMessage());
			}
		}

		return data;
	}

	private void handleInsertResults(
		List<Database.SaveResult> results,
		List<AsyncAction__c> actions,
		AsyncActionProcessor__mdt settings
	) {
		for (Integer i = 0; i < results.size(); i++) {
			Database.SaveResult result = results[i];
			if (!result.isSuccess()) {
				// Find the corresponding action and mark it as failed
				AsyncAction__c failedAction = this.findActionForTaskIndex(i, actions);
				if (failedAction != null) {
					String errorMsg = 'Task creation failed: ' + result.getErrors()[0].getMessage();
					new AsyncActions.Failure(settings).fail(failedAction, errorMsg);
				}
			}
		}
	}

	private AsyncAction__c findActionForTaskIndex(Integer taskIndex, List<AsyncAction__c> actions) {
		// In this simple implementation, task order matches action order
		// In more complex scenarios, you might need a more sophisticated mapping
		Integer actionIndex = 0;
		for (AsyncAction__c action : actions) {
			if (action.Status__c == 'Completed') {
				if (actionIndex == taskIndex) {
					return action;
				}
				actionIndex++;
			}
		}
		return null;
	}

	// Helper class for parsing custom data
	private class FollowupData {
		public String subject = 'Follow up with {AccountName}';
		public String priority = 'Normal';
		public Integer daysFromNow = 7;
	}
}
```

## Step 2: Create the Processor Configuration

Navigate to **Setup → Custom Metadata Types → Async Action Processor → Manage Records** and create:

-   **Label**: Account Followup Processor
-   **Async Action Processor Name**: Account_Followup_Processor
-   **Processor**: AccountFollowupProcessor
-   **Processor Type**: Apex
-   **Enabled**: ✓ (checked)
-   **Batch Size**: 20
-   **Retries**: 3
-   **Retry Interval**: 10
-   **Run On Insert**: ✓ (checked)
-   **Description**: Creates follow-up tasks for accounts with customizable priorities and subjects

## Step 3: Test the Processor

### Test 1: Basic Functionality

Create a simple test action in Developer Console:

```apex
// Get the processor configuration
AsyncActionProcessor__mdt settings = AsyncActionProcessor__mdt.getInstance('Account_Followup_Processor');

// Get an account to test with
Account testAccount = [SELECT Id FROM Account LIMIT 1];

// Create a basic async action
AsyncAction__c action = AsyncActions.initAction(settings, testAccount.Id);
insert action;

// Check the result after a few seconds
System.debug('Action Status: ' + [SELECT Status__c FROM AsyncAction__c WHERE Id = :action.Id].Status__c);
```

### Test 2: Custom Data

Test with custom followup data:

```apex
AsyncActionProcessor__mdt settings = AsyncActionProcessor__mdt.getInstance('Account_Followup_Processor');
Account testAccount = [SELECT Id FROM Account LIMIT 1];

// Create custom followup data
Map<String, Object> followupData = new Map<String, Object>{
    'subject' => 'High priority follow-up with {AccountName}',
    'priority' => 'High',
    'daysFromNow' => 3
};

AsyncAction__c action = AsyncActions.initAction(
    settings,
    testAccount.Id,
    JSON.serialize(followupData)
);
insert action;
```

### Test 3: Error Handling

Test error scenarios by creating an action with an invalid account ID:

```apex
AsyncActionProcessor__mdt settings = AsyncActionProcessor__mdt.getInstance('Account_Followup_Processor');

// Use a fake account ID to trigger an error
AsyncAction__c action = AsyncActions.initAction(settings, '001000000000000');
insert action;

// This should result in a failed action with retry behavior
```

## Step 4: Monitor and Verify

### Check Task Creation

```sql
SELECT Id, Subject, Priority, WhatId, Status, ActivityDate
FROM Task
WHERE Subject LIKE '%Follow up%'
ORDER BY CreatedDate DESC
```

### Monitor Action Status

```sql
SELECT Id, Status__c, Error__c, Retries__c, ProcessorName__c, RelatedRecordId__c
FROM AsyncAction__c
WHERE ProcessorName__c = 'Account_Followup_Processor'
ORDER BY CreatedDate DESC
```

## Step 5: Add Bulk Testing

Test the processor with multiple actions:

```apex
AsyncActionProcessor__mdt settings = AsyncActionProcessor__mdt.getInstance('Account_Followup_Processor');

List<Account> accounts = [SELECT Id FROM Account LIMIT 10];
List<AsyncAction__c> actions = new List<AsyncAction__c>();

for (Account acc : accounts) {
    Map<String, Object> data = new Map<String, Object>{
        'subject' => 'Bulk follow-up with {AccountName}',
        'priority' => 'Normal',
        'daysFromNow' => 5
    };

    AsyncAction__c action = AsyncActions.initAction(
        settings,
        acc.Id,
        JSON.serialize(data)
    );
    actions.add(action);
}

insert actions;
```

## Key Concepts Demonstrated

This example illustrates several important patterns:

### 1. Bulk Processing

-   Query all related data once (accounts)
-   Process actions in a loop
-   Perform DML operations in bulk

### 2. Error Handling

-   Individual action failure handling
-   Bulk DML result processing
-   Graceful degradation when data parsing fails

### 3. Data Context Usage

-   `RelatedRecordId__c` for linking to accounts
-   `Data__c` for custom configuration parameters
-   JSON serialization/deserialization patterns

### 4. Resource Optimization

-   Single SOQL query for all accounts
-   Bulk insert for all tasks
-   Efficient error handling

## Best Practices Illustrated

1. **Defensive Programming**: Check for null values and handle exceptions
2. **Bulk Operations**: Process multiple records efficiently
3. **Clear Error Messages**: Provide meaningful error descriptions
4. **Flexible Configuration**: Use JSON data for customizable behavior
5. **Proper Status Management**: Update action status appropriately

## Next Steps

Now that you've built your first processor:

1. **Add Unit Tests**: Create comprehensive test coverage for your processor
2. **Explore Flow Processors**: Try implementing similar logic using Flows
3. **Advanced Error Handling**: Learn about different retry behaviors
4. **Scheduling**: Set up scheduled processing for accumulated actions
5. **Monitoring**: Create reports and dashboards for operational visibility

## Common Enhancements

Consider these improvements for production use:

-   **Logging**: Add detailed logging for troubleshooting
-   **Validation**: Validate input data more thoroughly
-   **Configuration**: Use custom settings for processor-specific configuration
-   **Notifications**: Send notifications when actions fail
-   **Metrics**: Track processing performance and success rates
