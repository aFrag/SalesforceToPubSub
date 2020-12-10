@IsTest
private class GoogleUtilsTest {
    
    static testmethod void testgetGCPServiceAccount() {
        Test.startTest();

        GCP_Key__mdt gcp_key = new GCP_Key__mdt(
            Client_Email__c = 'test_email',
            Pubsub_Endpoint__c = 'test_endpoint',
            Token_Endpoint__c = 'test_token_endpoint'
            );
        
        GoogleUtils utils = new GoogleUtils('test');

        GCP_Key__mdt service_account = utils.getGCPServiceAccount('test');
        System.AssertEquals(gcp_key, service_account);

        Test.stopTest();
    }

    static testmethod void testgetGCPAuthToken() {
        Test.startTest();

        GCP_Key__mdt gcp_key = new GCP_Key__mdt(
            Client_Email__c = 'test_email',
            Pubsub_Endpoint__c = 'test_endpoint',
            Token_Endpoint__c = 'test_token_endpoint'
            );
        
        GoogleUtils utils = new GoogleUtils('test');

        String token = utils.getGCPAuthToken(gcp_key);

        System.AssertEquals('IN TEST', token);
        
        Test.stopTest();
    }

    static testmethod void testgetGCPAuthTokenCached() {
        Test.startTest();

        GCP_Key__mdt gcp_key = new GCP_Key__mdt(
            Client_Email__c = 'test_email',
            Pubsub_Endpoint__c = 'test_endpoint',
            Token_Endpoint__c = 'test_token_endpoint'
            );
        
        GoogleUtils utils = new GoogleUtils('test');

        System.AssertEquals('IN TEST', utils.getGCPAuthToken(gcp_key));
        GoogleUtils.cacheAccessToken('new cached token');
        System.AssertEquals('new cached token', utils.getGCPAuthToken(gcp_key));

        Test.stopTest();
    }

    static testmethod void testVariables() {
        Test.startTest();
        
        GoogleUtils utils = new GoogleUtils('test');

        System.AssertEquals('IN TEST', utils.get_token());
        System.AssertEquals('test_endpoint', utils.get_audience());

        Test.stopTest();
    }

}