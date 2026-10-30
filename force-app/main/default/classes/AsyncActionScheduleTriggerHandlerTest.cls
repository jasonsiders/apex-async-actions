@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest
private class AsyncActionScheduleTriggerHandlerTest {
	@IsTest
	static void shouldScheduleEnabledJobs() {
		AsyncActionScheduledJob__mdt jobSettings = AsyncActionTestUtils.initScheduledJobSettings();
		jobSettings.Enabled__c = true;
		AsyncActionSchedule__e event = new AsyncActionSchedule__e();

		EventBus.publishWithAccessLevel(event, System.AccessLevel.SYSTEM_MODE);
		Test.getEventBus().deliver();

		List<CronTrigger> jobs = AsyncActionScheduleTriggerHandlerTest.getScheduledJobs(jobSettings);
		Assert.isFalse(jobs?.isEmpty(), 'Enabled Scheduled Job was not created');
	}

	@IsTest
	static void shouldScheduleJobsAsAutomatedProcess() {
		AsyncActionScheduledJob__mdt jobSettings = AsyncActionTestUtils.initScheduledJobSettings();
		jobSettings.Enabled__c = true;
		AsyncActionSchedule__e event = new AsyncActionSchedule__e();

		EventBus.publishWithAccessLevel(event, System.AccessLevel.SYSTEM_MODE);
		Test.getEventBus().deliver();

		List<CronTrigger> jobs = AsyncActionScheduleTriggerHandlerTest.getScheduledJobs(jobSettings);
		Id ownerId = jobs?.isEmpty() == false ? jobs[0]?.OwnerId : null;
		User owner = [SELECT UserType FROM User WHERE Id = :ownerId WITH SYSTEM_MODE LIMIT 1] ?? null;
		Assert.areEqual(
			'AutomatedProcess',
			owner?.UserType,
			'Scheduled Job is not owned by the Automated Process user'
		);
	}

	// **** HELPER **** //
	static List<CronTrigger> getScheduledJobs(AsyncActionScheduledJob__mdt jobSettings) {
		String expectedJobName = AsyncActionScheduledJobUtils.getJobName(jobSettings);
		return [
			SELECT Id, OwnerId
			FROM CronTrigger
			WHERE CronJobDetail.Name = :expectedJobName
			WITH SYSTEM_MODE
			LIMIT 1
		];
	}
}
