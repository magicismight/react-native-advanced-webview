#import "RNAdvancedWebView.h"
#import "UIWebView+AccessoryHiding.h"
#import <React/RCTUIManager.h>

NSString *const RNAdvancedWebJSNavigationScheme = @"react-js-navigation";
NSString *const RNAdvancedWebViewJSPostMessageHost = @"postMessage";

@implementation RNAdvancedWebView

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    if (_hideAccessory) {
        [webView setHackishlyHidesInputAccessoryView:YES];
    }
    
    [webView setKeyboardDisplayRequiresUserAction:_keyboardDisplayRequiresUserAction];
}

- (void)setSource:(NSDictionary *)source
{
    // Decode query string and hash in local file path
    NSString *URLString = source[@"uri"] ?: source[@"url"];
    if ([URLString hasPrefix:@"/"] || [URLString hasPrefix:@"file:///"]) {
        source = @{
                   @"uri": [URLString stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding]
                   };
    }
    
    [super setSource:source];
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"

- (NSMutableDictionary<NSString *, id> *)getBaseEvent
{
    SEL selector = NSSelectorFromString(@"baseEvent");
    if ([self respondsToSelector:selector]) {
        return [self performSelector:selector];
    }
    return nil;
}

#pragma clang diagnostic pop

- (RCTDirectEventBlock)getEventBlock:(NSString *)key
{
    return (RCTDirectEventBlock)[self valueForKey:key];
}

#pragma mark - UIWebViewDelegate methods

- (BOOL)webView:(__unused UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request
 navigationType:(UIWebViewNavigationType)navigationType
{
    BOOL isJSNavigation = [request.URL.scheme isEqualToString:RNAdvancedWebJSNavigationScheme];
    
    static NSDictionary<NSNumber *, NSString *> *navigationTypes;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        navigationTypes = @{
                            @(UIWebViewNavigationTypeLinkClicked): @"click",
                            @(UIWebViewNavigationTypeFormSubmitted): @"formsubmit",
                            @(UIWebViewNavigationTypeBackForward): @"backforward",
                            @(UIWebViewNavigationTypeReload): @"reload",
                            @(UIWebViewNavigationTypeFormResubmitted): @"formresubmit",
                            @(UIWebViewNavigationTypeOther): @"other",
                            };
    });
    
    
    RCTDirectEventBlock onShouldStartLoadWithRequest = [self getEventBlock:@"onShouldStartLoadWithRequest"];
    // skip this for the JS Navigation handler
    
    if (!isJSNavigation && onShouldStartLoadWithRequest) {
        NSMutableDictionary<NSString *, id> *event = [self getBaseEvent];
        [event addEntriesFromDictionary: @{
                                           @"url": (request.URL).absoluteString,
                                           @"navigationType": navigationTypes[@(navigationType)]
                                           }];
        if (![self.delegate webView:self
          shouldStartLoadForRequest:event
                       withCallback:onShouldStartLoadWithRequest]) {
            return NO;
        }
    }
    
    
    RCTDirectEventBlock onLoadingStart = [self getEventBlock:@"onLoadingStart"];
    if (!isJSNavigation && onLoadingStart) {
        // We have this check to filter out iframe requests and whatnot
        BOOL isTopFrame = [request.URL isEqual:request.mainDocumentURL];
        if (isTopFrame) {
            NSMutableDictionary<NSString *, id> *event = [self getBaseEvent];
            [event addEntriesFromDictionary: @{
                                               @"url": (request.URL).absoluteString,
                                               @"navigationType": navigationTypes[@(navigationType)]
                                               }];
            onLoadingStart(event);
        }
    }
    
    RCTDirectEventBlock onMessage = [self getEventBlock:@"onMessage"];
    if (isJSNavigation && [request.URL.host isEqualToString:RNAdvancedWebViewJSPostMessageHost]) {
        NSString *data = request.URL.query;
        data = [data stringByReplacingOccurrencesOfString:@"+" withString:@" "];
        data = [data stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        
        NSMutableDictionary<NSString *, id> *event = [self getBaseEvent];
        [event addEntriesFromDictionary: @{
                                           @"data": data,
                                           }];
        onMessage(event);
    }
    
    // JS Navigation handler
    return !isJSNavigation;
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    if (self.messagingEnabled) {
#if RCT_DEV
        // See isNative in lodash
        NSString *testPostMessageNative = @"String(window.postMessage) === String(Object.hasOwnProperty).replace('hasOwnProperty', 'postMessage')";
        BOOL postMessageIsNative = [
                                    [webView stringByEvaluatingJavaScriptFromString:testPostMessageNative]
                                    isEqualToString:@"true"
                                    ];
        if (!postMessageIsNative) {
            RCTLogError(@"Setting onMessage on a WebView overrides existing values of window.postMessage, but a previous value was defined");
        }
#endif
        NSString *source = [NSString stringWithFormat:
                            @"(function() {"
                            "var messageStack = [];"
                            "var executing = false;"
                            "function executeStack() {"
                            "  var message = messageStack.shift();"
                            "  if (message) {"
                            "    executing = true;"
                            "    window.location = message;"
                            "    setTimeout(executeStack);"
                            "  } else {"
                            "    executing = false;"
                            "  }"
                            "};"
                            "window.originalPostMessage = window.postMessage;"
                            "window.postMessage = function(data) {"
                            "  messageStack.push('%@://%@?' + encodeURIComponent(String(data)));"
                            "  if (!executing) executeStack();"
                            "};"
                            "document.dispatchEvent(new CustomEvent('ReactNativeContextReady'));"
                            "})();", RNAdvancedWebJSNavigationScheme, RNAdvancedWebViewJSPostMessageHost
                            ];
        
        [webView stringByEvaluatingJavaScriptFromString:source];
    }
    
    RCTDirectEventBlock onLoadingFinish = [self getEventBlock:@"onLoadingFinish"];
    if (!onLoadingFinish) {
        return;
    }
    
    NSString *injectedJavaScript = (NSString *)[self valueForKey:@"_injectedJavaScript"];
    if (injectedJavaScript && [injectedJavaScript isKindOfClass:[NSString class]]) {
        NSString *jsEvaluationValue = [webView stringByEvaluatingJavaScriptFromString:injectedJavaScript];
        NSMutableDictionary<NSString *, id> *event = [self getBaseEvent];
        event[@"jsEvaluationValue"] = jsEvaluationValue;
        onLoadingFinish(event);
    }
    // we only need the final 'finishLoad' call so only fire the event when we're actually done loading.
    else if (!webView.loading && ![webView.request.URL.absoluteString isEqualToString:@"about:blank"]) {
        onLoadingFinish([self getBaseEvent]);
    }
}

@end
