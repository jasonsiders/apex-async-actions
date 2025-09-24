@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest
private class ExampleApexProcessorTest {
	@TestSetup
	static void setup() {
		Lead lead = new Lead(Company = 'Test Company', FirstName = 'John', LastName = 'Doe');
		insert lead;
	}
	@IsTest
	static void shouldConvertLeads() {
		Type processorType = ExampleApexProcessor.class;
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initApexProcessor(processorType);
		Lead lead = [SELECT Id FROM Lead LIMIT 1];
		Database.LeadConvert lc = ExampleApexProcessorTest.initLeadConvert(lead);
		AsyncAction__c action = AsyncActions.initAction(settings, lead, JSON.serialize(lc));
		insert action;

		Test.startTest();
		new AsyncActionLauncher()?.launch(settings);
		Test.stopTest();

		action = [SELECT Id, Status__c FROM AsyncAction__c];
		Assert.areEqual(AsyncActions.Status.COMPLETED.name(), action?.Status__c, 'Wrong Status');
		lead = [SELECT Id, IsConverted FROM Lead WHERE Id = :lead.Id];
		Assert.areEqual(true, lead?.IsConverted, 'Is not converted');
	}

	@IsTest
	static void shouldHandleErrors() {
		Type processorType = ExampleApexProcessor.class;
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initApexProcessor(processorType);
		settings.Retries__c = 0;
		Lead lead = [SELECT Id FROM Lead LIMIT 1];
		Database.LeadConvert lc = ExampleApexProcessorTest.initLeadConvert(lead);
		lc.setLeadId(null); // this should cause an error!
		AsyncAction__c action = AsyncActions.initAction(settings, lead, JSON.serialize(lc));
		insert action;

		Test.startTest();
		new AsyncActionLauncher()?.launch(settings);
		Test.stopTest();

		action = [SELECT Id, Status__c FROM AsyncAction__c];
		Assert.areEqual(AsyncActions.Status.FAILED.name(), action?.Status__c, 'Wrong Status');
		lead = [SELECT Id, IsConverted FROM Lead WHERE Id = :lead.Id];
		Assert.areEqual(false, lead?.IsConverted, 'Is converted');
	}

	static Database.LeadConvert initLeadConvert(Lead lead) {
		LeadStatus status = [SELECT ApiName FROM LeadStatus WHERE IsConverted = TRUE LIMIT 1];
		Database.LeadConvert lc = new Database.LeadConvert();
		lc.setLeadId(lead?.Id);
		lc.setConvertedStatus(status?.ApiName);
		return lc;
	}
}
