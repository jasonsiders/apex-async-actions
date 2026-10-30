/**
 * @description Global test utility class providing methods to test various parts of the AsyncActions framework.
 * Contains factory methods for creating test metadata and mock configuration objects.
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
@IsTest
global class AsyncActionTestUtils {
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
	 * @description Inserts a Standard User assigned the AsyncActionAdministrator permission set,
	 * which does not grant Create access on AsyncActionStart__e.
	 * @return The inserted User record
	 */
	public static User insertAdministrator() {
		Profile standardProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' WITH SYSTEM_MODE LIMIT 1];
		PermissionSet permissionSet = [
			SELECT Id
			FROM PermissionSet
			WHERE Name = 'AsyncActionAdministrator'
			WITH SYSTEM_MODE
			LIMIT 1
		];
		String username = 'testuser' + Crypto.getRandomInteger() + '@test.com';
		User user = new User(
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
		// Can't mix DML ops - this is a workaround
		User me = new User(Id = UserInfo.getUserId());
		System.runAs(me) {
			Database.insert(user, System.AccessLevel.SYSTEM_MODE);
			PermissionSetAssignment assignment = new PermissionSetAssignment(
				AssigneeId = user?.Id,
				PermissionSetId = permissionSet?.Id
			);
			Database.insert(assignment, System.AccessLevel.SYSTEM_MODE);
		}
		return user;
	}

	/**
	 * @description Returns the UserType of the user who owns the scheduled job for the given settings.
	 * @param jobSettings The scheduled job settings to check
	 * @return The owner's UserType (ex., 'AutomatedProcess'), or null if the job is not scheduled
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
}
