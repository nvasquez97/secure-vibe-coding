@IsTest
private class RiskAssessmentSchedulableTest {

    @TestSetup
    static void setup() {
        Account acc = new Account(Name = 'Schedulable Test Corp');
        insert acc;
        Opportunity opp = new Opportunity(
            Name      = 'Schedulable Test Opp',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Amount    = 25000
        );
        insert opp;
    }

    @IsTest
    static void testScheduleNightly() {
        Test.startTest();
        RiskAssessmentSchedulable.scheduleNightly();
        Test.stopTest();
        List<CronTrigger> jobs = [
            SELECT Id, CronExpression, State
            FROM CronTrigger
            WHERE CronJobDetail.Name = :RiskAssessmentSchedulable.JOB_NAME
        ];
        Assert.areEqual(1, jobs.size(), 'Expected exactly one scheduled job');
        Assert.areEqual(RiskAssessmentSchedulable.DEFAULT_CRON, jobs[0].CronExpression);
    }

    @IsTest
    static void testExecute_createsAssessments() {
        // Verify the execute method runs without exception and creates assessments
        Test.startTest();
        String cronId = System.schedule('Test Nightly', '0 0 2 * * ?', new RiskAssessmentSchedulable());
        Test.stopTest();
        // assessments are inserted (queueables run during stopTest)
        List<Risk_Assessment__c> ras = [SELECT Id FROM Risk_Assessment__c];
        Assert.isTrue(ras.size() >= 1, 'Expected assessments from schedulable execute');
    }
}
