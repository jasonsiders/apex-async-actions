The `AsyncActionProcessor__mdt` custom metadata type governs the configuration of specific async action processor implementations. Each record defines how a processor behaves, including execution parameters, retry logic, and performance settings.

## Overview

AsyncActionProcessor metadata records serve as the configuration backbone for the async actions framework. They control every aspect of processor behavior, from basic settings like batch size to advanced features like automatic retry intervals.

## Purpose and Usage

AsyncActionProcessor records define:

1. **Processor Implementation** - Links to the Apex class or Flow that contains processing logic
2. **Execution Control** - Determines when and how the processor runs
3. **Performance Settings** - Controls batch sizes and processing limits
4. **Error Handling** - Configures retry behavior and failure management
5. **Operational Parameters** - Sets intervals, timeouts, and other operational aspects

## Field Reference

| Field API Name     | Label           | Data Type      | Required | Default | Description                                            | Details                                                                                              |
| ------------------ | --------------- | -------------- | -------- | ------- | ------------------------------------------------------ | ---------------------------------------------------------------------------------------------------- |
| `DeveloperName`    | API Name        | Text(40)       | Yes      | -       | Unique identifier for the processor configuration      | Must be unique; used in AsyncAction.ProcessorName\_\_c; case-sensitive; cannot change after creation |
| `MasterLabel`      | Label           | Text(40)       | Yes      | -       | Human-readable name for the processor                  | Displayed in UI; can be changed                                                                      |
| `Processor__c`     | Processor       | Text(255)      | Yes      | -       | Fully qualified name of the Apex class or Flow         | Must match existing class/flow name exactly; case-sensitive                                          |
| `ProcessorType__c` | Processor Type  | Picklist       | Yes      | Apex    | Whether the processor is implemented in Apex or Flow   | Values: 'Apex', 'Flow'                                                                               |
| `Enabled__c`       | Enabled         | Checkbox       | No       | true    | Controls whether this processor can execute            | Disabled processors are skipped                                                                      |
| `BatchSize__c`     | Batch Size      | Number(18,0)   | Yes      | 200     | Number of AsyncAction records to process per execution | Start with 200+ and adjust based on processor requirements                                           |
| `Retries__c`       | Retries         | Number(18,0)   | No       | 0       | Default number of retry attempts for new actions       | Applied to new actions; individual actions can override                                              |
| `RetryInterval__c` | Retry Interval  | Number(18,0)   | No       | 5       | Minutes to wait between retry attempts                 | Minimum time before retry; actual time may be longer                                                 |
| `RunOnInsert__c`   | Run On Insert   | Checkbox       | No       | false   | Whether to automatically process actions when inserted | Triggers immediate processing via trigger                                                            |
| `MaxStackDepth__c` | Max Stack Depth | Number(18,0)   | No       | 1       | Maximum recursion depth for chained processing         | Prevents infinite recursion                                                                          |
| `Data__c`          | Data            | Long Text Area | No       | -       | Custom configuration data for the processor            | Can store JSON or other structured data                                                              |
| `Description__c`   | Description     | Long Text Area | No       | -       | Documentation about the processor's purpose            | Operational documentation                                                                            |

## Configuration Patterns

### High-Volume Batch Processing

For processors that handle large volumes of data efficiently:

```
BatchSize: 200
Retries: 2
RetryInterval: 5
RunOnInsert: ✗
MaxStackDepth: 1
```

### Real-Time Processing

For processors that need immediate response:

```
BatchSize: 50
Retries: 3
RetryInterval: 1
RunOnInsert: ✓
MaxStackDepth: 0
```

### Reliable Data Integration

For processors interfacing with external systems:

```
BatchSize: 100
Retries: 5
RetryInterval: 10
RunOnInsert: ✗
MaxStackDepth: 0
```

## Best Practices

### Performance Optimization

1. **Start with larger batch sizes (200+)** - Begin with higher batch sizes and adjust based on processing requirements
2. **Monitor Limits** - Watch for governor limit exceptions in debug logs
3. **Profile Performance** - Measure actual processing times and adjust accordingly
4. **Consider Complexity** - Reduce batch size for processor-intensive operations

### Reliability Configuration

1. **Appropriate Retries** - Set retry counts based on expected failure patterns
2. **Reasonable Intervals** - Allow enough time for transient issues to resolve
3. **Enable Monitoring** - Use description fields to document expected behavior
4. **Test Thoroughly** - Validate configuration under realistic load conditions

### Operational Management

1. **Descriptive Names** - Use clear, consistent naming conventions
2. **Document Purpose** - Fill in description fields with operational details
3. **Version Control** - Track configuration changes in source control
4. **Environment Sync** - Keep configurations consistent across environments

## Related Objects

-   [AsyncAction\_\_c](./AsyncAction-Custom-Object) - Records that reference these configurations
-   [AsyncActionScheduledJobItem\_\_mdt](./AsyncActionScheduledJobItem-Custom-Metadata-Type) - Scheduled execution of processors
-   [AsyncActionGlobalSetting\_\_mdt](./AsyncActionGlobalSetting-Custom-Metadata-Type) - Framework-wide settings

## See Also

-   [Creating Your First Processor](./Creating-Your-First-Processor) - Step-by-step processor creation guide
-   [Core Concepts](./Core-Concepts) - Framework architecture overview
