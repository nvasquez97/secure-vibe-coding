public without sharing class RiskAssessmentQueueable implements Queueable, Database.AllowsCallouts {
    // without sharing: queueable runs without a user session; must access Opportunity + Account
    // regardless of sharing rules to perform the risk assessment

    private Id opportunityId;
    private Id pendingAssessmentId;

    public RiskAssessmentQueueable(Id oppId, Id assessmentId) {
        this.opportunityId = oppId;
        this.pendingAssessmentId = assessmentId;
    }

    public static void enqueue(Id oppId, Id assessmentId) {
        System.enqueueJob(new RiskAssessmentQueueable(oppId, assessmentId));
    }

    public void execute(QueueableContext ctx) {
        Risk_Assessment__c ra = new Risk_Assessment__c(Id = pendingAssessmentId);
        try {
            Opportunity opp = [
                SELECT Id, Account.Name
                FROM Opportunity
                WHERE Id = :opportunityId
                LIMIT 1
            ];
            String accountName = opp.Account != null ? opp.Account.Name : 'Unknown';

            NewsAPICallout callout = new NewsAPICallout();
            List<NewsAPICallout.NewsArticle> articles = callout.fetchArticles(accountName);

            RiskScoringService.ScoringResult result = RiskScoringService.score(articles);

            ra.Status__c              = 'Completed';
            ra.Risk_Score__c          = result.score;
            ra.Risk_Level__c          = result.level;
            ra.Recommendation__c      = result.recommendation;
            ra.Assessment_Date__c     = Datetime.now();
            ra.Article_Count__c       = articles.size();
            ra.Negative_Signal_Count__c = result.negativeSignals;
            ra.External_Reference__c  = ctx.getJobId();

        } catch (Exception e) {
            ra.Status__c          = 'Error';
            ra.Recommendation__c  = e.getMessage();
            ra.Assessment_Date__c = Datetime.now();
        }
        try {
            update ra; // system context intentional — queueable has no user session
        } catch (DmlException ignored) {
            // Record deleted before queueable ran — discard silently
        }
    }
}
