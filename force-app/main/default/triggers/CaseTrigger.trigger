trigger CaseTrigger on Case (after insert,after update,after delete,after undelete) {
    if(Trigger.isAfter){
        List<Case> cases;

        if(Trigger.isDelete){
            cases = trigger.old;
        }else{
            cases = trigger.new;
        } 
        
        String serialisedCases = JSON.serialize(cases);
        PubSub gcpService = new PubSub(serialisedCases, String.valueOf(Trigger.operationType), PubSub.GCP_CASES_METADATA_NAME);
        ID jobID = System.enqueueJob(gcpService);
    }
}