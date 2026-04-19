public with sharing class RiskAssessmentController {

    @AuraEnabled(cacheable=true)
    public static Risk_Assessment__c getLatestAssessment(Id opportunityId) {
        List<Risk_Assessment__c> results = [
            SELECT Id, Status__c, Risk_Score__c, Risk_Level__c,
                   Recommendation__c, Assessment_Date__c,
                   Article_Count__c, Negative_Signal_Count__c,
                   External_Reference__c
            FROM Risk_Assessment__c
            WHERE Opportunity__c = :opportunityId
            WITH USER_MODE
            ORDER BY CreatedDate DESC, Id DESC
            LIMIT 1
        ];
        return results.isEmpty() ? null : results[0];
    }

    @AuraEnabled
    public static Id requestManualAssessment(Id opportunityId) {
        if (!FeatureManagement.checkPermission('Can_Request_Manual_Assessment')) {
            throw new AuraHandledException('You do not have permission to request a manual assessment.');
        }
        Risk_Assessment__c ra = new Risk_Assessment__c(
            Opportunity__c = opportunityId,
            Status__c      = 'Pending'
        );
        Database.insert(ra, AccessLevel.USER_MODE);
        RiskAssessmentQueueable.enqueue(opportunityId, ra.Id);
        return ra.Id;
    }

    @AuraEnabled(cacheable=true)
    public static Boolean hasManualAssessmentPermission() {
        return FeatureManagement.checkPermission('Can_Request_Manual_Assessment');
    }

    @AuraEnabled(cacheable=true)
    public static List<Opportunity> searchOpportunities(String searchTerm) {
        String pattern = '%' + String.escapeSingleQuotes(searchTerm) + '%';
        return [
            SELECT Id, Name, Account.Name
            FROM Opportunity
            WHERE Name LIKE :pattern
            WITH USER_MODE
            ORDER BY Name
            LIMIT 10
        ];
    }
}
