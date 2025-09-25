The `AsyncActionScheduledJobItem__mdt` custom metadata type links individual processors to scheduled jobs, defining which async action processors should be executed when a scheduled job runs.

## Overview

AsyncActionScheduledJobItem records create the association between scheduled jobs and processors. Each record represents a single processor that will be launched when its parent scheduled job executes.

## Purpose and Usage

Scheduled job items provide:

1. **Processor Association** - Link specific processors to scheduled jobs
2. **Selective Execution** - Enable/disable individual processors within a schedule
3. **Flexible Grouping** - Organize processors into logical scheduling groups
4. **Execution Control** - Fine-tune which processors run when

## Field Reference

| Field API Name            | Label                  | Data Type             | Required | Description                                            | Details                                               |
| ------------------------- | ---------------------- | --------------------- | -------- | ------------------------------------------------------ | ----------------------------------------------------- |
| `DeveloperName`           | API Name               | Text(40)              | Yes      | Unique identifier for the scheduled job item           | Standard metadata field; cannot change after creation |
| `MasterLabel`             | Label                  | Text(40)              | Yes      | Human-readable name for the item                       | Displayed in UI; can be changed                       |
| `ScheduledJob__c`         | Scheduled Job          | Metadata Relationship | Yes      | Reference to AsyncActionScheduledJob\_\_mdt            | Must reference active scheduled job record            |
| `AsyncActionProcessor__c` | Async Action Processor | Metadata Relationship | Yes      | Reference to AsyncActionProcessor\_\_mdt               | Must reference enabled processor configuration        |
| `Enabled__c`              | Enabled                | Checkbox              | No       | Controls whether this processor runs with the schedule | Disabled items are skipped during execution           |

## Related Components

-   [AsyncActionScheduledJob Custom Metadata Type](./AsyncActionScheduledJob-Custom-Metadata-Type) - Parent scheduled job configuration
-   [AsyncActionProcessor Custom Metadata Type](./AsyncActionProcessor-Custom-Metadata-Type) - Processor configuration
-   [Scheduled Job Configuration](./Scheduled-Job-Configuration) - Complete scheduling guide

## See Also

-   [Core Concepts](./Core-Concepts) - Framework architecture overview
-   [Creating Your First Processor](./Creating-Your-First-Processor) - Implementation guide
