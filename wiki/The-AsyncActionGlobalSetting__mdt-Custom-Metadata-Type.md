The `AsyncActionGlobalSetting__mdt` custom metadata type defines package-wide behavior for the async actions framework. It controls global settings that affect all processors and framework operations.

## Field Reference

| Field API Name    | Label         | Data Type | Required | Default | Description                                          |
| ----------------- | ------------- | --------- | -------- | ------- | ---------------------------------------------------- |
| `DeveloperName`   | API Name      | Text(40)  | Yes      | -       | Unique identifier for the global settings            |
| `MasterLabel`     | Label         | Text(40)  | Yes      | -       | Human-readable name for the settings                 |
| `LoggerPlugin__c` | Logger Plugin | Text(255) | No       | -       | Fully qualified name of custom logger implementation |

## Configuration

1. Navigate to **Setup → Custom Metadata Types → Async Action Global Setting → Manage Records**
2. Create or edit the global settings record
3. Set the **Logger Plugin** field to your custom logger class name
4. Save the record

Note: If no Async Action Global Setting record exists or no logger plugin is specified, the framework uses `System.debug()` for all logging.
