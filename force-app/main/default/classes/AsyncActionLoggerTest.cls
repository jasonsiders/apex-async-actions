/**
 * @description Test class for AsyncActionLogger functionality including custom adapters and default logging
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.EmptyStatementBlock')
@IsTest
private class AsyncActionLoggerTest {
	@IsTest
	static void shouldLog() {
		Type adapterType = MockAdapter.class;
		String adapterName = adapterType?.getName();
		AsyncActionTestUtils.mockParameter('LoggerPlugin', adapterName);

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
		String adapterName = adapterType?.getName();
		AsyncActionTestUtils.mockParameter('LoggerPlugin', adapterName);

		Test.startTest();
		AsyncActionLogger.Adapter logger = AsyncActionLogger.INSTANCE;
		Test.stopTest();

		Assert.isInstanceOfType(logger, adapterType, 'Wrong adapter type: ' + AsyncActionLogger.INSTANCE);
	}

	@IsTest
	static void shouldUseDefaultLogAdapterIfInvalid() {
		AsyncActionTestUtils.mockParameter('LoggerPlugin', 'foo/bar');

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
	static void shouldUseDefaultLogAdapterIfNotAnAdapter() {
		// Use a real class that exists but doesn't implement AsyncActionLogger.Adapter.
		// Type.forName() will succeed and newInstance() will return an object, but the
		// cast to Adapter throws a TypeException, which exercises the catch block in getInstance().
		AsyncActionTestUtils.mockParameter('LoggerPlugin', 'InvocableInitAsyncAction');

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
		AsyncActionTestUtils.mockParameter('LoggerPlugin', null);

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
	static void shouldUseNebulaAdapterIfNebulaIsInstalled() {
		Type adapterType = AsyncActionLogger.NebulaAdapter.class;
		String adapterName = adapterType?.getName();
		AsyncActionTestUtils.mockParameter('LoggerPlugin', adapterName);

		Test.startTest();
		AsyncActionLogger.Adapter logger = AsyncActionLogger.INSTANCE;
		Test.stopTest();

		Boolean isNebulaInstalled = AsyncActionLoggerTest.isNebulaInstalled();
		Type expectedType = isNebulaInstalled ? adapterType : AsyncActionLogger.DefaultLogger.class;
		Assert.isInstanceOfType(logger, expectedType, 'Wrong adapter type: ' + logger);
	}

	@IsTest
	static void shouldLogToNebula() {
		Type adapterType = AsyncActionLogger.NebulaAdapter.class;
		String adapterName = adapterType?.getName();
		AsyncActionTestUtils.mockParameter('LoggerPlugin', adapterName);

		try {
			Test.startTest();
			AsyncActionLogger.log(System.LoggingLevel.WARN, 'Test Log');
			AsyncActionLogger.log(System.LoggingLevel.ERROR, new DmlException('Oops'));
			AsyncActionLogger.save();
			Test.stopTest();
		} catch (Exception error) {
			Assert.fail('Failed to log: ' + error);
		}
	}

	@IsTest
	static void shouldBuildNebulaEntryArgs() {
		Test.startTest();
		Map<String, Object> args = AsyncActionLogger.initNebulaEntryArgs(System.LoggingLevel.WARN, 'Test Log');
		Test.stopTest();

		Assert.areEqual(System.LoggingLevel.WARN, args?.get('loggingLevel'), 'Wrong loggingLevel');
		Assert.areEqual('Test Log', args?.get('message'), 'Wrong message');
		Assert.areEqual(new List<String>{ 'apex-async-actions' }, args?.get('tags'), 'Wrong tags');
		Assert.isFalse(args?.containsKey('exception'), 'Should not include an exception');
	}

	@IsTest
	static void shouldIncludeExceptionInNebulaEntryArgs() {
		Exception error = new DmlException('Oops');

		Test.startTest();
		Map<String, Object> args = AsyncActionLogger.initNebulaEntryArgs(System.LoggingLevel.ERROR, error);
		Test.stopTest();

		Assert.areEqual(error, args?.get('exception'), 'Wrong exception');
	}

	@IsTest
	static void shouldPerformDefaultLoggingLogic() {
		// Ensure the default logger is used
		AsyncActionTestUtils.mockParameter('LoggerPlugin', null);

		Test.startTest();
		try {
			AsyncActionLogger.log(System.LoggingLevel.FINEST, 'Hello world!');
			AsyncActionLogger.save();
		} catch (Exception error) {
			Assert.fail('An error was thrown while performing default logging logic: ' + error);
		}
		Test.stopTest();
	}

	// **** PRIVATE **** //
	static Boolean isNebulaInstalled() {
		Type loggerType = Type.forName('Nebula', 'CallableLogger') ?? Type.forName('CallableLogger');
		return loggerType != null;
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
