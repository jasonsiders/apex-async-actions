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

### 1. Creation

```apex
AsyncAction__c action = AsyncActions.initAction(settings, recordId, data);
insert action;  // Status: "Pending"
```

### 2. Processing

-   The `AsyncActionJob` queries for pending actions
-   Actions are processed in batches according to configuration
-   Your processor implementation receives the batch and executes business logic

### 3. Completion

Actions end in one of four states:

-   **Completed** - Successfully processed
-   **Failed** - Permanently failed (no retries remaining)
-   **Canceled** - Manually canceled by a user
-   **Pending** - Still awaiting processing or retry

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

**Requirements:**

-   Must implement `AsyncActions.Processor`
-   Must have a public no-argument constructor
-   Framework uses `Type.forName()` for dynamic instantiation

### Flow Processors

Flow processors use Salesforce Flows for business logic:

-   The framework uses `AsyncActionFlowProcessor` as a wrapper
-   Flows must have specific input/output variables
-   Uses `Invocable.Action` for automatic bulkification
-   Ideal for declarative logic and non-developers

## Data Context and Relationships

AsyncAction records can carry context information to your processors:

### RelatedRecordId\_\_c

Links the action to any Salesforce record:

```apex
AsyncAction__c action = AsyncActions.initAction(settings, accountId);
// Later in processor:
Id accountId = (Id) action.RelatedRecordId__c;
```

### Data\_\_c

Stores custom serialized data structures:

```apex
Map<String, Object> customData = new Map<String, Object>{
    'amount' => 1000,
    'type' => 'premium'
};
AsyncAction__c action = AsyncActions.initAction(settings, recordId, JSON.serialize(customData));

// Later in processor:
Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(action.Data__c);
```

## Error Handling and Retry Logic

The framework provides sophisticated error handling through the `AsyncActions.Failure` class:

### Retry Behaviors

1. **ALLOW_RETRY** (default)

    - Actions retry until retries are exhausted
    - Then marked as "Failed"

2. **KEEP_ALIVE**

    - Actions never fail permanently
    - Continue retrying indefinitely
    - Use with caution

3. **SUDDEN_DEATH**
    - Actions fail immediately
    - No retries regardless of configuration

### Error Handling Example

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

## Batch Processing

The framework processes actions in configurable batches:

-   **Batch Size** controls how many actions are processed per job execution
-   Larger batches = better efficiency but higher risk of hitting limits
-   Smaller batches = more granular but more job executions
-   Default recommendation: 10-50 actions per batch

## Configuration Through Metadata

All processor behavior is controlled through `AsyncActionProcessor__mdt` records:

| Field             | Purpose                               |
| ----------------- | ------------------------------------- |
| **Processor**     | Class name or Flow API name           |
| **ProcessorType** | "Apex" or "Flow"                      |
| **Enabled**       | Controls whether the processor runs   |
| **BatchSize**     | Number of actions per execution       |
| **Retries**       | Default retry count for new actions   |
| **RetryInterval** | Minutes between retry attempts        |
| **RunOnInsert**   | Auto-process when actions are created |

## Job Execution Patterns

### Immediate Execution

When `RunOnInsert` is enabled:

```
Insert AsyncAction__c → Trigger → AsyncActionJob queued → Processing
```

### Scheduled Execution

Using `AsyncActionScheduledJob__mdt`:

```
Scheduled Job → AsyncActionSchedulable → AsyncActionJob → Processing
```

### Manual Execution

Using `AsyncActionLauncher`:

```apex
AsyncActionLauncher launcher = new AsyncActionLauncher();
Id jobId = launcher.launch(settings);
```

## Platform Event Integration

The framework includes `AsyncActionStart__e` platform events for:

-   Triggering processing from external systems
-   Bulk action creation
-   Cross-org communication

## Best Practices

### Design Principles

1. **Idempotent Operations** - Ensure processors can safely retry
2. **Bulk-Friendly Logic** - Design for batch processing from the start
3. **Graceful Degradation** - Handle partial failures appropriately
4. **Proper Error Handling** - Use the `Failure` class for custom error logic

### Performance Considerations

1. **Governor Limits** - Design for Salesforce's execution limits
2. **Batch Size Tuning** - Start with smaller batches and increase as needed
3. **SOQL Optimization** - Use selective queries in your processors
4. **DML Optimization** - Bulk operations whenever possible

### Monitoring and Observability

1. **Status Tracking** - Always update action status appropriately
2. **Error Logging** - Use the built-in logging framework
3. **Custom Monitoring** - Build dashboards and reports for operational visibility
4. **Performance Metrics** - Track processing times and failure rates

## Next Steps

Now that you understand the core concepts:

1. [Create Your First Processor](./Creating-Your-First-Processor) - Hands-on implementation guide
2. [Object Documentation](./AsyncAction-Custom-Object) - Detailed field-level information
3. [Class Documentation](./AsyncActions-Class) - Complete API reference
