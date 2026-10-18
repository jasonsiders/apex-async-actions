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

	/** @description Flushes buffered log entries; delegated to the adapter since only custom adapters require an explicit flush **/
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
			System.debug(System.LoggingLevel.WARN, adapterName + ' is not a instance of AsyncActionLogger.Adapter');
			return DEFAULT_LOGGER;
		}
	}

	/**
	 * @description On the outer class so tests can cover it without Nebula Logger installed; exceptions are also
	 * passed whole, so Nebula Logger can record their type and stack trace
	 * @param level The logging level for the message
	 * @param logMessage The message or object to log
	 * @return The newEntry arguments, keyed by the names Nebula Logger's CallableLogger expects
	 */
	@TestVisible
	private static Map<String, Object> initNebulaEntryArgs(System.LoggingLevel level, Object logMessage) {
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

	/** @description Bundled fallback that writes to System.debug; active when no LoggerPlugin parameter is configured **/
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
	public class NebulaAdapter implements AsyncActionLogger.Adapter {
		/** @description Typed as System.Callable so the package compiles without Nebula Logger installed **/
		private System.Callable logger;

		/** @description Throws when Nebula Logger isn't installed, so getInstance falls back to DefaultLogger **/
		public NebulaAdapter() {
			// Nebula Logger's managed package uses the Nebula namespace; its unlocked package has none
			Type loggerType = Type.forName('Nebula', 'CallableLogger') ?? Type.forName('CallableLogger');
			this.logger = (System.Callable) loggerType.newInstance();
			// Keeps AsyncActionLogger (and so this inner class) out of each entry's origin. A no-op until Nebula
			// Logger releases ignoreOrigin: older versions reject it as unknown, and CallableLogger reports that
			// without throwing
			this.logger?.call('ignoreOrigin', new Map<String, Object>{ 'apexType' => AsyncActionLogger.class });
		}

		/**
		 * @description Adds a log entry via the newEntry action
		 * @param level The logging level for the message
		 * @param logMessage The message or object to log
		 */
		public void log(System.LoggingLevel level, Object logMessage) {
			Map<String, Object> args = AsyncActionLogger.initNebulaEntryArgs(level, logMessage);
			this.logger?.call('newEntry', args);
		}

		/** @description Saves buffered entries via the saveLog action, using the logger's default save method **/
		public void save() {
			this.logger?.call('saveLog', null);
		}
	}
}
