The `AsyncActionProcessor__mdt` custom metadata type governs the configuration of specific async action processor implementations. Each record defines how a processor behaves, including execution parameters, retry logic, and performance settings.

Async Action Processor metadata records serve as the configuration backbone for the async actions framework. They control every aspect of processor behavior, from basic settings like batch size to advanced features like automatic retry intervals.

## Purpose and Usage

Async Action Processor records define:

1. **Processor Implementation** - Links to the Apex class or Flow that contains processing logic
2. **Execution Control** - Determines when and how the processor runs
3. **Performance Settings** - Controls batch sizes and processing limits
4. **Error Handling** - Configures retry behavior and failure management
5. **Operational Parameters** - Sets intervals, retries, and other operational aspects

## Field Reference

| Field API Name      | Label            | Data Type      | Required | Default | Description                                                         |
| ------------------- | ---------------- | -------------- | -------- | ------- | ------------------------------------------------------------------- |
| `DeveloperName`     | API Name         | Text(40)       | Yes      | -       | Unique identifier for the processor configuration                   |
| `MasterLabel`       | Label            | Text(40)       | Yes      | -       | Human-readable name for the processor                               |
| `Processor__c`      | Processor        | Text(255)      | Yes      | -       | Fully qualified name of the Apex class or Flow                      |
| `ProcessorType__c`  | Processor Type   | Picklist       | Yes      | Apex    | Whether the processor is implemented in Apex or Flow                |
| `Enabled__c`        | Enabled          | Checkbox       | No       | true    | Controls whether this processor can execute                         |
| `BatchSize__c`      | Batch Size       | Number(18,0)   | Yes      | 200     | Number of AsyncAction records to process per execution              |
| `Retries__c`        | Retries          | Number(18,0)   | No       | 0       | Default number of retry attempts for new actions                    |
| `RetryInterval__c`  | Retry Interval   | Number(18,0)   | No       | 5       | Minutes to wait between retry attempts                              |
| `RunOnInsert__c`    | Run On Insert    | Checkbox       | No       | false   | Whether to automatically process actions when inserted              |
| `MaxStackDepth__c`  | Max Stack Depth  | Number(18,0)   | No       | 1       | Maximum recursion depth for chained processing                      |
| `DelayInMinutes__c` | Delay In Minutes | Number(2,0)    | No       | -       | Override delay in minutes before enqueueing jobs (overrides global) |
| `Data__c`           | Data             | Long Text Area | No       | -       | Custom configuration data for the processor                         |
| `Description__c`    | Description      | Long Text Area | No       | -       | Documentation about the processor's purpose                         |

## Delay Configuration

The `DelayInMinutes__c` field controls the delay before enqueueing queueable jobs for this specific processor:

- **Default**: When blank, inherits the value from `AsyncActionGlobalSetting__mdt.DelayInMinutes__c`
- **Override**: Set to `0` for immediate execution, or a specific number of minutes to delay
- **Purpose**: Ensures the processor controls its own timing instead of inheriting org-wide defaults

This setting is particularly useful when:
- Your org has configured org-wide default delays for queueable jobs
- You need different timing behavior for different processors
- You want to prioritize certain processors over others

## Best Practices

-   **Start with larger batch sizes (200+)** - Begin with higher batch sizes and adjust based on processing requirements
-   **Monitor Limits** - Watch for governor limit exceptions in debug logs
-   **Profile Performance** - Measure actual processing times and adjust accordingly
-   **Consider Complexity** - Reduce batch size for processor-intensive operations
-   **Appropriate Retries** - Set retry counts based on expected failure patterns
-   **Reasonable Intervals** - Allow enough time for transient issues to resolve
-   **Delay Configuration** - Set to `0` for time-sensitive processors, or use a delay for lower-priority background work

## Related Objects

-   [AsyncAction\_\_c](./The-AsyncAction__c-Object) - Records that reference these configurations
-   [AsyncActionScheduledJobItem\_\_mdt](./The-AsyncActionScheduledJobItem__mdt-Custom-Metadata-Type) - Scheduled execution of processors
-   [AsyncActionGlobalSetting\_\_mdt](./The-AsyncActionGlobalSetting__mdt-Custom-Metadata-Type) - Framework-wide settings

---
