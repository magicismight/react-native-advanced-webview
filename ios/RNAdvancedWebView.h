#import <React/RCTWebView.h>

@interface RNAdvancedWebView : RCTWebView

@property (nonatomic, copy) NSString *initialJavaScript;
@property (nonatomic, assign) BOOL enableMessageOnLoadStart;

- (NSString *)evaluateJavaScript:(NSString *)script;

@end
