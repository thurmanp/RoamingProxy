#import <UIKit/UIKit.h>

@class RoamingProxyViewController;
typedef void(^viewDidLoadBlock_t)(RoamingProxyViewController *viewController);

@interface RoamingProxyViewController : UIViewController {
}

/// Text view for logging.
@property (weak, nonatomic) IBOutlet UITextView *textView;

/// The block is called when the view controller's view is loaded.
@property (copy, nonatomic) viewDidLoadBlock_t viewDidLoadBlock;


@end

