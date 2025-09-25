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

The framework includes the `AsyncActionAdministrator` permission set for admin users who need to monitor, retry, and manually intervene with async actions. This permission set is not required for end users to trigger or execute async actions.

Assign it to users who need administrative access:

```sh
sf org assign permset -n AsyncActionAdministrator
```

Or assign via Setup → Users → Permission Sets in the Salesforce UI.

## Next Steps

Once you've completed the installation, explore [Core Concepts](./Core-Concepts) to better understand the framework architecture. Then, create your first async action with step-by-step instructions: [Creating Your First Processor](./Creating-Your-First-Processor).
