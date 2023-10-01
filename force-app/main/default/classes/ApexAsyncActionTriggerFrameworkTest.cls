@IsTest 
private class ApexAsyncActionTriggerFrameworkTest {
    @IsTest 
    static void shouldRunBeforeInsert() {
        ApexAsyncActionTriggerFrameworkTest.testOperation(System.TriggerOperation.BEFORE_INSERT);
    }

    @IsTest 
    static void shouldRunBeforeUpdate() {
        ApexAsyncActionTriggerFrameworkTest.testOperation(System.TriggerOperation.BEFORE_UPDATE);
    }

    @IsTest 
    static void shouldRunBeforeDelete() {
        ApexAsyncActionTriggerFrameworkTest.testOperation(System.TriggerOperation.BEFORE_DELETE);
    }

    @IsTest 
    static void shouldRunAfterInsert() {
        ApexAsyncActionTriggerFrameworkTest.testOperation(System.TriggerOperation.AFTER_INSERT);
    }

    @IsTest 
    static void shouldRunAfterUpdate() {
        ApexAsyncActionTriggerFrameworkTest.testOperation(System.TriggerOperation.AFTER_UPDATE);
    }

    @IsTest 
    static void shouldRunAfterDelete() {
        ApexAsyncActionTriggerFrameworkTest.testOperation(System.TriggerOperation.AFTER_DELETE);
    }

    @IsTest 
    static void shouldRunAfterUndelete() {
        ApexAsyncActionTriggerFrameworkTest.testOperation(System.TriggerOperation.AFTER_UNDELETE);
    }

    @IsTest 
    static void shouldNotRunIfBypassed() {
        List<Account> accounts = ApexAsyncActionTriggerFrameworkTest.generateRecords();
        ApexAsyncActionTriggerFramework handler = new ExampleHandler();
        handler.operation = System.TriggerOperation.BEFORE_INSERT;
        handler.triggerNew = accounts;
        ApexAsyncActionTriggerFramework.disable(ExampleHandler.class);

        Test.startTest();
        handler?.run();
        Test.stopTest();

        Assert.isTrue(ApexAsyncActionTriggerFrameworkTest.results?.isEmpty(), 'Disabled handler ran anyways'); 
    }

    @IsTest 
    static void shouldRunIfReEnabled() {
        ApexAsyncActionTriggerFramework.disable(ExampleHandler.class);
        List<Account> accounts = ApexAsyncActionTriggerFrameworkTest.generateRecords();
        ApexAsyncActionTriggerFramework handler = new ExampleHandler();
        handler.operation = System.TriggerOperation.BEFORE_INSERT;
        handler.triggerNew = accounts;
        // Re-enabling the handler will make it eligible to be run
        ApexAsyncActionTriggerFramework.enable(ExampleHandler.class);

        Test.startTest();
        handler?.run();
        Test.stopTest();

        Assert.isFalse(ApexAsyncActionTriggerFrameworkTest.results?.isEmpty(), 'Handler was re-enabled, but did not run'); 
    }

    // **** HELPER **** //
    static Map<System.TriggerOperation, List<SObject>> results = new Map<System.TriggerOperation, List<SObject>>();

    static List<Account> generateRecords() {
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 200; i++) {
            accounts?.add(new Account());
        }
        return accounts;
    }

    static void testOperation(System.TriggerOperation operation) {
        List<Account> accounts = ApexAsyncActionTriggerFrameworkTest.generateRecords();
        ApexAsyncActionTriggerFramework handler = new ExampleHandler();
        handler.operation = operation;
        handler.triggerNew = accounts;

        Test.startTest();
        handler?.run();
        Test.stopTest();

        Assert.isTrue(ApexAsyncActionTriggerFrameworkTest.results?.containsKey(operation), 'Did not run ' + operation); 
        Assert.areEqual(1, ApexAsyncActionTriggerFrameworkTest.results?.size(), 'Wrong # of operations processed'); 
        Assert.areEqual(accounts?.size(), ApexAsyncActionTriggerFrameworkTest.results?.get(operation)?.size(), 'Wrong # of triggerNew records');
    }

    // **** INNER **** //
    public class ExampleHandler extends ApexAsyncActionTriggerFramework {
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
            ApexAsyncActionTriggerFrameworkTest.results?.put(this.operation, this.triggerNew);
        }
    }
}