/**
 * @description Test class for AsyncActionLogger functionality including custom adapters and default logging
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.EmptyStatementBlock')
@IsTest
private class AsyncActionLoggerTest {
	// Recorded by MockCallable; held here since inner classes can't declare static fields
	static List<String> callableActions = new List<String>{};
	static List<Map<String, Object>> callableArgs = new List<Map<String, Object>>{};

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
	static void shouldWrapCallableLogPlugin() {
		AsyncActionLoggerTest.useMockCallable();

		Test.startTest();
		AsyncActionLogger.Adapter logger = AsyncActionLogger.INSTANCE;
		Test.stopTest();

		Assert.isInstanceOfType(
			logger,
			AsyncActionLogger.CallableAdapter.class,
			'Wrong adapter type: ' + AsyncActionLogger.INSTANCE
		);
	}

	@IsTest
	static void shouldSendLogsToCallable() {
		AsyncActionLoggerTest.useMockCallable();

		Test.startTest();
		AsyncActionLogger.log(System.LoggingLevel.WARN, 'Test Log');
		Test.stopTest();

		Assert.areEqual(new List<String>{ 'newEntry' }, callableActions, 'Wrong actions');
		Map<String, Object> args = callableArgs?.get(0);
		Assert.areEqual(System.LoggingLevel.WARN, args?.get('loggingLevel'), 'Wrong loggingLevel');
		Assert.areEqual('Test Log', args?.get('message'), 'Wrong message');
		Assert.isFalse(args?.containsKey('exception'), 'Should not include an exception');
	}

	@IsTest
	static void shouldSendExceptionsToCallable() {
		AsyncActionLoggerTest.useMockCallable();
		Exception error = new DmlException('Oops');

		Test.startTest();
		AsyncActionLogger.log(System.LoggingLevel.ERROR, error);
		Test.stopTest();

		Map<String, Object> args = callableArgs?.get(0);
		Assert.areEqual(String.valueOf(error), args?.get('message'), 'Wrong message');
		Assert.areEqual(error, args?.get('exception'), 'Wrong exception');
	}

	@IsTest
	static void shouldSaveCallableLogs() {
		AsyncActionLoggerTest.useMockCallable();

		Test.startTest();
		AsyncActionLogger.save();
		Test.stopTest();

		Assert.areEqual(new List<String>{ 'saveLog' }, callableActions, 'Wrong actions');
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
	static void useMockCallable() {
		Type callableType = MockCallable.class;
		String callableName = callableType?.getName();
		AsyncActionTestUtils.mockParameter('LoggerPlugin', callableName);
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

	/**
	 * @description Mock System.Callable logger (ex., Nebula Logger's CallableLogger) that records each call for assertions
	 */
	public class MockCallable implements System.Callable {
		/**
		 * @description Records the call instead of logging it
		 * @param action The action to perform
		 * @param arguments The arguments for the action
		 * @return Always null
		 */
		public Object call(String action, Map<String, Object> arguments) {
			callableActions?.add(action);
			callableArgs?.add(arguments);
			return null;
		}
	}
}
