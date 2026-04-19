// sf-secure NOTE: API key read from Custom Metadata (NewsAPIConfig__mdt) for zero-config demo deployment.
// In production, migrate to Named Credential with External Credential auth parameter.
public with sharing class NewsAPICallout {

    private static final String BASE_URL = 'https://newsapi.org/v2/everything';
    private static final Integer PAGE_SIZE = 5;

    public interface IHttpCallout {
        HttpResponse send(HttpRequest req);
    }

    public class DefaultHttpCallout implements IHttpCallout {
        public HttpResponse send(HttpRequest req) {
            return new Http().send(req);
        }
    }

    public class NewsArticle {
        public String title;
        public String description;
        public String publishedAt;
        public String sourceName;
    }

    private final IHttpCallout httpClient;

    public NewsAPICallout() {
        this.httpClient = new DefaultHttpCallout();
    }

    public NewsAPICallout(IHttpCallout mockClient) {
        this.httpClient = mockClient;
    }

    public List<NewsArticle> fetchArticles(String accountName) {
        HttpRequest req = new HttpRequest();
        req.setMethod('GET');
        req.setEndpoint(buildEndpoint(accountName));
        req.setTimeout(10000);
        HttpResponse res = httpClient.send(req);
        if (res.getStatusCode() != 200) {
            throw new CalloutException('NewsAPI returned HTTP ' + res.getStatusCode() + ': ' + res.getBody());
        }
        return parseResponse(res.getBody());
    }

    private String buildEndpoint(String accountName) {
        NewsAPIConfig__mdt config = NewsAPIConfig__mdt.getInstance('NewsAPI');
        String apiKey = config != null ? config.API_Key__c : '';
        String encoded = EncodingUtil.urlEncode(accountName, 'UTF-8');
        return BASE_URL
            + '?q=' + encoded
            + '&sortBy=publishedAt'
            + '&pageSize=' + PAGE_SIZE
            + '&apiKey=' + apiKey;
    }

    private List<NewsArticle> parseResponse(String body) {
        List<NewsArticle> articles = new List<NewsArticle>();
        Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(body);
        List<Object> rawArticles = (List<Object>) root.get('articles');
        if (rawArticles == null) {
            return articles;
        }
        for (Object item : rawArticles) {
            Map<String, Object> raw = (Map<String, Object>) item;
            NewsArticle a = new NewsArticle();
            a.title = (String) raw.get('title');
            a.description = (String) raw.get('description');
            a.publishedAt = (String) raw.get('publishedAt');
            Map<String, Object> src = (Map<String, Object>) raw.get('source');
            if (src != null) {
                a.sourceName = (String) src.get('name');
            }
            articles.add(a);
        }
        return articles;
    }
}
