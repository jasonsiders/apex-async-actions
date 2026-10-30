/**
 * @description Global test utility class providing methods to test various parts of the AsyncActions framework.
 * Contains factory methods for creating test metadata and mock configuration objects.
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
@IsTest
global class AsyncActionTestUtils {
	/** @description ERROR messages saved through MockLogAdapter **/
	public static List<Object> errorLogs = new List<Object>{};

	/**
	 * @description Instantiates and returns an Apex processor settings object with default values for testing.
	 * @param processorType The processor class type to create settings for
	 * @return AsyncActionProcessor__mdt record configured for Apex processing
	 */
	global static AsyncActionProcessor__mdt initApexProcessor(Type processorType) {
		// Instantiates & returns an Apex processor settings object with default values for testing
		String className = processorType?.getName();
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initFlowProcessor(className);
		settings.ProcessorType__c = 'Apex';
		return settings;
	}

	/**
	 * @description Instantiates and returns a Flow processor settings object with default values for testing.
	 * @param flowName The name of the flow to create settings for
	 * @return AsyncActionProcessor__mdt record configured for Flow processing
	 */
	global static AsyncActionProcessor__mdt initFlowProcessor(String flowName) {
		// Instantiates & returns a Flow processor settings object with default values for testing
		AsyncActionProcessor__mdt settings = new AsyncActionProcessor__mdt(
			BatchSize__c = 200,
			DeveloperName = 'Test_' + flowName,
			Enabled__c = true,
			MasterLabel = 'Test ' + flowName,
			Processor__c = flowName,
			ProcessorType__c = 'Flow',
			Retries__c = 3,
			RetryInterval__c = 3,
			RunOnInsert__c = false
		);
		AsyncActionTestUtils.mockProcessorSettings(settings);
		return settings;
	}

	/**
	 * @description Instantiates and returns a scheduled job settings with default values for testing.
	 * @return AsyncActionScheduledJob__mdt record with test configuration
	 */
	global static AsyncActionScheduledJob__mdt initScheduledJobSettings() {
		// Instantiates and returns a scheduled job settings w/default values for testing
		Set<String> jobNames = AsyncActionScheduledJobService.settings?.keySet();
		Integer numSettings = jobNames?.size() ?? 0;
		String jobName = 'TestJob_' + (numSettings + 1);
		AsyncActionScheduledJob__mdt settings = new AsyncActionScheduledJob__mdt(
			DeveloperName = jobName,
			Enabled__c = false,
			MasterLabel = jobName,
			Type__c = 'Hourly'
		);
		AsyncActionTestUtils.mockScheduledJobSettings(settings);
		return settings;
	}

	/**
	 * @description Instantiates and returns a scheduled job item settings with default values for testing.
	 * @param actionSettings The action processor settings to associate with this job item
	 * @param jobSettings The scheduled job settings to associate with this job item
	 * @return AsyncActionScheduledJobItem__mdt record linking the action and job settings
	 */
	global static AsyncActionScheduledJobItem__mdt initScheduledJobItem(
		AsyncActionProcessor__mdt actionSettings,
		AsyncActionScheduledJob__mdt jobSettings
	) {
		// Instantiates and returns a scheduled job item settings w/default values for testing
		AsyncActionScheduledJobItem__mdt item = new AsyncActionScheduledJobItem__mdt(
			AsyncActionProcessor__r = actionSettings,
			DeveloperName = actionSettings?.DeveloperName + '_' + jobSettings?.DeveloperName,
			Enabled__c = true,
			ScheduledJob__r = jobSettings
		);
		AsyncActionTestUtils.mockScheduledJobItem(item);
		return item;
	}

	/**
	 * @description Gives subscriber tests a way to set parameters, since custom metadata can't be inserted via DML
	 * @param developerName The DeveloperName of the parameter to inject (ex., 'LoggerPlugin')
	 * @param value The Value__c of the parameter to inject
	 */
	global static void mockParameter(String developerName, String value) {
		AsyncActionParameter__mdt parameter = new AsyncActionParameter__mdt(
			DeveloperName = developerName,
			Value__c = value
		);
		Map<String, AsyncActionParameter__mdt> existing = AsyncActionParameterService.parameters ??
			new Map<String, AsyncActionParameter__mdt>{};
		// Copy, since a map already loaded from getAll() is read-only
		AsyncActionParameterService.parameters = new Map<String, AsyncActionParameter__mdt>(existing);
		AsyncActionParameterService.parameters?.put(developerName, parameter);
	}

	/**
	 * @description Provides @IsTest access to inject processor settings records to external callers.
	 * @param settings The processor settings record to inject for testing
	 */
	global static void mockProcessorSettings(AsyncActionProcessor__mdt settings) {
		// Gives @IsTest access to inject settings records to external callers
		AsyncActionProcessorService.processors = (AsyncActionProcessorService.processors != null)
			? AsyncActionProcessorService.processors
			: new Map<String, AsyncActionProcessor__mdt>{};
		String processorName = settings?.DeveloperName;
		AsyncActionProcessorService.processors?.put(processorName, settings);
	}

	/**
	 * @description Provides @IsTest access to inject scheduled job item settings records to external callers.
	 * IMPORTANT: The input object must have a fully populated ScheduledJob__r relationship.
	 * @param item The scheduled job item to inject for testing
	 */
	global static void mockScheduledJobItem(AsyncActionScheduledJobItem__mdt item) {
		// Gives @IsTest access to inject settings records to external callers
		// **IMPORTANT**: The input object must have a fully populated ScheduledJob__r relationship
		String jobName = item?.ScheduledJob__r?.DeveloperName;
		List<AsyncActionScheduledJobItem__mdt> matching = AsyncActionScheduledJobItemService.jobItems
				?.containsKey(jobName)
			? AsyncActionScheduledJobItemService.jobItems?.get(jobName)
			: new List<AsyncActionScheduledJobItem__mdt>{};
		matching?.add(item);
		AsyncActionScheduledJobItemService.jobItems?.put(jobName, matching);
	}

	/**
	 * @description Provides @IsTest access to inject job settings records to external callers.
	 * @param jobSettings The scheduled job settings record to inject for testing
	 */
	global static void mockScheduledJobSettings(AsyncActionScheduledJob__mdt jobSettings) {
		// Gives @IsTest access to inject job settings records to external callers
		AsyncActionScheduledJobService.settings = (AsyncActionScheduledJobService.settings != null)
			? AsyncActionScheduledJobService.settings
			: new Map<String, AsyncActionScheduledJob__mdt>{};
		String jobName = jobSettings?.DeveloperName;
		AsyncActionScheduledJobService.settings?.put(jobName, jobSettings);
	}

	/**
	 * @description Lets tests count the processors that were started
	 * @return The AsyncActionJob jobs
	 */
	public static List<AsyncApexJob> getProcessorJobs() {
		return [
			SELECT Id
			FROM AsyncApexJob
			WHERE ApexClass.Name = :AsyncActionJob.class.getName()
			WITH SYSTEM_MODE
		];
	}

	/**
	 * @description Scheduled jobs run as their owner, so this shows who a job runs as
	 * @param jobSettings The scheduled job settings to check
	 * @return The owner's UserType (ex., 'AutomatedProcess'), or null if not scheduled
	 */
	public static String getScheduledJobOwnerType(AsyncActionScheduledJob__mdt jobSettings) {
		String jobName = AsyncActionScheduledJobUtils.getJobName(jobSettings);
		User owner = [
			SELECT UserType
			FROM User
			WHERE Id IN (SELECT OwnerId FROM CronTrigger WHERE CronJobDetail.Name = :jobName)
			WITH SYSTEM_MODE
			LIMIT 1
		] ?? null;
		return owner?.UserType;
	}

	/**
	 * @description Inserts a Standard User with the AsyncActionAdministrator permission set
	 * @return The inserted User record
	 */
	public static User insertAdministrator() {
		PermissionSet permissionSet = [
			SELECT Id
			FROM PermissionSet
			WHERE Name = 'AsyncActionAdministrator'
			WITH SYSTEM_MODE
			LIMIT 1
		];
		User user = AsyncActionTestUtils.insertStandardUser();
		PermissionSetAssignment assignment = new PermissionSetAssignment(
			AssigneeId = user?.Id,
			PermissionSetId = permissionSet?.Id
		);
		AsyncActionTestUtils.insertSetupRecord(assignment);
		return user;
	}

	/**
	 * @description Inserts a Standard User with no package permission sets
	 * @return The inserted User record
	 */
	public static User insertStandardUser() {
		User user = AsyncActionTestUtils.initStandardUser();
		AsyncActionTestUtils.insertSetupRecord(user);
		return user;
	}

	/**
	 * @description Randomizes the username, which must be unique across all orgs
	 * @return The uninserted User record
	 */
	private static User initStandardUser() {
		Profile standardProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' WITH SYSTEM_MODE LIMIT 1];
		String username = 'testuser' + Crypto.getRandomInteger() + '@test.com';
		return new User(
			Alias = 'testuser',
			Email = username,
			EmailEncodingKey = 'UTF-8',
			LanguageLocaleKey = 'en_US',
			LastName = 'User',
			LocaleSidKey = 'en_US',
			ProfileId = standardProfile?.Id,
			TimeZoneSidKey = 'GMT',
			Username = username
		);
	}

	/**
	 * @description Uses runAs, since tests can't otherwise mix setup and non-setup DML
	 * @param record The record to insert, ex. a User
	 */
	private static void insertSetupRecord(SObject record) {
		User me = new User(Id = UserInfo.getUserId());
		System.runAs(me) {
			Database.insert(record, System.AccessLevel.SYSTEM_MODE);
		}
	}

	// **** INNER **** //
	/** @description Records ERROR logs for tests to assert on **/
	public class MockLogAdapter implements AsyncActionLogger.Adapter {
		/** @description ERROR messages not yet saved **/
		private List<Object> pendingLogs = new List<Object>{};

		/**
		 * @description Buffers ERROR messages until save()
		 * @param level The logging level for the message
		 * @param logMessage The message or object to log
		 */
		public void log(System.LoggingLevel level, Object logMessage) {
			if (level == System.LoggingLevel.ERROR) {
				this.pendingLogs?.add(logMessage);
			}
		}

		/** @description Moves buffered messages into errorLogs **/
		public void save() {
			AsyncActionTestUtils.errorLogs?.addAll(this.pendingLogs);
			this.pendingLogs?.clear();
		}
	}
}
