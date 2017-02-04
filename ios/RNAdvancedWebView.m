
#import "RNAdvancedWebView.h"

@implementation RNAdvancedWebView
{
    NSString *_initialJavaScript;
    UIWebView *_webView;
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    _webView = webView;
    if (_initialJavaScript != nil) {
        [webView stringByEvaluatingJavaScriptFromString:_initialJavaScript];
    }
}

- (NSString *)evaluateJavaScript:(NSString*)script
{
    return [_webView stringByEvaluatingJavaScriptFromString: script];
}

@end
