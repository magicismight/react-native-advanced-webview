#import "RNAdvancedWebView.h"
#import "UIWebView+AccessoryHiding.h"
#import "RCTUIManager.h"

NSString *const RNAdvancedWebJSNavigationScheme = @"react-js-navigation";
NSString *const RNAdvancedWebViewJSPostMessageHost = @"postMessage";

@implementation RNAdvancedWebView
{
    NSString *_initialJavaScript;
    UIWebView *_webView;
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    if (_hideAccessory) {
        [webView setHackishlyHidesInputAccessoryView:YES];
    }
    
    [_webView setKeyboardDisplayRequiresUserAction:_keyboardDisplayRequiresUserAction];
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
                            "window.postMessage.toString = function () {"
                            "return String(Object.hasOwnProperty).replace('hasOwnProperty', 'postMessage');"
                            "};"
                            "})();", RNAdvancedWebJSNavigationScheme, RNAdvancedWebViewJSPostMessageHost
                            ];

        [webView stringByEvaluatingJavaScriptFromString:source];
    }
    
    NSString *injectedJavaScript = (NSString *)[self valueForKey:@"_injectedJavaScript"];
    RCTDirectEventBlock onLoadingFinish = (RCTDirectEventBlock)[self valueForKey:@"onLoadingFinish"];
    
    if (injectedJavaScript != nil && [injectedJavaScript isKindOfClass:[NSString class]]) {
        NSString *jsEvaluationValue = [webView stringByEvaluatingJavaScriptFromString:injectedJavaScript];
        
        NSMutableDictionary<NSString *, id> *event = [self performSelector:@selector(baseEvent)];
        event[@"jsEvaluationValue"] = jsEvaluationValue;
        
        
        RCTDirectEventBlock onLoadingFinish = (RCTDirectEventBlock)[self valueForKey:@"onLoadingFinish"];
        onLoadingFinish(event);
    }
    // we only need the final 'finishLoad' call so only fire the event when we're actually done loading.
    else if (onLoadingFinish && !webView.loading && ![webView.request.URL.absoluteString isEqualToString:@"about:blank"]) {
        onLoadingFinish([self performSelector:@selector(baseEvent)]);
    }
}


@end
