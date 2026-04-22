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
                String incomingEmail = formData.get('Email');

                if (String.isNotBlank(incomingEmail)) {
                    List<Lead> existingLeads = [SELECT Id FROM Lead WHERE Email = :incomingEmail LIMIT 1];
                    if (!existingLeads.isEmpty()) {
                        System.debug(LoggingLevel.INFO, 'Lead with email ' + incomingEmail + ' already exists. Skipping lead creation.');
                        setResponse(res, 200, 'Lead with this email already exists. No new lead created.');
                        return;
                    }
                }
                
                Lead newLead = new Lead(LeadSource = 'Advertisement');
                
                List<Webflow_Field_Mapping__mdt> mappings = [
                    SELECT Webflow_Field_Name__c, Salesforce_Field_API_Name__c 
                    FROM Webflow_Field_Mapping__mdt
                    WHERE Is_Active__c = true
                ];

                for (Webflow_Field_Mapping__mdt mapping : mappings) {
                    String webflowKey = mapping.Webflow_Field_Name__c;
                    String sfApiName = mapping.Salesforce_Field_API_Name__c;

                    if (formData.containsKey(webflowKey) && String.isNotBlank(formData.get(webflowKey))) {
                        try {
                            newLead.put(sfApiName, formData.get(webflowKey));
                        } catch (Exception e) {
                            System.debug(LoggingLevel.WARN, 'Failed to map field ' + sfApiName + ': ' + e.getMessage());
                        }
                    }
                }
                
                if (String.isBlank(newLead.LastName)) {
                    newLead.LastName = 'Unknown Webflow Lead';
                }
                if (String.isBlank(newLead.Company)) {
                    newLead.Company = 'Not Provided';
                }
                if (String.isBlank(newLead.Email) && String.isNotBlank(incomingEmail)) {
                    newLead.Email = incomingEmail;
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