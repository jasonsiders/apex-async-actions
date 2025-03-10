@IsTest
private class AsyncActionPermissionUtilsTest {
	@IsTest
	static void shouldGetPermissionSet() {
		for (Integer i = 0; i < 3; i++) {
			PermissionSet permissionSet = AsyncActionPermissionUtils.getPermissionSet();
			Assert.isNotNull(permissionSet, 'Did not return a permission set');
			Assert.areEqual(1, Limits.getQueries(), 'Wrong # of SOQL queries made');
		}
	}

	@IsTest
	static void shouldAssignPermissionSet() {
		User me = new User(Id = UserInfo.getUserId());
		// Avoid creating duplicate assignments - just for testing
		List<PermissionSetAssignment> myAssignments = AsyncActionPermissionUtilsTest.getMyAssignments();
		Database.delete(myAssignments, System.AccessLevel.SYSTEM_MODE);

		Test.startTest();
		AsyncActionPermissionUtils.assignPermissionSet(me);
		Test.stopTest();

		List<PermissionSetAssignment> assignments = AsyncActionPermissionUtilsTest.getMyAssignments();
		Assert.isFalse(assignments?.isEmpty(), 'Permission set was not assigned');
	}

	// **** HELPER **** //
	static List<PermissionSetAssignment> getMyAssignments() {
		return [
			SELECT Id
			FROM PermissionSetAssignment
			WHERE
				AssigneeId = :UserInfo.getUserId()
				AND PermissionSet.Name = :AsyncActionPermissionUtils.PERMISSION_SET_NAME
		];
	}
}
