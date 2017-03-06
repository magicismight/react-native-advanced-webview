
#import "RNAdvancedWebViewManager.h"
#import "RNAdvancedWebView.h"
#import <React/RCTBridge.h>
#import <React/RCTUIManager.h>
#import <React/RCTUtils.h>

@implementation RNAdvancedWebViewManager

RCT_EXPORT_MODULE()

- (UIView *)view
{
    RNAdvancedWebView *webView = [RNAdvancedWebView new];
    webView.delegate = self;
    return webView;
}

RCT_EXPORT_VIEW_PROPERTY(initialJavaScript, NSString)
RCT_EXPORT_VIEW_PROPERTY(enableMessageOnLoadStart, BOOL)
RCT_EXPORT_VIEW_PROPERTY(hideAccessory, BOOL)

@end

