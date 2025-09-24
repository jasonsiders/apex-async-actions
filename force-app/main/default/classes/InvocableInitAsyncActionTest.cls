@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest
private class InvocableInitAsyncActionTest {
	@IsTest
	static void shouldGenerateActionForSettings() {
		Type processor = MockAsyncActionProcessor.class;
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initApexProcessor(processor);
		InvocableInitAsyncAction.Input input = InvocableInitAsyncActionTest.initInput(settings);
		List<InvocableInitAsyncAction.Input> inputs = new List<InvocableInitAsyncAction.Input>{ input };

		Test.startTest();
		List<AsyncAction__c> actions = InvocableInitAsyncAction.invoke(inputs);
		Test.stopTest();

		Assert.areEqual(inputs?.size(), actions?.size(), 'Wrong # of inputs/oututs');
		AsyncAction__c action = actions?.get(0);
		Assert.areEqual(input?.data, action?.Data__c, 'Wrong Data');
		Assert.areEqual(input?.developerName, action?.ProcessorName__c, 'Wrong Processor');
		Assert.areEqual(input?.relatedRecordId, action?.RelatedRecordId__c, 'Wrong RelatedRecordId');
	}

	@SuppressWarnings('PMD.EmptyCatchBlock')
	@IsTest
	static void shouldThrowErrorIfInvalidDeveloperName() {
		Type processor = MockAsyncActionProcessor.class;
		AsyncActionProcessor__mdt settings = AsyncActionTestUtils.initApexProcessor(processor);
		InvocableInitAsyncAction.Input input = InvocableInitAsyncActionTest.initInput(settings);
		input.developerName = 'obviously_not_a_real_developer_name';
		List<InvocableInitAsyncAction.Input> inputs = new List<InvocableInitAsyncAction.Input>{ input };

		Test.startTest();
		try {
			InvocableInitAsyncAction.invoke(inputs);
			Assert.fail('Did not throw an exception');
		} catch (System.IllegalArgumentException error) {
			// As expected...
		}
		Test.stopTest();
	}

	static InvocableInitAsyncAction.Input initInput(AsyncActionProcessor__mdt settings) {
		InvocableInitAsyncAction.Input input = new InvocableInitAsyncAction.Input();
		input.data = '{"foo": "bar"}';
		input.developerName = settings?.DeveloperName;
		input.relatedRecordId = UserInfo.getUserId();
		return input;
	}
}
