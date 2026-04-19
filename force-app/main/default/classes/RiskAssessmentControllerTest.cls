@IsTest
private class RiskAssessmentControllerTest {

    @TestSetup
    static void setup() {
        Account acc = new Account(Name = 'Controller Test Corp');
        insert acc;
        Opportunity opp = new Opportunity(
            Name      = 'Controller Test Opp',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Amount    = 75000
        );
        insert opp;
    }

    private static void ensureManagerPermission() {
        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'Risk_Advisor_Manager' LIMIT 1];
        List<PermissionSetAssignment> existing = [
            SELECT Id FROM PermissionSetAssignment
            WHERE AssigneeId = :UserInfo.getUserId() AND PermissionSetId = :ps.Id
        ];
        if (existing.isEmpty()) {
            insert new PermissionSetAssignment(AssigneeId = UserInfo.getUserId(), PermissionSetId = ps.Id);
        }
    }

    @IsTest
    static void testGetLatestAssessment_returnsLatest() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        Risk_Assessment__c old = new Risk_Assessment__c(
            Opportunity__c = opp.Id,
            Status__c      = 'Completed',
            Risk_Score__c  = 20,
            Risk_Level__c  = 'Low'
        );
        insert old;

        Risk_Assessment__c latest = new Risk_Assessment__c(
            Opportunity__c = opp.Id,
            Status__c      = 'Completed',
            Risk_Score__c  = 60,
            Risk_Level__c  = 'High'
        );
        insert latest;

        Test.startTest();
        Risk_Assessment__c result = RiskAssessmentController.getLatestAssessment(opp.Id);
        Test.stopTest();

        Assert.areEqual(latest.Id, result.Id, 'Expected the most recently inserted assessment');
    }

    @IsTest
    static void testGetLatestAssessment_noAssessment() {
        // Use a new Opportunity created here, delete its trigger-created RA before querying
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Opportunity opp = new Opportunity(
            Name      = 'No Assessment Test Opp',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;
        // Trigger creates a Pending RA; delete it to test the no-assessment path.
        // The enqueued queueable handles deleted records gracefully (try/catch on update).
        delete [SELECT Id FROM Risk_Assessment__c WHERE Opportunity__c = :opp.Id];

        Test.startTest();
        Risk_Assessment__c result = RiskAssessmentController.getLatestAssessment(opp.Id);
        Test.stopTest();

        Assert.isNull(result);
    }

    @IsTest
    static void testRequestManualAssessment_withPermission() {
        ensureManagerPermission();
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        Test.startTest();
        Id assessmentId = RiskAssessmentController.requestManualAssessment(opp.Id);
        // Assert Pending status before stopTest() fires the queueable
        Assert.isNotNull(assessmentId);
        Risk_Assessment__c ra = [SELECT Status__c FROM Risk_Assessment__c WHERE Id = :assessmentId];
        Assert.areEqual('Pending', ra.Status__c);
        Test.stopTest();
    }

    @IsTest
    static void testRequestManualAssessment_withoutPermission() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            LastName            = 'NoPermUser',
            Email               = 'noperm@test.com',
            Username            = 'noperm' + System.currentTimeMillis() + '@test.com',
            Alias               = 'npu',
            TimeZoneSidKey      = 'America/New_York',
            LocaleSidKey        = 'en_US',
            EmailEncodingKey    = 'UTF-8',
            LanguageLocaleKey   = 'en_US',
            ProfileId           = p.Id
        );
        insert u;

        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        Test.startTest();
        System.runAs(u) {
            try {
                RiskAssessmentController.requestManualAssessment(opp.Id);
                Assert.fail('Expected AuraHandledException');
            } catch (AuraHandledException e) {
                Assert.isTrue(e.getMessage().length() > 0);
            }
        }
        Test.stopTest();
    }

    @IsTest
    static void testSearchOpportunities() {
        Test.startTest();
        List<Opportunity> results = RiskAssessmentController.searchOpportunities('Controller Test');
        Test.stopTest();
        Assert.isTrue(results.size() >= 1);
        Assert.isTrue(results[0].Name.contains('Controller Test'));
    }

    @IsTest
    static void testHasManualAssessmentPermission_withPermission() {
        ensureManagerPermission();
        Test.startTest();
        Boolean hasPerm = RiskAssessmentController.hasManualAssessmentPermission();
        Test.stopTest();
        Assert.isTrue(hasPerm);
    }
}
