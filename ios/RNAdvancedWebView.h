#import <React/RCTWebView.h>

@interface RNAdvancedWebView : RCTWebView

@property (nonatomic, copy) NSString *initialJavaScript;

- (NSString *)evaluateJavaScript:(NSString *)script;

@end
