The Template Async Action Flow is a pre-built Flow template that demonstrates the proper structure for creating Flow-based async action processors. It serves as a starting point for declarative async action implementations.

## Overview

This template flow provides the correct input/output variable structure and basic processing logic required for Flow processors. You can clone and customize it to create your own Flow-based async action processors without writing Apex code.

## Input/Output Variables

The template includes the required variables that the framework expects:

### Input Variables

| Variable Name | Data Type                   | Required | Description                             |
| ------------- | --------------------------- | -------- | --------------------------------------- |
| `asyncAction` | AsyncAction\_\_c            | Yes      | The async action record being processed |
| `settings`    | AsyncActionProcessor\_\_mdt | Yes      | Processor configuration settings        |

### Output Variables

| Variable Name | Data Type        | Required | Description                                         |
| ------------- | ---------------- | -------- | --------------------------------------------------- |
| `asyncAction` | AsyncAction\_\_c | Yes      | Updated async action record with processing results |

## Flow Structure

The template implements the basic required pattern. Subscribers should add their business logic **before** the 'Set Status = Completed' step.

**Important**: Each run of the flow should **either** end with setting the action's status to 'Completed', or call the `Handle Async Action Failures` invocable.

### Basic Pattern

```
1. [Your business logic here]
2. Decision - Check if processing succeeded
   → Success: Set asyncAction.Status__c = "Completed"
   → Failure: Call "Handle Async Action Failures" invocable
3. Output Assignment - Return the updated asyncAction record
```

## Customization Steps

### Step 1: Clone the Template

1. Navigate to **Setup → Flows**
2. Find "Template Async Action Flow"
3. Clone the flow with a new name
4. Set API Name to match your processor metadata

### Step 2: Add Business Logic

Replace the basic template logic with your actual business requirements before the status assignment:

#### Example: Create Follow-up Task

```
1. Get Records - Query Account using asyncAction.RelatedRecordId__c
2. Assignment - Build Task record with account details
3. Create Records - Insert the Task
4. Decision - Check if Task creation succeeded
   → Success: Set asyncAction.Status__c = "Completed"
   → Failure: Call "Handle Async Action Failures" invocable
```

## Considerations

### JSON Data Limitations

Flow doesn't offer great support for JSON manipulation. If an action requires additional context beyond a `RelatedRecordId__c`, consider using an Apex processor instead for complex data handling.

### Flow Performance

-   Your flow receives one action per execution
-   Framework may run your flow multiple times in parallel
-   Flow governor limits apply to the cumulative execution
-   Design your flow to be efficient for repeated execution

## See Also

-   [Core Concepts](./Core-Concepts) - Framework architecture overview
-   [Creating Your First Processor](./Creating-Your-First-Processor) - Apex processor implementation
-   [AsyncActions.Processor Interface](./AsyncActions.Processor-Interface) - Technical interface details
