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

	static List<AsyncApexJob> getJobs(String jobName) {
		return [
			SELECT Id, CronTriggerId, CronTrigger.CronJobDetail.Name, Status
			FROM AsyncApexJob
			WHERE CronTrigger.CronJobDetail.Name = :jobName
			WITH SYSTEM_MODE
		];
	}

	// **** INNER **** //
	private class MySchedulable implements System.Schedulable {
		public void execute(System.SchedulableContext context) {
			// Nothing needed here
		}
	}
}
