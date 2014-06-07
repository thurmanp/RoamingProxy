#import <Foundation/Foundation.h>
#import "HTTPConnection.h"
#import "Reachability.h"

@interface MyHTTPConnection : HTTPConnection

+(void)setReplacementDict:(NSDictionary *)dict;
+(void)setBlockPolicy:(BOOL)block;
@end
