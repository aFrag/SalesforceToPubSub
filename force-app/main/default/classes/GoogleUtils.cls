public class GoogleUtils {
   // gcpPartition name is set on the gcpPartition file under cachePartitions folder and default size is 1mb
   // More details on Salesforce Setup -> quick search -> Platform Cache  
   private final static String CACHE_ACCESS_TOKEN_KEY = 'local.gcpPartition.googleCloudAccessToken';
   // Class to deserialise response from the Google token URL and get the ID Token
    class GoogleAuthResponse {
       public String access_token;
    }

    private String authToken = '';
    private String audience = '';

    public GoogleUtils(String metadata_name){
       GCP_Key__mdt serviceAccount = getGCPServiceAccount(metadata_name);
       audience = serviceAccount.Pubsub_Endpoint__c;
       authToken = getGCPAuthToken(serviceAccount);
    }
    
    public String get_token(){
        return authToken;
    }
    
    public String get_audience(){
        return audience;
    }
    /**
    * Constructs the JWT and invokes the Google Auth endpoint
    * @param serviceAccount has the GCP keys obtained from the
    * custom metadata object
    * @return the auth response from GCP containing the id token
    */
   public String getGCPAuthToken(GCP_Key__mdt serviceAccount) {
       String cachedAccessToken = (String) Cache.Org.get(CACHE_ACCESS_TOKEN_KEY);
       if (cachedAccessToken != null) {
           System.debug('Returning cached access token');
           return cachedAccessToken;
       } else {
           GoogleAuthResponse result = new GoogleAuthResponse();

           Auth.JWT jwt = new Auth.JWT();
           // Token endpoint is usually https://accounts.google.com, in order for salesforce to access this url
           // we need to add it as a remote site, see remoteSiteSettings folder
           // same thing with pubsub url
           jwt.setAud(serviceAccount.Token_Endpoint__c);
           jwt.setIss(serviceAccount.client_email__c);

           // Additional claims to set scope
           Map<String, Object> claims = new Map<String, Object>();
           claims.put('scope', 'https://www.googleapis.com/auth/pubsub');
           jwt.setAdditionalClaims(claims);

           // Create the object that signs the JWT bearer token
           Auth.JWS jws = new Auth.JWS(jwt, 'google_cloud');

           // Get the resulting JWS in case debugging is required
           String token = jws.getCompactSerialization();

           // Set the token endpoint that the JWT bearer token is posted to
           String tokenEndpoint = serviceAccount.Token_Endpoint__c;

           Auth.JWTBearerTokenExchange bearer = new Auth.JWTBearerTokenExchange(tokenEndpoint, jws);

           if (!Test.isRunningTest()) {
               System.HttpResponse response = bearer.getHTTPResponse();
               result =(GoogleAuthResponse) JSON.deserialize(response.getBody(), GoogleAuthResponse.class);
           } else {
               result.access_token = 'IN TEST';
           }
           cacheAccessToken(result.access_token);
           return result.access_token;
       }
   }

   /**
    * Get GCP service account keys from metadata
    * @return the metadata record for the GCP service account
    */
   public GCP_Key__mdt getGCPServiceAccount(String metadata_name) {
       List<GCP_Key__mdt> gcp_sa_keys = new List<GCP_Key__mdt>();
       if (Test.isRunningTest()) {
            gcp_sa_keys.add(new GCP_Key__mdt(
                Client_Email__c = 'test_email',
                Pubsub_Endpoint__c = 'test_endpoint',
                Token_Endpoint__c = 'test_token_endpoint'
                ));
       }else{
            gcp_sa_keys = [SELECT
                Client_Email__c,
                Pubsub_Endpoint__c,
                Token_Endpoint__c
                FROM GCP_Key__mdt
                WHERE MasterLabel = :metadata_name];
        }

       if (gcp_sa_keys.size() > 0) {
           return gcp_sa_keys[0];
       } else {
           throw new GCPServiceAccountException('Cannot find GCP Service Account Keys');
       }
   }

   /**
    * Caches an access token in org cache so future API requests don't need to get a new token.
    * Compared to using Custom Settings, updating the org cache doesn't require a DML operation
    * and can be interleaved between callouts. The cache also handles expiration for us.
    */
   public static void cacheAccessToken(String accessToken) {
       // Cache the access token in the default org cache with a TTL of 30 seconds less than its expiration
       Cache.Org.put(CACHE_ACCESS_TOKEN_KEY, accessToken, 3600 - 30);
   }
   
   /**
    * Proactively clear the access token from the Custom Settings cache.
    * This won't invalidate the previous access token on Google's side, but it will remove it from
    * our cache so that future requests will be forced to fetch a new token.
    */
   public static Boolean clearAccessToken() {
       return Cache.Org.remove(CACHE_ACCESS_TOKEN_KEY);
   }

   public class GCPServiceAccountException extends Exception {}
}