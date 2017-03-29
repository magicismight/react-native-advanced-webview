#import <React/RCTWebView.h>

@interface RNAdvancedWebView : RCTWebView

@property (nonatomic, copy) NSString *initialJavaScript;
@property (nonatomic, assign) BOOL hideAccessory;
@property (nonatomic, assign) BOOL keyboardDisplayRequiresUserAction;

- (UIImage *)takeSnapshot:(CGRect)rect;

@end
