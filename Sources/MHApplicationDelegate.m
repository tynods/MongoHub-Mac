//
//  MHApplicationDelegate.m
//  MongoHub
//
//  Created by Syd on 10-4-24.
//  Copyright MusicPeace.ORG 2010 . All rights reserved.
//

#import "MHApplicationDelegate.h"
#import "MHConnectionWindowController.h"
#import "ConnectionsArrayController.h"
#import "MHConnectionEditorWindowController.h"
#import "MHConnectionStore.h"
#import "MHPreferenceWindowController.h"
#import "MHConnectionViewItem.h"
#import "MHLogWindowController.h"
#import <Sparkle/Sparkle.h>
#import "ALIterativeMigrator.h"

#define YOUR_EXTERNAL_RECORD_EXTENSION @"mgo"
#define YOUR_STORE_TYPE NSXMLStoreType

#define MHSofwareUpdateChannelKey                       @"MHSofwareUpdateChannel"
#define MHConnectTimeoutKey                             @"MHConnectTimeoutKey"
#define MHSocketTimeoutKey                              @"MHSocketTimeoutKey"

@interface MHApplicationDelegate()
@property (nonatomic, strong, readwrite) MHConnectionEditorWindowController *connectionEditorWindowController;
@property (nonatomic, strong, readwrite) SUUpdater *updater;
@property (nonatomic, strong, readwrite) MHPreferenceWindowController *preferenceWindowController;
@property (nonatomic, strong, readwrite) NSMutableArray *urlConnectionEditorWindowControllers;
@property (nonatomic, strong, readwrite) NSMutableArray *connectionWindowControllers;
@property (nonatomic, strong, readwrite) MHLogWindowController *logWindowController;

@property (nonatomic, strong, readwrite) IBOutlet NSWindow *window;
@property (nonatomic, strong, readwrite) IBOutlet MHConnectionCollectionView *connectionCollectionView;
@property (nonatomic, strong, readwrite) IBOutlet ConnectionsArrayController *connectionsArrayController;
@property (nonatomic, strong, readwrite) IBOutlet NSTextField *bundleVersion;
@property (nonatomic, strong, readwrite) IBOutlet NSPanel *supportPanel;

@property (nonatomic, readonly, assign) NSURL *dataStoreURL;

@end

@interface MHApplicationDelegate (MHLogWindowControllerDelegate) <MHLogWindowControllerDelegate>

@end

@implementation MHApplicationDelegate

@synthesize updater = _updater;
@synthesize window = _window;
@synthesize connectionCollectionView = _connectionCollectionView;
@synthesize connectionsArrayController = _connectionsArrayController;
@synthesize bundleVersion = _bundleVersion;
@synthesize preferenceWindowController = _preferenceWindowController;
@synthesize connectionEditorWindowController = _connectionEditorWindowController;
@synthesize urlConnectionEditorWindowControllers = _urlConnectionEditorWindowControllers;
@synthesize connectionWindowControllers = _connectionWindowControllers;
@synthesize supportPanel = _supportPanel;
@synthesize logWindowController = _logWindowController;

- (void)awakeFromNib
{
    if ([[NSProcessInfo processInfo].environment[@"MONGOC_VERBOSE"] integerValue] != 0) {
        [MODClient setLogCallback:^(MODLogLevel level, const char *domain, const char *message) {
            NSLog(@"%@ %s %s", [MODClient logLevelStringForLogLevel:level], domain, message);
        }];
    }
    self.connectionWindowControllers = [NSMutableArray array];
    self.urlConnectionEditorWindowControllers = [NSMutableArray array];
    [self.connectionsArrayController setSortDescriptors:[NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"alias" ascending:YES selector:@selector(caseInsensitiveCompare:)]]];
}

- (void)dealloc
{
    self.connectionWindowControllers = nil;
    self.window = nil;
    [_managedObjectContext release];
    [_persistentStoreCoordinator release];
    [_managedObjectModel release];
    
    self.urlConnectionEditorWindowControllers = nil;
    self.connectionCollectionView = nil;
    self.preferenceWindowController = nil;
    self.updater = nil;
    self.connectionsArrayController = nil;
    self.bundleVersion = nil;
    
    [super dealloc];
}

- (NSURL *)dataStoreURL
{
    return [NSURL fileURLWithPath:[self.applicationSupportDirectory stringByAppendingPathComponent:@"storedata"]];
}

/**
    Returns the support directory for the application, used to store the Core Data
    store file.  This code uses a directory named "MongoHub" for
    the content, either in the NSApplicationSupportDirectory location or (if the
    former cannot be found), the system's temporary directory.
 */

- (NSString *)applicationSupportDirectory
{

    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : NSTemporaryDirectory();
    return [basePath stringByAppendingPathComponent:@"MongoHub"];
}

/**
    Returns the external records directory for the application.
    This code uses a directory named "MongoHub" for the content, 
    either in the ~/Library/Caches/Metadata/CoreData location or (if the
    former cannot be found), the system's temporary directory.
 */

- (NSString *)externalRecordsDirectory
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : NSTemporaryDirectory();
    return [basePath stringByAppendingPathComponent:@"Metadata/CoreData/MongoHub"];
}

/**
    Creates, retains, and returns the managed object model for the application 
    by merging all of the models found in the application bundle.
 */
 
- (NSManagedObjectModel *)managedObjectModel
{
    if (_managedObjectModel) {
        return _managedObjectModel;
    }
    
    _managedObjectModel = [[NSManagedObjectModel mergedModelFromBundles:nil] retain];
    return _managedObjectModel;
}


/**
    Returns the persistent store coordinator for the application.  This 
    implementation will create and return a coordinator, having added the 
    store for the application to it.  (The directory for the store is created, 
    if necessary.)
 */

- (NSPersistentStoreCoordinator *) persistentStoreCoordinator
{
    if (_persistentStoreCoordinator) return _persistentStoreCoordinator;

    NSManagedObjectModel *mom = self.managedObjectModel;
    if (!mom) {
        NSAssert(NO, @"Managed object model is nil");
        NSLog(@"%@:%@ No model to generate a store from", [self class], NSStringFromSelector(_cmd));
        return nil;
    }

    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *applicationSupportDirectory = [self applicationSupportDirectory];
    NSError *error = nil;
    
    if (![fileManager fileExistsAtPath:applicationSupportDirectory isDirectory:NULL]) {
        if (![fileManager createDirectoryAtPath:applicationSupportDirectory withIntermediateDirectories:NO attributes:nil error:&error]) {
            NSAssert2(NO, @"Failed to create App Support directory %@ : %@", applicationSupportDirectory, error);
            NSLog(@"Error creating application support directory at %@ : %@",applicationSupportDirectory,error);
            return nil;
        }
    }

    NSString *externalRecordsDirectory = [self externalRecordsDirectory];
    if (![fileManager fileExistsAtPath:externalRecordsDirectory isDirectory:NULL]) {
        if (![fileManager createDirectoryAtPath:externalRecordsDirectory withIntermediateDirectories:YES attributes:nil error:&error]) {
            NSLog(@"Error creating external records directory at %@ : %@",externalRecordsDirectory,error);
            NSAssert2(NO, @"Failed to create external records directory %@ : %@", externalRecordsDirectory, error);
            NSLog(@"Error creating external records directory at %@ : %@",externalRecordsDirectory,error);
            return nil;
        };
    }

    // set store options to enable spotlight indexing
    NSMutableDictionary *storeOptions = [NSMutableDictionary dictionary];
    storeOptions[NSExternalRecordExtensionOption] = YOUR_EXTERNAL_RECORD_EXTENSION;
    storeOptions[NSExternalRecordsDirectoryOption] = externalRecordsDirectory;
    storeOptions[NSMigratePersistentStoresAutomaticallyOption] = @(YES);
    storeOptions[NSInferMappingModelAutomaticallyOption] = @(YES);
    storeOptions[NSMigratePersistentStoresAutomaticallyOption] = @(YES);
    
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel: mom];
    NSArray* modelNames = @[
                            @"MongoHub_DataModel",
                            @"MongoHub_DataModel3.0",
                            @"MongoHub_DataModel4",
                            @"MongoHub_DataModel5",
                            @"MongoHub_DataModel6",
                            @"MongoHub_DataModel7",
                            @"MongoHub_DataModel8",
                            @"MongoHub_DataModel9",
                            @"MongoHub_DataModel10",
                            @"MongoHub_DataModel11",
                            @"MongoHub_DataModel12",
                            @"MongoHub_DataModel13",
                            ];
    if (![ALIterativeMigrator iterativeMigrateURL:self.dataStoreURL
                                           ofType:YOUR_STORE_TYPE
                                          toModel:[self managedObjectModel]
                                orderedModelNames:modelNames
                                            error:&error]) {
        NSLog(@"Error migrating to latest model: %@\n %@", error, [error userInfo]);
    }
    if (![_persistentStoreCoordinator addPersistentStoreWithType:YOUR_STORE_TYPE
                                                   configuration:nil
                                                             URL:self.dataStoreURL
                                                         options:storeOptions
                                                           error:&error]) {
        [[NSApplication sharedApplication] presentError:error];
        [_persistentStoreCoordinator release];
        _persistentStoreCoordinator = nil;
        return nil;
    }    

    return _persistentStoreCoordinator;
}

/**
    Returns the managed object context for the application (which is already
    bound to the persistent store coordinator for the application.) 
 */
 
- (NSManagedObjectContext *)managedObjectContext
{
    if (_managedObjectContext) return _managedObjectContext;

    NSPersistentStoreCoordinator *coordinator = self.persistentStoreCoordinator;
    
    if (!coordinator) {
        NSError *error = nil;
        NSAlert *alert;
        
        alert = [NSAlert alertWithMessageText:@"Failed to load the store database" defaultButton:@"Reset" alternateButton:@"Cancel" otherButton:nil informativeTextWithFormat:@"By clicking on reset you will loose the connection information"];
        alert.alertStyle = NSCriticalAlertStyle;
        switch ([alert runModal]) {
            case 0:
                return nil;
                break;
            case 1:
                
                if ([[NSFileManager defaultManager] removeItemAtURL:self.dataStoreURL error:&error]) {
                    coordinator = self.persistentStoreCoordinator;
                    if (!coordinator) {
                        return nil;
                    }
                } else {
                    [[NSApplication sharedApplication] presentError:error];
                    return nil;
                }
                break;
                
            default:
                return nil;
                break;
        };
    }
    _managedObjectContext = [[NSManagedObjectContext alloc] init];
    [_managedObjectContext setPersistentStoreCoordinator:coordinator];

    return _managedObjectContext;
}

/**
    Returns the NSUndoManager for the application.  In this case, the manager
    returned is that of the managed object context for the application.
 */
 
- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)window
{
    return self.managedObjectContext.undoManager;
}

- (void)dockOpenConnectionAction:(NSMenuItem *)menuItem
{
    MHConnectionStore *connectionStore;
    
    connectionStore = [self connectionStoreWithAlias:menuItem.title];
    if (connectionStore) {
        [self openConnection:connectionStore];
    }
}

/**
    Performs the save action for the application, which is to send the save:
    message to the application's managed object context.  Any encountered errors
    are presented to the user.
 */
 
- (void)saveConnections
{
    NSError *error = nil;
    
    if (![[self managedObjectContext] commitEditing]) {
        NSLog(@"%@:%@ unable to commit editing before saving", [self class], NSStringFromSelector(_cmd));
    }

    if (![[self managedObjectContext] save:&error]) {
        [[NSApplication sharedApplication] presentError:error];
    }
}

- (void)checkForUpdatesEveryDay:(id)sender
{
    [self.updater checkForUpdatesInBackground];
    [self performSelector:@selector(checkForUpdatesEveryDay:) withObject:nil afterDelay:3600 * 24];
}

- (MHConnectionWindowController *)connectionWindowControllerForConnectionStore:(MHConnectionStore *)connection
{
    for (MHConnectionWindowController *controller in self.connectionWindowControllers) {
        if (controller.connectionStore == connection) {
            return controller;
        }
    }
    return nil;
}

- (void)openConnection:(MHConnectionStore *)connection
{
    MHConnectionWindowController *connectionWindowController;
    
    connectionWindowController = [self connectionWindowControllerForConnectionStore:connection];
    if (connectionWindowController) {
        [connectionWindowController showWindow:nil];
    } else {
        connectionWindowController = [[MHConnectionWindowController alloc] init];
        connectionWindowController.delegate = self;
        connectionWindowController.connectionStore = connection;
        [connectionWindowController showWindow:self];
        [self.connectionWindowControllers addObject:connectionWindowController];
        [connectionWindowController release];
    }
}

- (void)editConnection:(MHConnectionStore *)connection
{
    self.connectionEditorWindowController = [[[MHConnectionEditorWindowController alloc] init] autorelease];
    self.connectionEditorWindowController.delegate = self;
    self.connectionEditorWindowController.editedConnectionStore = connection;
    [self.connectionEditorWindowController modalForWindow:self.window];
}

- (void)duplicateConnection:(MHConnectionStore *)connection
{
    if (!self.connectionEditorWindowController) {
        self.connectionEditorWindowController = [[[MHConnectionEditorWindowController alloc] init] autorelease];
        self.connectionEditorWindowController.delegate = self;
        self.connectionEditorWindowController.connectionStoreDefaultValue = connection;
        [self.connectionEditorWindowController modalForWindow:self.window];
    }
}

- (void)deleteConnection:(MHConnectionStore *)connection
{
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert addButtonWithTitle:@"Cancel"];
    [alert addButtonWithTitle:@"Delete"];
    [alert setMessageText:[NSString stringWithFormat:@"Delete \"%@\"?", connection.alias]];
    [alert setInformativeText:@"Deleted connections cannot be restored."];
    [alert setAlertStyle:NSWarningAlertStyle];
    
    [alert beginSheetModalForWindow:self.window modalDelegate:self didEndSelector:@selector(deleteConnectionAlertDidEnd:returnCode:contextInfo:) contextInfo:connection];
}

- (void)copyURLConnection:(MHConnectionStore *)connection
{
    NSPasteboard *pasteboard = NSPasteboard.generalPasteboard;
    NSString *stringURL = [connection stringURLWithSSHMapping:nil];
    
    [pasteboard declareTypes:@[ NSStringPboardType, NSURLPboardType ] owner:nil];
    [pasteboard setString:stringURL forType:NSStringPboardType];
    [pasteboard setString:stringURL forType:NSURLPboardType];
}

- (void)closingWindowPreferenceController:(NSNotification *)notification
{
    if (notification.object == self.preferenceWindowController) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:nil object:notification.object];
        self.preferenceWindowController = nil;
    }
}

- (MHSoftwareUpdateChannel)softwareUpdateChannel
{
    NSString *value;
    MHSoftwareUpdateChannel result = MHSoftwareUpdateChannelDefault;
    
    value = [NSUserDefaults.standardUserDefaults objectForKey:MHSofwareUpdateChannelKey];
    if ([value isEqualToString:@"beta"]) {
        result = MHSoftwareUpdateChannelBeta;
    }
    return result;
}

- (void)setSoftwareUpdateChannel:(MHSoftwareUpdateChannel)value
{
    switch (value) {
        case MHSoftwareUpdateChannelDefault:
            [NSUserDefaults.standardUserDefaults removeObjectForKey:MHSofwareUpdateChannelKey];
            break;
        
        case MHSoftwareUpdateChannelBeta:
            [NSUserDefaults.standardUserDefaults setObject:@"beta" forKey:MHSofwareUpdateChannelKey];
            break;
    }
    [NSUserDefaults.standardUserDefaults synchronize];
    [self.updater checkForUpdatesInBackground];
}

- (uint32_t)defaultConnectTimeout
{
    return MODClient.defaultConnectTimeout;
}

- (void)setConnectTimeout:(uint32_t)connectTimeout
{
    if (connectTimeout == 0 || connectTimeout == MODClient.defaultConnectTimeout) {
        [NSUserDefaults.standardUserDefaults removeObjectForKey:MHConnectTimeoutKey];
    } else {
        [NSUserDefaults.standardUserDefaults setInteger:connectTimeout forKey:MHConnectTimeoutKey];
    }
}

- (uint32_t)connectTimeout
{
    return (uint32_t)[NSUserDefaults.standardUserDefaults integerForKey:MHConnectTimeoutKey];
}

- (uint32_t)defaultSocketTimeout
{
    return MODClient.defaultSocketTimeout;
}

- (void)setSocketTimeout:(uint32_t)socketTimeout
{
    if (socketTimeout == 0 || socketTimeout == MODClient.defaultSocketTimeout) {
        [NSUserDefaults.standardUserDefaults removeObjectForKey:MHSocketTimeoutKey];
    } else {
        [NSUserDefaults.standardUserDefaults setInteger:socketTimeout forKey:MHSocketTimeoutKey];
    }
}

- (uint32_t)socketTimeout
{
    return (uint32_t)[NSUserDefaults.standardUserDefaults integerForKey:MHSocketTimeoutKey];
}

- (MHConnectionStore *)connectionStoreWithAlias:(NSString *)alias
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"alias=%@", alias];
    NSArray *items = [self.connectionsArrayController itemsUsingFetchPredicate:predicate];
    return (items.count == 1)?[items objectAtIndex:0]:nil;
}

@end

@implementation MHApplicationDelegate (NSApplicationDelegate)

-(void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
    NSAppleEventManager *appleEventManager = [NSAppleEventManager sharedAppleEventManager];
    [appleEventManager setEventHandler:self
                           andSelector:@selector(handleGetURLEvent:withReplyEvent:)
                         forEventClass:kInternetEventClass andEventID:kAEGetURL];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    self.bundleVersion.stringValue = [NSString stringWithFormat:@"version: %@", [NSBundle.mainBundle.infoDictionary objectForKey:@"CFBundleShortVersionString"]];
    
    self.updater = [[[SUUpdater alloc] init] autorelease];
    self.updater.delegate = self;
    [self checkForUpdatesEveryDay:nil];
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender
{
    BOOL windowVisible = NO;
    
    for (NSWindow *window in [NSApp windows]) {
        windowVisible = windowVisible || window.isVisible;
    }
    if (!windowVisible) {
        [self.window makeKeyAndOrderFront:nil];
    }
    return NO;
}

- (void)applicationDidBecomeActive:(NSNotification *)notification
{
    BOOL windowVisible = NO;
    
    for (NSWindow *window in [NSApp windows]) {
        windowVisible = windowVisible || window.isVisible;
    }
    if (!windowVisible) {
        [self.window makeKeyAndOrderFront:nil];
    }
}

- (void)application:(NSApplication *)theApplication openFiles:(NSArray *)files
{
    NSString *aPath = [files lastObject]; // just an example to get at one of the paths
    
    if (aPath && [aPath hasSuffix:YOUR_EXTERNAL_RECORD_EXTENSION]) {
        // decode URI from path
        NSURL *objectURI = [[NSPersistentStoreCoordinator elementsDerivedFromExternalRecordURL:[NSURL fileURLWithPath:aPath]] objectForKey:NSObjectURIKey];
        if (objectURI) {
            NSManagedObjectID *moid = [[self persistentStoreCoordinator] managedObjectIDForURIRepresentation:objectURI];
            if (moid) {
                NSManagedObject *mo = [[self managedObjectContext] objectWithID:moid];
                NSLog(@"The record for path %@ is %@",moid,mo);
                
                // your code to select the object in your application's UI
            }
            
        }
    }
    
}

- (NSMenu *)applicationDockMenu:(NSApplication *)sender
{
    NSMenu *menu;
    NSMenu *subMenu;
    NSMenuItem *menuItem;
    
    menu = [[NSMenu alloc] init];
    subMenu = [[NSMenu alloc] init];
    menuItem = [menu addItemWithTitle:@"Connections" action:nil keyEquivalent:@""];
    
    [menu setSubmenu:subMenu forItem:menuItem];
    for (MHConnectionStore *connectionStore in self.connectionsArrayController.arrangedObjects) {
        menuItem = [subMenu addItemWithTitle:connectionStore.alias action:nil keyEquivalent:@""];
        menuItem.target = self;
        menuItem.action = @selector(dockOpenConnectionAction:);
    }
    [subMenu release];
    return [menu autorelease];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
    return NO;
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
    if (!_managedObjectContext) return NSTerminateNow;
    
    if (![_managedObjectContext commitEditing]) {
        NSLog(@"%@:%@ unable to commit editing to terminate", [self class], NSStringFromSelector(_cmd));
        return NSTerminateCancel;
    }
    
    if (![_managedObjectContext hasChanges]) return NSTerminateNow;
    
    NSError *error = nil;
    if (![_managedObjectContext save:&error]) {
        
        // This error handling simply presents error information in a panel with an
        // "Ok" button, which does not include any attempt at error recovery (meaning,
        // attempting to fix the error.)  As a result, this implementation will
        // present the information to the user and then follow up with a panel asking
        // if the user wishes to "Quit Anyway", without saving the changes.
        
        // Typically, this process should be altered to include application-specific
        // recovery steps.
        
        BOOL result = [sender presentError:error];
        if (result) return NSTerminateCancel;
        
        NSString *question = NSLocalizedString(@"Could not save changes while quitting.  Quit anyway?", @"Quit without saves error question message");
        NSString *info = NSLocalizedString(@"Quitting now will lose any changes you have made since the last successful save", @"Quit without saves error question info");
        NSString *quitButton = NSLocalizedString(@"Quit anyway", @"Quit anyway button title");
        NSString *cancelButton = NSLocalizedString(@"Cancel", @"Cancel button title");
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:question];
        [alert setInformativeText:info];
        [alert addButtonWithTitle:quitButton];
        [alert addButtonWithTitle:cancelButton];
        
        NSInteger answer = [alert runModal];
        [alert release];
        alert = nil;
        
        if (answer == NSAlertAlternateReturn) return NSTerminateCancel;
        
    }
    
    return NSTerminateNow;
}

@end

@implementation MHApplicationDelegate (Action)

- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)anItem
{
    if (anItem.action == @selector(copy:)) {
        return self.window.isKeyWindow && self.connectionsArrayController.selectedObjects.count == 1;
    } else if (anItem.action == @selector(paste:)) {
        return self.window.isKeyWindow && [[[NSPasteboard generalPasteboard] stringForType:NSPasteboardTypeString] hasPrefix:@"mongodb://"];
    } else {
        return [self respondsToSelector:anItem.action];
    }
}

- (void)copy:(id)sender
{
    if (self.connectionsArrayController.selectedObjects.count == 1 && !self.connectionEditorWindowController) {
        [self copyURLConnection:self.connectionsArrayController.selectedObjects[0]];
    }
}

- (IBAction)paste:(id)sender
{
    NSString *stringURL;
    
    stringURL = [[NSPasteboard generalPasteboard] stringForType:NSPasteboardTypeString];
    if (![stringURL hasPrefix:@"mongodb://"]) {
        [[NSAlert alertWithMessageText:@"No URL found" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@""] runModal];
    } else {
        NSEntityDescription *entity;
        MHConnectionStore *connectionStore;
        NSString *errorMessage;
        MHConnectionEditorWindowController *controller;
        
        entity = [NSEntityDescription entityForName:@"Connection" inManagedObjectContext:self.managedObjectContext];
        connectionStore = [[[MHConnectionStore alloc] initWithEntity:entity insertIntoManagedObjectContext:nil] autorelease];
        if (![connectionStore setValuesFromStringURL:stringURL errorMessage:&errorMessage]) {
            [[NSAlert alertWithMessageText:errorMessage defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"%@", stringURL] runModal];
            return;
        }
        controller = [[[MHConnectionEditorWindowController alloc] init] autorelease];
        controller.delegate = self;
        controller.connectionStoreDefaultValue = connectionStore;
        controller.window.title = stringURL;
        [controller showWindow:nil];
        [self.urlConnectionEditorWindowControllers addObject:controller];
    }
}

- (IBAction)checkForUpdatesAction:(id)sender
{
    [self.updater checkForUpdates:sender];
}

- (IBAction)addNewConnectionAction:(id)sender
{
    if (!self.connectionEditorWindowController) {
        self.connectionEditorWindowController = [[[MHConnectionEditorWindowController alloc] init] autorelease];
        self.connectionEditorWindowController.delegate = self;
        [self.connectionEditorWindowController modalForWindow:self.window];
    }
}

- (IBAction)editConnectionAction:(id)sender
{
    if (self.connectionsArrayController.selectedObjects.count == 1 && !self.connectionEditorWindowController) {
        [self editConnection:[self.connectionsArrayController.selectedObjects objectAtIndex:0]];
    }
}

- (IBAction)duplicateConnectionAction:(id)sender
{
    if (self.connectionsArrayController.selectedObjects.count == 1 && !self.connectionEditorWindowController) {
        [self duplicateConnection:[self.connectionsArrayController.selectedObjects objectAtIndex:0]];
    }
}

- (IBAction)deleteConnectionAction:(id)sender
{
    if (self.connectionsArrayController.selectedObjects.count == 1) {
        [self deleteConnection:[self.connectionsArrayController.selectedObjects objectAtIndex:0]];
    }
}

- (void)deleteConnectionAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    if (returnCode == NSAlertSecondButtonReturn) {
        [self.connectionsArrayController removeObject:contextInfo];
        [self saveConnections];
        [self.connectionsArrayController setSelectedObjects:@[]];
    }
}

- (IBAction)resizeConnectionItemView:(id)sender
{
    CGFloat value = [sender floatValue]/100.0f*360.0f;
    
    self.connectionCollectionView.itemSize = NSMakeSize(value, value * 0.8);
}

- (IBAction)openConnectionAction:(id)sender
{
    if (!self.connectionsArrayController.selectedObjects) {
        return;
    }
    [self openConnection:[self.connectionsArrayController.selectedObjects objectAtIndex:0]];
}

- (IBAction)openSupportPanel:(id)sender
{
    [NSApp beginSheet:self.supportPanel modalForWindow:self.window modalDelegate:self didEndSelector:@selector(supportPanelDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (void)supportPanelDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    [sheet close];
}

- (IBAction)closeSupportPanel:(id)sender
{
    [NSApp endSheet:self.supportPanel];
}

- (IBAction)openFeatureRequestBugReport:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/jeromelebel/MongoHub-Mac/issues"]];
}

- (IBAction)openConnectionWindow:(id)sender
{
    [self.window makeKeyAndOrderFront:sender];
}

- (IBAction)openPreferenceWindow:(id)sender
{
    if (!self.preferenceWindowController) {
        self.preferenceWindowController = [MHPreferenceWindowController preferenceWindowController];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(closingWindowPreferenceController:) name:MHPreferenceWindowControllerClosing object:self.preferenceWindowController];
    }
    [self.preferenceWindowController showWindow:sender];
}

- (IBAction)openLogWindow:(id)sender
{
    if (!self.logWindowController) {
        self.logWindowController = [MHLogWindowController logWindowController];
        self.logWindowController.delegate = self;
        [MODClient setLogCallback:^(MODLogLevel level, const char *domain, const char *message) {
            [self.logWindowController addLogLine:[NSString stringWithUTF8String:message] domain:[NSString stringWithFormat:@"mongoc.%s", domain] level:[MODClient logLevelStringForLogLevel:level]];
        }];
    }
    [self.logWindowController showWindow:self];
}

@end

@implementation MHApplicationDelegate (SUUpdate)

+ (NSString *)systemVersionString
{
    return [[NSDictionary dictionaryWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"] objectForKey:@"ProductVersion"];
}

+ (id)defaultComparator
{
    id comparator = [NSClassFromString(@"SUStandardVersionComparator") performSelector:@selector(defaultComparator)];
  
    NSAssert(comparator != nil, @"cannot get an instance of 'SUStandardVersionComparator'");
    return comparator;
}

- (BOOL)hostSupportsItem:(SUAppcastItem *)ui
{
    if ([ui minimumSystemVersion] == nil || [[ui minimumSystemVersion] isEqualToString:@""]) { return YES; }
    
    BOOL minimumVersionOK = TRUE;
    
    // Check minimum and maximum System Version
    if ([ui minimumSystemVersion] != nil && ![[ui minimumSystemVersion] isEqualToString:@""]) {
        minimumVersionOK = [[MHApplicationDelegate defaultComparator] compareVersion:[ui minimumSystemVersion] toVersion:[MHApplicationDelegate systemVersionString]] != NSOrderedDescending;
    }
    
    return minimumVersionOK;
}

- (SUAppcastItem *)bestValidUpdateInAppcast:(SUAppcast *)appcast forUpdater:(SUUpdater *)bundle
{
    SUAppcastItem *result = nil;
    BOOL shouldUseBeta;
    id comparator = [MHApplicationDelegate defaultComparator];
  
    // use beta if the user wants to use beta, or if we are using a beta version right now
    shouldUseBeta = self.softwareUpdateChannel == MHSoftwareUpdateChannelBeta
                    || [NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"] rangeOfString:@"b"].location != NSNotFound;
    for (SUAppcastItem *item in appcast.items) {
        if ([self hostSupportsItem:item] && (shouldUseBeta || ![[item.propertiesDictionary objectForKey:@"beta"] isEqualToString:@"1"])) {
          if (result == nil) {
              result = item;
          } else if ([comparator compareVersion:result.versionString toVersion:item.versionString] != NSOrderedDescending) {
              result = item;
          }
        }
    }
    return result;
}

- (void)handleGetURLEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent
{
    MHConnectionStore *connectionStore;
    NSEntityDescription *entity;
    NSString *errorMessage;
    NSString *stringURL;
    MHConnectionEditorWindowController *controller;
    
    entity = [NSEntityDescription entityForName:@"Connection" inManagedObjectContext:self.managedObjectContext];
    stringURL = [event paramDescriptorForKeyword:keyDirectObject].stringValue;
    connectionStore = [[[MHConnectionStore alloc] initWithEntity:entity insertIntoManagedObjectContext:nil] autorelease];
    if (![connectionStore setValuesFromStringURL:stringURL errorMessage:&errorMessage]) {
        [[NSAlert alertWithMessageText:errorMessage defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"%@", stringURL] runModal];
        return;
    }

    controller = [[[MHConnectionEditorWindowController alloc] init] autorelease];
    controller.delegate = self;
    controller.connectionStoreDefaultValue = connectionStore;
    controller.window.title = stringURL;
    [controller showWindow:nil];
    [self.urlConnectionEditorWindowControllers addObject:controller];
}

@end

@implementation MHApplicationDelegate(MHConnectionEditorWindowControllerDelegate)

- (void)connectionWindowControllerDidCancel:(MHConnectionEditorWindowController *)controller
{
    if (self.connectionEditorWindowController == controller) {
        self.connectionEditorWindowController = nil;
    } else {
        [self.urlConnectionEditorWindowControllers removeObject:controller];
    }
}

- (void)connectionWindowControllerDidValidate:(MHConnectionEditorWindowController *)controller
{
    [self saveConnections];
    self.connectionCollectionView.needsDisplay = YES;
    if (self.connectionEditorWindowController == controller) {
        self.connectionEditorWindowController = nil;
    } else {
        [self.urlConnectionEditorWindowControllers removeObject:controller];
    }
}

- (MHConnectionStore *)connectionWindowController:(MHConnectionEditorWindowController *)controller connectionStoreWithAlias:(NSString *)alias
{
    return [self connectionStoreWithAlias:alias];
}

@end

@implementation MHApplicationDelegate (MHConnectionViewItemDelegate)

- (void)connectionViewItemDelegateNewItem:(MHConnectionCollectionView *)connectionCollectionView
{
    [self addNewConnectionAction:nil];
}

- (void)connectionViewItemDelegate:(MHConnectionCollectionView *)connectionCollectionView openItem:(MHConnectionViewItem *)connectionViewItem
{
    [self openConnection:connectionViewItem.representedObject];
}

- (void)connectionViewItemDelegate:(MHConnectionCollectionView *)connectionCollectionView editItem:(MHConnectionViewItem *)connectionViewItem
{
    [self editConnection:connectionViewItem.representedObject];
}

- (void)connectionViewItemDelegate:(MHConnectionCollectionView *)connectionCollectionView duplicateItem:(MHConnectionViewItem *)connectionViewItem
{
    [self duplicateConnection:connectionViewItem.representedObject];
}

- (void)connectionViewItemDelegate:(MHConnectionCollectionView *)connectionCollectionView copyURLItem:(MHConnectionViewItem *)connectionViewItem
{
    [self copyURLConnection:connectionViewItem.representedObject];
}

- (void)connectionViewItemDelegate:(MHConnectionCollectionView *)connectionCollectionView deleteItem:(MHConnectionViewItem *)connectionViewItem
{
    [self deleteConnection:connectionViewItem.representedObject];
}

@end

@implementation MHApplicationDelegate (MHConnectionWindowControllerDelegate)

- (void)connectionWindowControllerWillClose:(MHConnectionWindowController *)controller
{
    [self.connectionWindowControllers removeObject:controller];
}

- (BOOL)connectionWindowControllerSSHVerbose:(MHConnectionWindowController *)controller
{
    return [[NSProcessInfo processInfo].environment[@"SSH_VERBOSE"] integerValue] != 0;
}

- (void)connectionWindowControllerLogMessage:(NSString *)message domain:(NSString *)domain level:(NSString *)level
{
    [self.logWindowController addLogLine:message domain:domain level:level];
}

@end


@implementation MHApplicationDelegate (MHLogWindowControllerDelegate)

- (void)logWindowControllerWillClose:(MHLogWindowController *)logWindowController
{
    if (logWindowController == self.logWindowController) {
        self.logWindowController = nil;
        [MODClient setLogCallback:nil];
    }
}

@end

#define CollectionTabsKey                   @"CollectionTabs"
#define MapReduceTabKey                     @"MapReduceTab"
#define AggregationKey                      @"Aggregation"

@implementation MHApplicationDelegate (Preferences)

- (BOOL)hasCollectionMapReduceTab
{
    if ([[NSUserDefaults standardUserDefaults] dictionaryForKey:CollectionTabsKey][MapReduceTabKey]) {
        return [[[NSUserDefaults standardUserDefaults] dictionaryForKey:CollectionTabsKey][MapReduceTabKey] boolValue];
    } else {
        return YES;
    }
}

- (void)setCollectionMapReduceTab:(BOOL)value
{
    NSMutableDictionary *values = [[[NSUserDefaults standardUserDefaults] dictionaryForKey:CollectionTabsKey] mutableCopy];
    
    if (!values) {
        values = [[NSMutableDictionary alloc] init];
    }
    values[MapReduceTabKey] = @(value);
    [[NSUserDefaults standardUserDefaults] setObject:values forKey:CollectionTabsKey];
    MOD_RELEASE(values);
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (BOOL)hasCollectionAggregationTab
{
    if ([[NSUserDefaults standardUserDefaults] dictionaryForKey:CollectionTabsKey][AggregationKey]) {
        return [[[NSUserDefaults standardUserDefaults] dictionaryForKey:CollectionTabsKey][AggregationKey] boolValue];
    } else {
        return NO;
    }
}

- (void)setCollectionAggregationTab:(BOOL)value
{
    NSMutableDictionary *values = [[[NSUserDefaults standardUserDefaults] dictionaryForKey:CollectionTabsKey] mutableCopy];
    
    if (!values) {
        values = [[NSMutableDictionary alloc] init];
    }
    values[AggregationKey] = @(value);
    [[NSUserDefaults standardUserDefaults] setObject:values forKey:CollectionTabsKey];
    MOD_RELEASE(values);
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end
