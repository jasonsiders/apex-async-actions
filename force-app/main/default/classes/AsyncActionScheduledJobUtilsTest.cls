/**
 * @description Test class for AsyncActionScheduledJobUtils functionality including job scheduling and aborting
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.EmptyStatementBlock')
@IsTest
private class AsyncActionScheduledJobUtilsTest {
	@IsTest
	static void shouldAbortScheduledJob() {
		String jobName = 'Test_Job_123';
		System.schedule(jobName, '0 0 * * * ?', new MySchedulable());
		AsyncApexJob job = AsyncActionScheduledJobUtilsTest.getJobs(jobName)[0];

		Test.startTest();
		AsyncActionScheduledJobUtils.abortJobs(job);
		Test.stopTest();

		Assert.areEqual(0, AsyncActionScheduledJobUtilsTest.getJobs(jobName)?.size(), 'Wrong # of remaining jobs');
	}

	@IsTest
	static void shouldAbortScheduledJobByCronTrigger() {
		String jobName = 'Test_Job_456';
		System.schedule(jobName, '0 0 * * * ?', new MySchedulable());
		CronTrigger ct = [
			SELECT Id, CronJobDetail.Name
			FROM CronTrigger
			WHERE CronJobDetail.Name = :jobName
			WITH SYSTEM_MODE
		];

		Test.startTest();
		AsyncActionScheduledJobUtils.abortJobs(ct);
		Test.stopTest();

		Assert.areEqual(0, AsyncActionScheduledJobUtilsTest.getJobs(jobName)?.size(), 'Wrong # of remaining jobs');
	}

	/**
	 * @description Helper method to retrieve AsyncApexJob records by job name
	 * @param jobName The name of the scheduled job to search for
	 * @return List of AsyncApexJob records matching the job name
	 */
	static List<AsyncApexJob> getJobs(String jobName) {
		return [
			SELECT Id, CronTriggerId, CronTrigger.CronJobDetail.Name, Status
			FROM AsyncApexJob
			WHERE CronTrigger.CronJobDetail.Name = :jobName
			WITH SYSTEM_MODE
		];
	}

	@IsTest
	static void shouldHandleLockedJobGracefully() {
		AsyncActionScheduledJobUtils.terminator = new LockedJobSimulator();
		String jobName = 'Test_Job_789';
		System.schedule(jobName, '0 0 * * * ?', new MySchedulable());
		CronTrigger ct = [
			SELECT Id, CronJobDetail.Name
			FROM CronTrigger
			WHERE CronJobDetail.Name = :jobName
			WITH SYSTEM_MODE
		];

		Test.startTest();
		AsyncActionScheduledJobUtils.abortJobs(ct);
		Test.stopTest();

		// The job should still exist because abort was blocked by the lock
		List<AsyncApexJob> remainingJobs = AsyncActionScheduledJobUtilsTest.getJobs(jobName);
		Assert.areEqual(1, remainingJobs?.size(), 'Locked job should not have been aborted');
	}

	// **** INNER **** //
	/**
	 * @description Test schedulable class used for testing scheduled job functionality
	 */
	private class MySchedulable implements System.Schedulable {
		/**
		 * @description Execute method for schedulable interface (no-op for testing)
		 * @param context The schedulable context (unused in test implementation)
		 */
		public void execute(System.SchedulableContext context) {
			// Nothing needed here
		}
	}

	/**
	 * @description Mock terminator that simulates a locked job by throwing StringException
	 */
	private class LockedJobSimulator extends AsyncActionScheduledJobUtils.JobTerminator {
		public override void abortJob(Id jobId) {
			throw new System.StringException('Job object is locked and currently processing.');
		}
	}
}
