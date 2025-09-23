# Getting Started

This guide will walk you through installing and setting up `apex-async-actions` in your Salesforce org, then creating your first asynchronous processor.

## Prerequisites

Before installing `apex-async-actions`, ensure you have:

-   A Salesforce org (Production, Sandbox, Developer Edition, or Scratch Org)
-   Sufficient administrative privileges to install packages and assign permission sets
-   The Salesforce CLI (recommended for installation)

## Installation

### Step 1: Install the Package

`apex-async-actions` is distributed as an unlocked package. Find the latest version in the [GitHub Releases](https://github.com/jasonsiders/apex-async-actions/releases) page.

Install using the Salesforce CLI:

```sh
sf package install --package 04tXXXXXXXXXXXXXX --wait 10
```

Replace `04tXXXXXXXXXXXXXX` with the actual package version ID from the releases page.

Alternatively, you can install via the Salesforce UI by visiting:

```
https://login.salesforce.com/packaging/installPackage.apexp?p0=04tXXXXXXXXXXXXXX
```

### Step 2: Assign Permissions

The framework includes the `AsyncActionAdministrator` permission set that grants access to all async action objects and features.

Assign it to yourself and any users who need to work with async actions:

```sh
sf org assign permset -n AsyncActionAdministrator
```

Or assign via Setup → Users → Permission Sets in the Salesforce UI.

### Step 3: Verify Installation

1. Navigate to **Setup → Apps → App Manager**
2. Confirm you see the "Async Actions" app
3. Switch to the "Async Actions" app using the app launcher
4. Verify you can see the "Async Actions" tab

## Your First Async Action

Let's create a simple async action that logs a message. This will demonstrate the core concepts and workflow.

### Step 1: Create a Processor Class

Create a new Apex class in your org:

```apex
public class WelcomeProcessor implements AsyncActions.Processor {
	public void process(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions) {
		for (AsyncAction__c action : actions) {
			// Get any custom data from the action
			String message = action.Data__c ?? 'Hello from Async Actions!';

			// Log the message
			System.debug('Processing action: ' + message);

			// Mark the action as completed
			action.Status__c = 'Completed';
		}
		// The framework automatically updates the actions after this method completes
	}
}
```

### Step 2: Create Processor Configuration

Navigate to **Setup → Custom Metadata Types → Async Action Processor → Manage Records** and create a new record:

-   **Label**: Welcome Processor
-   **Async Action Processor Name**: Welcome_Processor
-   **Processor**: WelcomeProcessor
-   **Processor Type**: Apex
-   **Enabled**: Checked
-   **Batch Size**: 10
-   **Retries**: 3
-   **Retry Interval**: 5
-   **Run On Insert**: Checked

![Sample Processor Configuration](../media/sample_processor_config.png)

### Step 3: Create an Async Action

Now create an async action record to test your processor. You can do this in several ways:

**Option A: Using the UI**

1. Go to the Async Actions tab
2. Click "New"
3. Set **Processor Name** to "Welcome_Processor"
4. Set **Data** to "My first async action!"
5. Save the record

**Option B: Using Apex in Developer Console**

```apex
AsyncActionProcessor__mdt settings = AsyncActionProcessor__mdt.getInstance('Welcome_Processor');
AsyncAction__c action = AsyncActions.initAction(settings, null, 'My first async action!');
insert action;
```

### Step 4: Monitor Execution

Since you enabled "Run On Insert", the action should process automatically within a few seconds. Monitor the execution:

1. Refresh the Async Action record
2. Check that the **Status** changed from "Pending" to "Completed"
3. Check the debug logs in Developer Console for your message

## Next Steps

Congratulations! You've successfully created and executed your first async action. Here's what to explore next:

### Learn Core Concepts

-   [Core Concepts](./Core-Concepts) - Understand the framework architecture
-   [Error Handling](./Error-Handling-and-Retry-Logic) - Learn about retry behaviors and failure handling

### Explore Advanced Features

-   [Flow Integration](./Flow-TemplateAsyncActionFlow) - Create processors using Flows
-   [Scheduled Jobs](./Scheduled-Job-Configuration) - Set up recurring processing
-   [Monitoring](./Monitoring-and-Troubleshooting) - Track and troubleshoot your actions

### Review Objects and Classes

-   [AsyncAction\_\_c Object](./Object-AsyncAction) - Understanding the core data model
-   [AsyncActions Class](./The-AsyncActions-Class) - The main framework class
-   [AsyncActionJob Class](./The-AsyncActionJob-Class) - How processing works under the hood

## Common Issues

### "Processor not found" Error

-   Verify your processor class name exactly matches the **Processor** field in the metadata
-   Ensure the processor class is public and has a public no-argument constructor
-   Check that the processor implements `AsyncActions.Processor`

### Actions Stay "Pending"

-   Verify the processor metadata record is **Enabled**
-   Check that the **Processor Name** on the action matches the metadata **DeveloperName**
-   If **Run On Insert** is disabled, you may need to manually trigger processing

### Permission Issues

-   Ensure users have the `AsyncActionAdministrator` permission set
-   Check object and field-level security for `AsyncAction__c` and related objects

## Support

For additional help:

-   Review the [Best Practices](./Best-Practices) guide
-   Check the [Monitoring and Troubleshooting](./Monitoring-and-Troubleshooting) documentation
-   Review example implementations in the package
