@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest
private class AsyncActionScheduleTriggerHandlerTest {
	@IsTest
	static void shouldScheduleJobsAsAutomatedProcess() {
		AsyncActionScheduledJob__mdt jobSettings = AsyncActionTestUtils.initEnabledScheduledJobSettings();
		AsyncActionSchedule__e event = new AsyncActionSchedule__e();

		EventBus.publishWithAccessLevel(event, System.AccessLevel.SYSTEM_MODE);
		Test.getEventBus().deliver();

		String ownerType = AsyncActionTestUtils.getScheduledJobOwnerType(jobSettings);
		Assert.areEqual('AutomatedProcess', ownerType, 'Scheduled Job is not owned by the Automated Process user');
	}

	@IsTest
	static void shouldLogEnforcementErrors() {
		String adapterName = AsyncActionTestUtils.MockLogAdapter.class.getName();
		AsyncActionTestUtils.mockParameter('LoggerPlugin', adapterName);
		AsyncActionScheduledJobUtils.terminator = new FailingTerminator();
		// Has no settings, so enforce() tries to abort it, and running it doesn't reschedule it
		String jobName = AsyncActionScheduledJobUtils.SCHEDULED_JOB_PREFIX + 'Orphaned_Job';
		System.Schedulable job = new AsyncActionSchedulable(null);
		System.schedule(jobName, AsyncActionScheduledJobUtils.HOURLY_CRON_EXP, job);
		AsyncActionSchedule__e event = new AsyncActionSchedule__e();

		EventBus.publishWithAccessLevel(event, System.AccessLevel.SYSTEM_MODE);
		Test.getEventBus().deliver();

		Assert.isFalse(AsyncActionTestUtils.errorLogs?.isEmpty(), 'Enforcement error was not logged');
	}

	// **** INNER **** //
	/** @description Throws an error that tryAbortJob() doesn't handle, so it reaches the trigger handler **/
	private class FailingTerminator extends AsyncActionScheduledJobUtils.JobTerminator {
		public override void abortJob(Id jobId) {
			throw new System.AsyncException('Simulated abort failure');
		}
	}
}
