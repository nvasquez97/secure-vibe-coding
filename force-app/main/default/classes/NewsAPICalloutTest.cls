@IsTest
private class NewsAPICalloutTest {

    private class MockHttpCallout implements NewsAPICallout.IHttpCallout {
        private Integer statusCode;
        private String  body;
        MockHttpCallout(Integer code, String b) {
            this.statusCode = code;
            this.body = b;
        }
        public HttpResponse send(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody(body);
            return res;
        }
    }

    private static String sampleJson() {
        return '{"status":"ok","totalResults":2,"articles":['
            + '{"source":{"name":"Reuters"},"title":"Acme reports fraud case",'
            + '"description":"Details about the fraud.","publishedAt":"2026-01-01T00:00:00Z"},'
            + '{"source":{"name":"BBC"},"title":"Acme expands globally",'
            + '"description":"Positive growth story.","publishedAt":"2026-01-02T00:00:00Z"}'
            + ']}';
    }

    @IsTest
    static void testFetchArticles_success() {
        NewsAPICallout callout = new NewsAPICallout(new MockHttpCallout(200, sampleJson()));
        Test.startTest();
        List<NewsAPICallout.NewsArticle> articles = callout.fetchArticles('Acme');
        Test.stopTest();
        Assert.areEqual(2, articles.size());
        Assert.areEqual('Acme reports fraud case', articles[0].title);
        Assert.areEqual('Reuters', articles[0].sourceName);
    }

    @IsTest
    static void testFetchArticles_httpError() {
        NewsAPICallout callout = new NewsAPICallout(new MockHttpCallout(401, '{"message":"Unauthorized"}'));
        Test.startTest();
        try {
            callout.fetchArticles('Acme');
            Assert.fail('Expected CalloutException');
        } catch (CalloutException e) {
            Assert.isTrue(e.getMessage().contains('401'));
        }
        Test.stopTest();
    }

    @IsTest
    static void testFetchArticles_emptyArticles() {
        String emptyJson = '{"status":"ok","totalResults":0,"articles":[]}';
        NewsAPICallout callout = new NewsAPICallout(new MockHttpCallout(200, emptyJson));
        Test.startTest();
        List<NewsAPICallout.NewsArticle> articles = callout.fetchArticles('UnknownCorp');
        Test.stopTest();
        Assert.areEqual(0, articles.size());
    }
}
