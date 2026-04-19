public with sharing class OpportunityTriggerHandler {

    public static void handleAfterInsert(List<Opportunity> newOpps) {
        enqueueAssessments(newOpps);
    }

    public static void handleAfterUpdate(
        List<Opportunity> newOpps,
        Map<Id, Opportunity> oldOppMap
    ) {
        List<Opportunity> changed = new List<Opportunity>();
        for (Opportunity opp : newOpps) {
            Opportunity old = oldOppMap.get(opp.Id);
            if (opp.Amount != old.Amount || opp.StageName != old.StageName) {
                changed.add(opp);
            }
        }
        if (!changed.isEmpty()) {
            enqueueAssessments(changed);
        }
    }

    private static void enqueueAssessments(List<Opportunity> opps) {
        List<Risk_Assessment__c> assessments = new List<Risk_Assessment__c>();
        for (Opportunity opp : opps) {
            assessments.add(new Risk_Assessment__c(
                Opportunity__c = opp.Id,
                Status__c      = 'Pending'
            ));
        }
        Database.insert(assessments, AccessLevel.SYSTEM_MODE); // SYSTEM_MODE: trigger context, insert on behalf of system

        for (Integer i = 0; i < opps.size(); i++) {
            RiskAssessmentQueueable.enqueue(opps[i].Id, assessments[i].Id);
        }
    }
}
