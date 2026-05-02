public with sharing class RiskScoringService {

    private static final List<String> NEGATIVE_KEYWORDS = new List<String>{
        'lawsuit', 'fraud', 'bankruptcy', 'recall', 'fine',
        'penalty', 'loss', 'investigation', 'scandal', 'layoff', 'shutdown'
    };

    public class ScoringResult {
        public Integer score;
        public String  level;
        public String  recommendation;
        public Integer negativeSignals;
    }

    public static ScoringResult score(List<NewsAPICallout.NewsArticle> articles) {
        ScoringResult result = new ScoringResult();
        result.negativeSignals = countNegativeSignals(articles);
        result.score = Math.min(100, result.negativeSignals * 20);
        result.level = scoreToLevel(result.score);
        result.recommendation = buildRecommendation(articles, result.level);
        return result;
    }

    private static String scoreToLevel(Integer score) {
        if (score >= 75) return 'Critical';
        if (score >= 50) return 'High';
        if (score >= 25) return 'Medium';
        return 'Low';
    }

    private static Integer countNegativeSignals(List<NewsAPICallout.NewsArticle> articles) {
        Integer count = 0;
        for (NewsAPICallout.NewsArticle a : articles) {
            String combined = '';
            if (a.title != null) combined += a.title.toLowerCase();
            if (a.description != null) combined += ' ' + a.description.toLowerCase();
            for (String kw : NEGATIVE_KEYWORDS) {
                if (combined.contains(kw)) {
                    count++;
                }
            }
        }
        return count;
    }

    private static String buildRecommendation(List<NewsAPICallout.NewsArticle> articles, String level) {
        if (articles == null || articles.isEmpty()) {
            return 'No recent news found for this account.';
        }
        List<String> titles = new List<String>();
        for (NewsAPICallout.NewsArticle a : articles) {
            if (String.isNotBlank(a.title)) {
                titles.add(a.title);
            }
        }
        return String.join(titles, ' | ');
    }
}
