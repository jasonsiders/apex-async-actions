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
		try {
			// Collect account IDs
			Set<Id> accountIds = new Set<Id>();
			for (AsyncAction__c action : actions) {
				if (action.RelatedRecordId__c != null) {
					accountIds.add((Id) action.RelatedRecordId__c);
				}
			}

			// Query accounts
			Map<Id, Account> accountMap = new Map<Id, Account>(
				[SELECT Id, Name, OwnerId FROM Account WHERE Id IN :accountIds]
			);

			// Create tasks
			List<Task> tasksToInsert = new List<Task>();
			for (AsyncAction__c action : actions) {
				Id accountId = (Id) action.RelatedRecordId__c;
				Account account = accountMap.get(accountId);

				if (account != null) {
					// Parse custom data with defaults
					String subject = 'Follow up with ' + account.Name;
					String priority = 'Normal';
					Integer daysFromNow = 7;

					if (String.isNotBlank(action.Data__c)) {
						Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(action.Data__c);
						subject = (String) data.get('subject') ?? subject;
						priority = (String) data.get('priority') ?? priority;
						daysFromNow = (Integer) data.get('daysFromNow') ?? daysFromNow;
					}

					// Create task
					tasksToInsert.add(
						new Task(
							WhatId = account.Id,
							OwnerId = account.OwnerId,
							Subject = subject,
							Priority = priority,
							Status = 'Not Started',
							ActivityDate = Date.today().addDays(daysFromNow)
						)
					);

					action.Status__c = 'Completed';
				}
			}

			// Insert tasks
			if (!tasksToInsert.isEmpty()) {
				insert tasksToInsert;
			}
		} catch (Exception e) {
			new AsyncActions.Failure(settings).fail(actions, e);
		}
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

Create a simple test action:

```apex
// Get the processor configuration
AsyncActionProcessor__mdt settings = AsyncActionTestUtils.createProcessor('Account_Followup_Processor');

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

## Step 5: Add Unit Tests

Create comprehensive test coverage for your processor:

```apex
@IsTest
public class AccountFollowupProcessorTest {
	@IsTest
	static void testBasicProcessing() {
		// Setup test data
		Account testAccount = new Account(Name = 'Test Account');
		insert testAccount;

		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.createProcessor('Account_Followup_Processor');
		AsyncAction__c action = AsyncActions.initAction(settings, testAccount.Id);
		insert action;

		// Test processing
		Test.startTest();
		new AccountFollowupProcessor().process(settings, new List<AsyncAction__c>{ action });
		Test.stopTest();

		// Verify results
		action = [SELECT Status__c FROM AsyncAction__c WHERE Id = :action.Id];
		System.assertEquals('Completed', action.Status__c);

		List<Task> tasks = [SELECT Id, Subject FROM Task WHERE WhatId = :testAccount.Id];
		System.assertEquals(1, tasks.size());
		System.assert(tasks[0].Subject.contains('Test Account'));
	}
}
```
