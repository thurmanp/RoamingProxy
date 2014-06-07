#import <UIKit/UIKit.h>
#import <CoreTelephony/CTCarrier.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import "MTAudioPlayer.h"
#import "Reachability.h"

@class RoamingProxyViewController;
@class HTTPServer;

@interface RoamingProxyAppDelegate : NSObject <UIApplicationDelegate>
{
	HTTPServer *httpServer;
    MTAudioPlayer * audioPlayer;
	
	UIWindow *window;
	RoamingProxyViewController *viewController;
    
    UIBackgroundTaskIdentifier bgTask;
}

@property (nonatomic, retain) HTTPServer *httpServer;
@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet RoamingProxyViewController *viewController;
@property (strong, nonatomic) NSString *userConfig;
@property (strong, nonatomic) NSString *userName;
@property (strong, nonatomic) NSString *restApi;

+ (NetworkStatus)checkNetworkStatus;
@end

