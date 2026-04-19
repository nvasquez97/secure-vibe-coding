// Step 1: Find first Opportunity created by createMockData
List<Opportunity> opps = [
    SELECT Id, Name, Account.Name
    FROM Opportunity
    WHERE Name LIKE 'Apple%' OR Name LIKE 'Tesla%' OR Name LIKE 'Amazon%'
    ORDER BY CreatedDate ASC
    LIMIT 1
];

if (opps.isEmpty()) {
    throw new IllegalArgumentException('No mock Opportunities found. Run createMockData.apex first.');
}

Opportunity opp = opps[0];
System.debug('Testing with Opportunity: ' + opp.Name + ' (Account: ' + opp.Account.Name + ')');

// Step 2: Verify at least one Completed assessment exists
List<Risk_Assessment__c> completed = [
    SELECT Id, Risk_Score__c, Risk_Level__c, Recommendation__c
    FROM Risk_Assessment__c
    WHERE Opportunity__c = :opp.Id
    AND Status__c = 'Completed'
    ORDER BY CreatedDate DESC, Id DESC
    LIMIT 1
];

if (completed.isEmpty()) {
    throw new IllegalArgumentException(
        'No Completed assessment found for Opportunity ' + opp.Name +
        '. The trigger queueable may not have run yet. Wait a moment and retry, or check async logs.'
    );
}

Risk_Assessment__c ra = completed[0];
System.debug('=== Completed Assessment Found ===');
System.debug('Risk Score: ' + ra.Risk_Score__c);
System.debug('Risk Level: ' + ra.Risk_Level__c);
System.debug('Recommendation (first 200 chars): ' +
    (ra.Recommendation__c != null ? ra.Recommendation__c.left(200) : 'n/a'));

// Step 3: Request a new manual assessment
Id newAssessmentId = RiskAssessmentController.requestManualAssessment(opp.Id);
System.debug('=== Manual Assessment Enqueued ===');
System.debug('New Assessment Id: ' + newAssessmentId);
System.debug('SUCCESS: testManualAssessment.apex completed without exception.');
