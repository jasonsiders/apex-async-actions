public abstract class AsyncActionTriggerFramework {
	// Simple TriggerHandler framework utilized by triggers in this package.
	// Includes methods to disable triggers, if desired by callers
	// **** STATIC **** //
	static Set<Type> bypassed = new Set<Type>();

	public static void disable(Type handlerType) {
		AsyncActionTriggerFramework.bypassed?.add(handlerType);
	}

	public static void enable(Type handlerType) {
		AsyncActionTriggerFramework.bypassed?.remove(handlerType);
	}

	// **** MEMBER **** //
	@TestVisible
	protected List<SObject> triggerNew,
		triggerOld;
	@TestVisible
	protected Map<Id, SObject> triggerNewMap,
		triggerOldMap;
	@TestVisible
	protected System.TriggerOperation operation;

	protected AsyncActionTriggerFramework() {
		this.initialize();
	}

	public abstract Type getType();

	public void run() {
		if (this.enabled() == false) {
			return;
		} else if (this.operation == System.TriggerOperation.BEFORE_INSERT) {
			this.beforeInsert();
		} else if (this.operation == System.TriggerOperation.BEFORE_UPDATE) {
			this.beforeUpdate();
		} else if (this.operation == System.TriggerOperation.BEFORE_DELETE) {
			this.beforeDelete();
		} else if (this.operation == System.TriggerOperation.AFTER_INSERT) {
			this.afterInsert();
		} else if (this.operation == System.TriggerOperation.AFTER_UPDATE) {
			this.afterUpdate();
		} else if (this.operation == System.TriggerOperation.AFTER_DELETE) {
			this.afterDelete();
		} else if (this.operation == System.TriggerOperation.AFTER_UNDELETE) {
			this.afterUndelete();
		}
	}

	// **** VIRTUAL **** //
	protected virtual void beforeInsert() {
	}
	protected virtual void beforeUpdate() {
	}
	protected virtual void beforeDelete() {
	}
	protected virtual void afterInsert() {
	}
	protected virtual void afterUpdate() {
	}
	protected virtual void afterDelete() {
	}
	protected virtual void afterUndelete() {
	}

	// **** PRIVATE **** //
	private Boolean enabled() {
		Type currentType = this.getType();
		return AsyncActionTriggerFramework.bypassed?.contains(currentType) == false;
	}

	private void initialize() {
		Boolean isTrigger = Trigger.isExecuting;
		this.triggerNew = (isTrigger) ? Trigger.new : new List<SObject>();
		this.triggerOld = (isTrigger) ? Trigger.old : new List<SObject>();
		this.triggerNewMap = (isTrigger) ? Trigger.newMap : new Map<Id, SObject>();
		this.triggerOldMap = (isTrigger) ? Trigger.oldMap : new Map<Id, SObject>();
		this.operation = (isTrigger) ? Trigger.operationType : null;
	}
}
