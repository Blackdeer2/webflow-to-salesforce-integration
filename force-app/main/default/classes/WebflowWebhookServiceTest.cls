@isTest
private class WebflowWebhookServiceTest {

    private static String generateValidSignature(String timestamp, String body, String secret) {
        String payload = timestamp + ':' + body;
        Blob hashBytes = Crypto.generateMac('HmacSHA256', Blob.valueOf(payload), Blob.valueOf(secret));
        return EncodingUtil.convertToHex(hashBytes).toLowerCase();
    }

    @isTest
    static void testSuccessfulLeadCreation() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/webhook/lead';
        req.httpMethod = 'POST';

        String jsonBody = '{"triggerType": "form_submission", "payload": {"name": "Contact Form", "data": {"Name": "Test Tester", "Email": "test@caydigital.ai", "Company/Project": "Test Corp", "Discussion Topic": "Test Topic"}}}';
        req.requestBody = Blob.valueOf(jsonBody);

        String timestamp = String.valueOf(DateTime.now().getTime());
        String secret = System.Label.Webflow_Webhook_Secret;
        String signature = generateValidSignature(timestamp, jsonBody, secret);

        req.headers.put('X-Webflow-Timestamp', timestamp);
        req.headers.put('X-Webflow-Signature', signature);

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        WebflowWebhookService.handleWebhook();
        Test.stopTest();

        System.assertEquals(200, res.statusCode, 'Status code should be 200 OK');

        List<Lead> createdLeads = [SELECT Id, LastName, Company, Email, Description, LeadSource FROM Lead];
        
        System.assertEquals(1, createdLeads.size(), 'One Lead should be created');
        System.assertEquals('Test Tester', createdLeads[0].LastName, 'Last Name mapped incorrectly');
        System.assertEquals('Test Corp', createdLeads[0].Company, 'Company mapped incorrectly');
        System.assertEquals('test@caydigital.ai', createdLeads[0].Email, 'Email mapped incorrectly');
        System.assertEquals('Contact Form', createdLeads[0].LeadSource, 'LeadSource mapped incorrectly');
        System.assert(createdLeads[0].Description.contains('Test Topic'), 'Description mapped incorrectly');
    }

    @isTest
    static void testMissingHeaders() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/webhook/lead';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{"triggerType": "form_submission"}');


        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        WebflowWebhookService.handleWebhook();
        Test.stopTest();

        System.assertEquals(400, res.statusCode, 'Should return 400 Bad Request for missing headers');
    }

    @isTest
    static void testInvalidSignature() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/webhook/lead';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{"triggerType": "form_submission"}');

        req.headers.put('X-Webflow-Timestamp', '1234567890');
        req.headers.put('X-Webflow-Signature', 'invalid_fake_signature_123');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        WebflowWebhookService.handleWebhook();
        Test.stopTest();

        System.assertEquals(401, res.statusCode, 'Should return 401 Unauthorized for invalid signature');
    }
}