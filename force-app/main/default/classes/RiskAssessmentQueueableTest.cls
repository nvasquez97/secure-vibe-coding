@IsTest
private class RiskAssessmentQueueableTest {

    private class MockCallout implements NewsAPICallout.IHttpCallout {
        public HttpResponse send(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"status":"ok","totalResults":1,"articles":['
                + '{"source":{"name":"Reuters"},"title":"Company reports loss",'
                + '"description":"Quarterly losses.","publishedAt":"2026-01-01T00:00:00Z"}'
                + ']}');
            return res;
        }
    }

    private class ErrorCallout implements NewsAPICallout.IHttpCallout {
        public HttpResponse send(HttpRequest req) {
            throw new CalloutException('Simulated timeout');
        }
    }

    @TestSetup
    static void setup() {
        Account acc = new Account(Name = 'Queueable Test Corp');
        insert acc;
    }

    @IsTest
    static void testExecute_completesAssessment() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Opportunity opp = new Opportunity(
            Name      = 'Queueable Test Opp',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Amount    = 50000
        );
        insert opp;

        Risk_Assessment__c ra = new Risk_Assessment__c(
            Opportunity__c = opp.Id,
            Status__c      = 'Pending'
        );
        insert ra;

        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Test.startTest();
        System.enqueueJob(new RiskAssessmentQueueable(opp.Id, ra.Id));
        Test.stopTest();

        Risk_Assessment__c updated = [
            SELECT Status__c, Risk_Score__c, Risk_Level__c, Article_Count__c
            FROM Risk_Assessment__c WHERE Id = :ra.Id
        ];
        Assert.areEqual('Completed', updated.Status__c);
        Assert.isTrue(updated.Risk_Score__c >= 0);
        Assert.areEqual(1, (Integer) updated.Article_Count__c);
    }

    private class SuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"status":"ok","totalResults":1,"articles":['
                + '{"source":{"name":"Reuters"},"title":"Company reports loss",'
                + '"description":"Quarterly losses.","publishedAt":"2026-01-01T00:00:00Z"}'
                + ']}');
            return res;
        }
    }

    @IsTest
    static void testExecute_handlesCalloutError() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Opportunity opp = new Opportunity(
            Name      = 'Error Test Opp',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Amount    = 50000
        );
        insert opp;

        Risk_Assessment__c ra = new Risk_Assessment__c(
            Opportunity__c = opp.Id,
            Status__c      = 'Pending'
        );
        insert ra;

        // RiskAssessmentQueueable uses NewsAPICallout internally; mock via HttpCalloutMock
        Test.setMock(HttpCalloutMock.class, new ErrorMock());
        Test.startTest();
        System.enqueueJob(new RiskAssessmentQueueable(opp.Id, ra.Id));
        Test.stopTest();

        Risk_Assessment__c updated = [SELECT Status__c FROM Risk_Assessment__c WHERE Id = :ra.Id];
        Assert.areEqual('Error', updated.Status__c);
    }

    private class ErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            throw new CalloutException('Simulated timeout');
        }
    }
}
