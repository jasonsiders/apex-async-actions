public abstract class AsyncActionPermissionUtils {
	public static final String PERMISSION_SET_NAME = 'AsyncActionAdministrator';
	static PermissionSet permissionSet;

	public static void assignPermissionSet(List<User> users) {
		PermissionSet permissionSet = AsyncActionPermissionUtils.getPermissionSet();
		List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();
		for (User user : users) {
			PermissionSetAssignment assignment = new PermissionSetAssignment(
				AssigneeId = user?.Id,
				PermissionSetId = permissionSet?.Id
			);
			assignments?.add(assignment);
		}
		insert assignments;
	}

	public static void assignPermissionSet(User user) {
		AsyncActionPermissionUtils.assignPermissionSet(new List<User>{ user });
	}

	public static PermissionSet getPermissionSet() {
		permissionSet = permissionSet ?? AsyncActionPermissionUtils.retrievePermissions();
		return permissionSet;
	}

	static PermissionSet retrievePermissions() {
		List<PermissionSet> permissionSet = [SELECT Id FROM PermissionSet WHERE Name = :PERMISSION_SET_NAME LIMIT 1];
		return (permissionSet?.isEmpty() == false) ? permissionSet[0] : null;
	}
}
