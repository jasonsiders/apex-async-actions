@IsTest 
private class AsyncActionStartHandlerTest {
    @IsTest 
    static void shouldLaunchAllJobsIfNoneListed() {
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

    @IsTest 
    static void shouldLaunchJobsListedInActions() {
        AsyncActionSetting__mdt settings = AsyncActionTestUtils.initGlobalSettings();
        AsyncActionProcessor__mdt config = AsyncActionTestUtils.initProcessorSettings(MockProcessor.class);
        AsyncActionProcessor processor = new MockProcessor();
        insert processor?.initAction(null);
        AsyncActionStart__e event = new AsyncActionStart__e();
        event.Actions__c = 'MockProcessor,OtherJobs,etc';
        
        EventBus.publish(event);
        Test.getEventBus().deliver();

        List<AsyncApexJob> jobs = [SELECT Id FROM AsyncApexJob WHERE ApexClass.Name = 'MockProcessor'];
        Assert.isFalse(jobs?.isEmpty(), 'Job(s) were not launched');
    }

    @IsTest 
    static void shouldNotLaunchJobsIfNotListed() {
        AsyncActionSetting__mdt settings = AsyncActionTestUtils.initGlobalSettings();
        AsyncActionProcessor__mdt config = AsyncActionTestUtils.initProcessorSettings(MockProcessor.class);
        AsyncActionProcessor processor = new MockProcessor();
        insert processor?.initAction(null);
        AsyncActionStart__e event = new AsyncActionStart__e();
        event.Actions__c = 'FakeClass1,FakeClass2,etc';

        EventBus.publish(event);
        Test.getEventBus().deliver();

        List<AsyncApexJob> jobs = [SELECT Id FROM AsyncApexJob WHERE ApexClass.Name = 'MockProcessor'];
        Assert.isTrue(jobs?.isEmpty(), 'Job(s) were launched, but not listed in Actions__c');
    }
}