/**
 * @description Provides framework-wide logging by delegating to a configurable adapter.
 * Defaults to System.debug; subscribers supply a custom adapter, or the bundled NebulaAdapter,
 * via the LoggerPlugin AsyncActionParameter__mdt so log output can be routed to any platform
 * without changing call sites.
 */
// Global modifier and debug statements are required for subscriber extensibility; empty save() block is an intentional no-op
@SuppressWarnings('PMD.AvoidDebugStatements,PMD.AvoidGlobalModifier,PMD.EmptyStatementBlock')
global abstract class AsyncActionLogger {
	/** @description Shared fallback so DefaultLogger is only constructed once regardless of which code path triggers it **/
	private static final AsyncActionLogger.Adapter DEFAULT_LOGGER = new AsyncActionLogger.DefaultLogger();

	/** @description Cached once at class load to avoid repeated metadata queries per transaction **/
	@TestVisible
	private static final AsyncActionLogger.Adapter INSTANCE = AsyncActionLogger.getInstance() ?? DEFAULT_LOGGER;

	/**
	 * @description Delegates to the configured adapter so call sites are decoupled from the adapter implementation
	 * @param level The logging level for the message
	 * @param logMessage The message or object to log
	 */
	global static void log(System.LoggingLevel level, Object logMessage) {
		INSTANCE?.log(level, logMessage);
	}

	/** @description Delegated to the adapter, since only some adapters buffer entries that need a flush **/
	global static void save() {
		INSTANCE?.save();
	}

	// **** PRIVATE **** //

	/**
	 * @description Reads the LoggerPlugin parameter once so initialization cost is paid only once per transaction
	 * @return Configured adapter, or DefaultLogger when none is specified or the specified class fails to load
	 */
	private static AsyncActionLogger.Adapter getInstance() {
		String adapterName;
		try {
			adapterName = AsyncActionParameterService.getParameter('LoggerPlugin');
			AsyncActionLogger.Adapter adapter = String.isNotBlank(adapterName)
				? (AsyncActionLogger.Adapter) Type.forName(adapterName)?.newInstance()
				: DEFAULT_LOGGER;
			return adapter ?? DEFAULT_LOGGER;
		} catch (Exception error) {
			System.debug(System.LoggingLevel.WARN, adapterName + ' could not be loaded, using DefaultLogger: ' + error);
			return DEFAULT_LOGGER;
		}
	}

	// **** INNER **** //

	/** @description Contract custom adapters must satisfy; implement and register the class name via the LoggerPlugin AsyncActionParameter__mdt **/
	global interface Adapter {
		/**
		 * @description Called on every log statement; implementations must be safe to invoke in any execution context
		 * @param level The logging level for the message
		 * @param logMessage The message or object to log
		 */
		void log(System.LoggingLevel level, Object logMessage);
		/** @description Flushes buffered entries; called after each trigger and job execution **/
		void save();
	}

	/** @description Bundled fallback that writes to System.debug; used when LoggerPlugin is blank or fails **/
	@TestVisible
	private class DefaultLogger implements AsyncActionLogger.Adapter {
		/** @description Private to prevent external construction; access logging via AsyncActionLogger.log and AsyncActionLogger.save **/
		private DefaultLogger() {
		}

		/**
		 * @description Routes the message to System.debug so it appears in standard debug logs
		 * @param level The logging level for the message
		 * @param logMessage The message or object to log
		 */
		public void log(System.LoggingLevel level, Object logMessage) {
			System.debug(level, logMessage);
		}

		/** @description System.debug writes are immediate so no flush step is needed; declared to satisfy the Adapter contract **/
		public void save() {
		}
	}

	/** @description Bundled adapter for Nebula Logger; calls its CallableLogger, so there is no package dependency **/
	public virtual class NebulaAdapter implements AsyncActionLogger.Adapter {
		/** @description Typed as System.Callable so the package compiles without Nebula Logger installed **/
		private System.Callable logger;

		/** @description Throws when Nebula Logger isn't installed, so getInstance falls back to DefaultLogger **/
		public NebulaAdapter() {
			this.logger = this.initLogger();
			this.ignoreOrigin();
		}

		/**
		 * @description Attempts to initialize Nebula Logger's CallableLogger
		 * @throws System.TypeException when NebulaLogger is not installed
		 */
		private void initLogger() {
			Type loggerType = this.getLoggerType();
			if (loggerType == null) {
				throw new System.TypeException('Nebula Logger is not installed');
			} else {
				return (System.Callable) loggerType?.newInstance();
			}
		}

		/**
		 * @description Virtual so tests can stand in for Nebula Logger, whether or not it's installed
		 * @return Nebula Logger's CallableLogger type, or null when Nebula Logger isn't installed
		 */
		@TestVisible
		private virtual Type getLoggerType() {
			// Note: Nebula Logger's managed package uses the Nebula namespace; its unlocked package has none
			return Type.forName('Nebula', 'CallableLogger') ?? Type.forName('CallableLogger');
		}

		/** @description Omit this class from Nebula Logger's log stack traces */
		private void ignoreOrigin() {
			Map<Stirng, Object> args = new Map<String, Object>{ 'apexType' => AsyncActionLogger.class };
			this.logger?.call('ignoreOrigin', args);
		}

		/**
		 * @description Adds a log entry via the newEntry action
		 * @param level The logging level for the message
		 * @param logMessage The message or object to log
		 */
		public void log(System.LoggingLevel level, Object logMessage) {
			Map<String, Object> args = this.initEntryArgs(level, logMessage);
			this.logger?.call('newEntry', args);
		}

		/** @description Saves buffered entries via the saveLog action, using the logger's default save method **/
		public void save() {
			this.logger?.call('saveLog', null);
		}

		/**
		 * @description Exceptions are passed whole, so Nebula Logger can record their type and stack trace
		 * @param level The logging level for the message
		 * @param logMessage The message or object to log
		 * @return The newEntry arguments, keyed by the names Nebula Logger's CallableLogger expects
		 */
		@TestVisible
		private Map<String, Object> initEntryArgs(System.LoggingLevel level, Object logMessage) {
			Map<String, Object> args = new Map<String, Object>{
				'loggingLevel' => level,
				'message' => String.valueOf(logMessage),
				'tags' => new List<String>{ 'apex-async-actions' }
			};
			if (logMessage instanceof Exception) {
				args?.put('exception', logMessage);
			}
			return args;
		}
	}
}
