// Create a Lead Convert Action
AsyncActionProcessor__mdt leadJob = AsyncActionProcessor__mdt.getInstance('Example_Lead_Convert');
Lead lead = new Lead(Company = 'Test Company', FirstName = 'John', LastName = 'Doe');
insert lead;
LeadStatus status = [SELECT ApiName FROM LeadStatus WHERE IsConverted = true LIMIT 1];
Database.LeadConvert conversionInfo = new Database.LeadConvert();
conversionInfo.setConvertedStatus(status?.ApiName);
conversionInfo.setLeadId(lead?.Id);
AsyncAction__c leadAction = AsyncActions.initAction(leadJob, lead, JSON.serialize(conversionInfo));
// Create an Opportunity/Closed Won Action
AsyncActionProcessor__mdt oppJob = AsyncActionProcessor__mdt.getInstance('Example_Opportunity_Closed_Won');
Account account = new Account(Name = 'Test Account');
insert account;
Opportunity opportunity = new Opportunity(
    AccountId = account?.Id,
    Amount = 100,
    CloseDate = Date.today(),
    Name = 'Test Opportunity',
    StageName = 'New'
);
insert opportunity;
AsyncAction__c oppAction = AsyncActions.initAction(oppJob, opportunity);
List<AsyncAction__c> actions = new List<AsyncAction__c>{ leadAction, oppAction };
insert actions;
System.debug('Inserted Actions: ' + actions);