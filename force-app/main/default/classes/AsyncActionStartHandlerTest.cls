@IsTest 
private class AsyncActionStartHandlerTest {
    @IsTest 
    static void shouldLaunchJobs() {
        AsyncActionSetting__mdt settings = AsyncActionTestUtils.initGlobalSettings();
        AsyncActionProcessor__mdt config = AsyncActionTestUtils.initProcessorSettings(MockProcessor.class);
        AsyncActionProcessor processor = new MockProcessor();
        insert processor?.initAction(null);

        AsyncActionStart__e event = new AsyncActionStart__e();
        EventBus.publish(event);
        Test.getEventBus().deliver();

        List<AsyncApexJob> jobs = [SELECT Id FROM AsyncApexJob WHERE ApexClass.Name = 'MockProcessor'];
        Assert.isFalse(jobs?.isEmpty(), 'Job(s) were not launched');
    }
}