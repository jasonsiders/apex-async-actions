The `AsyncActionJob` class is the queueable that orchestrates the processing of async actions in bulk.

## Overview

`AsyncActionJob` implements the `Queueable` interface and serves as the execution engine for async action processors. It handles batching, error recovery, and processor lifecycle management.

## Key Features

-   **Bulk Processing** - Processes multiple actions in configurable batch sizes
-   **Error Recovery** - Uses Finalizer pattern for robust error handling
-   **Processor Loading** - Dynamically instantiates processor implementations
-   **Governor Limit Management** - Respects Salesforce execution limits
-   **Automatic Chaining** - Chains additional jobs when more work is available

## Architecture

```
AsyncActionLauncher → AsyncActionJob → Processor Implementation
                           ↓
                     AsyncActionJobFinalizer
```

## Execution Flow

1. **Job Initialization** - Loads processor configuration and pending actions
2. **Batch Processing** - Groups actions according to batch size limits
3. **Processor Execution** - Calls the configured processor implementation
4. **Result Handling** - Updates action records with processing results
5. **Error Recovery** - Finalizer handles any uncaught exceptions
6. **Job Chaining** - Queues additional jobs if more work remains

## Configuration

Job behavior is controlled by `AsyncActionProcessor__mdt` settings:

-   **BatchSize\_\_c** - Number of actions processed per job execution
-   **MaxJobs\_\_c** - Maximum concurrent jobs for this processor
-   **Enabled\_\_c** - Whether the processor can be executed

## Error Handling

The job uses a two-tier error handling approach:

### Primary Error Handling

-   Processors handle business logic errors using `AsyncActions.Failure`
-   Individual action failures don't stop batch processing

### Finalizer Error Handling

-   `AsyncActionJobFinalizer` catches system-level failures
-   Ensures actions aren't lost due to uncaught exceptions
-   Provides audit trail for system errors

## Performance Considerations

-   **Batch Size Tuning** - Balance throughput vs. governor limits
-   **Concurrent Job Limits** - Prevent resource exhaustion
-   **Selective Processing** - Query only necessary fields
-   **Bulk DML Operations** - Update actions efficiently

## Monitoring

Monitor job execution through:

-   Apex Jobs queue in Setup
-   AsyncAction\_\_c record status updates
-   System debug logs
-   Custom logging (if configured)

## See Also

-   [AsyncActionLauncher Class](./AsyncActionLauncher-Class) - Job creation and management
-   [AsyncActions Class](./AsyncActions-Class) - Core framework utilities
-   [AsyncActionProcessor Custom Metadata Type](./AsyncActionProcessor-Custom-Metadata-Type) - Configuration details
