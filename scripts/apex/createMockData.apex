// Creates demo-ready Accounts and Opportunities. Safe to re-run — skips existing records.

final String VIEWER_USERNAME = 'riskadvisor-viewer@secure-vibe-coding.com';

List<String> accountNames = new List<String>{
    'Apple', 'Tesla', 'Amazon', 'Microsoft', 'Boeing',
    'Pfizer', 'Goldman Sachs', 'ExxonMobil', 'Meta', 'Walmart'
};

List<String> stages = new List<String>{
    'Prospecting', 'Qualification', 'Needs Analysis', 'Value Proposition',
    'Proposal/Price Quote', 'Negotiation/Review', 'Closed Won'
};
List<Decimal> amounts = new List<Decimal>{
    10000, 50000, 100000, 250000, 500000,
    750000, 1000000, 2000000, 3500000, 5000000
};

// Resolve viewer user
List<User> viewerUsers = [SELECT Id FROM User WHERE Username = :VIEWER_USERNAME LIMIT 1];
Id viewerUserId = viewerUsers.isEmpty() ? UserInfo.getUserId() : viewerUsers[0].Id;
if (viewerUsers.isEmpty()) {
    System.debug('WARNING: Viewer user ' + VIEWER_USERNAME + ' not found. Using running user for even-numbered Opportunities.');
}

// Upsert Accounts by Name
Map<String, Account> existingAccounts = new Map<String, Account>();
for (Account a : [SELECT Id, Name FROM Account WHERE Name IN :accountNames]) {
    existingAccounts.put(a.Name, a);
}

List<Account> toInsertAccounts = new List<Account>();
for (String name : accountNames) {
    if (!existingAccounts.containsKey(name)) {
        toInsertAccounts.add(new Account(Name = name));
    }
}
if (!toInsertAccounts.isEmpty()) {
    insert toInsertAccounts;
    for (Account a : toInsertAccounts) {
        existingAccounts.put(a.Name, a);
    }
}
System.debug('Accounts ready: ' + existingAccounts.size());

// Create Opportunities (2 per Account)
Map<String, List<Opportunity>> existingOpps = new Map<String, List<Opportunity>>();
for (Opportunity o : [SELECT Id, Name, AccountId FROM Opportunity
                       WHERE AccountId IN :existingAccounts.values()]) {
    String key = o.AccountId;
    if (!existingOpps.containsKey(key)) existingOpps.put(key, new List<Opportunity>());
    existingOpps.get(key).add(o);
}

List<Opportunity> toInsertOpps = new List<Opportunity>();
Integer oppIndex = 0;
for (Integer i = 0; i < accountNames.size(); i++) {
    String name = accountNames[i];
    Account acc = existingAccounts.get(name);
    List<Opportunity> existing = existingOpps.containsKey(acc.Id) ? existingOpps.get(acc.Id) : new List<Opportunity>();

    // Opp 1 — owned by running user (admin)
    if (existing.size() < 1) {
        toInsertOpps.add(new Opportunity(
            Name      = name + ' — Strategic Deal',
            AccountId = acc.Id,
            StageName = stages[Math.mod(oppIndex, stages.size())],
            Amount    = amounts[Math.mod(oppIndex, amounts.size())],
            CloseDate = Date.today().addDays(30 + oppIndex * 3),
            OwnerId   = UserInfo.getUserId()
        ));
        oppIndex++;
    }

    // Opp 2 — owned by viewer user
    if (existing.size() < 2) {
        toInsertOpps.add(new Opportunity(
            Name      = name + ' — Expansion Opportunity',
            AccountId = acc.Id,
            StageName = stages[Math.mod(oppIndex, stages.size())],
            Amount    = amounts[Math.mod(oppIndex, amounts.size())],
            CloseDate = Date.today().addDays(30 + oppIndex * 3),
            OwnerId   = viewerUserId
        ));
        oppIndex++;
    }
}

if (!toInsertOpps.isEmpty()) {
    insert toInsertOpps;
    System.debug('Inserted ' + toInsertOpps.size() + ' Opportunities.');
} else {
    System.debug('All Opportunities already exist — skipped insert.');
}

System.debug('=== Mock data seeding complete ===');
System.debug('Accounts: ' + existingAccounts.size());
System.debug('Opportunities inserted this run: ' + toInsertOpps.size());
