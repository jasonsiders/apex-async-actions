/**
 * @description Abstract trigger handler framework for triggers in this package.
 * Provides a simple framework with trigger context management and the ability to disable triggers.
 */
@SuppressWarnings('PMD.EmptyStatementBlock')
public abstract class AsyncActionTriggerFramework {
	private static Set<Type> bypassed = new Set<Type>{};

	/**
	 * @description The new trigger records (Trigger.new).
	 */
	@TestVisible
	protected List<SObject> triggerNew;
	/**
	 * @description The old trigger records (Trigger.old).
	 */
	@TestVisible
	protected List<SObject> triggerOld;
	/**
	 * @description Map of new trigger records by ID (Trigger.newMap).
	 */
	@TestVisible
	protected Map<Id, SObject> triggerNewMap;
	/**
	 * @description Map of old trigger records by ID (Trigger.oldMap).
	 */
	@TestVisible
	protected Map<Id, SObject> triggerOldMap;
	/**
	 * @description The current trigger operation type.
	 */
	@TestVisible
	protected System.TriggerOperation operation;

	/**
	 * @description Constructor that initializes trigger context variables.
	 */
	protected AsyncActionTriggerFramework() {
		this.initialize();
	}

	/**
	 * @description Abstract method that subclasses must implement to return their Type.
	 * @return The Type of the implementing class
	 */
	public abstract Type getType();

	/**
	 * @description Main execution method that delegates to appropriate trigger event handlers.
	 */
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
	/**
	 * @description Virtual method for before insert trigger logic. Override in subclasses as needed.
	 */
	protected virtual void beforeInsert() {
	}
	/**
	 * @description Virtual method for before update trigger logic. Override in subclasses as needed.
	 */
	protected virtual void beforeUpdate() {
	}
	/**
	 * @description Virtual method for before delete trigger logic. Override in subclasses as needed.
	 */
	protected virtual void beforeDelete() {
	}
	/**
	 * @description Virtual method for after insert trigger logic. Override in subclasses as needed.
	 */
	protected virtual void afterInsert() {
	}
	/**
	 * @description Virtual method for after update trigger logic. Override in subclasses as needed.
	 */
	protected virtual void afterUpdate() {
	}
	/**
	 * @description Virtual method for after delete trigger logic. Override in subclasses as needed.
	 */
	protected virtual void afterDelete() {
	}
	/**
	 * @description Virtual method for after undelete trigger logic. Override in subclasses as needed.
	 */
	protected virtual void afterUndelete() {
	}

	// **** STATIC **** //
	/**
	 * @description Disables trigger execution for the specified handler type.
	 * @param handlerType The handler class type to disable
	 */
	public static void disable(Type handlerType) {
		AsyncActionTriggerFramework.bypassed?.add(handlerType);
	}

	/**
	 * @description Enables trigger execution for the specified handler type.
	 * @param handlerType The handler class type to enable
	 */
	public static void enable(Type handlerType) {
		AsyncActionTriggerFramework.bypassed?.remove(handlerType);
	}

	// **** PRIVATE **** //
	private Boolean enabled() {
		Type currentType = this.getType();
		return AsyncActionTriggerFramework.bypassed?.contains(currentType) == false;
	}

	private void initialize() {
		Boolean isTrigger = Trigger.isExecuting;
		this.triggerNew = (isTrigger) ? Trigger.new : new List<SObject>{};
		this.triggerOld = (isTrigger) ? Trigger.old : new List<SObject>{};
		this.triggerNewMap = (isTrigger) ? Trigger.newMap : new Map<Id, SObject>{};
		this.triggerOldMap = (isTrigger) ? Trigger.oldMap : new Map<Id, SObject>{};
		this.operation = (isTrigger) ? Trigger.operationType : null;
	}
}
