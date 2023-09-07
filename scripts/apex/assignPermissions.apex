// Run this script to assign yourself the necessary permissions, typically in a new org
final String PERMISSION_SET_NAME = 'AsyncActionAdministrator';
final String SEARCH_KEY = '%' + PERMISSION_SET_NAME;
List<PermissionSet> permissions = [SELECT Id, Name FROM PermissionSet WHERE Name LIKE :SEARCH_KEY];
PermissionSet permission = (permissions?.isEmpty() == false) ? permissions[0] : null; 
PermissionSetAssignment assignment = new PermissionSetAssignment(
    AssigneeId = UserInfo.getUserId(),
    PermissionSetId = permission?.Id
); 
try {
    upsert assignment;
    System.debug('Success! ' + assignment?.Id);
} catch (Exception error) {
    System.debug('Failed: ' + error);
}