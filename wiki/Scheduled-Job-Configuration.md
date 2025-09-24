Advanced configuration patterns for scheduling async action processors and managing automated processing workflows.

## Overview

Scheduled job configuration enables automated, time-based processing of async actions. This covers advanced scheduling patterns, job coordination, and enterprise-grade automation scenarios.

## Advanced Scheduling Patterns

### Cascading Jobs

Chain multiple processors in sequence:

```apex
public class CascadingScheduledProcessor implements Schedulable {
	private String[] processorChain;
	private Integer currentIndex;

	public CascadingScheduledProcessor(String[] processors) {
		this.processorChain = processors;
		this.currentIndex = 0;
	}

	public void execute(SchedulableContext context) {
		if (currentIndex < processorChain.size()) {
			String currentProcessor = processorChain[currentIndex];

			// Launch current processor
			AsyncActionLauncher.launch(currentProcessor);

			// Schedule next in chain
			currentIndex++;
			if (currentIndex < processorChain.size()) {
				DateTime nextRun = DateTime.now().addMinutes(5);
				String cronExp = getCronExpression(nextRun);
				System.schedule('Cascade_' + currentIndex, cronExp, this);
			}
		}
	}
}
```

### Conditional Scheduling

Schedule based on dynamic conditions:

```apex
public class ConditionalScheduler implements Schedulable {
	public void execute(SchedulableContext context) {
		// Check system load
		if (isSystemLoadAcceptable()) {
			AsyncActionLauncher.launch('Heavy_Processing_Processor');
		}

		// Check business hours
		if (BusinessHours.isWithin(getBusinessHoursId(), DateTime.now())) {
			AsyncActionLauncher.launch('Business_Hours_Processor');
		}

		// Check pending action volume
		Integer pendingCount = getPendingActionCount();
		if (pendingCount > 1000) {
			AsyncActionLauncher.launch('High_Volume_Processor');
		}
	}
}
```

### Time Zone Aware Scheduling

Handle global organizations with multiple time zones:

```apex
public class TimeZoneAwareScheduler implements Schedulable {
	private String timeZoneName;

	public TimeZoneAwareScheduler(String timeZone) {
		this.timeZoneName = timeZone;
	}

	public void execute(SchedulableContext context) {
		TimeZone tz = TimeZone.getTimeZone(timeZoneName);
		DateTime localTime = DateTime.now().addSeconds(tz.getOffset(DateTime.now()) / 1000);

		// Schedule based on local business hours
		Time businessStart = Time.newInstance(9, 0, 0, 0);
		Time businessEnd = Time.newInstance(17, 0, 0, 0);

		if (localTime.time() >= businessStart && localTime.time() <= businessEnd) {
			AsyncActionLauncher.launch('Regional_Processor_' + timeZoneName);
		}
	}
}
```

## Enterprise Configuration Patterns

### Multi-Tenant Scheduling

Handle multiple business units or customers:

```apex
public class MultiTenantScheduler implements Schedulable {
	public void execute(SchedulableContext context) {
		// Get all active tenants
		List<TenantConfiguration__c> tenants = [
			SELECT ProcessorName__c, ScheduleConfig__c, Active__c
			FROM TenantConfiguration__c
			WHERE Active__c = TRUE
		];

		for (TenantConfiguration__c tenant : tenants) {
			if (shouldProcessTenant(tenant)) {
				AsyncActionLauncher.launch(tenant.ProcessorName__c);
			}
		}
	}

	private Boolean shouldProcessTenant(TenantConfiguration__c tenant) {
		// Check tenant-specific scheduling rules
		Map<String, Object> config = (Map<String, Object>) JSON.deserializeUntyped(tenant.ScheduleConfig__c);
		String schedule = (String) config.get('schedule');

		return matchesSchedule(schedule);
	}
}
```

### Load Balancing

Distribute processing across time slots:

```apex
public class LoadBalancedScheduler implements Schedulable {
	private static Map<String, Integer> processorSlots = new Map<String, Integer>{
		'Processor_A' => 0, // 0-15 minutes
		'Processor_B' => 15, // 15-30 minutes
		'Processor_C' => 30, // 30-45 minutes
		'Processor_D' => 45 // 45-60 minutes
	};

	public void execute(SchedulableContext context) {
		Integer currentMinute = DateTime.now().minute();

		for (String processorName : processorSlots.keySet()) {
			Integer slotStart = processorSlots.get(processorName);
			Integer slotEnd = slotStart + 15;

			if (currentMinute >= slotStart && currentMinute < slotEnd) {
				AsyncActionLauncher.launch(processorName);
				break;
			}
		}
	}
}
```

## Dynamic Schedule Management

### Schedule Modification

Programmatically update schedules:

```apex
public class ScheduleManager {
	public static void updateProcessorSchedule(String processorName, String newCronExpression) {
		// Abort existing job
		List<CronTrigger> existingJobs = [
			SELECT Id
			FROM CronTrigger
			WHERE CronJobDetail.Name = :processorName + '_Scheduled'
		];

		for (CronTrigger job : existingJobs) {
			System.abortJob(job.Id);
		}

		// Schedule with new expression
		AsyncActionSchedulable scheduler = new AsyncActionSchedulable(processorName);
		System.schedule(processorName + '_Scheduled', newCronExpression, scheduler);
	}

	public static void pauseProcessorSchedule(String processorName) {
		List<CronTrigger> jobs = [
			SELECT Id
			FROM CronTrigger
			WHERE CronJobDetail.Name = :processorName + '_Scheduled'
		];

		for (CronTrigger job : jobs) {
			System.abortJob(job.Id);
		}
	}
}
```

### Configuration-Driven Scheduling

Store schedules in custom metadata:

```apex
public class ConfigurationDrivenScheduler {
	public static void initializeAllSchedules() {
		List<ProcessorScheduleConfig__mdt> configs = [
			SELECT ProcessorName__c, CronExpression__c, Active__c, JobName__c
			FROM ProcessorScheduleConfig__mdt
			WHERE Active__c = TRUE
		];

		for (ProcessorScheduleConfig__mdt config : configs) {
			try {
				AsyncActionSchedulable scheduler = new AsyncActionSchedulable(config.ProcessorName__c);
				System.schedule(config.JobName__c, config.CronExpression__c, scheduler);
			} catch (Exception e) {
				System.debug('Failed to schedule ' + config.ProcessorName__c + ': ' + e.getMessage());
			}
		}
	}
}
```

## Monitoring and Health Checks

### Schedule Health Monitoring

```apex
public class ScheduleHealthMonitor {
	public static void checkScheduleHealth() {
		List<ProcessorScheduleConfig__mdt> expectedSchedules = [
			SELECT ProcessorName__c, JobName__c
			FROM ProcessorScheduleConfig__mdt
			WHERE Active__c = TRUE
		];

		Set<String> expectedJobNames = new Set<String>();
		for (ProcessorScheduleConfig__mdt config : expectedSchedules) {
			expectedJobNames.add(config.JobName__c);
		}

		List<CronTrigger> activeJobs = [
			SELECT CronJobDetail.Name
			FROM CronTrigger
			WHERE State = 'WAITING'
		];

		Set<String> activeJobNames = new Set<String>();
		for (CronTrigger job : activeJobs) {
			activeJobNames.add(job.CronJobDetail.Name);
		}

		// Find missing schedules
		Set<String> missingJobs = expectedJobNames.clone();
		missingJobs.removeAll(activeJobNames);

		if (!missingJobs.isEmpty()) {
			sendScheduleAlert('Missing scheduled jobs: ' + String.join(new List<String>(missingJobs), ', '));
		}
	}
}
```

### Execution Tracking

```apex
public class ScheduleExecutionTracker {
	public static void recordExecution(String processorName) {
		ScheduleExecution__c execution = new ScheduleExecution__c(
			ProcessorName__c = processorName,
			ExecutionTime__c = DateTime.now(),
			ActionsProcessed__c = getProcessedCount(processorName)
		);

		insert execution;
	}

	public static void checkMissedExecutions() {
		List<ProcessorScheduleConfig__mdt> configs = [
			SELECT ProcessorName__c, ExpectedFrequencyMinutes__c
			FROM ProcessorScheduleConfig__mdt
			WHERE Active__c = TRUE
		];

		for (ProcessorScheduleConfig__mdt config : configs) {
			DateTime cutoff = DateTime.now().addMinutes(-(Integer) config.ExpectedFrequencyMinutes__c * 2);

			List<ScheduleExecution__c> recentExecutions = [
				SELECT Id
				FROM ScheduleExecution__c
				WHERE ProcessorName__c = :config.ProcessorName__c AND ExecutionTime__c >= :cutoff
				LIMIT 1
			];

			if (recentExecutions.isEmpty()) {
				sendMissedExecutionAlert(config.ProcessorName__c);
			}
		}
	}
}
```

## Disaster Recovery

### Schedule Backup and Restore

```apex
public class ScheduleBackupManager {
	public static void backupSchedules() {
		List<CronTrigger> activeSchedules = [
			SELECT CronJobDetail.Name, CronExpression, NextFireTime
			FROM CronTrigger
			WHERE State = 'WAITING' AND CronJobDetail.JobType = '7' // Schedulable class
		];

		List<ScheduleBackup__c> backups = new List<ScheduleBackup__c>();
		for (CronTrigger schedule : activeSchedules) {
			backups.add(
				new ScheduleBackup__c(
					JobName__c = schedule.CronJobDetail.Name,
					CronExpression__c = schedule.CronExpression,
					BackupDate__c = Date.today()
				)
			);
		}

		insert backups;
	}

	public static void restoreSchedules() {
		List<ScheduleBackup__c> backups = [
			SELECT JobName__c, CronExpression__c
			FROM ScheduleBackup__c
			WHERE BackupDate__c = :Date.today()
		];

		for (ScheduleBackup__c backup : backups) {
			try {
				// Extract processor name from job name
				String processorName = backup.JobName__c.replace('_Scheduled', '');
				AsyncActionSchedulable scheduler = new AsyncActionSchedulable(processorName);
				System.schedule(backup.JobName__c, backup.CronExpression__c, scheduler);
			} catch (Exception e) {
				System.debug('Failed to restore schedule: ' + backup.JobName__c + ' - ' + e.getMessage());
			}
		}
	}
}
```

## Testing Scheduled Jobs

### Time-Based Testing

```apex
@isTest
static void testScheduledExecution() {
    // Setup test data
    AsyncActionProcessor__mdt settings = createTestSettings();
    AsyncAction__c action = AsyncActions.initAction(settings, testRecordId);
    insert action;

    String cronExpression = '0 0 1 * * ?';  // Daily at 1 AM

    Test.startTest();

    // Schedule the job
    String jobId = System.schedule('Test Scheduled Job', cronExpression,
        new AsyncActionSchedulable(settings.DeveloperName));

    // Verify job was scheduled
    CronTrigger ct = [SELECT Id, NextFireTime FROM CronTrigger WHERE Id = :jobId];
    System.assertNotEquals(null, ct.NextFireTime);

    Test.stopTest();

    // In a real test, you would use launchImmediate to test processing logic
    AsyncActionLauncher.launchImmediate(settings.DeveloperName);

    // Verify processing occurred
    action = [SELECT Status__c FROM AsyncAction__c WHERE Id = :action.Id];
    System.assertEquals('Completed', action.Status__c);
}
```

## Best Practices

### Schedule Design

1. **Avoid Overlap** - Ensure jobs don't run longer than their intervals
2. **Stagger Start Times** - Prevent resource contention
3. **Consider Time Zones** - Plan for global organizations
4. **Monitor Health** - Regular checks for missed executions

### Performance Optimization

1. **Batch Size Tuning** - Balance throughput vs. governor limits
2. **Off-Peak Processing** - Schedule heavy work during low usage
3. **Resource Planning** - Consider concurrent job limits
4. **Selective Processing** - Only process what's needed

### Operational Excellence

1. **Documentation** - Clear schedule documentation
2. **Alerting** - Automated notifications for issues
3. **Backup/Recovery** - Schedule backup and restoration procedures
4. **Testing** - Regular validation of scheduled operations

## See Also

-   [Monitoring & Troubleshooting](./Monitoring-and-Troubleshooting) - Operational guidance
