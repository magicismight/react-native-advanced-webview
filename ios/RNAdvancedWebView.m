#import "RNAdvancedWebView.h"
#import "UIWebView+AccessoryHiding.h"

@implementation RNAdvancedWebView
{
    NSString *_initialJavaScript;
    UIWebView *_webView;
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    if (!_webView) {
        _webView = webView;
        
        if (_hideAccessory) {
            [webView setHackishlyHidesInputAccessoryView:YES];
        }
    }
 
    if (self.messagingEnabled && _enableMessageOnLoadStart) {

        // See isNative in lodash
        NSString *testPostMessageNative = @"String(window.postMessage) === String(Object.hasOwnProperty).replace('hasOwnProperty', 'postMessage')";
        BOOL postMessageIsNative = [
                                    [webView stringByEvaluatingJavaScriptFromString:testPostMessageNative]
                                    isEqualToString:@"true"
                                    ];
        NSString *source = [NSString stringWithFormat:
                            @"window.originalPostMessage = window.postMessage;"
                            "window.postMessage = function(data) {"
                            "window.location = '%@://%@?' + encodeURIComponent(String(data));"
                            "};"
                            "window.postMessage.toString = function () {"
                            "return String(Object.hasOwnProperty).replace('hasOwnProperty', 'postMessage');"
                            "};", RCTJSNavigationScheme, @"postMessage"
                            ];
        [webView stringByEvaluatingJavaScriptFromString:source];

       
    }
    
    if (_initialJavaScript != nil) {
        [webView stringByEvaluatingJavaScriptFromString:_initialJavaScript];
    }
}

- (NSString *)evaluateJavaScript:(NSString*)script
{
    return [_webView stringByEvaluatingJavaScriptFromString: script];
}

@end
