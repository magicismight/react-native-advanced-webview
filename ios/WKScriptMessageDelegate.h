
#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

// Trampoline object to avoid retain cycle with the script message handler
@interface WKScriptMessageDelegate : NSObject<WKScriptMessageHandler>

@property (nonatomic, weak) id<WKScriptMessageHandler> scriptDelegate;

- (instancetype)initWithDelegate:(id<WKScriptMessageHandler>)scriptDelegate;

@end

