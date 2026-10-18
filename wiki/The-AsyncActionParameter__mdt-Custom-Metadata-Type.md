The `AsyncActionParameter__mdt` custom metadata type defines package-wide behavior for the async actions framework. Each record is a single named parameter, identified by its `DeveloperName`, with a text `Value__c`.

> _**Note**: This object is **optional**. You do not need to create any records to enable the framework's core functionality._

## Fields

| Field API Name   | Label       | Data Type             | Required | Description                                                     |
| ---------------- | ----------- | --------------------- | -------- | --------------------------------------------------------------- |
| `DeveloperName`  | API Name    | Text(40)              | Yes      | The unique name used by the framework to look up this parameter |
| `MasterLabel`    | Label       | Text(40)              | Yes      | A human-readable label for this parameter                       |
| `Value__c`       | Value       | Text(255)             | No       | The value of this parameter                                     |
| `Description__c` | Description | Long Text Area (1000) | No       | An optional description of what this parameter controls         |

## Available Parameters

The framework recognizes the following parameters. Any other `DeveloperName` values are ignored.

### `LoggerPlugin`

|                   |                                                                                                                                                                                                                                                  |
| ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Purpose**       | Routes the framework's internal logs to your preferred logging framework                                                                                                                                                                         |
| **Value**         | Fully qualified name of an Apex class that implements [`AsyncActionLogger.Adapter`](./The-AsyncActionLogger.Adapter-Interface), such as the bundled [`AsyncActionLogger.NebulaAdapter`](./The-AsyncActionLogger.Adapter-Interface#nebula-logger) |
| **Example Value** | `MyLoggerAdapter`                                                                                                                                                                                                                                |
| **Default**       | When blank, missing, or invalid, the framework writes logs via `System.debug()`                                                                                                                                                                  |

### `DelayInMinutes`

|                   |                                                                                                                                                   |
| ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Purpose**       | The default number of minutes to delay before enqueueing new jobs, across all processors                                                          |
| **Value**         | A whole number of minutes. Values that aren't whole numbers are ignored.                                                                          |
| **Example Value** | `0`                                                                                                                                               |
| **Default**       | `0` (no delay)                                                                                                                                    |
| **Override**      | Individual processors can override this via [`AsyncActionProcessor__mdt.DelayInMinutes__c`](./The-AsyncActionProcessor__mdt-Custom-Metadata-Type) |

This parameter addresses orgs that have configured an org-wide default delay for queueable jobs. When set to `0`, the framework explicitly requests immediate execution, bypassing the org-wide default.

## Configuration

1. Navigate to **Setup → Custom Metadata Types → Async Action Parameter → Manage Records**
2. Click **New**
3. Set the **Name** to one of the parameters listed above (ex., `LoggerPlugin`)
4. Set the **Value**
5. Save the record

## Testing With Parameters

Use `AsyncActionTestUtils.mockParameter` to inject a parameter value in your Apex tests:

```apex
@IsTest
static void myTest() {
	AsyncActionTestUtils.mockParameter('LoggerPlugin', 'MyLoggerAdapter');
	// ... test logic
}
```

## Related Objects

- [AsyncActionProcessor\_\_mdt](./The-AsyncActionProcessor__mdt-Custom-Metadata-Type) - Processor-specific configurations that can override parameters
- [AsyncAction\_\_c](./The-AsyncAction__c-Object) - Records processed according to these parameters
