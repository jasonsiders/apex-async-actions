This tutorial walks you through creating your first async action processor. We'll build a simple processor that creates follow-up tasks for accounts, demonstrating the basic framework pattern.

## Scenario

Let's create an "Account Follow-up Processor" that creates a follow-up task for each account. This example focuses on simplicity to show how easy it is to get started with the framework.

## Step 1: Create the Processor Class

Create a new Apex class called `AccountFollowupProcessor`:

```apex
public class AccountFollowupProcessor implements AsyncActions.Processor {
	public void process(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions) {
		// Get account IDs from the actions
		Set<Id> accountIds = new Set<Id>();
		for (AsyncAction__c action : actions) {
			accountIds.add(action.RelatedRecordId__c);
		}

		// Query the accounts we need
		Map<Id, Account> accountMap = new Map<Id, Account>(
			[
				SELECT Id, Name, OwnerId
				FROM Account
				WHERE Id IN :accountIds
			]
		);

		// Create tasks for each action
		List<Task> tasksToInsert = new List<Task>();
		for (AsyncAction__c action : actions) {
			Account account = accountMap.get(action.RelatedRecordId__c);
			if (account != null) {
				tasksToInsert.add(
					new Task(
						WhatId = account.Id,
						OwnerId = account.OwnerId,
						Subject = 'Follow up with ' + account.Name,
						Priority = 'Normal',
						Status = 'Not Started',
						ActivityDate = Date.today().addDays(7)
					)
				);
				action.Status__c = 'Completed';
			}
		}

		// Insert all tasks at once
		if (!tasksToInsert.isEmpty()) {
			insert tasksToInsert;
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
-   **Description**: Creates follow-up tasks for accounts

## Step 3: Test the Processor

Create a simple test action:

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

Create test coverage for your processor:

```apex
@IsTest
public class AccountFollowupProcessorTest {
	@IsTest
	static void testBasicProcessing() {
		// Setup test data
		Account testAccount = new Account(Name = 'Test Account');
		insert testAccount;

		AsyncActionProcessor__mdt settings = AsyncActionProcessor__mdt.getInstance('Account_Followup_Processor');
		AsyncAction__c action = AsyncActions.initAction(settings, testAccount.Id);

		// Test processing
		Test.startTest();
		new AccountFollowupProcessor().process(settings, new List<AsyncAction__c>{ action });
		Test.stopTest();

		// Verify results
		System.assertEquals('Completed', action.Status__c);

		List<Task> tasks = [SELECT Id, Subject FROM Task WHERE WhatId = :testAccount.Id];
		System.assertEquals(1, tasks.size());
		System.assert(tasks[0].Subject.contains('Test Account'));
	}
}
```

That's it! You've created your first async action processor. This simple example shows the basic pattern: implement the interface, process the actions in bulk, and mark them as completed.
