#import <React/RCTWebView.h>

@interface RNAdvancedWebView : RCTWebView

@property (nonatomic, copy) NSString *initialJavaScript;
@property (nonatomic, assign) BOOL enableMessageOnLoadStart;
@property (nonatomic, assign) BOOL hideAccessory;

- (UIImage *)takeSnapshot:(CGRect)rect;

@end
