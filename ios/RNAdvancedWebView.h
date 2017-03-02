#import <React/RCTWebView.h>

@interface RNAdvancedWebView : RCTWebView

@property (nonatomic, copy) NSString *initialJavaScript;
@property (nonatomic, assign) BOOL enableMessageOnLoadStart;
@property (nonatomic, assign) BOOL hideAccessory;

- (NSString *)evaluateJavaScript:(NSString *)script;

@end
