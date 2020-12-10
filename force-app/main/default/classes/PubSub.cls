public class PubSub implements Queueable, Database.AllowsCallouts {
    public static Boolean runningInASandbox {
        get {
            if (runningInASandbox == null) {
                runningInASandbox = [SELECT IsSandbox FROM Organization LIMIT 1].IsSandbox;
            }
            return runningInASandbox;
        }
        set;
    }
    // In order to get the appropriate metadada to publish messages to salesforce-cases Topic
    public static final String GCP_CASES_METADATA_NAME = (runningInASandbox ? 'Stage': 'Prod') + '_GCP_PubSub_Cases';

    // Serialised data coming from triggers
    private String serializedData;

    // Action to be performed in GCP, can be 'create' in this example
    private String action;

    // Metadata name in order to get the appropriate entry from sf metadata
    private String metadata_name;

    // Class to construct the request body to publish to pubsub
    // The body should be {"messages":[{"data": "base64 encoded data" }]}
    class PubSubData {
        String data;
        
        public PubSubData(List<SObject> data, String action){
            List< Map<String, Object>> newData = new List< Map<String, Object>>();
            for(SObject d : data){
                //Create a copy of the map because the original is protected
                Map<String, Object> fieldsToValue = new Map<String, Object>(d.getPopulatedFieldsAsMap());
                fieldsToValue.put('action', action);
                newData.add(fieldsToValue);
            }
            String json_list = JSON.serialize(newData);
            String encoded_list = EncodingUtil.base64Encode(Blob.valueof(json_list));
            this.data = encoded_list;
        }

    }
    class PubsubRequest {
        public List<PubSubData> messages = new List<PubSubData>();

        public PubsubRequest(List<SObject> list_data, String action){
            PubSubData data = new PubSubData(list_data, action);
            messages.add(data);
        }
        
    }
    // Constructor    
    public PubSub(String serializedData, String action, String metadata_name) {
        this.serializedData = serializedData;
        this.action = action;
        this.metadata_name = metadata_name;
    }

    /**
     * Invokes the GCP Cloud Function
     * @param token obtained from the authentication request
     * @param pubsubEndpoint of the PubSub topic
     */
    @TestVisible
    private void pushDataToPubsub(String token, String pubsubEndpoint) {
        List<SObject> deserialisedData = (List<SObject>) JSON.deserialize(serializedData, List<SObject>.class);
        if(!deserialisedData.get(0) instanceof Case){
            throw new GCPServiceAccountException('The object you are trying to push to PubSub is not supported');
        }
        PubsubRequest requestMessage = new PubsubRequest(deserialisedData, this.action);

        HTTP http = new HTTP();
        HTTPRequest req = new HTTPRequest();
        req.setHeader('Content-Type','application/json');
        req.setHeader('Authorization', 'Bearer ' + token);
        req.setEndpoint(pubsubEndpoint);
        req.setMethod('POST');
        req.setBody(JSON.serialize(requestMessage));

        HTTPResponse response=new HttpResponse();
        System.debug('POST request to ' + pubsubEndpoint);
        if (!Test.isRunningTest()) {
            response = http.send(req);
        }
        
        if (response.getStatusCode() == 200) {
            System.debug(pubsubEndpoint + ' called successfully');
        } else {
            System.debug(LoggingLevel.ERROR, 'Error occured ' + response.getStatus() + ' ' + response.getStatusCode());
        }
    }

    /**
     * Process the new customer record(s)
     *
     * Called asynchronousely by Salesforce when chat(s) are added
     * @param context passed by the platform
     */
    public void execute(QueueableContext context) {

        GoogleUtils utils = new GoogleUtils(this.metadata_name);

        if (utils.get_token() != null) {
            this.pushDataToPubsub(utils.get_token(), utils.get_audience());
        }
    }

    public class GCPServiceAccountException extends Exception {}
}
