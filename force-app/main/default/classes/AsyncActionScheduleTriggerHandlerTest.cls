@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest
private class AsyncActionScheduleTriggerHandlerTest {
	@IsTest
	static void shouldScheduleJobsAsAutomatedProcess() {
		AsyncActionScheduledJob__mdt jobSettings = AsyncActionTestUtils.initScheduledJobSettings();
		jobSettings.Enabled__c = true;
		AsyncActionSchedule__e event = new AsyncActionSchedule__e();

		EventBus.publishWithAccessLevel(event, System.AccessLevel.SYSTEM_MODE);
		Test.getEventBus().deliver();

		String ownerType = AsyncActionTestUtils.getScheduledJobOwnerType(jobSettings);
		Assert.areEqual('AutomatedProcess', ownerType, 'Scheduled Job is not owned by the Automated Process user');
	}
}
