Guide to configuring scheduled processing of async actions using the framework's scheduling system.

## Overview

The async actions framework provides a comprehensive scheduling system through `AsyncActionScheduledJob__mdt` and `AsyncActionScheduledJobItem__mdt` metadata types. This system allows you to configure automated processing of async actions at specific intervals.

## Framework Integration

The framework automatically manages scheduled jobs based on metadata records:

### Job Creation Process

1. **Startup Check** - Framework scans for enabled AsyncActionScheduledJob records
2. **Job Verification** - Checks if corresponding Salesforce scheduled job exists
3. **Job Creation** - Creates missing jobs using the specified schedule
4. **Job Updates** - Updates existing jobs if configuration changes
5. **Job Cleanup** - Removes jobs for disabled/deleted metadata records

### Execution Flow

When a scheduled job runs:

1. **Job Activation** - Salesforce triggers the scheduled job
2. **Processor Query** - Framework queries for configured processors
3. **Action Processing** - Each processor processes its pending actions
4. **Result Tracking** - Processing results are logged and tracked

## Configuration Components

### AsyncActionScheduledJob\_\_mdt

Defines the overall scheduled job configuration:

-   **Schedule Expression** - When the job should run (cron expression)
-   **Job Type** - System or custom scheduling behavior
-   **Enabled Status** - Whether the job is active

### AsyncActionScheduledJobItem\_\_mdt

Defines which processors run as part of a scheduled job:

-   **Parent Job** - Links to the AsyncActionScheduledJob record
-   **Processor Configuration** - Which processor to run
-   **Execution Parameters** - Job-specific settings

## Common Scheduling Patterns

### Hourly Processing

```
CronExpression: 0 0 * ? * *
Description: Every hour on the hour
```

### Daily Batch Processing

```
CronExpression: 0 0 2 * * ?
Description: Every day at 2:00 AM
```

### Weekly Cleanup

```
CronExpression: 0 0 1 ? * SUN
Description: Every Sunday at 1:00 AM for weekly cleanup
```

### Business Hours Processing

```
CronExpression: 0 0 9-17 ? * MON-FRI
Description: Every hour during business hours (9 AM - 5 PM), Monday through Friday
```

## Setup Instructions

### Step 1: Create Scheduled Job Record

1. Navigate to **Setup → Custom Metadata Types → Async Action Scheduled Job → Manage Records**
2. Create a new record with:
    - **Label**: Descriptive name for your scheduled job
    - **Schedule Expression**: Cron expression for timing
    - **Job Type**: Usually "Custom"
    - **Enabled**: Checked
    - **Description**: Documentation about the job's purpose

### Step 2: Create Job Items

1. Navigate to **Setup → Custom Metadata Types → Async Action Scheduled Job Item → Manage Records**
2. For each processor you want to include:
    - **Label**: Descriptive name
    - **Scheduled Job**: Link to your scheduled job record
    - **Processor**: Link to the processor configuration
    - **Enabled**: Checked

### Step 3: Verify Configuration

1. Check that the scheduled job appears in **Setup → Scheduled Jobs**
2. Monitor the first few executions in debug logs
3. Verify actions are being processed as expected

## Cron Expression Reference

Salesforce uses standard cron expressions with six fields:

```
Seconds Minutes Hours DayOfMonth Month DayOfWeek
```

**Examples:**

-   `0 0 12 * * ?` - Every day at noon
-   `0 15 10 ? * MON-FRI` - 10:15 AM Monday through Friday
-   `0 0/5 14 * * ?` - Every 5 minutes starting at 2:00 PM

## Troubleshooting

### Scheduled Job Not Running

1. Verify the scheduled job record is enabled
2. Check cron expression syntax
3. Confirm job appears in Salesforce's scheduled jobs list
4. Review debug logs for errors

### Actions Not Processing

1. Verify processor metadata is enabled
2. Check that actions exist with matching processor names
3. Confirm job items are properly configured
4. Review processor implementation for errors

## Best Practices

1. **Reasonable Frequency** - Don't schedule jobs too frequently to avoid hitting limits
2. **Off-Peak Hours** - Schedule intensive processing during low-usage periods
3. **Batch Sizing** - Configure appropriate batch sizes for scheduled processing
4. **Monitoring** - Set up alerts for failed scheduled jobs
5. **Testing** - Test scheduled jobs in sandbox environments first

## See Also

-   [AsyncActionScheduledJob Custom Metadata Type](./AsyncActionScheduledJob-Custom-Metadata-Type) - Detailed field reference
-   [AsyncActionScheduledJobItem Custom Metadata Type](./AsyncActionScheduledJobItem-Custom-Metadata-Type) - Job item configuration
-   [Core Concepts](./Core-Concepts) - Framework architecture overview
