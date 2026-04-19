public without sharing class RiskAssessmentSchedulable implements Schedulable {
    // without sharing: scheduled job runs in system context, no user session

    public static final String DEFAULT_CRON = '0 0 2 * * ?';
    public static final String JOB_NAME     = 'Nightly Risk Assessment';

    public void execute(SchedulableContext sc) {
        List<Opportunity> openOpps = [
            SELECT Id
            FROM Opportunity
            WHERE IsClosed = false
            LIMIT 200
        ];
        if (openOpps.isEmpty()) return;

        List<Risk_Assessment__c> assessments = new List<Risk_Assessment__c>();
        for (Opportunity opp : openOpps) {
            assessments.add(new Risk_Assessment__c(
                Opportunity__c = opp.Id,
                Status__c      = 'Pending'
            ));
        }
        Database.insert(assessments, AccessLevel.SYSTEM_MODE); // SYSTEM_MODE: scheduled context, no user session

        for (Integer i = 0; i < openOpps.size(); i++) {
            RiskAssessmentQueueable.enqueue(openOpps[i].Id, assessments[i].Id);
        }
    }

    public static void scheduleNightly() {
        for (CronTrigger ct : [SELECT Id FROM CronTrigger WHERE CronJobDetail.Name = :JOB_NAME]) {
            System.abortJob(ct.Id);
        }
        System.schedule(JOB_NAME, DEFAULT_CRON, new RiskAssessmentSchedulable());
    }
}
