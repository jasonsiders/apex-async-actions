@SuppressWarnings('PMD.AvoidDebugStatements,PMD.AvoidGlobalModifier,PMD.EmptyStatementBlock')
global abstract class AsyncActionLogger {
	/**
	 * This class is responsible for logging details about the AsyncActionFramework
	 * By default, it uses standard System.debug logs
	 * If desired, subscribers can write their own logging plugins, via the `AsyncActionLogger.Adapter` interface
	 * and register it in the `AsyncActionGlobalSetting__mdt.LoggerPlugin__c` field
	 * The framework stores the current logging instance in a singleton,
	 * which is accessed by the static `log` ad `save` methods by the application
	 **/
	@TestVisible
	private static final AsyncActionLogger.Adapter INSTANCE = AsyncActionLogger.getInstance();

	global static void log(System.LoggingLevel level, Object logMessage) {
		// Call the singleton instance's log method
		INSTANCE?.log(level, logMessage);
	}

	global static void save() {
		// Call the singleton instance's save method
		INSTANCE?.save();
	}

	private static AsyncActionLogger.Adapter getInstance() {
		// Initialize a log adapter object based on the provided value in custom metadata
		// If no metadata records, or if an invalid adapter is defined, will use the DefaultLogger instead
		String adapterName;
		try {
			AsyncActionGlobalSetting__mdt settings = AsyncActionGlobalSettingService.getSettings();
			adapterName = settings?.LoggerPlugin__c;
			AsyncActionLogger.Adapter adapter = (AsyncActionLogger.Adapter) Type.forName(adapterName)?.newInstance();
			return adapter ?? new AsyncActionLogger.DefaultLogger();
		} catch (Exception error) {
			System.debug(System.LoggingLevel.WARN, adapterName + ' is not a instance of AsyncActionLogger.Adapter');
			return new AsyncActionLogger.DefaultLogger();
		}
	}

	// **** INNER **** //
	global interface Adapter {
		/**
		 * The main logging interface for callers to implement
		 * Once implemented, specify the fully qualified api name of your class
		 * in AsyncActionGlobalSetting__mdt.LoggerPlugin__c
		 **/
		void log(System.LoggingLevel level, Object logMessage);
		void save();
	}

	@TestVisible
	private class DefaultLogger implements AsyncActionLogger.Adapter {
		/**
		 * The default log implementation will post logs to traditional Salesforce debug logs
		 **/
		private DefaultLogger() {
			// This adapter should not be constructed manually,
			// or otherwise accessed directly by external consumers
		}

		public void log(System.LoggingLevel level, Object logMessage) {
			// Print to traditional salesforce debug logs
			System.debug(level, logMessage);
		}

		public void save() {
			// Many custom logging tools require a method like this, to commit logs to the database.
			// However, traditional salesforce debug logs do not require this, so this method will no-op.
		}
	}
}
