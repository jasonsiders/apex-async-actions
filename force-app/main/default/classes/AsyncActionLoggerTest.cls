@IsTest 
private class AsyncActionLoggerTest {
    @IsTest 
    static void shouldInitializeCustomLogAdapter() {
        Type adapterType = MockAdapter.class;
        AsyncActionGlobalSetting__mdt settings = AsyncActionTestUtils.initGlobalSettings();
        settings.LoggerAdapter__c = adapterType?.getName();

        Test.startTest();
        AsyncActionLogger.Adapter logger = AsyncActionLogger.init();
        Test.stopTest();

        System.debug(logger);
        Assert.isInstanceOfType(logger, adapterType, 'Wrong adapter type');
    }

    @IsTest 
    static void shouldUseDefaultLogAdapterIfInvalid() {
        AsyncActionGlobalSetting__mdt settings = AsyncActionTestUtils.initGlobalSettings();
        settings.LoggerAdapter__c = 'foo/bar';

        Test.startTest();
        AsyncActionLogger.Adapter logger = AsyncActionLogger.init();
        Test.stopTest();

        Assert.isInstanceOfType(logger, AsyncActionLogger.DefaultLogger.class, 'Wrong adapter type');
    }

    @IsTest 
    static void shouldUseDefualtLogAdapterIfNone() {
        AsyncActionGlobalSetting__mdt settings = AsyncActionTestUtils.initGlobalSettings();
        settings.LoggerAdapter__c = null;

        Test.startTest();
        AsyncActionLogger.Adapter logger = AsyncActionLogger.init();
        Test.stopTest();

        Assert.isInstanceOfType(logger, AsyncActionLogger.DefaultLogger.class, 'Wrong adapter type');
    }

    @IsTest 
    static void shouldPerformDefaultLoggingLogic() {
        AsyncActionLogger.DefaultLogger logger = (AsyncActionLogger.DefaultLogger) AsyncActionLogger.init();

        Test.startTest();
        try {
            logger?.log(System.LoggingLevel.FINEST, AsyncActionLoggerTest.class, UserInfo.getUserId(), 'Hello world!');
            logger?.save(false);
        } catch (Exception error) {
            Assert.fail('An error was thrown while performing default logging logic: ' + error);
        }
        Test.stopTest();
    }

    // **** INNER **** // 
    public class MockAdapter implements AsyncActionLogger.Adapter {
        public void log(System.LoggingLevel level, Type type, Id recordId, Object msg) {
            // Doesn't matter
        }

        public void save(Boolean publishImmediate) {
            // Doesn't matter
        }
    }
}