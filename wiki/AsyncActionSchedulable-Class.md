The `AsyncActionSchedulable` class provides scheduled execution capabilities for async action processors.

## Overview

`AsyncActionSchedulable` implements the `Schedulable` interface to enable time-based processing of async actions. This allows processors to run on a schedule rather than being triggered manually or by events.

## Implementation

The class implements `Schedulable.execute()` and delegates to the `AsyncActionLauncher` for actual processing.

```apex
public void execute(SchedulableContext context) {
    AsyncActionLauncher.launch(processorName);
}
```

## Configuration

### Scheduling Processors

Schedule processors using Salesforce's standard scheduling APIs:

```apex
// Schedule to run every hour
String cronExpression = '0 0 * * * ?';
String jobName = 'Hourly Data Sync';

AsyncActionSchedulable scheduler = new AsyncActionSchedulable('Data_Sync_Processor');
System.schedule(jobName, cronExpression, scheduler);
```

### Cron Expression Examples

```apex
// Every 15 minutes
'0 */15 * * * ?'

// Daily at 2 AM
'0 0 2 * * ?'

// Every weekday at 9 AM
'0 0 9 ? * MON-FRI'

// First day of every month at midnight
'0 0 0 1 * ?'
```

## Use Cases

### Regular Data Processing

Schedule processors for routine data operations:

```apex
// Daily cleanup of completed actions
AsyncActionSchedulable cleanup = new AsyncActionSchedulable('Cleanup_Processor');
System.schedule('Daily Cleanup', '0 0 1 * * ?', cleanup);
```

### Batch Processing Windows

Process large volumes during off-peak hours:

```apex
// Nightly batch processing
AsyncActionSchedulable batchProcessor = new AsyncActionSchedulable('Batch_Processor');
System.schedule('Nightly Batch', '0 0 23 * * ?', batchProcessor);
```

### Integration Synchronization

Sync with external systems on schedule:

```apex
// Hourly CRM sync
AsyncActionSchedulable crmSync = new AsyncActionSchedulable('CRM_Sync_Processor');
System.schedule('CRM Sync', '0 0 * * * ?', crmSync);
```

## Monitoring Scheduled Jobs

### View Scheduled Jobs

```apex
List<CronTrigger> scheduledJobs = [
    SELECT Id, CronJobDetail.Name, State, NextFireTime
    FROM CronTrigger
    WHERE CronJobDetail.JobType = '7'
];
```

### Abort Scheduled Jobs

```apex
// Abort specific job
System.abortJob(cronTriggerId);

// Abort all async action schedulers
for (CronTrigger job : [SELECT Id FROM CronTrigger WHERE CronJobDetail.Name LIKE 'AsyncAction%']) {
    System.abortJob(job.Id);
}
```

## Error Handling

Scheduled jobs use the same error handling as manual launches:

-   Failed actions follow configured retry behavior
-   System errors are captured by the finalizer pattern
-   Job failures are logged in the system

## Governor Limits

### Scheduling Limits

-   Maximum 100 scheduled Apex jobs per organization
-   Jobs cannot be scheduled to run more frequently than every hour in production

### Processing Limits

-   Each scheduled execution runs in its own context
-   Standard queueable and DML limits apply
-   Consider batch size configuration for large datasets

## Best Practices

### Scheduling Strategy

1. **Off-Peak Processing** - Schedule heavy processing during low-usage periods
2. **Overlap Prevention** - Ensure jobs don't overlap if they take longer than the schedule interval
3. **Error Monitoring** - Set up alerts for scheduled job failures
4. **Resource Management** - Consider governor limits when scheduling multiple jobs

### Testing Scheduled Jobs

```apex
@isTest
static void testScheduledProcessor() {
    String cronExpression = '0 0 1 * * ?';

    Test.startTest();
    String jobId = System.schedule('Test Job', cronExpression,
        new AsyncActionSchedulable('Test_Processor'));
    Test.stopTest();

    // Verify job was scheduled
    CronTrigger ct = [SELECT Id, NextFireTime FROM CronTrigger WHERE Id = :jobId];
    System.assertNotEquals(null, ct.NextFireTime);
}
```

## See Also

-   [AsyncActionLauncher Class](./AsyncActionLauncher-Class) - Manual job launching
-   [Scheduled Job Configuration](./Scheduled-Job-Configuration) - Advanced scheduling patterns
-   [Monitoring & Troubleshooting](./Monitoring-and-Troubleshooting) - Operational guidance
