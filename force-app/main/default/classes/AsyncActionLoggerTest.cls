/**
 * @description Test class for AsyncActionLogger functionality including custom adapters and default logging
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.EmptyStatementBlock')
@IsTest
private class AsyncActionLoggerTest {
	@IsTest
	static void shouldLog() {
		Type adapterType = MockAdapter.class;
		AsyncActionGlobalSetting__mdt settings = AsyncActionTestUtils.initGlobalSettings();
		settings.LoggerPlugin__c = adapterType?.getName();

		try {
			Test.startTest();
			AsyncActionLogger.log(System.LoggingLevel.DEBUG, 'Test Log');
			AsyncActionLogger.save();
			Test.stopTest();
		} catch (Exception error) {
			Assert.fail('Failed to log: ' + error);
		}
	}

	@IsTest
	static void shouldInitializeCustomLogAdapter() {
		Type adapterType = MockAdapter.class;
		AsyncActionGlobalSetting__mdt settings = AsyncActionTestUtils.initGlobalSettings();
		settings.LoggerPlugin__c = adapterType?.getName();

		Test.startTest();
		AsyncActionLogger.Adapter logger = AsyncActionLogger.INSTANCE;
		Test.stopTest();

		Assert.isInstanceOfType(logger, adapterType, 'Wrong adapter type: ' + AsyncActionLogger.INSTANCE);
	}

	@IsTest
	static void shouldUseDefaultLogAdapterIfInvalid() {
		AsyncActionGlobalSetting__mdt settings = AsyncActionTestUtils.initGlobalSettings();
		settings.LoggerPlugin__c = 'foo/bar';

		Test.startTest();
		AsyncActionLogger.Adapter logger = AsyncActionLogger.INSTANCE;
		Test.stopTest();

		Assert.isInstanceOfType(
			logger,
			AsyncActionLogger.DefaultLogger.class,
			'Wrong adapter type: ' + AsyncActionLogger.INSTANCE
		);
	}

	@IsTest
	static void shouldUseDefualtLogAdapterIfNone() {
		AsyncActionGlobalSetting__mdt settings = AsyncActionTestUtils.initGlobalSettings();
		settings.LoggerPlugin__c = null;

		Test.startTest();
		AsyncActionLogger.Adapter logger = AsyncActionLogger.INSTANCE;
		Test.stopTest();

		Assert.isInstanceOfType(
			logger,
			AsyncActionLogger.DefaultLogger.class,
			'Wrong adapter type: ' + AsyncActionLogger.INSTANCE
		);
	}

	@IsTest
	static void shouldPerformDefaultLoggingLogic() {
		// Ensure the default logger is used
		AsyncActionGlobalSetting__mdt settings = AsyncActionTestUtils.initGlobalSettings();
		settings.LoggerPlugin__c = null;

		Test.startTest();
		try {
			AsyncActionLogger.log(System.LoggingLevel.FINEST, 'Hello world!');
			AsyncActionLogger.save();
		} catch (Exception error) {
			Assert.fail('An error was thrown while performing default logging logic: ' + error);
		}
		Test.stopTest();
	}

	// **** INNER **** //
	/**
	 * @description Mock adapter implementation for testing custom logging functionality
	 */
	public class MockAdapter implements AsyncActionLogger.Adapter {
		/**
		 * @description Mock log implementation that does nothing
		 * @param level The logging level (unused in mock)
		 * @param msg The message to log (unused in mock)
		 */
		public void log(System.LoggingLevel level, Object msg) {
			// Doesn't matter
		}

		/**
		 * @description Mock save implementation that does nothing
		 */
		public void save() {
			// Doesn't matter
		}
	}
}
