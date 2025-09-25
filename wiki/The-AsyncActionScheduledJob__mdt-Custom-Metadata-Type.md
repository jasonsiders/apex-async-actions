The `AsyncActionScheduledJob__mdt` custom metadata type defines automatic scheduled jobs that process accumulated async actions at regular intervals. This provides a declarative way to set up recurring processing without manual job management.

Scheduled job records provide:

-   **Automatic Job Creation** - Framework creates scheduled jobs based on metadata configuration
-   **Recurring Processing** - Process accumulated actions at predictable intervals
-   **Flexible Scheduling** - Support for hourly, semi-hourly, and custom cron schedules
-   **Operational Control** - Enable/disable scheduled processing without code changes
-   **Multi-Processor Support** - Link multiple processors to a single schedule

## Field Reference

| Field API Name      | Label           | Data Type    | Required | Default          | Description                                      |
| ------------------- | --------------- | ------------ | -------- | ---------------- | ------------------------------------------------ |
| `DeveloperName`     | API Name        | Text(40)     | Yes      | -                | Unique identifier for the scheduled job          |
| `MasterLabel`       | Label           | Text(40)     | Yes      | -                | Human-readable name for the scheduled job        |
| `Enabled__c`        | Enabled         | Checkbox     | No       | true             | Controls whether the scheduled job is active     |
| `Type__c`           | Type            | Picklist     | Yes      | Custom           | Scheduling pattern (Custom, Hourly, Semi-Hourly) |
| `CronExpression__c` | Cron Expression | Text(20)     | No       | "0 0 \* \* \* ?" | Custom cron expression for flexible scheduling   |
| `Interval__c`       | Interval        | Number(18,0) | No       | 30               | Minutes between executions for Semi-Hourly type  |
