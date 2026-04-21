@RestResource(urlMapping='/webhook/lead/*')
global class WebflowWebhookService {

    private static final String TIMESTAMP_HEADER = 'x-webflow-timestamp';
    private static final String SIGNATURE_HEADER = 'x-webflow-signature';
    private static final String WEBFLOW_SECRET = System.Label.Webflow_Webhook_Secret;

    @HttpPost
    global static void handleWebhook() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        try {
            String timestampHeader = '';
            String signatureHeader = '';
            
            for (String key : req.headers.keySet()) {
                if (key.equalsIgnoreCase(TIMESTAMP_HEADER)) timestampHeader = req.headers.get(key);
                else if (key.equalsIgnoreCase(SIGNATURE_HEADER)) signatureHeader = req.headers.get(key);
            }

            if (String.isBlank(timestampHeader) || String.isBlank(signatureHeader)) {
                setResponse(res, 400, 'Missing required Webflow headers.');
                return;
            }
            
            if (String.isBlank(WEBFLOW_SECRET)) {
                setResponse(res, 500, 'Webhook secret is not configured in Salesforce.');
                return;
            }

            String body = req.requestBody.toString();
            
            if (!isValidSignature(timestampHeader, body, signatureHeader)) {
                setResponse(res, 401, 'Invalid webhook signature.');
                return;
            }

            WebflowWebhookEvent webhookEvent = (WebflowWebhookEvent) JSON.deserialize(body, WebflowWebhookEvent.class);
            
            if (webhookEvent?.payload?.data != null) {
                Map<String, String> formData = webhookEvent.payload.data;
                
                Lead newLead = new Lead(
                    LastName = String.isNotBlank(formData.get('Name')) ? formData.get('Name') : 'Unknown Webflow Lead',
                    Company = String.isNotBlank(formData.get('Company/Project')) ? formData.get('Company/Project') : 'Not Provided',
                    Email = formData.get('Email'),
                    LeadSource = webhookEvent.payload.name
                );
                
                if (String.isNotBlank(formData.get('Discussion Topic'))) {
                    newLead.Description = 'Discussion Topic: ' + formData.get('Discussion Topic');
                }
                
                insert newLead;
            }

            setResponse(res, 200, 'Success');

        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'Webhook processing failed: ' + ex.getMessage());
            setResponse(res, 500, 'Internal Server Error: ' + ex.getMessage());
        }
    }
    
    private static Boolean isValidSignature(String timestamp, String body, String receivedSignature) {
        String payload = timestamp + ':' + body;
        
        Blob hashBytes = Crypto.generateMac('HmacSHA256', Blob.valueOf(payload), Blob.valueOf(WEBFLOW_SECRET));
        String computedSignature = EncodingUtil.convertToHex(hashBytes).toLowerCase();
        
        return computedSignature == receivedSignature.toLowerCase();
    }

    private static void setResponse(RestResponse res, Integer statusCode, String message) {
        res.statusCode = statusCode;
        res.responseBody = Blob.valueOf(message);
    }
}