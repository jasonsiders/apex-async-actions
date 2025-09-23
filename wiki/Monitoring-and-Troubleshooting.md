Comprehensive guide to monitoring async action processing and troubleshooting common issues in production environments.

## Overview

Effective monitoring and troubleshooting are essential for maintaining reliable async action processing. This guide covers monitoring strategies, diagnostic techniques, and resolution patterns for common issues.

## Monitoring Strategies

### Real-Time Monitoring

#### Processing Queue Depth

Monitor pending action volumes:

```apex
public class QueueDepthMonitor {
	public static Map<String, Integer> getQueueDepths() {
		Map<String, Integer> depths = new Map<String, Integer>();

		List<AggregateResult> results = [
			SELECT ProcessorName__c, COUNT(Id) depth
			FROM AsyncAction__c
			WHERE Status__c IN ('Pending', 'Retry')
			GROUP BY ProcessorName__c
		];

		for (AggregateResult result : results) {
			depths.put((String) result.get('ProcessorName__c'), (Integer) result.get('depth'));
		}

		return depths;
	}

	public static void alertOnHighDepth(Integer threshold) {
		Map<String, Integer> depths = getQueueDepths();

		for (String processor : depths.keySet()) {
			if (depths.get(processor) > threshold) {
				sendAlert('High queue depth for ' + processor + ': ' + depths.get(processor));
			}
		}
	}
}
```

#### Processing Rate Monitoring

Track actions processed per hour:

```apex
public class ProcessingRateMonitor {
	public static Map<String, Decimal> getHourlyProcessingRates() {
		Map<String, Decimal> rates = new Map<String, Decimal>();

		List<AggregateResult> results = [
			SELECT ProcessorName__c, COUNT(Id) completed
			FROM AsyncAction__c
			WHERE Status__c = 'Completed' AND LastModifiedDate >= :DateTime.now().addHours(-1)
			GROUP BY ProcessorName__c
		];

		for (AggregateResult result : results) {
			rates.put((String) result.get('ProcessorName__c'), (Decimal) result.get('completed'));
		}

		return rates;
	}
}
```

### Error Rate Monitoring

#### Error Percentage Tracking

```apex
public class ErrorRateMonitor {
    public static Map<String, Decimal> getErrorRates(Integer hoursBack) {
        Map<String, Decimal> errorRates = new Map<String, Decimal>();
        DateTime cutoff = DateTime.now().addHours(-hoursBack);

        List<AggregateResult> results = [
            SELECT ProcessorName__c,
                   COUNT(Id) total,
                   SUM(CASE WHEN Status__c = 'Failed' THEN 1 ELSE 0 END) failures
            FROM AsyncAction__c
            WHERE LastModifiedDate >= :cutoff
            GROUP BY ProcessorName__c
        ];

        for (AggregateResult result : results) {
            String processor = (String)result.get('ProcessorName__c');
            Decimal total = (Decimal)result.get('total');
            Decimal failures = (Decimal)result.get('failures');

            if (total > 0) {
                errorRates.put(processor, (failures / total) * 100);
            }
        }

        return errorRates;
    }

    public static void alertOnHighErrorRate(Decimal threshold) {
        Map<String, Decimal> rates = getErrorRates(1);

        for (String processor : rates.keySet()) {
            if (rates.get(processor) > threshold) {
                sendAlert('High error rate for ' + processor + ': ' + rates.get(processor) + '%');
            }
        }
    }
}
```

### Job Queue Monitoring

#### Active Job Tracking

```apex
public class JobQueueMonitor {
	public static List<AsyncApexJob> getActiveAsyncActionJobs() {
		return [
			SELECT Id, JobType, Status, CreatedDate, CompletedDate, NumberOfErrors, JobItemsProcessed, TotalJobItems
			FROM AsyncApexJob
			WHERE
				JobType = 'Queueable'
				AND ClassName LIKE '%AsyncActionJob%'
				AND Status IN ('Holding', 'Queued', 'Processing')
			ORDER BY CreatedDate DESC
		];
	}

	public static void alertOnStuckJobs() {
		List<AsyncApexJob> longRunningJobs = [
			SELECT Id, CreatedDate, Status
			FROM AsyncApexJob
			WHERE
				JobType = 'Queueable'
				AND ClassName LIKE '%AsyncActionJob%'
				AND Status = 'Processing'
				AND CreatedDate <= :DateTime.now().addMinutes(-30)
		];

		if (!longRunningJobs.isEmpty()) {
			sendAlert('Found ' + longRunningJobs.size() + ' long-running async action jobs');
		}
	}
}
```

## Diagnostic Queries

### Action Status Analysis

```sql
-- Current status distribution
SELECT Status__c, COUNT(Id) count
FROM AsyncAction__c
WHERE CreatedDate = LAST_N_DAYS:7
GROUP BY Status__c
ORDER BY COUNT(Id) DESC

-- Actions by processor and status
SELECT ProcessorName__c, Status__c, COUNT(Id) count
FROM AsyncAction__c
WHERE CreatedDate = LAST_N_DAYS:1
GROUP BY ProcessorName__c, Status__c
ORDER BY ProcessorName__c, COUNT(Id) DESC
```

### Error Pattern Analysis

```sql
-- Most common error messages
SELECT ErrorMessage__c, COUNT(Id) frequency
FROM AsyncAction__c
WHERE Status__c = 'Failed'
AND CreatedDate = LAST_N_DAYS:7
AND ErrorMessage__c != null
GROUP BY ErrorMessage__c
ORDER BY COUNT(Id) DESC
LIMIT 10

-- Failed actions requiring attention
SELECT Id, ProcessorName__c, RecordId__c, ErrorMessage__c,
       RetryCount__c, CreatedDate, LastModifiedDate
FROM AsyncAction__c
WHERE Status__c = 'Failed'
AND RetryBehavior__c = 'KEEP_ALIVE'
ORDER BY LastModifiedDate DESC
```

### Performance Analysis

```sql
-- Average processing time by processor
SELECT ProcessorName__c,
       AVG(ProcessingDuration__c) avgDuration,
       MAX(ProcessingDuration__c) maxDuration,
       COUNT(Id) sampleSize
FROM AsyncAction__c
WHERE Status__c = 'Completed'
AND ProcessingDuration__c != null
AND CreatedDate = LAST_N_DAYS:7
GROUP BY ProcessorName__c
ORDER BY AVG(ProcessingDuration__c) DESC

-- Retry analysis
SELECT ProcessorName__c,
       AVG(RetryCount__c) avgRetries,
       MAX(RetryCount__c) maxRetries,
       SUM(CASE WHEN RetryCount__c > 0 THEN 1 ELSE 0 END) retriedActions
FROM AsyncAction__c
WHERE Status__c IN ('Completed', 'Failed')
AND CreatedDate = LAST_N_DAYS:7
GROUP BY ProcessorName__c
```

## Common Issues and Resolutions

### High Queue Depths

#### Symptoms

-   Increasing numbers of pending actions
-   Delayed processing times
-   User complaints about delayed operations

#### Diagnosis

```apex
public class QueueDepthDiagnostic {
	public static void diagnoseHighDepth(String processorName) {
		// Check queue depth trend
		List<AggregateResult> hourlyDepth = [
			SELECT HOUR_IN_DAY(CreatedDate) hour, COUNT(Id) created
			FROM AsyncAction__c
			WHERE ProcessorName__c = :processorName AND CreatedDate = LAST_N_DAYS:1 AND Status__c = 'Pending'
			GROUP BY HOUR_IN_DAY(CreatedDate)
			ORDER BY HOUR_IN_DAY(CreatedDate)
		];

		// Check processor configuration
		AsyncActionProcessor__mdt settings = [
			SELECT BatchSize__c, MaxJobs__c, Enabled__c
			FROM AsyncActionProcessor__mdt
			WHERE DeveloperName = :processorName
		];

		// Check for stuck jobs
		List<AsyncApexJob> stuckJobs = [
			SELECT Id, Status, CreatedDate
			FROM AsyncApexJob
			WHERE JobType = 'Queueable' AND Status = 'Processing' AND CreatedDate <= :DateTime.now().addHours(-1)
		];

		System.debug('Hourly creation pattern: ' + hourlyDepth);
		System.debug('Processor settings: ' + settings);
		System.debug('Potentially stuck jobs: ' + stuckJobs.size());
	}
}
```

#### Resolution

1. **Increase Batch Size** - Process more actions per job
2. **Increase Max Jobs** - Allow more concurrent processing
3. **Scale Processing Schedule** - More frequent job launches
4. **Optimize Processor Logic** - Reduce processing time per action

### Processing Failures

#### Root Cause Analysis

```apex
public class FailureAnalysis {
	public static void analyzeFailures(String processorName, Integer days) {
		List<AsyncAction__c> failures = [
			SELECT ErrorMessage__c, RetryCount__c, CreatedDate
			FROM AsyncAction__c
			WHERE
				ProcessorName__c = :processorName
				AND Status__c = 'Failed'
				AND CreatedDate = :DateTime.now().addDays(-days)
			ORDER BY CreatedDate DESC
			LIMIT 100
		];

		Map<String, Integer> errorCounts = new Map<String, Integer>();
		for (AsyncAction__c failure : failures) {
			String errorType = extractErrorType(failure.ErrorMessage__c);
			errorCounts.put(errorType, errorCounts.getOrDefault(errorType, 0) + 1);
		}

		System.debug('Failure analysis for ' + processorName + ':');
		for (String errorType : errorCounts.keySet()) {
			System.debug(errorType + ': ' + errorCounts.get(errorType) + ' occurrences');
		}
	}

	private static String extractErrorType(String errorMessage) {
		if (errorMessage == null)
			return 'Unknown';
		if (errorMessage.contains('TIMEOUT'))
			return 'Timeout';
		if (errorMessage.contains('LIMIT'))
			return 'Governor Limit';
		if (errorMessage.contains('INVALID'))
			return 'Validation Error';
		if (errorMessage.contains('UNABLE_TO_LOCK_ROW'))
			return 'Lock Contention';
		return 'Other';
	}
}
```

### Performance Degradation

#### Performance Profiling

```apex
public class PerformanceProfiler {
	public static void profileProcessor(String processorName) {
		List<AggregateResult> performanceMetrics = [
			SELECT
				AVG(ProcessingDuration__c) avgDuration,
				MIN(ProcessingDuration__c) minDuration,
				MAX(ProcessingDuration__c) maxDuration,
				CALENDAR_MONTH(CreatedDate) month,
				CALENDAR_YEAR(CreatedDate) year
			FROM AsyncAction__c
			WHERE
				ProcessorName__c = :processorName
				AND Status__c = 'Completed'
				AND ProcessingDuration__c != NULL
				AND CreatedDate = LAST_N_MONTHS:3
			GROUP BY CALENDAR_MONTH(CreatedDate), CALENDAR_YEAR(CreatedDate)
			ORDER BY CALENDAR_YEAR(CreatedDate), CALENDAR_MONTH(CreatedDate)
		];

		System.debug('Performance trend for ' + processorName + ':');
		for (AggregateResult metric : performanceMetrics) {
			System.debug(
				metric.get('year') +
					'-' +
					metric.get('month') +
					': Avg=' +
					metric.get('avgDuration') +
					'ms, Min=' +
					metric.get('minDuration') +
					'ms, Max=' +
					metric.get('maxDuration') +
					'ms'
			);
		}
	}
}
```

## Health Dashboards

### System Health Check

```apex
public class SystemHealthCheck {
	public class HealthReport {
		public Integer totalPending;
		public Integer totalProcessing;
		public Integer hourlyCompletions;
		public Decimal overallErrorRate;
		public Map<String, Integer> queueDepths;
		public List<String> alerts;
	}

	public static HealthReport generateHealthReport() {
		HealthReport report = new HealthReport();
		report.alerts = new List<String>();

		// Queue depths
		report.queueDepths = QueueDepthMonitor.getQueueDepths();
		report.totalPending = 0;
		for (Integer depth : report.queueDepths.values()) {
			report.totalPending += depth;
		}

		// Processing jobs
		List<AsyncApexJob> processingJobs = [
			SELECT COUNT()
			FROM AsyncApexJob
			WHERE JobType = 'Queueable' AND Status = 'Processing' AND ClassName LIKE '%AsyncActionJob%'
		];
		report.totalProcessing = processingJobs.size();

		// Hourly completions
		List<AggregateResult> completions = [
			SELECT COUNT(Id) completed
			FROM AsyncAction__c
			WHERE Status__c = 'Completed' AND LastModifiedDate >= :DateTime.now().addHours(-1)
		];
		report.hourlyCompletions = (Integer) completions[0].get('completed');

		// Error rate
		Map<String, Decimal> errorRates = ErrorRateMonitor.getErrorRates(24);
		report.overallErrorRate = calculateOverallErrorRate(errorRates);

		// Generate alerts
		if (report.totalPending > 10000) {
			report.alerts.add('High total pending actions: ' + report.totalPending);
		}
		if (report.overallErrorRate > 5.0) {
			report.alerts.add('High error rate: ' + report.overallErrorRate + '%');
		}

		return report;
	}
}
```

## Alerting Configuration

### Alert Rules

```apex
public class AlertManager {
	public static void checkAllAlerts() {
		// Queue depth alerts
		QueueDepthMonitor.alertOnHighDepth(1000);

		// Error rate alerts
		ErrorRateMonitor.alertOnHighErrorRate(10.0);

		// Stuck job alerts
		JobQueueMonitor.alertOnStuckJobs();

		// Schedule health alerts
		ScheduleHealthMonitor.checkMissedExecutions();
	}

	private static void sendAlert(String message) {
		// Send email alert
		Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
		email.setToAddresses(new List<String>{ 'admin@company.com' });
		email.setSubject('Async Actions Alert');
		email.setPlainTextBody(message);
		Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });

		// Log alert
		AsyncActionAlert__c alert = new AsyncActionAlert__c(
			Message__c = message,
			Timestamp__c = DateTime.now(),
			Severity__c = 'High'
		);
		insert alert;
	}
}
```

## Troubleshooting Workflows

### Issue Escalation Process

1. **Level 1** - Automated monitoring detects issue
2. **Level 2** - Run diagnostic queries and health checks
3. **Level 3** - Analyze error patterns and performance metrics
4. **Level 4** - Manual investigation and resolution

### Recovery Procedures

```apex
public class RecoveryProcedures {
	public static void recoverStuckProcessor(String processorName) {
		// 1. Abort stuck jobs
		List<AsyncApexJob> stuckJobs = [
			SELECT Id
			FROM AsyncApexJob
			WHERE JobType = 'Queueable' AND Status = 'Processing' AND CreatedDate <= :DateTime.now().addHours(-1)
		];
		for (AsyncApexJob job : stuckJobs) {
			System.abortJob(job.Id);
		}

		// 2. Reset retry actions
		List<AsyncAction__c> retryActions = [
			SELECT Id
			FROM AsyncAction__c
			WHERE ProcessorName__c = :processorName AND Status__c = 'Retry' AND NextRetryTime__c <= :DateTime.now()
		];
		for (AsyncAction__c action : retryActions) {
			action.Status__c = 'Pending';
			action.NextRetryTime__c = null;
		}
		update retryActions;

		// 3. Restart processing
		AsyncActionLauncher.launch(processorName);
	}
}
```

## See Also

-   [AsyncActionLogger Class](./AsyncActionLogger-Class) - Centralized logging
-   [Error Handling and Retry Logic](./Error-Handling-and-Retry-Logic) - Error handling patterns
-   [Scheduled Job Configuration](./Scheduled-Job-Configuration) - Automated scheduling
