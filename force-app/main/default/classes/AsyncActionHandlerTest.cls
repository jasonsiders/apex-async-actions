@IsTest 
private class AsyncActionHandlerTest {
    @IsTest 
    static void shouldLaunchJobsIfTriggerEnabled() {
        AsyncActionSetting__mdt settings = AsyncActionTestUtils.initGlobalSettings();
        AsyncActionProcessor__mdt config = AsyncActionTestUtils.initProcessorSettings(MockProcessor.class);
        config.RunOnInsert__c = true;
        AsyncActionProcessor processor = new MockProcessor();
        AsyncAction__c action = processor?.initAction(null);
        
        insert action;
        Test.getEventBus().deliver();

        List<AsyncApexJob> jobs = [SELECT Id FROM AsyncApexJob WHERE ApexClass.Name = 'MockProcessor' LIMIT 1];
        Assert.isFalse(jobs?.isEmpty(), 'Job(s) were not launched on insert'); 
    }

    @IsTest 
    static void shouldNotLaunchJobsIfTriggerDisabled() {
        AsyncActionSetting__mdt settings = AsyncActionTestUtils.initGlobalSettings();
        AsyncActionProcessor__mdt config = AsyncActionTestUtils.initProcessorSettings(MockProcessor.class);
        config.RunOnInsert__c = false;
        AsyncActionProcessor processor = new MockProcessor();
        AsyncAction__c action = processor?.initAction(null);
        
        insert action;
        Test.getEventBus().deliver();

        List<AsyncApexJob> jobs = [SELECT Id FROM AsyncApexJob WHERE ApexClass.Name = 'MockProcessor' LIMIT 1];
        Assert.isTrue(jobs?.isEmpty(), 'Job(s) were launched on insert'); 
    }

    @IsTest 
    static void shouldScheduleIfEnabled() {
        AsyncActionSetting__mdt settings = AsyncActionTestUtils.initGlobalSettings();
        settings.RunScheduledJob__c = true;
        settings.ScheduledJobInterval__c = 15;
        AsyncActionProcessor__mdt config = AsyncActionTestUtils.initProcessorSettings(MockProcessor.class);
        AsyncActionProcessor processor = new MockProcessor();
        AsyncAction__c action = processor?.initAction(null);
        
        insert action;
        Test.getEventBus().deliver();

        List<AsyncApexJob> jobs = [SELECT Id FROM AsyncApexJob WHERE ApexClass.Name = 'AsyncActionSchedulable' LIMIT 1];
        Assert.isFalse(jobs?.isEmpty(), 'Enabled Scheduled Job was not created');
    }

    @IsTest 
    static void shouldScheduleIfDisabled() {
        AsyncActionSetting__mdt settings = AsyncActionTestUtils.initGlobalSettings();
        settings.RunScheduledJob__c = false;
        AsyncActionProcessor__mdt config = AsyncActionTestUtils.initProcessorSettings(MockProcessor.class);
        AsyncActionProcessor processor = new MockProcessor();
        AsyncAction__c action = processor?.initAction(null);
        
        insert action;
        Test.getEventBus().deliver();

        List<AsyncApexJob> jobs = [SELECT Id FROM AsyncApexJob WHERE ApexClass.Name = 'AsyncActionSchedulable' LIMIT 1];
        Assert.isTrue(jobs?.isEmpty(), 'Disabled Scheduled Job was created');
    }
}