@isTest
public class PubSubTest {
    
    static testmethod void testQueueable() {
        Test.startTest();
        case cs1 = new case();
        cs1.Subject= 'Testing  Cases';
        cs1.Origin='Email';
        cs1.Description = 'Email to case premium app1 ';
        cs1.Status ='open';
        insert cs1;
        Test.stopTest();

        List<AsyncApexJob> asyncJobList = [select id, ApexClass.Name, JobType, Status from AsyncApexJob where ApexClass.Name = 'PubSub'];
        System.assertEquals(1, asyncJobList.size());
    }

}