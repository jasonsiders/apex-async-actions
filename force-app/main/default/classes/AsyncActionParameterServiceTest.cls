@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest
private class AsyncActionParameterServiceTest {
	@IsTest
	static void shouldReturnNullIfParameterDoesNotExist() {
		Test.startTest();
		String value = AsyncActionParameterService.getParameter('Does_Not_Exist_1234');
		Test.stopTest();

		Assert.isNull(value, 'Returned a value for a parameter that does not exist');
	}

	@IsTest
	static void shouldInjectParameters() {
		AsyncActionTestUtils.mockParameter('Foo', 'Bar');

		Test.startTest();
		String value = AsyncActionParameterService.getParameter('Foo');
		Test.stopTest();

		Assert.areEqual('Bar', value, 'Did not use injected parameter');
	}
}
