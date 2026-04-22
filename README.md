# Webflow to Salesforce Lead Integration

This repository contains an Apex-based REST service that securely integrates Webflow form submissions into Salesforce Leads using dynamic Custom Metadata mapping.

## 📂 Project Structure (Where to find what)

Here is a breakdown of the key components in this repository:

### 1. Apex Classes (`force-app/main/default/classes/`)
* **`WebflowWebhookService.cls`**: The core API logic. It handles the REST endpoint, validates the HMAC-SHA256 signature, prevents duplicate Leads by Email, and dynamically maps fields.
* **`WebflowWebhookServiceTest.cls`**: Unit tests ensuring logic stability and code coverage.
* **`WebflowWebhookEvent.cls` & `WebflowPayload.cls`**: Wrapper classes used to deserialize the incoming Webflow JSON payload.

### 2. Custom Metadata (`force-app/main/default/objects/` & `customMetadata/`)
* **`Webflow_Field_Mapping__mdt`**: The structure of the metadata table (includes fields like `Webflow_Field_Name__c`, `Salesforce_Field_API_Name__c`, and the `Is_Active__c` toggle).
* **Mapping Records**: Inside the `customMetadata/` folder, you will find the active rules that link Webflow keys to Salesforce fields:
  * `Webflow_Field_Mapping.Name_Mapping.md-meta.xml`
  * `Webflow_Field_Mapping.Email_Mapping.md-meta.xml`
  * `Webflow_Field_Mapping.Company_Mapping.md-meta.xml`
  * `Webflow_Field_Mapping.Description_Mapping.md-meta.xml`

### 3. Security Labels (`force-app/main/default/labels/`)
* **`CustomLabels.labels-meta.xml`**: Contains the `Webflow_Webhook_Secret` label. This is where the secure API key is stored to validate incoming requests from Webflow.

## 🚀 Key Features
- **Security First:** HMAC-SHA256 signature validation using Webflow's timestamp and request body.
- **Dynamic Field Mapping:** Add, remove, or disable (`Is_Active__c = false`) mapped fields directly from the Salesforce UI without modifying Apex code.
- **Duplicate Prevention:** Checks for existing Leads by Email before creating a new record.

## 🛠 Deployment & Setup

1. **Deploy the source code** to your target Salesforce org using Salesforce CLI:
   ```bash
   sf project deploy start --target-org <your-org-alias>
