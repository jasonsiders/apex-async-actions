// Run this script to assign yourself the necessary permissions, typically in a new org
try {
	User me = new User(Id = UserInfo.getUserId());
	AsyncActionPermissionUtils.assignPermissionSet(me);
	System.debug('Success!');
} catch (Exception error) {
	System.debug('Failed: ' + error);
}
