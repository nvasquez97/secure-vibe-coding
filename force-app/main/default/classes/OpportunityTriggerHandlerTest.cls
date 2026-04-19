@IsTest
private class OpportunityTriggerHandlerTest {

    private class MockCallout implements NewsAPICallout.IHttpCallout {
        public HttpResponse send(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"status":"ok","totalResults":0,"articles":[]}');
            return res;
        }
    }

    @TestSetup
    static void setup() {
        Account acc = new Account(Name = 'Test Corp');
        insert acc;
    }

    @IsTest
    static void testAfterInsert_createsAssessment() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Test.startTest();
        Opportunity opp = new Opportunity(
            Name        = 'Test Opp Insert',
            AccountId   = acc.Id,
            StageName   = 'Prospecting',
            CloseDate   = Date.today().addDays(30),
            Amount      = 10000
        );
        insert opp;
        Test.stopTest();
        List<Risk_Assessment__c> ras = [SELECT Id, Opportunity__c FROM Risk_Assessment__c WHERE Opportunity__c = :opp.Id];
        Assert.isTrue(ras.size() >= 1, 'Expected at least one Risk Assessment after insert');
    }

    @IsTest
    static void testAfterUpdate_amountChange_createsNewAssessment() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Test.startTest();
        Opportunity opp = new Opportunity(
            Name        = 'Test Opp Update Amount',
            AccountId   = acc.Id,
            StageName   = 'Prospecting',
            CloseDate   = Date.today().addDays(30),
            Amount      = 10000
        );
        insert opp;
        Integer before = [SELECT COUNT() FROM Risk_Assessment__c WHERE Opportunity__c = :opp.Id];
        opp.Amount = 99999;
        update opp;
        Test.stopTest();
        Integer after = [SELECT COUNT() FROM Risk_Assessment__c WHERE Opportunity__c = :opp.Id];
        Assert.isTrue(after > before, 'Expected additional Risk Assessment after Amount change');
    }

    @IsTest
    static void testAfterUpdate_noChangeNoAssessment() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Test.startTest();
        Opportunity opp = new Opportunity(
            Name        = 'Test Opp No Change',
            AccountId   = acc.Id,
            StageName   = 'Prospecting',
            CloseDate   = Date.today().addDays(30),
            Amount      = 10000
        );
        insert opp;
        Integer before = [SELECT COUNT() FROM Risk_Assessment__c WHERE Opportunity__c = :opp.Id];
        opp.Name = 'Test Opp No Change Updated';
        update opp;
        Test.stopTest();
        Integer after = [SELECT COUNT() FROM Risk_Assessment__c WHERE Opportunity__c = :opp.Id];
        Assert.areEqual(before, after, 'No new assessment expected when Amount/Stage unchanged');
    }
}
