@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.ApexUnitTestClassShouldHaveAsserts')
@IsTest
private class AsyncActionTriggerFrameworkTest {
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
	static List<Account> generateRecords() {
		List<Account> accounts = new List<Account>{};
		for (Integer i = 0; i < 200; i++) {
			accounts?.add(new Account());
		}
		return accounts;
	}

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
	public class ExampleHandler extends AsyncActionTriggerFramework {
		public override Type getType() {
			return ExampleHandler.class;
		}

		public override void beforeInsert() {
			this.mapOperation();
		}

		public override void beforeUpdate() {
			this.mapOperation();
		}

		public override void beforeDelete() {
			this.mapOperation();
		}

		public override void afterInsert() {
			this.mapOperation();
		}

		public override void afterUpdate() {
			this.mapOperation();
		}

		public override void afterDelete() {
			this.mapOperation();
		}

		public override void afterUndelete() {
			this.mapOperation();
		}

		public void mapOperation() {
			AsyncActionTriggerFrameworkTest.results?.put(this.operation, this.triggerNew);
		}
	}

	public class DummyHandler extends AsyncActionTriggerFramework {
		public override Type getType() {
			return DummyHandler.class;
		}
	}
}
