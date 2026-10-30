/**
 * @description Test class for AsyncActionLogger functionality including custom adapters and default logging
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.EmptyStatementBlock')
@IsTest
private class AsyncActionLoggerTest {
	/** @description The last args the mock Callable received for each action, so tests can assert what NebulaAdapter sent **/
	private static Map<String, Map<String, Object>> argsByAction = new Map<String, Map<String, Object>>();

	@IsTest
	static void shouldLog() {
		Type adapterType = AsyncActionTestUtils.MockLogAdapter.class;
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
		Type adapterType = AsyncActionTestUtils.MockLogAdapter.class;
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

		Type nebulaType = Type.forName('Nebula', 'CallableLogger') ?? Type.forName('CallableLogger');
		Type expectedType = (nebulaType != null) ? adapterType : AsyncActionLogger.DefaultLogger.class;
		Assert.isInstanceOfType(logger, expectedType, 'Wrong adapter type: ' + logger);
	}

	@IsTest
	static void shouldLogToNebula() {
		AsyncActionLogger.Adapter logger = new MockNebulaAdapter();

		try {
			Test.startTest();
			logger?.log(System.LoggingLevel.WARN, 'Test Log');
			logger?.log(System.LoggingLevel.ERROR, new DmlException('Oops'));
			logger?.save();
			Test.stopTest();
		} catch (Exception error) {
			Assert.fail('Failed to log: ' + error);
		}
	}

	@IsTest
	static void shouldThrowIfNebulaIsNotInstalled() {
		Test.startTest();
		try {
			new InvalidNebulaAdapter();
			Assert.fail('Did not throw a System.TypeException');
		} catch (System.TypeException typeError) {
			Assert.areEqual('Nebula Logger is not installed', typeError?.getMessage(), 'Wrong error');
		}
		Test.stopTest();
	}

	@IsTest
	static void shouldBuildNebulaEntryArgs() {
		AsyncActionLogger.Adapter logger = new MockNebulaAdapter();

		Test.startTest();
		logger?.log(System.LoggingLevel.WARN, 'Test Log');
		Test.stopTest();

		Map<String, Object> args = argsByAction?.get('newEntry');

		Assert.areEqual(System.LoggingLevel.WARN, args?.get('loggingLevel'), 'Wrong loggingLevel');
		Assert.areEqual('Test Log', args?.get('message'), 'Wrong message');
		Assert.areEqual(new List<String>{ 'apex-async-actions' }, args?.get('tags'), 'Wrong tags');
		Assert.isFalse(args?.containsKey('exception'), 'Should not include an exception');
	}

	@IsTest
	static void shouldIncludeExceptionInNebulaEntryArgs() {
		AsyncActionLogger.Adapter logger = new MockNebulaAdapter();
		Exception error = new DmlException('Oops');

		Test.startTest();
		logger?.log(System.LoggingLevel.ERROR, error);
		Test.stopTest();

		Map<String, Object> args = argsByAction?.get('newEntry');

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

	// **** INNER **** //
	/**
	 * @description Reports no CallableLogger type, as if Nebula Logger isn't installed
	 */
	private class InvalidNebulaAdapter extends AsyncActionLogger.NebulaAdapter {
		/**
		 * @description Simulates a missing Nebula Logger package
		 * @return null
		 */
		protected override Type getLoggerType() {
			return null;
		}
	}

	/**
	 * @description Swaps Nebula Logger's CallableLogger for MockCallable, so tests can run without Nebula Logger
	 */
	private class MockNebulaAdapter extends AsyncActionLogger.NebulaAdapter {
		/**
		 * @description Stands in for Nebula Logger's CallableLogger type
		 * @return The MockCallable type
		 */
		protected override Type getLoggerType() {
			return MockCallable.class;
		}
	}

	/**
	 * @description Mock CallableLogger that records each action's args in argsByAction
	 */
	public class MockCallable implements System.Callable {
		/**
		 * @description Records the action's args in place of calling Nebula Logger
		 * @param action The action name
		 * @param args The action arguments
		 * @return null
		 */
		public Object call(String action, Map<String, Object> args) {
			argsByAction?.put(action, args);
			return null;
		}
	}
}
