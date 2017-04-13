#import "RNAdvancedWebViewManager.h"
#import "RNAdvancedWebView.h"

#import <React/RCTBridge.h>
#import <React/RCTUIManager.h>
#import <React/UIView+React.h>
#import <React/RCTUtils.h>


@interface RNAdvancedWebViewManager () <RNAdvancedWebViewDelegate>

@end

@implementation RNAdvancedWebViewManager
{
    NSConditionLock *_shouldStartLoadLock;
    BOOL _shouldStartLoad;
}

RCT_EXPORT_MODULE()

- (UIView *)view
{
    RNAdvancedWebView *webView = [RNAdvancedWebView new];
    webView.delegate = self;
    return webView;
}

RCT_EXPORT_VIEW_PROPERTY(source, NSDictionary)
RCT_REMAP_VIEW_PROPERTY(bounces, _webView.scrollView.bounces, BOOL)
RCT_REMAP_VIEW_PROPERTY(scrollEnabled, _webView.scrollView.scrollEnabled, BOOL)
RCT_REMAP_VIEW_PROPERTY(decelerationRate, _webView.scrollView.decelerationRate, CGFloat)
RCT_EXPORT_VIEW_PROPERTY(scalesPageToFit, BOOL)
RCT_EXPORT_VIEW_PROPERTY(messagingEnabled, BOOL)
RCT_EXPORT_VIEW_PROPERTY(injectedJavaScript, NSString)
RCT_EXPORT_VIEW_PROPERTY(contentInset, UIEdgeInsets)
RCT_EXPORT_VIEW_PROPERTY(automaticallyAdjustContentInsets, BOOL)
RCT_EXPORT_VIEW_PROPERTY(onLoadingStart, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onLoadingFinish, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onLoadingError, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onMessage, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onShouldStartLoadWithRequest, RCTDirectEventBlock)
RCT_REMAP_VIEW_PROPERTY(allowsInlineMediaPlayback, _webView.allowsInlineMediaPlayback, BOOL)
RCT_REMAP_VIEW_PROPERTY(mediaPlaybackRequiresUserAction, _webView.mediaPlaybackRequiresUserAction, BOOL)
RCT_REMAP_VIEW_PROPERTY(dataDetectorTypes, _webView.dataDetectorTypes, UIDataDetectorTypes)
RCT_EXPORT_VIEW_PROPERTY(hideAccessory, BOOL)
RCT_EXPORT_VIEW_PROPERTY(keyboardDisplayRequiresUserAction, BOOL)

RCT_EXPORT_METHOD(takeSnapshot:(id /* NSString or NSNumber */)target
                  withOptions:(NSDictionary *)options
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, UIView *> *viewRegistry) {
        
        // Get view
        UIView *view;
        if (target == nil || [target isEqual:@"window"]) {
            view = RCTKeyWindow();
        } else if ([target isKindOfClass:[NSNumber class]]) {
            view = viewRegistry[target];
            if (!view) {
                RCTLogError(@"No view found with reactTag: %@", target);
                return;
            } else if (![view isKindOfClass:[RNAdvancedWebView class]]) {
                RCTLogError(@"Can not call `takeSnapeshot` on a none `RNAdvancedWebView` view: %@", view);
                return;
            }
        }
        
        __weak RNAdvancedWebView *webview = view;
        
        // Get options
        CGRect rect = [RCTConvert CGRect:options];
        NSString *format = [RCTConvert NSString:options[@"format"] ?: @"png"];
        
        // Capture image
        if (rect.size.width < 0.1 || rect.size.height < 0.1) {
            rect = CGRectNull;
        }
        
        
        UIImage *image = [webview takeSnapshot:rect];
        
        
        if (!image) {
            reject(RCTErrorUnspecified, @"Failed to capture view snapshot.", nil);
            return;
        }
        
        // Convert image to data (on a background thread)
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            NSData *data;
            if ([format isEqualToString:@"png"]) {
                data = UIImagePNGRepresentation(image);
            } else if ([format isEqualToString:@"jpeg"]) {
                CGFloat quality = [RCTConvert CGFloat:options[@"quality"] ?: @1];
                data = UIImageJPEGRepresentation(image, quality);
            } else {
                RCTLogError(@"Unsupported image format: %@", format);
                return;
            }
            
            // Save to a temp file
            NSError *error = nil;
            NSString *tempFilePath = RCTTempFilePath(format, &error);
            if (tempFilePath) {
                if ([data writeToFile:tempFilePath options:(NSDataWritingOptions)0 error:&error]) {
                    resolve(tempFilePath);
                    return;
                }
            }
            
            // If we reached here, something went wrong
            reject(RCTErrorUnspecified, error.localizedDescription, error);
        });
    }];
}

RCT_EXPORT_METHOD(goBack:(nonnull NSNumber *)reactTag)
{
    [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, RNAdvancedWebView *> *viewRegistry) {
        RNAdvancedWebView *view = viewRegistry[reactTag];
        if (![view isKindOfClass:[RNAdvancedWebView class]]) {
            RCTLogError(@"Invalid view returned from registry, expecting RNAdvancedWebView, got: %@", view);
        } else {
            [view goBack];
        }
    }];
}

RCT_EXPORT_METHOD(goForward:(nonnull NSNumber *)reactTag)
{
    [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, UIView *> *viewRegistry) {
        id view = viewRegistry[reactTag];
        if (![view isKindOfClass:[RNAdvancedWebView class]]) {
            RCTLogError(@"Invalid view returned from registry, expecting RNAdvancedWebView, got: %@", view);
        } else {
            [view goForward];
        }
    }];
}

RCT_EXPORT_METHOD(reload:(nonnull NSNumber *)reactTag)
{
    [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, RNAdvancedWebView *> *viewRegistry) {
        RNAdvancedWebView *view = viewRegistry[reactTag];
        if (![view isKindOfClass:[RNAdvancedWebView class]]) {
            RCTLogError(@"Invalid view returned from registry, expecting RCTWebView, got: %@", view);
        } else {
            [view reload];
        }
    }];
}

RCT_EXPORT_METHOD(stopLoading:(nonnull NSNumber *)reactTag)
{
    [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, RNAdvancedWebView *> *viewRegistry) {
        RNAdvancedWebView *view = viewRegistry[reactTag];
        if (![view isKindOfClass:[RNAdvancedWebView class]]) {
            RCTLogError(@"Invalid view returned from registry, expecting RCTWebView, got: %@", view);
        } else {
            [view stopLoading];
        }
    }];
}

RCT_EXPORT_METHOD(postMessage:(nonnull NSNumber *)reactTag message:(NSString *)message)
{
    [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, RNAdvancedWebView *> *viewRegistry) {
        RNAdvancedWebView *view = viewRegistry[reactTag];
        if (![view isKindOfClass:[RNAdvancedWebView class]]) {
            RCTLogError(@"Invalid view returned from registry, expecting RNAdvancedWebView, got: %@", view);
        } else {
            [view postMessage:message];
        }
    }];
}

RCT_EXPORT_METHOD(injectJavaScript:(nonnull NSNumber *)reactTag script:(NSString *)script)
{
    [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, RNAdvancedWebView *> *viewRegistry) {
        RNAdvancedWebView *view = viewRegistry[reactTag];
        if (![view isKindOfClass:[RNAdvancedWebView class]]) {
            RCTLogError(@"Invalid view returned from registry, expecting RNAdvancedWebView, got: %@", view);
        } else {
            [view injectJavaScript:script];
        }
    }];
}

#pragma mark - Exported synchronous methods

- (BOOL)webView:(__unused RNAdvancedWebView *)webView
shouldStartLoadForRequest:(NSMutableDictionary<NSString *, id> *)request
   withCallback:(RCTDirectEventBlock)callback
{
    _shouldStartLoadLock = [[NSConditionLock alloc] initWithCondition:arc4random()];
    _shouldStartLoad = YES;
    request[@"lockIdentifier"] = @(_shouldStartLoadLock.condition);
    callback(request);
    
    // Block the main thread for a maximum of 250ms until the JS thread returns
    if ([_shouldStartLoadLock lockWhenCondition:0 beforeDate:[NSDate dateWithTimeIntervalSinceNow:.25]]) {
        BOOL returnValue = _shouldStartLoad;
        [_shouldStartLoadLock unlock];
        _shouldStartLoadLock = nil;
        return returnValue;
    } else {
        RCTLogWarn(@"Did not receive response to shouldStartLoad in time, defaulting to YES");
        return YES;
    }
}

RCT_EXPORT_METHOD(startLoadWithResult:(BOOL)result lockIdentifier:(NSInteger)lockIdentifier)
{
    if ([_shouldStartLoadLock tryLockWhenCondition:lockIdentifier]) {
        _shouldStartLoad = result;
        [_shouldStartLoadLock unlockWithCondition:0];
    } else {
        RCTLogWarn(@"startLoadWithResult invoked with invalid lockIdentifier: "
                   "got %zd, expected %zd", lockIdentifier, _shouldStartLoadLock.condition);
    }
}

@end


