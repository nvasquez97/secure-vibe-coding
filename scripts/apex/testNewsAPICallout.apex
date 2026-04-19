NewsAPICallout callout = new NewsAPICallout();
List<NewsAPICallout.NewsArticle> articles = callout.fetchArticles('Apple');

if (articles.isEmpty()) {
    throw new IllegalArgumentException('NewsAPI returned zero articles for "Apple". Check API key and Remote Site Setting.');
}

System.debug('=== NewsAPI Callout SUCCESS ===');
System.debug('Articles returned: ' + articles.size());
System.debug('First article title: ' + articles[0].title);
System.debug('First article source: ' + articles[0].sourceName);
System.debug('First article publishedAt: ' + articles[0].publishedAt);
