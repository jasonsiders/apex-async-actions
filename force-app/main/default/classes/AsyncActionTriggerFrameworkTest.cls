/**
 * @description Test class for AsyncActionTriggerFramework functionality including all trigger operations and bypass mechanisms
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.ApexUnitTestClassShouldHaveAsserts')
@IsTest
private class AsyncActionTriggerFrameworkTest {
	/**
	 * @description Static map to store test results for different trigger operations
	 */
	static Map<System.TriggerOperation, List<SObject>> results = new Map<System.TriggerOperation, List<SObject>>{};

	// **** TESTS **** //
	@IsTest
	static void shouldRunBeforeInsert() {
		AsyncActionTriggerFrameworkTest.testOperation(System.TriggerOperation.BEFORE_INSERT);
	}

	@IsTest
	static void shouldRunBeforeUpdate() {
		AsyncActionTriggerFrameworkTest.testOperation(System.TriggerOperation.BEFORE_UPDATE);
	}

	@IsTest
	static void shouldRunBeforeDelete() {
		AsyncActionTriggerFrameworkTest.testOperation(System.TriggerOperation.BEFORE_DELETE);
	}

	@IsTest
	static void shouldRunAfterInsert() {
		AsyncActionTriggerFrameworkTest.testOperation(System.TriggerOperation.AFTER_INSERT);
	}

	@IsTest
	static void shouldRunAfterUpdate() {
		AsyncActionTriggerFrameworkTest.testOperation(System.TriggerOperation.AFTER_UPDATE);
	}

	@IsTest
	static void shouldRunAfterDelete() {
		AsyncActionTriggerFrameworkTest.testOperation(System.TriggerOperation.AFTER_DELETE);
	}

	@IsTest
	static void shouldRunAfterUndelete() {
		AsyncActionTriggerFrameworkTest.testOperation(System.TriggerOperation.AFTER_UNDELETE);
	}

	@IsTest
	static void shouldNotRunIfBypassed() {
		List<Account> accounts = AsyncActionTriggerFrameworkTest.generateRecords();
		AsyncActionTriggerFramework handler = new ExampleHandler();
		handler.operation = System.TriggerOperation.BEFORE_INSERT;
		handler.triggerNew = accounts;
		AsyncActionTriggerFramework.disable(ExampleHandler.class);

		Test.startTest();
		handler?.run();
		Test.stopTest();

		Assert.isTrue(AsyncActionTriggerFrameworkTest.results?.isEmpty(), 'Disabled handler ran anyways');
	}

	@IsTest
	static void shouldRunIfReEnabled() {
		AsyncActionTriggerFramework.disable(ExampleHandler.class);
		List<Account> accounts = AsyncActionTriggerFrameworkTest.generateRecords();
		AsyncActionTriggerFramework handler = new ExampleHandler();
		handler.operation = System.TriggerOperation.BEFORE_INSERT;
		handler.triggerNew = accounts;
		// Re-enabling the handler will make it eligible to be run
		AsyncActionTriggerFramework.enable(ExampleHandler.class);

		Test.startTest();
		handler?.run();
		Test.stopTest();

		Assert.isFalse(AsyncActionTriggerFrameworkTest.results?.isEmpty(), 'Handler was re-enabled, but did not run');
	}

	@IsTest
	static void testTriggerBaseClass() {
		// Purely for code coverage. The base class is virtual, so the defualt implementation of the operation methods do nothing
		try {
			for (System.TriggerOperation operation : System.TriggerOperation.values()) {
				AsyncActionTriggerFramework handler = new DummyHandler();
				handler.operation = operation;
				handler?.run();
			}
		} catch (Exception error) {
			Assert.fail('Error during execution of base class: ' + error);
		}
	}

	// **** HELPER **** //
	/**
	 * @description Helper method to generate test Account records
	 * @return List of 200 test Account records
	 */
	static List<Account> generateRecords() {
		List<Account> accounts = new List<Account>{};
		for (Integer i = 0; i < 200; i++) {
			accounts?.add(new Account());
		}
		return accounts;
	}

	/**
	 * @description Helper method to test a specific trigger operation
	 * @param operation The trigger operation to test
	 */
	static void testOperation(System.TriggerOperation operation) {
		List<Account> accounts = AsyncActionTriggerFrameworkTest.generateRecords();
		AsyncActionTriggerFramework handler = new ExampleHandler();
		handler.operation = operation;
		handler.triggerNew = accounts;

		Test.startTest();
		handler?.run();
		Test.stopTest();

		Assert.isTrue(AsyncActionTriggerFrameworkTest.results?.containsKey(operation), 'Did not run ' + operation);
		Assert.areEqual(1, AsyncActionTriggerFrameworkTest.results?.size(), 'Wrong # of operations processed');
		Assert.areEqual(
			accounts?.size(),
			AsyncActionTriggerFrameworkTest.results?.get(operation)?.size(),
			'Wrong # of triggerNew records'
		);
	}

	// **** INNER **** //
	/**
	 * @description Example trigger handler implementation for testing all trigger operations
	 */
	public class ExampleHandler extends AsyncActionTriggerFramework {
		/**
		 * @description Returns the Type of this handler class
		 * @return The Type of ExampleHandler class
		 */
		public override Type getType() {
			return ExampleHandler.class;
		}

		/**
		 * @description Override for before insert trigger operation
		 */
		public override void beforeInsert() {
			this.mapOperation();
		}

		/**
		 * @description Override for before update trigger operation
		 */
		public override void beforeUpdate() {
			this.mapOperation();
		}

		/**
		 * @description Override for before delete trigger operation
		 */
		public override void beforeDelete() {
			this.mapOperation();
		}

		/**
		 * @description Override for after insert trigger operation
		 */
		public override void afterInsert() {
			this.mapOperation();
		}

		/**
		 * @description Override for after update trigger operation
		 */
		public override void afterUpdate() {
			this.mapOperation();
		}

		/**
		 * @description Override for after delete trigger operation
		 */
		public override void afterDelete() {
			this.mapOperation();
		}

		/**
		 * @description Override for after undelete trigger operation
		 */
		public override void afterUndelete() {
			this.mapOperation();
		}

		/**
		 * @description Maps the current operation and trigger new records to the test results
		 */
		public void mapOperation() {
			AsyncActionTriggerFrameworkTest.results?.put(this.operation, this.triggerNew);
		}
	}

	/**
	 * @description Dummy trigger handler implementation for testing base class coverage
	 */
	public class DummyHandler extends AsyncActionTriggerFramework {
		/**
		 * @description Returns the Type of this handler class
		 * @return The Type of DummyHandler class
		 */
		public override Type getType() {
			return DummyHandler.class;
		}
	}
}
