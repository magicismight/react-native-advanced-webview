
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

RCT_REMAP_METHOD(evaluateJavaScript, evaluateJavaScript:(nonnull NSNumber *)reactTag script:(nonnull NSString *)script resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
    [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, RCTWebView *> *viewRegistry) {
        RNAdvancedWebView *view = viewRegistry[reactTag];
        if (![view isKindOfClass:[RCTWebView class]]) {
            RCTLogError(@"Invalid view returned from registry, expecting RCTWebView, got: %@", view);
            return;
        }
        
        NSString *result = [view evaluateJavaScript: script];
        if (result && [result length] > 0) {
            resolve(result);
        } else {
            reject(RCTErrorUnspecified, @"Error evaluating script.", nil);
        }
    }];
}

@end

