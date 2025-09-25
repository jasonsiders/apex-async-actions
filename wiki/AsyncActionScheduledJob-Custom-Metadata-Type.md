The `AsyncActionScheduledJob__mdt` custom metadata type defines automatic scheduled jobs that process accumulated async actions at regular intervals. These records enable hands-off operation of async action processors.

## Overview

AsyncActionScheduledJob records automatically create and manage Salesforce scheduled jobs that run the `AsyncActionSchedulable` class. This provides a declarative way to set up recurring processing without manual job management.

## Purpose and Usage

Scheduled job records provide:

1. **Automatic Job Creation** - Framework creates scheduled jobs based on metadata configuration
2. **Recurring Processing** - Process accumulated actions at predictable intervals
3. **Flexible Scheduling** - Support for hourly, semi-hourly, and custom cron schedules
4. **Operational Control** - Enable/disable scheduled processing without code changes
5. **Multi-Processor Support** - Link multiple processors to a single schedule

## Field Reference

| Field API Name      | Label           | Data Type    | Required | Default          | Description                                      | Details                                                  |
| ------------------- | --------------- | ------------ | -------- | ---------------- | ------------------------------------------------ | -------------------------------------------------------- |
| `DeveloperName`     | API Name        | Text(40)     | Yes      | -                | Unique identifier for the scheduled job          | Standard metadata field; cannot change after creation    |
| `MasterLabel`       | Label           | Text(40)     | Yes      | -                | Human-readable name for the scheduled job        | Displayed in UI; can be changed                          |
| `Enabled__c`        | Enabled         | Checkbox     | No       | true             | Controls whether the scheduled job is active     | Disabled jobs are not created/scheduled                  |
| `Type__c`           | Type            | Picklist     | Yes      | Custom           | Scheduling pattern (Custom, Hourly, Semi-Hourly) | Determines which scheduling fields are used              |
| `CronExpression__c` | Cron Expression | Text(20)     | No       | "0 0 \* \* \* ?" | Custom cron expression for flexible scheduling   | Used when Type = "Custom"; standard cron syntax          |
| `Interval__c`       | Interval        | Number(18,0) | No       | 30               | Minutes between executions for Semi-Hourly type  | Used when Type = "Semi-Hourly"; valid values: 15, 30, 45 |

## Related Components

-   [AsyncActionScheduledJobItem Custom Metadata Type](./AsyncActionScheduledJobItem-Custom-Metadata-Type) - Links processors to scheduled jobs
-   [Scheduled Job Configuration](./Scheduled-Job-Configuration) - Complete scheduling guide

## See Also

-   [Core Concepts](./Core-Concepts) - Framework architecture overview
-   [Monitoring and Troubleshooting](./Monitoring-and-Troubleshooting) - Operations guide
