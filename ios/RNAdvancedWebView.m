
#import "RNAdvancedWebView.h"

@implementation RNAdvancedWebView
{
    NSString *_initialJavaScript;
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    if (_initialJavaScript != nil) {
        [webView stringByEvaluatingJavaScriptFromString:_initialJavaScript];
    }
}

@end
