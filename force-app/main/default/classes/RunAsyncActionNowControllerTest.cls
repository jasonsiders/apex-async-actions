@IsTest 
private class RunAsyncActionNowControllerTest {
    @IsTest 
    static void shouldLaunchAction() {
        AsyncActionScheduledJob__mdt jobSettings = AsyncActionTestUtils.initScheduledJobSettings();
		AsyncActionProcessor__mdt config = AsyncActionTestUtils.initProcessorSettings(MockAsyncActionProcessor.class);
        AsyncAction__c action = RunAsyncActionNowControllerTest.getAction();

        Test.startTest();
        RunAsyncActionNowController.runAction(action?.Id);
        Test.getEventBus().deliver();
        Test.stopTest();

        action = RunAsyncActionNowControllerTest.getAction(); 
        Assert.areEqual(AsyncActionProcessor.Status.COMPLETED.name(), action?.Status__c, 'Action was not processed');
    }

    @IsTest 
    static void shouldHandleFutureScheduledAction() {
        AsyncActionScheduledJob__mdt jobSettings = AsyncActionTestUtils.initScheduledJobSettings();
		AsyncActionProcessor__mdt config = AsyncActionTestUtils.initProcessorSettings(MockAsyncActionProcessor.class);
        AsyncAction__c action = RunAsyncActionNowControllerTest.getAction();
        // The action should process this action now, regardless of its scheduled value
        action.Scheduled__c = DateTime.now().addDays(10);
        update action;

        Test.startTest();
        RunAsyncActionNowController.runAction(action?.Id);
        Test.getEventBus().deliver();
        Test.stopTest();

        action = RunAsyncActionNowControllerTest.getAction(); 
        Assert.areEqual(AsyncActionProcessor.Status.COMPLETED.name(), action?.Status__c, 'Action was not processed');
    }

    @IsTest 
    static void shouldHandleErrors() {
        AuraHandledException auraError; 

        Test.startTest();
        try {
            RunAsyncActionNowController.runAction('not a real id');
        } catch (AuraHandledException caughtError) {
            auraError = caughtError; 
        }
        Test.stopTest();

        Assert.isNotNull(auraError, 'AuraHandledException');
    }

    // **** HELPER **** // 
    @TestSetup 
    static void setup() {
        Account account = new Account(Name = 'Test Account');
        insert account;
        AsyncActionProcessor__mdt config = AsyncActionTestUtils.initProcessorSettings(MockAsyncActionProcessor.class);
        config.Retries__c = 0;
        config.RunOnInsert__c = false;
        AsyncActionProcessor processor = new MockAsyncActionProcessor();
        String data = JSON.serialize(new Map<String, Object>{ 'numCases' => 1 });
        AsyncAction__c action = processor?.initAction(account?.Id, data);
        action.Status__c = AsyncActionProcessor.Status.CANCELED.name();
        insert action;
    }

    static AsyncAction__c getAction() {
        List<AsyncAction__c> actions = [
            SELECT Id, Scheduled__c, Status__c 
            FROM AsyncAction__c 
            ORDER BY CreatedDate DESC 
            LIMIT 1
        ];
        return actions?.isEmpty() == false ? actions[0] : null;
    }
}