The `AsyncActionGlobalSetting__mdt` custom metadata type defines package-wide behavior for the async actions framework. It controls global settings that affect all processors and framework operations.

Async Action Global Setting records establish framework defaults that apply across all processors. These settings provide centralized control over logging and execution timing.

## Purpose and Usage

Async Action Global Setting records define:

1. **Logging Configuration** - Custom logger implementation for framework-wide logging
2. **Default Delay Settings** - Global default for queueable job delays across all processors
3. **Framework Behavior** - Controls that affect all async action processing

## Field Reference

| Field API Name      | Label            | Data Type   | Required | Default | Description                                                                                                                    |
| ------------------- | ---------------- | ----------- | -------- | ------- | ------------------------------------------------------------------------------------------------------------------------------ |
| `DeveloperName`     | API Name         | Text(40)    | Yes      | -       | Unique identifier for the global settings                                                                                      |
| `MasterLabel`       | Label            | Text(40)    | Yes      | -       | Human-readable name for the settings                                                                                           |
| `LoggerPlugin__c`   | Logger Plugin    | Text(255)   | No       | -       | Fully qualified name of custom logger implementation that implements AsyncActionLogger.Adapter                                 |
| `DelayInMinutes__c` | Delay (Minutes)  | Number(18,0) | No       | 0       | Default number of minutes to delay before enqueueing new jobs across all processors. Individual processors may override this. |

## Configuration

1. Navigate to **Setup → Custom Metadata Types → Async Action Global Setting → Manage Records**
2. Create or edit the global settings record
3. Set the **Logger Plugin** field to your custom logger class name (must implement `AsyncActionLogger.Adapter`)
4. Set the **Delay (Minutes)** field to control default queueable delay timing (set to 0 for immediate execution)
5. Save the record

**Note**: If no Async Action Global Setting record exists or no logger plugin is specified, the framework uses `System.debug()` for all logging.

## Delay Configuration

The `DelayInMinutes__c` field controls how long the framework waits before enqueueing queueable jobs. This setting addresses scenarios where orgs have configured org-wide default delays for queueable jobs:

- **Default**: `0` (no delay - immediate execution)
- **Override**: Individual processors can override this via `AsyncActionProcessor__mdt.DelayInMinutes__c`
- **Purpose**: Ensures the framework controls its own timing instead of inheriting org-wide defaults

When set to `0`, the framework explicitly requests immediate execution, bypassing any org-wide default delay settings.

## Best Practices

- **Logger Implementation** - Use a custom logger that implements the `AsyncActionLogger.Adapter` interface for production monitoring
- **Delay Configuration** - Set to `0` unless you have a specific need to delay all async processing
- **Single Record** - Only one global settings record should exist per org

## Related Objects

- [AsyncActionProcessor\_\_mdt](./The-AsyncActionProcessor__mdt-Custom-Metadata-Type) - Processor-specific configurations that can override global settings
- [AsyncAction\_\_c](./The-AsyncAction__c-Object) - Records processed according to these global settings

---
