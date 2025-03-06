@SuppressWarnings('PMD.ApexDoc, PMD.AvoidDebugStatements, PMD.EmptyStatementBlock')
global abstract class AsyncActionLogger {
	@TestVisible
	private static final AsyncActionLogger.Adapter INSTANCE = AsyncActionLogger.getInstance();

	global static void log(System.LoggingLevel level, Object logMessage) {
		INSTANCE?.log(level, logMessage);
	}

	global static void save(Boolean publishImmediate) {
		INSTANCE?.save(publishImmediate);
	}

	private static AsyncActionLogger.Adapter getInstance() {
		// Initialize a log adapter object based on the provided value in custom metadata
		// If no metadata records, or if an invalid adapter is defined, will use the DefaultLogger instead
		AsyncActionGlobalSetting__mdt settings = AsyncActionGlobalSettingService.getSettings();
		String adapterName = settings?.LoggerPlugin__c;
		try {
			return (AsyncActionLogger.Adapter) Type.forName(adapterName)?.newInstance() ??
				new AsyncActionLogger.DefaultLogger();
		} catch (Exception error) {
			System.debug(System.LoggingLevel.WARN, adapterName + ' is not a instance of AsyncActionLogger.Adapter');
			return new AsyncActionLogger.DefaultLogger();
		}
	}

	// **** INNER **** //
	global interface Adapter {
		void log(System.LoggingLevel level, Object logMessage);
		void save(Boolean publishImmediate);
	}

	public class DefaultLogger implements AsyncActionLogger.Adapter {
		// The default log implementation will post logs to traditional Salesforce debug logs

		private DefaultLogger() {
			// Adapters should not be constructed manually
		}

		public void log(System.LoggingLevel level, Object logMessage) {
			// Print to traditional salesforce debug logs
			System.debug(level, logMessage);
		}

		public void save(Boolean publishImmediately) {
			// Many custom logging tools require a method like this, to commit logs to the database.
			// However, traditional salesforce debug logs do not require this, so this method will no-op.
		}
	}
}
