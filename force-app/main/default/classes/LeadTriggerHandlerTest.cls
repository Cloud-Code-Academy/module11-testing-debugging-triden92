@isTest
public with sharing class LeadTriggerHandlerTest {

    @TestSetup
    static void createTestLeads(){
        
        final Integer MIN = 25;
        final Integer MAX = 100;
        Integer randomNumber = MIN + (Integer)Math.floor(Math.random() * (MAX - MIN + 1));
        List<Lead> leadList = new List<Lead>();
        
        for(Integer i = 0; i < randomNumber; i++){
            Lead newLead = new Lead();
            newLead.FirstName = 'Test';
            newLead.LastName = 'Lead ' + i;
            newLead.Company = 'Test Company ' + i;
            if(Math.mod(i,20) == 0){
                newLead.Title = 'jr Marketing Manager';
                newLead.Phone = '555-000'+i;
            }
            else if(Math.mod(i,19) == 0){
                newLead.Title = 'Deputy Legal Counsel';
            }
            else if(Math.mod(i,18) == 0){
                newLead.Title = 'assist CS Supervisor';
                newLead.LeadSource = 'Website';
                newLead.Phone = '555-000'+i;
            }
            else if(Math.mod(i,17) == 0){
                newLead.Title = 'head of Sales';
                newLead.Phone = '555-000'+i;
            }
            else if(Math.mod(i,16) == 0){
                newLead.Title = 'chief of R&D';
                newLead.LeadSource = 'Website';
                newLead.Email = 'testlead'+i+'@testcompany'+i+'.com';
            }
            else if(Math.mod(i,15) == 0){
                newLead.Title = 'Chief Exec';
                newLead.LeadSource = 'Website';
            }
            else if(Math.mod(i,14) == 0){
                newLead.Title = 'Head of Department';
                newLead.Phone = '555-000'+i;
            }
            else if(Math.mod(i,13) == 0){
                newLead.Title = 'Sales manage';
            }
            else if(Math.mod(i,12) == 0){
                newLead.Title = 'Field Service Mgr';
                newLead.Phone = '555-000'+i;
                newLead.LeadSource = 'Website';
                newLead.Email = 'testlead'+i+'@testcompany'+i+'.com';
                newLead.Industry = 'Technology';
            }
            else if(Math.mod(i,11) == 0){
                newLead.Title = 'Vice president of Marketing';
                newLead.Industry = 'Technology';
            }
            else if(Math.mod(i,10) == 0){
                newLead.Title = 'VP of CS';
            }
            else if(Math.mod(i,9) == 0){
                newLead.Title = 'V.P. of Service';
            }
            else {
                newLead.Title = 'Field Service Rep';
                newLead.Industry = 'Technology';
            }
            leadList.add(newLead);
           
        }
        
        insert leadList;
        
    }
   
    @isTest
    static void testHandleTitleNormalization(){
        List<Lead> leadList = [SELECT Id, Name, Company, Email, Title FROM Lead WHERE Company LIKE 'Test%'];
        Test.startTest();
        LeadTriggerHandler.handleTitleNormalization(leadList);
        Test.stopTest();
        List<String> badTitles = new List<String>{'vp','v\\.p.\\','\\bvice president\\b','\\mgr\\','\\bmanage\\b','\\bhead of department\\b','exec','chief','\\bhead\\b','\\bassist\\b','deputy','jr'};
        List<Lead> verifyLeadsList = [SELECT Id, Name, Company, Email, Title FROM Lead WHERE Email LIKE 'testlead%'];
        for(Lead testLead :verifyLeadsList){
            for(String title :badTitles){
                System.assert(!testLead.Title.contains(title), 'Title Not Cleaned');
            }
        }
    }

    @isTest
    static void testHandleAutoLeadScoring(){

        List<Lead> leadList = [SELECT Id, Name, Company, Email, Title, LeadSource, Phone, Industry, Lead_Score__c FROM Lead WHERE Company LIKE 'Test%'];
        Test.startTest();
        LeadTriggerHandler.handleAutoLeadScoring(leadList);
        Test.stopTest();

        List<Lead> verifyLeadsList = [SELECT Id, Name, Company, Email, Title, LeadSource, Phone, Industry, Lead_Score__c FROM Lead WHERE Company LIKE 'Test%'];
        for(Lead ld :verifyLeadsList){
            Integer leadScore = 0;
            if(ld.LeadSource == 'Website' && ld.Email != null){
                leadScore += 3;
            }
            if(ld.Phone != null){
                leadScore += 5;
            }
            if(ld.Industry == 'Technology'){
                leadScore += 10;
            }

            System.assertEquals(leadScore, ld.Lead_Score__c,'Incorrect Lead Score');
        }
    }

    @isTest
    static void testHandleLeadAutoConvert(){
        List<Lead> leadList = [SELECT Id, Name, FirstName,LastName,Company, Email, Title, Industry, LeadSource, Phone, Lead_Score__c, IsConverted FROM Lead WHERE Company LIKE 'Test%'];
        List<Account> newAccounts = new List<Account>();
        List<Contact> newContacts = new List<Contact>();
        Map<Id,String> accountNameByLeadIdMap = new Map<Id,String>();
        Integer i = 0;
        for(Lead ld :leadList){
            if(Math.mod(i,3) == 0 || Math.mod(i,4) == 0 || Math.mod(i,5) == 0 || Math.mod(i,6) == 0){
                Account acc = new Account(Name = ld.Company);
                newAccounts.add(acc);
                accountNameByLeadIdMap.put(ld.Id,ld.Company);
                i++;
                continue;
            }
            i++;
            
        }          
        insert newAccounts;
        List<Account> accList = [SELECT Id, Name FROM Account WHERE Name IN :accountNameByLeadIdMap.values()];
        Map<String,Id> accountIdByNameMap = new Map<String,Id>();
        for(Account acc :accList){
            accountIdByNameMap.put(acc.Name,acc.Id);
        }
        for(Lead ld :leadList){
            if(accountNameByLeadIdMap.containsKey(ld.Id)){
                Contact cont = new Contact(FirstName = ld.FirstName, LastName = ld.LastName, Email = ld.Email, Phone = ld.Phone, AccountId = accountIdByNameMap.get(ld.Company));
                newContacts.add(cont);
            }
        }

        insert newContacts;

        Test.startTest();
        LeadTriggerHandler.handleLeadAutoConvert(leadList);
        Test.stopTest();


        List<Lead> verifyLeadsList = [SELECT Id, Name, Company, Email, Title, Industry, LeadSource, Phone, Lead_Score__c, IsConverted, ConvertedAccountId, ConvertedContactId FROM Lead WHERE Company LIKE 'Test%'];
        List<Id> contactIdList = new List<Id>();
        Map<Id,String> emailBContactIdMap = new Map<Id,String>();
        for(Lead ld :verifyLeadsList){
            contactIdList.add(ld.ConvertedContactId);
            if(ld.IsConverted == true){
                emailBContactIdMap.put(ld.ConvertedContactId, ld.Email);
            } 
        }
        for(Lead ld :verifyLeadsList){
            if(emailBContactIdMap.containsKey(ld.ConvertedContactId)){
                System.assertEquals(true, ld.IsConverted, 'Lead Not Converted');
            }
            else{
                System.assertEquals(false, ld.IsConverted, 'Lead Converted Incorrectly');
            }
        }
        List<Contact> contactList = [SELECT Id, Email FROM Contact WHERE Id IN :contactIdList];
        for(Contact cont :contactList){
            System.assertEquals(emailBContactIdMap.get(cont.Id), cont.Email, 'Email Not Updated');
        }
        
    }
            
}
