#import "RNAdvancedWebView.h"
#import "UIWebView+AccessoryHiding.h"
#import "RCTUIManager.h"

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
 
    if (self.messagingEnabled) {

        // See isNative in lodash
        NSString *testPostMessageNative = @"String(window.postMessage) === String(Object.hasOwnProperty).replace('hasOwnProperty', 'postMessage')";
        BOOL postMessageIsNative = [
                                    [webView stringByEvaluatingJavaScriptFromString:testPostMessageNative]
                                    isEqualToString:@"true"
                                    ];
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
                            "})();", RCTJSNavigationScheme, @"postMessage"
                            ];
        [webView stringByEvaluatingJavaScriptFromString:source];

        self.messagingEnabled = NO;
    }
    
    if (_initialJavaScript != nil) {
        [webView stringByEvaluatingJavaScriptFromString:_initialJavaScript];
    }
}

- (UIImage *)takeSnapshot:(CGRect)rect
{
    CGFloat scale = [UIScreen mainScreen].scale;
    CGSize boundsSize = _webView.bounds.size;
    CGFloat boundsWidth = boundsSize.width;
    CGFloat boundsHeight = boundsSize.height;
    CGSize contentSize = _webView.scrollView.contentSize;
    CGFloat contentHeight = contentSize.height;
    CGPoint offset = _webView.scrollView.contentOffset;
    
    [_webView.scrollView setContentOffset:CGPointMake(0, 0)];
    
    NSMutableArray *images = [NSMutableArray array];
    while (contentHeight > 0) {
        UIGraphicsBeginImageContextWithOptions(boundsSize, NO, 0.0);
        [_webView.layer renderInContext:UIGraphicsGetCurrentContext()];
        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        [images addObject:image];
        
        CGFloat offsetY = _webView.scrollView.contentOffset.y;
        [_webView.scrollView setContentOffset:CGPointMake(0, offsetY + boundsHeight)];
        contentHeight -= boundsHeight;
    }
    
    [_webView.scrollView setContentOffset:offset];
    
    CGSize imageSize = CGSizeMake(contentSize.width * scale,
                                  contentSize.height * scale);
    UIGraphicsBeginImageContext(imageSize);
    [images enumerateObjectsUsingBlock:^(UIImage *image, NSUInteger idx, BOOL *stop) {
        [image drawInRect:CGRectMake(0,
                                     scale * boundsHeight * idx,
                                     scale * boundsWidth,
                                     scale * boundsHeight)];
    }];
    UIImage *fullImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return fullImage;
}


@end
