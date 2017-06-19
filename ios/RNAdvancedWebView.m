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
    
    SEL baseEvent = NSSelectorFromString(@"baseEvent");
    if (![self respondsToSelector:baseEvent]) {
        return;
    }
    
    RCTDirectEventBlock onLoadingFinish = (RCTDirectEventBlock)[self valueForKey:@"onLoadingFinish"];
    if (!onLoadingFinish) {
        return;
    }
    
    NSString *injectedJavaScript = (NSString *)[self valueForKey:@"_injectedJavaScript"];
    if (injectedJavaScript && [injectedJavaScript isKindOfClass:[NSString class]]) {
        NSString *jsEvaluationValue = [webView stringByEvaluatingJavaScriptFromString:injectedJavaScript];
        NSMutableDictionary<NSString *, id> *event = [self performSelector:baseEvent];
        event[@"jsEvaluationValue"] = jsEvaluationValue;
        onLoadingFinish(event);
    }
    // we only need the final 'finishLoad' call so only fire the event when we're actually done loading.
    else if (!webView.loading && ![webView.request.URL.absoluteString isEqualToString:@"about:blank"]) {
        onLoadingFinish([self performSelector:baseEvent]);
    }
}


@end
