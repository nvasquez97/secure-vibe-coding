@IsTest
private class RiskScoringServiceTest {

    private static NewsAPICallout.NewsArticle makeArticle(String title, String body) {
        NewsAPICallout.NewsArticle a = new NewsAPICallout.NewsArticle();
        a.title = title;
        a.description = body;
        a.publishedAt = '2026-01-01T00:00:00Z';
        a.sourceName  = 'TestSource';
        return a;
    }

    @IsTest
    static void testScore_noNegativeSignals() {
        List<NewsAPICallout.NewsArticle> articles = new List<NewsAPICallout.NewsArticle>{
            makeArticle('Company announces record growth', 'Earnings up 20%.')
        };
        RiskScoringService.ScoringResult r = RiskScoringService.score(articles);
        Assert.areEqual(0, r.score);
        Assert.areEqual('Low', r.level);
        Assert.areEqual(0, r.negativeSignals);
    }

    @IsTest
    static void testScore_mediumRisk() {
        List<NewsAPICallout.NewsArticle> articles = new List<NewsAPICallout.NewsArticle>{
            makeArticle('Company faces lawsuit', 'Details of the lawsuit.'),
            makeArticle('Quarterly loss reported', 'Significant loss this quarter.')
        };
        RiskScoringService.ScoringResult r = RiskScoringService.score(articles);
        Assert.isTrue(r.score >= 25, 'Expected medium+ score');
        Assert.isTrue(r.negativeSignals >= 2);
    }

    @IsTest
    static void testScore_criticalRisk() {
        List<NewsAPICallout.NewsArticle> articles = new List<NewsAPICallout.NewsArticle>{
            makeArticle('Bankruptcy fraud lawsuit penalty recall investigation', 'scandal layoff fine loss'),
            makeArticle('More fraud bankruptcy', 'Additional scandals')
        };
        RiskScoringService.ScoringResult r = RiskScoringService.score(articles);
        Assert.areEqual(100, r.score);
        Assert.areEqual('Critical', r.level);
    }

    @IsTest
    static void testScore_emptyArticles() {
        RiskScoringService.ScoringResult r = RiskScoringService.score(new List<NewsAPICallout.NewsArticle>());
        Assert.areEqual(0, r.score);
        Assert.areEqual('Low', r.level);
        Assert.isTrue(r.recommendation.contains('No recent news'));
    }

    @IsTest
    static void testScoreLevelBoundaries() {
        // Scores are multiples of 20 (negativeSignals * 20). Achievable level thresholds:
        // Low: 0 or 20 (0-24), Medium: 40 (25-49), High: 60 (50-74), Critical: 80 (75-100)
        Assert.areEqual('Low',      RiskScoringService.score(signalArticles(0)).level);  // score 0
        Assert.areEqual('Low',      RiskScoringService.score(signalArticles(1)).level);  // score 20
        Assert.areEqual('Medium',   RiskScoringService.score(signalArticles(2)).level);  // score 40
        Assert.areEqual('High',     RiskScoringService.score(signalArticles(3)).level);  // score 60
        Assert.areEqual('Critical', RiskScoringService.score(signalArticles(4)).level);  // score 80
    }

    private static List<NewsAPICallout.NewsArticle> signalArticles(Integer count) {
        List<NewsAPICallout.NewsArticle> articles = new List<NewsAPICallout.NewsArticle>();
        for (Integer i = 0; i < count; i++) {
            articles.add(makeArticle('lawsuit article ' + i, ''));
        }
        return articles;
    }
}
