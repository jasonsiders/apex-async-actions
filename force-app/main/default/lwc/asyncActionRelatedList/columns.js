import ACTION_NAME_FIELD from "@salesforce/schema/AsyncAction__c.Name";
import PROCESSOR_FIELD from "@salesforce/schema/AsyncAction__c.ProcessorClass__c";
import SCHEDULED_FIELD from "@salesforce/schema/AsyncAction__c.Scheduled__c";
import STATUS_FIELD from "@salesforce/schema/AsyncAction__c.Status__c";
const CREATED_BY_NAME_FIELD = "CreatedByName";
const CREATED_BY_URL_FIELD = "CreatedByUrl";
const URL_FIELD = "ActionUrl";
const COLUMNS = [
	{
		label: "Async Action",
		fieldName: URL_FIELD,
		includeInRelatedList: true,
		type: "url",
		typeAttributes: {
			label: { fieldName: ACTION_NAME_FIELD?.fieldApiName }
		}
	},
	{
		label: "Processor Class",
		fieldName: PROCESSOR_FIELD?.fieldApiName,
		includeInRelatedList: true
	},
	{
		label: "Status",
		fieldName: STATUS_FIELD?.fieldApiName,
		includeInRelatedList: true
	},
	{
		label: "Created By",
		fieldName: CREATED_BY_URL_FIELD,
		type: "url",
		typeAttributes: {
			label: { fieldName: CREATED_BY_NAME_FIELD }
		}
	},
	{
		label: "Scheduled",
		fieldName: SCHEDULED_FIELD?.fieldApiName,
		includeInRelatedList: true,
		type: "date",
		typeAttributes: {
			day: "2-digit",
			hour: "2-digit",
			minute: "2-digit",
			month: "2-digit",
			year: "2-digit"
		}
	}
];

export default function getColumns() {
	return COLUMNS;
}
