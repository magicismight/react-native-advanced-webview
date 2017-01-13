
#import "RNAdvancedWebViewManager.h"
#import "RNAdvancedWebView.h"

@implementation RNAdvancedWebViewManager

RCT_EXPORT_MODULE()

- (UIView *)view
{
    RNAdvancedWebView *webView = [RNAdvancedWebView new];
    webView.delegate = self;
    return webView;
}

RCT_EXPORT_VIEW_PROPERTY(initialJavaScript, NSString)

@end

