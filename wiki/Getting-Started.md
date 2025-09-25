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

The framework includes the `AsyncActionAdministrator` permission set for users who need to monitor, retry, and manually intervene with async actions. **Note: This permission set is NOT required for end users to trigger or execute async actions.**

Assign it to users who need administrative access:

```sh
sf org assign permset -n AsyncActionAdministrator
```

Or assign via Setup → Users → Permission Sets in the Salesforce UI.

## Your First Async Action

For a complete guide on creating your first async action with step-by-step instructions, see [Creating Your First Processor](./Creating-Your-First-Processor).

## Next Steps

Once you've completed the installation, here's what to explore:

### Learn Core Concepts

-   [Core Concepts](./Core-Concepts) - Understand the framework architecture

### Explore Advanced Features

-   [Flow Integration](./Template-Async-Action-Flow) - Create processors using Flows
-   [Error Handling](./Error-Handling-and-Retry-Logic) - Advanced error handling patterns

### Review Objects and Classes

-   [AsyncAction\_\_c Object](./AsyncAction-Custom-Object) - Understanding the core data model
-   [AsyncActions Class](./AsyncActions-Class) - The main framework class

## Common Issues

### "Processor not found" Error

-   Verify your processor class name exactly matches the **Processor** field in the metadata
-   Ensure the processor class is public and has a public no-argument constructor
-   Check that the processor implements `AsyncActions.Processor`

### Actions Stay "Pending"

-   Verify the processor metadata record is **Enabled**
-   Check that the **Processor Name** on the action matches the metadata **DeveloperName**
-   If **Run On Insert** is disabled, you may need to manually trigger processing
