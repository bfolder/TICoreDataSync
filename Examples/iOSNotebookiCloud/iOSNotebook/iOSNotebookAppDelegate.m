//
//  iOSNotebookAppDelegate.m
//  iOSNotebook
//
//  Created by Tim Isted on 13/05/2011.
//  Copyright 2011 Tim Isted. All rights reserved.
//

#import "iOSNotebookAppDelegate.h"
#import "RootViewController.h"
#import "TICoreDataSync.h"

@interface iOSNotebookAppDelegate () <DBSessionDelegate, TICDSApplicationSyncManagerDelegate, TICDSDocumentSyncManagerDelegate>
- (void)registerSyncManager;
@end

@implementation iOSNotebookAppDelegate

-(NSURL *)cloudStoreURL
{
    NSURL *ubiquitousURL = [[NSFileManager defaultManager] URLForUbiquityContainerIdentifier: nil];
    NSURL *storeURL = [ubiquitousURL URLByAppendingPathComponent:@"SyncData"];
    return storeURL;
}

#pragma mark -
#pragma mark Initial Sync Registration
- (void)registerSyncManager
{
    [TICDSLog setVerbosity:TICDSLogVerbosityEveryStep];
    TICDSFileManagerBasedApplicationSyncManager *manager =
    [TICDSFileManagerBasedApplicationSyncManager
     defaultApplicationSyncManager];
    
    NSURL *dropboxLocation = self.cloudStoreURL;
    
    [manager setApplicationContainingDirectoryLocation:
     dropboxLocation];
    
    NSString *clientUuid = [[NSUserDefaults standardUserDefaults] stringForKey:@"iOSNotebookAppSyncClientUUID"];
    
    if( !clientUuid ) {
        clientUuid = [TICDSUtilities uuidString];
        [[NSUserDefaults standardUserDefaults] setValue:clientUuid forKey:@"iOSNotebookAppSyncClientUUID"];
    }
    
    NSString *deviceDescription = [[UIDevice currentDevice] name];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(activityDidIncrease:) name:TICDSApplicationSyncManagerDidIncreaseActivityNotification object:manager];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(activityDidDecrease:) name:TICDSApplicationSyncManagerDidDecreaseActivityNotification object:manager];
    
    [manager registerWithDelegate:self
              globalAppIdentifier:@"com.timisted.notebook" 
           uniqueClientIdentifier:clientUuid 
                      description:deviceDescription 
                         userInfo:nil];
}

#pragma mark -
#pragma mark Synchronization
- (IBAction)beginSynchronizing:(id)sender
{
    [[self documentSyncManager] initiateSynchronization];
}

- (void)activityDidIncrease:(NSNotification *)aNotification
{
    _activity++;
    
    if( _activity > 0 ) {
        [[UIApplication sharedApplication] 
         setNetworkActivityIndicatorVisible:YES];
    }
}

- (void)activityDidDecrease:(NSNotification *)aNotification
{
    if( _activity > 0) {
        _activity--;
    }
    
    if( _activity < 1 ) {
        [[UIApplication sharedApplication] 
         setNetworkActivityIndicatorVisible:NO];
    }
}

#pragma mark -
#pragma mark Application Sync Manager Delegate
- (void)applicationSyncManagerDidPauseRegistrationToAskWhetherToUseEncryptionForFirstTimeRegistration:(TICDSApplicationSyncManager *)aSyncManager
{
    [aSyncManager continueRegisteringWithEncryptionPassword: nil];
}

- (void)applicationSyncManagerDidPauseRegistrationToRequestPasswordForEncryptedApplicationSyncData:(TICDSApplicationSyncManager *)aSyncManager
{
    
    [aSyncManager continueRegisteringWithEncryptionPassword: nil];
}

- (TICDSDocumentSyncManager *)applicationSyncManager:(TICDSApplicationSyncManager *)aSyncManager preConfiguredDocumentSyncManagerForDownloadedDocumentWithIdentifier:(NSString *)anIdentifier atURL:(NSURL *)aFileURL
{
    /* Return nil because this is a non-document based app and this method will never be called.
    
       If you implement multiple documents, you'll need to return a configured (but not yet registered) sync manager.
       See the documentation for details, specifically:
       http://timisted.github.com/TICoreDataSync/reference/html/Protocols/TICDSApplicationSyncManagerDelegate.html#//api/name/applicationSyncManager:preConfiguredDocumentSyncManagerForDownloadedDocumentWithIdentifier:atURL:
    */
    
    return nil;
}

- (void)applicationSyncManagerDidFinishRegistering:(TICDSApplicationSyncManager *)aSyncManager
{
    TICDSFileManagerBasedDocumentSyncManager *docSyncManager =
    [[TICDSFileManagerBasedDocumentSyncManager alloc] init];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(activityDidIncrease:) name:TICDSDocumentSyncManagerDidIncreaseActivityNotification object:docSyncManager];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(activityDidDecrease:) name:TICDSDocumentSyncManagerDidDecreaseActivityNotification object:docSyncManager];
    
    [docSyncManager registerWithDelegate:self
                          appSyncManager:aSyncManager
                    managedObjectContext:(TICDSSynchronizedManagedObjectContext *)[self managedObjectContext]
                      documentIdentifier:@"Notebook"
                             description:@"Application's data"
                                userInfo:nil];
    
    [self setDocumentSyncManager:docSyncManager];
    [docSyncManager release];
}

#pragma mark -
#pragma mark Document Sync Manager Delegate
- (void)documentSyncManager:(TICDSDocumentSyncManager *)aSyncManager didPauseSynchronizationAwaitingResolutionOfSyncConflict:(id)aConflict
{
    [aSyncManager continueSynchronizationByResolvingConflictWithResolutionType:TICDSSyncConflictResolutionTypeLocalWins];
}

- (NSURL *)documentSyncManager:(TICDSDocumentSyncManager *)aSyncManager URLForWholeStoreToUploadForDocumentWithIdentifier:(NSString *)anIdentifier description:(NSString *)aDescription userInfo:(NSDictionary *)userInfo
{
    return [self applicationDocumentsDirectory];
}

- (NSURL *)documentSyncManagerURLForDownloadedStore:(TICDSDocumentSyncManager *)aSyncManager
{
    return [self applicationDocumentsDirectory];
}

- (void)documentSyncManager:(TICDSDocumentSyncManager *)aSyncManager didPauseRegistrationAsRemoteFileStructureDoesNotExistForDocumentWithIdentifier:(NSString *)anIdentifier description:(NSString *)aDescription userInfo:(NSDictionary *)userInfo
{
    [self setDownloadStoreAfterRegistering:NO];
    [aSyncManager continueRegistrationByCreatingRemoteFileStructure:YES];
}

- (void)documentSyncManager:(TICDSDocumentSyncManager *)aSyncManager didPauseRegistrationAsRemoteFileStructureWasDeletedForDocumentWithIdentifier:(NSString *)anIdentifier description:(NSString *)aDescription userInfo:(NSDictionary *)userInfo
{
    [self setDownloadStoreAfterRegistering:NO];
    [aSyncManager continueRegistrationByCreatingRemoteFileStructure:YES];
}

- (void)documentSyncManagerDidDetermineThatClientHadPreviouslyBeenDeletedFromSynchronizingWithDocument:(TICDSDocumentSyncManager *)aSyncManager
{
    NSLog(@"DOC WAS DELETED");
    [self setDownloadStoreAfterRegistering:YES];
}

- (void)documentSyncManagerDidFinishRegistering:(TICDSDocumentSyncManager *)aSyncManager
{
    if( [self shouldDownloadStoreAfterRegistering] ) {
        [[self documentSyncManager] initiateDownloadOfWholeStore];
    }
    
    if( ![aSyncManager isKindOfClass:
          [TICDSFileManagerBasedDocumentSyncManager class]] ) {
        return;
    }
    
    [(TICDSFileManagerBasedDocumentSyncManager *)aSyncManager
     enableAutomaticSynchronizationAfterChangesDetectedFromOtherClients];
    
    //[self performSelector:@selector(removeAllSyncData:) withObject:nil afterDelay:8.0];
    //[self performSelector:@selector(getPreviouslySynchronizedClients) withObject:nil afterDelay:2.0];
    //[self performSelector:@selector(deleteDocument) withObject:nil afterDelay:2.0];
    //[self performSelector:@selector(deleteClient) withObject:nil afterDelay:2.0];
}

- (void)applicationSyncManagerDidFinishRemovingAllSyncData:(TICDSApplicationSyncManager *)aSyncManager
{
    NSLog(@"Registering again");
    
    TICDSFileManagerBasedApplicationSyncManager *manager =
    [TICDSFileManagerBasedApplicationSyncManager
     defaultApplicationSyncManager];
    
    NSURL *dropboxLocation = self.cloudStoreURL; //[TICDSFileManagerBasedApplicationSyncManager localDropboxDirectoryLocation];
    [manager setApplicationContainingDirectoryLocation:dropboxLocation];
    
    NSString *clientUuid = [[NSUserDefaults standardUserDefaults]
                            stringForKey:@"NotebookAppSyncClientUUID"];
    if( !clientUuid ) {
        clientUuid = [TICDSUtilities uuidString];
        [[NSUserDefaults standardUserDefaults]
         setValue:clientUuid
         forKey:@"NotebookAppSyncClientUUID"];
    }
    
    [manager registerWithDelegate:self
              globalAppIdentifier:@"com.timisted.notebook"
           uniqueClientIdentifier:clientUuid
                      description:@"iOS Device"
                         userInfo:nil];
}

- (void)removeAllRemoteSyncData
{
    [[[self documentSyncManager] applicationSyncManager] removeAllSyncDataFromRemote];
}

- (void)getPreviouslySynchronizedClients
{
    [[[self documentSyncManager] applicationSyncManager] requestListOfSynchronizedClientsIncludingDocuments:YES];
}

- (void)deleteClient
{
    [[self documentSyncManager] deleteDocumentSynchronizationDataForClientWithIdentifier:@"B29A21AB-529A-4CBB-A603-332CAD8F2D33-715-000001314CB7EE5B"];
}

- (void)applicationSyncManager:(TICDSApplicationSyncManager *)aSyncManager didFinishFetchingInformationForAllRegisteredDevices:(NSDictionary *)information
{
    NSLog(@"App client info: %@", information);
}

- (BOOL)documentSyncManagerShouldUploadWholeStoreAfterDocumentRegistration:(TICDSDocumentSyncManager *)aSyncManager
{
    return ![self shouldDownloadStoreAfterRegistering];
}

- (void)documentSyncManager:(TICDSDocumentSyncManager *)aSyncManager willReplaceStoreWithDownloadedStoreAtURL:(NSURL *)aStoreURL
{
    NSError *anyError = nil;
    BOOL success = [[self persistentStoreCoordinator] removePersistentStore:[[self persistentStoreCoordinator] persistentStoreForURL:aStoreURL] error:&anyError];
    
    if( !success ) {
        NSLog(@"Failed to remove persistent store at %@: %@", 
              aStoreURL, anyError);
    }
}

- (void)documentSyncManager:(TICDSDocumentSyncManager *)aSyncManager didReplaceStoreWithDownloadedStoreAtURL:(NSURL *)aStoreURL
{
    NSError *anyError = nil;
    id store = [[self persistentStoreCoordinator] addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:aStoreURL options:nil error:&anyError];
    
    if( !store ) {
        NSLog(@"Failed to add persistent store at %@: %@", aStoreURL, anyError);
    }
}

- (void)documentSyncManager:(TICDSDocumentSyncManager *)aSyncManager didMakeChangesToObjectsInBackgroundContextAndSaveWithNotification:(NSNotification *)aNotification
{
    [[self managedObjectContext] mergeChangesFromContextDidSaveNotification:aNotification];
}

- (void)documentSyncManager:(TICDSDocumentSyncManager *)aSyncManager didFailToSynchronizeWithError:(NSError *)anError
{
    if( [anError code] != TICDSErrorCodeSynchronizationFailedBecauseIntegrityKeysDoNotMatch ) {
        return;
    }
    
    [aSyncManager initiateDownloadOfWholeStore];
}

- (BOOL)documentSyncManager:(TICDSDocumentSyncManager *)aSyncManager
shouldBeginSynchronizingAfterManagedObjectContextDidSave:
(TICDSSynchronizedManagedObjectContext *)aMoc
{
    return YES;
}

- (BOOL)documentSyncManagerShouldVacuumUnneededRemoteFilesAfterDocumentRegistration:(TICDSDocumentSyncManager *)aSyncManager
{
    return YES;
}


#pragma mark -
#pragma mark Application Lifecycle
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [self registerSyncManager];
    
    [[self window] setRootViewController:[self navigationController]];
    [[self window] makeKeyAndVisible];
    return YES;
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
    if ([[DBSession sharedSession] handleOpenURL:url] == YES) {
        if ([[DBSession sharedSession] isLinked]) {
            NSLog(@"%s App linked successfully!", __PRETTY_FUNCTION__);
            [self registerSyncManager];
        } else {
            NSLog(@"%s App was not linked successfully.", __PRETTY_FUNCTION__);
        }
    } else {
        NSLog(@"%s DBSession couldn't handle opening the URL %@", __PRETTY_FUNCTION__, url);
    }

    return YES;
}

#pragma mark -
#pragma mark DBSessionDelegate methods

- (void)sessionDidReceiveAuthorizationFailure:(DBSession *)session userId:(NSString *)userId;
{
    NSLog(@"%s Could not create DBSession for user %@", __PRETTY_FUNCTION__, userId);
}

#pragma mark -
#pragma mark Properties
@synthesize window=_window;
@synthesize managedObjectContext=__managedObjectContext;
@synthesize managedObjectModel=__managedObjectModel;
@synthesize persistentStoreCoordinator=__persistentStoreCoordinator;
@synthesize navigationController=_navigationController;
@synthesize documentSyncManager = _documentSyncManager;
@synthesize downloadStoreAfterRegistering = _downloadStoreAfterRegistering;

#pragma mark -
#pragma mark Apple Stuff
- (void)applicationWillTerminate:(UIApplication *)application
{
    // Saves changes in the application's managed object context before the application terminates.
    [self saveContext];
}

- (void)dealloc
{
    [_window release];
    [__managedObjectContext release];
    [__managedObjectModel release];
    [__persistentStoreCoordinator release];
    [_navigationController release];
    [_documentSyncManager release], _documentSyncManager = nil;
    
    [super dealloc];
}

- (void)awakeFromNib
{
    RootViewController *rootViewController = (RootViewController *)[self.navigationController topViewController];
    rootViewController.managedObjectContext = self.managedObjectContext;
}

- (void)saveContext
{
    NSError *error = nil;
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    if (managedObjectContext != nil)
    {
        if ([managedObjectContext hasChanges] && ![managedObjectContext save:&error])
        {
            /*
             Replace this implementation with code to handle the error appropriately.
             
             abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. If it is not possible to recover from the error, display an alert panel that instructs the user to quit the application by pressing the Home button.
             */
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        } 
    }
}

#pragma mark - Core Data stack

/**
 Returns the managed object context for the application.
 If the context doesn't already exist, it is created and bound to the persistent store coordinator for the application.
 */
- (NSManagedObjectContext *)managedObjectContext
{
    if (__managedObjectContext != nil)
    {
        return __managedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil)
    {
        __managedObjectContext = [[TICDSSynchronizedManagedObjectContext alloc] init];
        [__managedObjectContext setPersistentStoreCoordinator:coordinator];
    }
    return __managedObjectContext;
}

/**
 Returns the managed object model for the application.
 If the model doesn't already exist, it is created from the application's model.
 */
- (NSManagedObjectModel *)managedObjectModel
{
    if (__managedObjectModel != nil)
    {
        return __managedObjectModel;
    }
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"Notebook" withExtension:@"momd"];
    __managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];    
    return __managedObjectModel;
}

/**
 Returns the persistent store coordinator for the application.
 If the coordinator doesn't already exist, it is created and the application's store added to it.
 */
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    if (__persistentStoreCoordinator != nil)
    {
        return __persistentStoreCoordinator;
    }
    
    NSURL *storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"Notebook.sqlite"];
    
    if( ![[NSFileManager defaultManager] fileExistsAtPath:[storeURL path]] ) {
        [self setDownloadStoreAfterRegistering:YES];
    }
    
    NSError *error = nil;
    __persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    if (![__persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:&error])
    {
        /*
         Replace this implementation with code to handle the error appropriately.
         
         abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. If it is not possible to recover from the error, display an alert panel that instructs the user to quit the application by pressing the Home button.
         
         Typical reasons for an error here include:
         * The persistent store is not accessible;
         * The schema for the persistent store is incompatible with current managed object model.
         Check the error message to determine what the actual problem was.
         
         
         If the persistent store is not accessible, there is typically something wrong with the file path. Often, a file URL is pointing into the application's resources directory instead of a writeable directory.
         
         If you encounter schema incompatibility errors during development, you can reduce their frequency by:
         * Simply deleting the existing store:
         [[NSFileManager defaultManager] removeItemAtURL:storeURL error:nil]
         
         * Performing automatic lightweight migration by passing the following dictionary as the options parameter: 
         [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption, [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption, nil];
         
         Lightweight migration will only work for a limited set of schema changes; consult "Core Data Model Versioning and Data Migration Programming Guide" for details.
         
         */
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }    
    
    return __persistentStoreCoordinator;
}

#pragma mark - Application's Documents directory

/**
 Returns the URL to the application's Documents directory.
 */
- (NSURL *)applicationDocumentsDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

@end
