Understanding the core concepts of `apex-async-actions` is essential for effectively using the framework. This guide explains the fundamental architecture and patterns that drive the system.

## Framework Architecture

The `apex-async-actions` framework is built around several key components that work together to provide reliable asynchronous processing:

```
AsyncAction__c Records → AsyncActionJob → Processor Implementation
       ↓                      ↓                    ↓
   Work Items            Orchestrator         Business Logic
```

### Key Components

1. **AsyncAction\_\_c** - Individual work items representing tasks to be processed
2. **AsyncActionProcessor\_\_mdt** - Configuration metadata that controls processor behavior
3. **AsyncActionJob** - The queueable job that orchestrates processing
4. **Processor Implementation** - Your custom business logic (Apex class or Flow)

## The AsyncAction Lifecycle

Every async action follows a predictable lifecycle:

-   **1. Creation**: An Async Action record represents a single work item to be processed by the framework. You can create valid Async Action records using the [`AsyncActions.initAction`](./The-AsyncActions-Class#initaction) method in Apex, or the [`Init Async Action`](./The-Init-Async-Action-Invocable-Action) invocable action in Flows.
-   **2. Processing**: The `AsyncActionJob` queries for pending actions and processes them in batches according to configuration. Your processor implementation receives the batch and executes the business logic.
-   **3. Completion**: Actions end in one of four states:
    -   `Completed`: Successfully processed.
    -   `Failed`: Permanently failed with no retries remaining.
    -   `Canceled`: Manually canceled by a user.
    -   `Pending`: Still awaiting processing (or retry).

## Processor Types

The framework supports two types of processor implementations:

### Apex Processors

Apex processors implement the `AsyncActions.Processor` interface:

```apex
public class MyProcessor implements AsyncActions.Processor {
	public void process(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions) {
		// Your business logic here
		for (AsyncAction__c action : actions) {
			// Process the action
			action.Status__c = 'Completed';
		}
	}
}
```

Apex processors must implement the `AsyncActions.Processor` interface and have a public no-argument constructor. The framework uses `Type.forName()` for dynamic instantiation.

### Flow Processors

Flow processors use Salesforce Flows for business logic. Use the included [Flow Template](./The-Template-Async-Action-Flow) as a starting point; this includes the required inputs/outputs needed to function properly.

The framework uses `AsyncActionFlowProcessor` as a wrapper and flows must have specific input/output variables. Flow processors use `Invocable.Action` for automatic bulkification, making them ideal for declarative logic and non-developers.

## Data Context and Relationships

AsyncAction records can carry context information to your processors:

-   **RelatedRecordId\_\_c**: Links the action to any Salesforce record
-   **Data\_\_c**: Stores custom serialized data structures

```apex
Map<String, Object> customData = new Map<String, Object>{
    'amount' => 1000,
    'type' => 'premium'
};
AsyncAction__c action = AsyncActions.initAction(
    settings,
    someAccountId,
    JSON.serialize(customData)
);
// Later in processor:
Id accountId = (Id) action.RelatedRecordId__c;
Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(action.Data__c);
```

## Error Handling and Retry Logic

The framework provides sophisticated error handling using the [`AsyncActions.Failure`](./The-AsyncActions.Failure-Class) class and the [`AsyncActions.RetryBehavior`](./The-AsyncActions.RetryBehavior-Enum) enum.

```apex
public void process(AsyncActionProcessor__mdt settings, List<AsyncAction__c> actions) {
    try {
        // Your business logic
        performSomeOperation(actions);
        // Mark successful actions as completed
        for (AsyncAction__c action : actions) {
            action.Status__c = 'Completed';
        }
    } catch (Exception error) {
        // Handle failures with specific retry behavior
        new AsyncActions.Failure(settings, AsyncActions.RetryBehavior.ALLOW_RETRY)
            .fail(actions, error);
    }
}
```

## Configuration Through Metadata

All processor behavior is controlled through `AsyncActionProcessor__mdt` records:

| Field            | Purpose                               |
| ---------------- | ------------------------------------- |
| `Processor`      | Class name or Flow API name           |
| `Processor Type` | "Apex" or "Flow"                      |
| `Enabled`        | Controls whether the processor runs   |
| `Batch Size`     | Number of actions per execution       |
| `Retries`        | Default retry count for new actions   |
| `Retry Interval` | Minutes between retry attempts        |
| `Run On Insert`  | Auto-process when actions are created |

## Job Execution Patterns

The framework supports three primary patterns for initiating async job processing, each suited to different operational scenarios:

-   **Immediate Execution**: When `Run On Insert` is enabled, an instance of the processor job will start moments after the Async Action record is inserted. If any actions fail, they can still be retried through scheduled jobs.
-   **Scheduled Execution**: Use the [AsyncActionScheduledJob\_\_mdt](./The-AsyncActionScheduledJob__mdt-Custom-Metadata-Type) to configure scheduled jobs to run at some regular interval (hourly, semi-hourly, or using a custom cron expression). You can completely customize which async action processors are run by associating [AsyncActionScheduledJobItem\_\_mdt](./The-AsyncActionScheduledJobItem__mdt-Custom-Metadata-Type) records with a scheduled job record.
-   **Manual Execution**: Manually invoke a processor job at any time using the [AsyncActionLauncher](./The-AsyncActionLauncher-Class) class:

```apex
AsyncActionProcessor__mdt job = AsyncActionProcessor__mdt.getInstance('Some_Job');
Id jobId = new AsyncActionLauncher().launch(job);
```

In each of the above cases, the job will _only_ ever process [Async Action](./The-AsyncAction__c-Object.md) records with a _Status_ of "Pending", and a _Next Eligible At_ value in the past.
