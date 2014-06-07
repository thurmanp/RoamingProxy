#import "RoamingProxyAppDelegate.h"
#import "RoamingProxyViewController.h"
#import "HTTPServer.h"
#import "DDLog.h"
#import "DDTTYLogger.h"
#import "DDASLLogger.h"
#import "MyHTTPConnection.h"
#import "UITextViewLogger.h"

// Log levels: off, error, warn, info, verbose
static const int ddLogLevel = LOG_LEVEL_VERBOSE;

static NSString * const kConfigurationKey = @"com.apple.configuration.managed";
static NSString * const kConfigurationUserName = @"user";
static NSString * const kPayloadUserConfig = @"config";
static NSString * const kConfigurationRestApi = @"restconfig";

static NSString *carrierPListSymLinkPath = @"/var/mobile/Library/Preferences/com.apple.carrier.plist";
static NSString *operatorPListSymLinkPath = @"/var/mobile/Library/Preferences/com.apple.operator.plist";

@implementation RoamingProxyAppDelegate

@synthesize window;
@synthesize viewController;
@synthesize httpServer;
@synthesize restApi;
@synthesize userConfig;
@synthesize userName;

- (void)readDefaultsValues {
    NSDictionary *config = [[NSUserDefaults standardUserDefaults] dictionaryForKey:kConfigurationKey];
    NSString *_userName = config[kConfigurationUserName];
    NSString *_restApi = config[kConfigurationRestApi];
    // Data coming from MDM server should be validated before use.
    // If validation fails, be sure to set a sensible default value as a fallback, even if it is nil.
    if (_userName && [_userName isKindOfClass:[NSString class]]) {
        self.userName=_userName;
    } else {
        self.userName=@"thurmanp";
    }
    if (_restApi && [_restApi isKindOfClass:[NSString class]]) {
        self.restApi=_restApi;
    } else {
        self.restApi=@"http://thurmanp.dyndns.org:8080/pac";
    }
}

-(void)application:(UIApplication *)application performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    [self fetchConfig];
    completionHandler(UIBackgroundFetchResultNewData);
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    [[UIApplication sharedApplication] setMinimumBackgroundFetchInterval:60];
}

- (void)application:(UIApplication*)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData*)deviceToken {
    
    NSString *tokenStr = [deviceToken description];
    NSString *pushToken = [[[tokenStr
                              stringByReplacingOccurrencesOfString:@"<" withString:@""]
                             stringByReplacingOccurrencesOfString:@">" withString:@""]
                            stringByReplacingOccurrencesOfString:@" " withString:@""];
    
    // Save the token to server
    NSURL *_url =[NSURL URLWithString:self.restApi];
    
    NSString *urlStr = [NSString stringWithFormat:@"http://%@:8080/pushassociations", [_url host]];
    NSURL *url = [NSURL URLWithString:urlStr];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    
    [req setHTTPMethod:@"POST"];
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-type"];
    NSDictionary *payload = [NSDictionary dictionaryWithObjectsAndKeys:self.userName,@"user",@"ios", @"type",pushToken,@"token", nil];
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
    
    [req setHTTPBody:jsonData];
    //(void)[[NSURLConnection alloc] initWithRequest:req delegate:nil];
    [NSURLConnection sendAsynchronousRequest:req
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response,
                                               NSData *data, NSError *connectionError)
     {
         if (connectionError != nil)
         {
             //if notification registration fails, revert to background fetch every 60s
             [[UIApplication sharedApplication] setMinimumBackgroundFetchInterval:60];
         }
     }];
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    DDLogInfo(@"Got remote notification: %@",userInfo);
    [self fetchConfig];
    completionHandler(UIBackgroundFetchResultNewData);
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Configure our logging framework.
	// To keep things simple and fast, we're just going to log to the Xcode console.
    
    [DDLog addLogger:[DDTTYLogger sharedInstance]];
    [DDLog addLogger:[DDASLLogger sharedInstance]];
    // setup the text view logger
    UITextViewLogger *textViewLogger = [UITextViewLogger new];
    textViewLogger.autoScrollsToBottom = YES;
    // only log INFO messages to this textViewLogger
    [DDLog addLogger:textViewLogger withLogLevel:LOG_FLAG_INFO];
    
    RoamingProxyViewController *myviewController = self.viewController;
    myviewController.viewDidLoadBlock = ^(RoamingProxyViewController *_viewController) {
        textViewLogger.textView = _viewController.textView;
    };
    DDLogInfo(@"Starting app");
    // Add the view controller's view to the window and display.
    [window addSubview:myviewController.view];
    [window makeKeyAndVisible];
    
    [self readDefaultsValues];
    
    [self fetchConfig];
    
    // don't initially schedule any background fetch, let's try notifications first
    [[UIApplication sharedApplication] setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalNever];
    
    [[UIApplication sharedApplication] registerForRemoteNotificationTypes:
     (UIRemoteNotificationTypeBadge |UIRemoteNotificationTypeSound |UIRemoteNotificationTypeAlert)];
    
	
	// Create server using our custom MyHTTPServer class
	httpServer = [[HTTPServer alloc] init];
    DDLogInfo(@"server created");
	// Tell the server to broadcast its presence via Bonjour.
	// This allows browsers such as Safari to automatically discover our service.
	[httpServer setType:@"_http._tcp."];
	
	// Normally there's no need to run our server on any specific port.
	// Technologies like Bonjour allow clients to dynamically discover the server's port at runtime.
	// However, for easy testing you may want force a certain port so you can just hit the refresh button.
	[httpServer setPort:8080];
    
    [MyHTTPConnection setReplacementDict:[[NSDictionary alloc] init]];
    
    [httpServer setConnectionClass:[MyHTTPConnection class]];
	
	// Serve files from our embedded Web folder
	//NSString *webPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Web"];
    NSString *webPath = [[NSBundle mainBundle] resourcePath];
	DDLogInfo(@"Setting document root: %@", webPath);
	
    DDLogInfo(@"Starting server");
	[httpServer setDocumentRoot:webPath];
	
	// Start the server (and check for problems)
	
	NSError *error;
	if(![httpServer start:&error])
	{
		DDLogError(@"Error starting HTTP Server: %@", error);
	}
    [self continuousServer];
    DDLogInfo(@"Started server");
    return YES;
}


// Uncomment the following to disable continuous server
- (void)applicationWillResignActive:(UIApplication *)application
{
    DDLogInfo(@"Resigning");
    [self continuousServer];
    
    // or run server for ~1 s
    //  [self tempServer];
}
- (void)applicationDidBecomeActive:(UIApplication *)application
{
    /*
     Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
     */
    
    DDLogDebug(@"App becomes active");
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    DDLogDebug(@"Entered background");
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    DDLogDebug(@"Entered foreground");
    /*
     Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
     */
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    /*
     Called when the application is about to terminate.
     Save data if appropriate.
     See also applicationDidEnterBackground:.
     */
    DDLogInfo(@"App terminates");
}

- (void) continuousServer
{
    UIApplication*    app = [UIApplication sharedApplication];
    
    bgTask = [app beginBackgroundTaskWithExpirationHandler:^{
        // Clean up any unfinished task business by marking where you.
        // stopped or ending the task outright.
        [app endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
    
    // Start the long-running task and return immediately.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        audioPlayer = [[MTAudioPlayer alloc]init];
        [audioPlayer playBackgroundAudio];
        
        // Must comment out or else will stop server
        // [app endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    });
}

- (void) tempServer
{
    audioPlayer = [[MTAudioPlayer alloc]init];
    [audioPlayer playBackgroundAudio];
}

- (BOOL)isRoaming
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *error;
    NSString *carrierPListPath = [fm destinationOfSymbolicLinkAtPath:carrierPListSymLinkPath error:&error];
    NSString *operatorPListPath = [fm destinationOfSymbolicLinkAtPath:operatorPListSymLinkPath error:&error];
    return (![operatorPListPath isEqualToString:carrierPListPath]);
}

- (void)fetchConfig;
{
    NSString *urlFormat = [NSString stringWithFormat:@"%@/%@",restApi,userName];
    NSURL *url = [NSURL URLWithString:urlFormat];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    [NSURLConnection sendAsynchronousRequest:request
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response,
                                               NSData *data, NSError *connectionError)
     {
         if (data.length > 0 && connectionError == nil)
         {
             NSDictionary *payload = [NSJSONSerialization JSONObjectWithData:data
                                                                     options:0
                                                                       error:NULL];
             NSString *block = [payload objectForKey:@"block"];
             NSArray *objects = [payload objectForKey:@"hosts"];
             NSMutableArray *wrappedObjects = [[NSMutableArray alloc] init];
             
             [objects enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop){
                 NSString *elem = (NSString *)obj;
                 [wrappedObjects addObject:[NSString stringWithFormat:@"\"%@\"",elem]];
                 stop=FALSE;
             }];
             NSString *value = [ wrappedObjects componentsJoinedByString:@","];
             [MyHTTPConnection setReplacementDict:[NSDictionary dictionaryWithObject:value forKey:@"userConfig"]];
             [MyHTTPConnection setBlockPolicy:[block isEqualToString:@"block"]];
         }
     }];
}

+ (NetworkStatus)checkNetworkStatus {
    // called after network status changes
    Reachability *internetReachable = [Reachability reachabilityForInternetConnection];
    NetworkStatus internetStatus = [internetReachable currentReachabilityStatus];
    switch (internetStatus)
    {
        case NotReachable:
        {
            DDLogDebug(@"The internet is down.");
            break;
        }
        case ReachableViaWiFi:
        {
            DDLogDebug(@"The internet is working via WIFI");
            break;
        }
        case ReachableViaWWAN:
        {
            DDLogDebug(@"The internet is working via WWAN!");
            break;
        }
    }
    return internetStatus;
}
@end
