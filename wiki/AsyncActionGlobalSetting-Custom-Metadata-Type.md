The `AsyncActionGlobalSetting__mdt` custom metadata type defines package-wide behavior for the async actions framework. It controls global settings that affect all processors and framework operations.

## Overview

AsyncActionGlobalSetting records provide a centralized location for framework-wide configuration. Unlike processor-specific settings, these configurations apply to all async action operations across your entire org.

## Purpose and Usage

Global settings control:

1. **Logging Framework** - Integration with external logging systems
2. **Framework Behavior** - System-wide operational parameters
3. **Plugin Configuration** - Extension points for custom functionality
4. **Debug Settings** - Development and troubleshooting options

The framework expects at most one AsyncActionGlobalSetting record. If multiple records exist, the framework will use the first record returned by the query. If no records exist, the framework uses default behavior.

## Field Reference

| Field API Name    | Label         | Data Type | Required | Default | Description                                          | Details                                              |
| ----------------- | ------------- | --------- | -------- | ------- | ---------------------------------------------------- | ---------------------------------------------------- |
| `DeveloperName`   | API Name      | Text(40)  | Yes      | -       | Unique identifier for the global settings            | Standard metadata field                              |
| `MasterLabel`     | Label         | Text(40)  | Yes      | -       | Human-readable name for the settings                 | Standard metadata field                              |
| `LoggerPlugin__c` | Logger Plugin | Text(255) | No       | -       | Fully qualified name of custom logger implementation | Must implement `AsyncActionLogger.Adapter` interface |

## Configuration

### Setup Process

1. Navigate to **Setup → Custom Metadata Types → Async Action Global Setting → Manage Records**
2. Create or edit the global settings record
3. Set the **Logger Plugin** field to your custom logger class name
4. Save the record

### Default Behavior

If no AsyncActionGlobalSetting record exists or no logger plugin is specified, the framework uses `System.debug()` for all logging.

## Related Components

-   [Plugin Framework](./Plugin-Framework) - Creating custom logger plugins
-   [AsyncActionLogger Class](./AsyncActionLogger-Class) - Core logging framework

## See Also

-   [Core Concepts](./Core-Concepts) - Framework architecture overview
-   [Best Practices](./Best-Practices) - Framework best practices
