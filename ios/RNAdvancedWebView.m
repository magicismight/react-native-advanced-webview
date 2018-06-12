#import "RNAdvancedWebView.h"
#import <React/RCTUIManager.h>
#import "RNAdvancedWebView.h"
#import <UIKit/UIScrollView.h>

#import <UIKit/UIKit.h>

#import <React/RCTAutoInsetsProtocol.h>
#import <React/RCTConvert.h>
#import <React/RCTEventDispatcher.h>
#import <React/RCTLog.h>
#import <React/RCTUtils.h>
#import <React/RCTView.h>
#import <React/UIView+React.h>

#import <objc/runtime.h>

#import <UIKit/UIPasteboard.h>
#import <MobileCoreServices/UTCoreTypes.h>

NSString *const RNAdvancedWebJSNavigationScheme = @"react-js-navigation";
NSString *const RNAdvancedWebViewJSPostMessageHost = @"postMessage";
NSString *const RNAdvancedWebViewJSDataTransferSetHost = @"dataTransferSet";
NSString *const RNAdvancedWebViewHtmlType = @"Apple Web Archive pasteboard type";
// runtime trick to remove WKWebView keyboard default toolbar
// see: http://stackoverflow.com/questions/19033292/ios-7-uiwebview-keyboard-issue/19042279#19042279
@interface _SwizzleHelperWK : NSObject
@end

@implementation _SwizzleHelperWK

-(id)inputAccessoryView
{
    return nil;
}

@end


@interface RNAdvancedWebView () <WKNavigationDelegate, RCTAutoInsetsProtocol, WKUIDelegate, UIScrollViewDelegate>

@property (nonatomic, copy) RCTDirectEventBlock onLoadingStart;
@property (nonatomic, copy) RCTDirectEventBlock onLoadingFinish;
@property (nonatomic, copy) RCTDirectEventBlock onLoadingError;
@property (nonatomic, copy) RCTDirectEventBlock onShouldStartLoadWithRequest;
@property (nonatomic, copy) RCTDirectEventBlock onProgress;
@property (nonatomic, copy) RCTDirectEventBlock onMessage;
@property (assign) BOOL sendCookies;

@end

@implementation RNAdvancedWebView
{
    WKWebView *_webView;
    NSString *_injectedJavaScript;
    CGPoint _originOffset;
    BOOL _navigationFinished;
    NSMutableArray <NSString *>* _pendingMessages;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _hideAccessory = NO;
        _keyboardDisplayRequiresUserAction = NO;
        _contentInsetAdjustmentBehavior = 0;
        _validSchemes = @[@"http", @"https", @"file", @"ftp", @"ws"];
        
        _pendingMessages = [[NSMutableArray alloc] init];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(keyboardWillChange:)
                                                     name:UIKeyboardWillChangeFrameNotification object:nil];
    }
    return self;
}

RCT_NOT_IMPLEMENTED(- (instancetype)initWithCoder:(NSCoder *)aDecoder)

- (instancetype)initWithProcessPool:(WKProcessPool *)processPool
{
    if(self = [self initWithFrame:CGRectZero])
    {
        super.backgroundColor = [UIColor clearColor];
        
        _automaticallyAdjustContentInsets = YES;
        _contentInset = UIEdgeInsetsZero;
        
        WKWebViewConfiguration* config = [[WKWebViewConfiguration alloc] init];
        config.processPool = processPool;
        @try {
            [config setValue:[NSNumber numberWithBool:YES] forKey:@"allowUniversalAccessFromFileURLs"];
        } @catch (NSException *exception) {
            NSLog(@"%@", exception);
        }
        
        WKPreferences *preferences = [[WKPreferences alloc] init];
        @try {
            [preferences setValue:[NSNumber numberWithBool:YES] forKey:@"allowFileAccessFromFileURLs"];
        } @catch (NSException *exception) {
            NSLog(@"%@", exception);
        }
        
        config.preferences = preferences;
        
        _webView = [[WKWebView alloc] initWithFrame:self.bounds configuration:config];
        _webView.UIDelegate = self;
        _webView.navigationDelegate = self;
        
        [_webView addObserver:self forKeyPath:@"estimatedProgress" options:NSKeyValueObservingOptionNew context:nil];
        [_webView.scrollView addObserver:self forKeyPath:@"contentInset" options:NSKeyValueObservingOptionNew context:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(pasteboardChangedNotification:)
                                                     name:UIPasteboardChangedNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(pasteboardChangedNotification:)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:nil];
        [self injectDataTransferGetData];
        [self addSubview:_webView];
    }
    return self;
}

- (void)loadRequest:(NSURLRequest *)request
{
    _navigationFinished = NO;
    if (request.URL && _sendCookies) {
        NSDictionary *cookies = [NSHTTPCookie requestHeaderFieldsWithCookies:[[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:request.URL]];
        if ([cookies objectForKey:@"Cookie"]) {
            NSMutableURLRequest *mutableRequest = request.mutableCopy;
            [mutableRequest addValue:cookies[@"Cookie"] forHTTPHeaderField:@"Cookie"];
            request = mutableRequest;
        }
    }
    [_webView loadRequest:request];
}

- (void)goForward
{
    _navigationFinished = NO;
    [_webView goForward];
}

- (void)evaluateJavaScript:(NSString *)javaScriptString
         completionHandler:(void (^)(id, NSError *error))completionHandler
{
    [_webView evaluateJavaScript:javaScriptString completionHandler:completionHandler];
}

- (void)goBack
{
    _navigationFinished = NO;
    [_webView goBack];
}

- (BOOL)canGoBack
{
    return [_webView canGoBack];
}

- (BOOL)canGoForward
{
    return [_webView canGoForward];
}

- (void)reload
{
    _navigationFinished = NO;
    NSURLRequest *request = [RCTConvert NSURLRequest:self.source];
    if (request.URL && !_webView.URL.absoluteString.length) {
        [self loadRequest:request];
    } else {
        [_webView reload];
    }
}

- (void)stopLoading
{
    _navigationFinished = NO;
    [_webView stopLoading];
}

- (void)postMessage:(NSString *)message
{
    if (_navigationFinished) {
        NSDictionary *eventInitDict = @{
                                        @"data": message,
                                        };
        NSString *source = [NSString
                            stringWithFormat:@"document.dispatchEvent(new MessageEvent('message', %@));",
                            RCTJSONStringify(eventInitDict, NULL)
                            ];
        [_webView evaluateJavaScript:source completionHandler:nil];
    } else {
        [_pendingMessages addObject:message];
    }

}

- (void)injectJavaScript:(NSString *)script
{
    [_webView evaluateJavaScript:script completionHandler:nil];
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
    if (![_source isEqualToDictionary:source]) {
        _source = [source copy];
        _sendCookies = [source[@"sendCookies"] boolValue];
        if ([source[@"customUserAgent"] length] != 0 && [_webView respondsToSelector:@selector(setCustomUserAgent:)]) {
            [_webView setCustomUserAgent:source[@"customUserAgent"]];
        }
        
        // Allow loading local files:
        // <WKWebView source={{ file: RNFS.MainBundlePath + '/data/index.html', allowingReadAccessToURL: RNFS.MainBundlePath }} />
        // Only works for iOS 9+. So iOS 8 will simply ignore those two values
        NSString *file = [RCTConvert NSString:source[@"file"]];
        NSString *allowingReadAccessToURL = [RCTConvert NSString:source[@"allowingReadAccessToURL"]];
        
        if (file && [_webView respondsToSelector:@selector(loadFileURL:allowingReadAccessToURL:)]) {
            NSURL *fileURL = [RCTConvert NSURL:file];
            NSURL *baseURL = [RCTConvert NSURL:allowingReadAccessToURL];
            [_webView loadFileURL:fileURL allowingReadAccessToURL:baseURL];
            return;
        }
        
        // Check for a static html source first
        NSString *html = [RCTConvert NSString:source[@"html"]];
        if (html) {
            NSURL *baseURL = [RCTConvert NSURL:source[@"baseUrl"]];
            if (!baseURL) {
                baseURL = [NSURL URLWithString:@"about:blank"];
            }
            [_webView loadHTMLString:html baseURL:baseURL];
            return;
        }
        
        NSURLRequest *request = [RCTConvert NSURLRequest:source];
        
        // Because of the way React works, as pages redirect, we actually end up
        // passing the redirect urls back here, so we ignore them if trying to load
        // the same url. We'll expose a call to 'reload' to allow a user to load
        // the existing page.
        if ([request.URL isEqual:_webView.URL]) {
            return;
        }
        if (!request.URL) {
            // Clear the webview
            [_webView loadHTMLString:@"" baseURL:nil];
            return;
        }
        [self loadRequest:request];
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    _webView.frame = self.bounds;
}

- (void)setContentInset:(UIEdgeInsets)contentInset
{
    _contentInset = contentInset;
    [RCTView autoAdjustInsetsForView:self
                      withScrollView:_webView.scrollView
                        updateOffset:NO];
}

- (void)setContentInsetAdjustmentBehavior:(NSInteger)contentInsetAdjustmentBehavior
{
    if (_contentInsetAdjustmentBehavior == contentInsetAdjustmentBehavior) {
        return;
    }
    _contentInsetAdjustmentBehavior = contentInsetAdjustmentBehavior;
    if (@available(iOS 11.0, *)) {
        _webView.scrollView.contentInsetAdjustmentBehavior = (UIScrollViewContentInsetAdjustmentBehavior)_contentInsetAdjustmentBehavior;
    }
}

- (void)setBackgroundColor:(UIColor *)backgroundColor
{
    CGFloat alpha = CGColorGetAlpha(backgroundColor.CGColor);
    self.opaque = _webView.opaque = _webView.scrollView.opaque = (alpha == 1.0);
    _webView.backgroundColor = _webView.scrollView.backgroundColor = backgroundColor;
}

- (UIColor *)backgroundColor
{
    return _webView.backgroundColor;
}

- (NSMutableDictionary<NSString *, id> *)baseEvent
{
    NSMutableDictionary<NSString *, id> *event = [[NSMutableDictionary alloc] initWithDictionary:@{
                                                                                                   @"url": _webView.URL.absoluteString ?: @"",
                                                                                                   @"loading" : @(_webView.loading),
                                                                                                   @"title": _webView.title,
                                                                                                   @"canGoBack": @(_webView.canGoBack),
                                                                                                   @"canGoForward" : @(_webView.canGoForward),
                                                                                                   }];
    return event;
}

- (void)refreshContentInset
{
    [RCTView autoAdjustInsetsForView:self
                      withScrollView:_webView.scrollView
                        updateOffset:YES];
}

- (void)dealloc
{
    _webView.scrollView.delegate = nil;
    _webView.UIDelegate = nil;
    _webView.navigationDelegate = nil;
    [_webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"about:blank"]]];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    @try {
        [_webView removeObserver:self forKeyPath:@"estimatedProgress"];
        [_webView.scrollView removeObserver:self forKeyPath:@"contentInset"];
    }
    @catch (NSException * __unused exception) {}
    _webView = nil;
}

#pragma mark - NSKeyValueObserving

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if ([keyPath isEqualToString:@"estimatedProgress"]) {
        if (_onProgress) {
            _onProgress(@{@"progress": [change objectForKey:NSKeyValueChangeNewKey]});
        }
    } else if ([keyPath isEqualToString:@"contentInset"]) {
        if (!_automaticallyAdjustContentInsets) {
            NSValue *value = [change objectForKey:NSKeyValueChangeNewKey];
            UIEdgeInsets contentInset = value.UIEdgeInsetsValue;
            if (!UIEdgeInsetsEqualToEdgeInsets(_contentInset, contentInset)) {
                [RCTView autoAdjustInsetsForView:self
                                  withScrollView:_webView.scrollView
                                    updateOffset:NO];
            }
        }
    }
}

#pragma mark - UIPastboard inject

- (void)pasteboardChangedNotification:(NSNotification*)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self injectDataTransferGetData];
    });
}

// Set data from JavaScript to Pastboard
- (void)setDataToPasteboard:(NSString *)dataString
{
    NSRange range = [dataString rangeOfString:@","];
    NSString *type = [dataString substringToIndex:range.location];
    NSString *data = [dataString substringFromIndex:range.location + range.length];
    UIPasteboard *clipboard = [UIPasteboard generalPasteboard];
    
    if ([type isEqualToString:@"text/html"]) {
        NSMutableDictionary *resourceDictionary = [NSMutableDictionary dictionary];
        
        [resourceDictionary setObject:[data dataUsingEncoding:NSUTF8StringEncoding]  forKey:@"WebResourceData"];
        [resourceDictionary setObject:@"" forKey:@"WebResourceFrameName"];
        [resourceDictionary setObject:@"text/html" forKey:@"WebResourceMIMEType"];
        [resourceDictionary setObject:@"UTF-8" forKey:@"WebResourceTextEncodingName"];
        [resourceDictionary setObject:[_webView.URL absoluteString] forKey:@"WebResourceURL"];
        
        NSDictionary *containerDictionary = [NSDictionary dictionaryWithObjectsAndKeys:resourceDictionary, @"WebMainResource", nil];
        NSDictionary *htmlItems = [NSDictionary dictionaryWithObjectsAndKeys:containerDictionary, RNAdvancedWebViewHtmlType, nil];
        [clipboard addItems: [NSArray arrayWithObjects: htmlItems, nil]];
    } else if ([type isEqualToString:@"text/plain"]) {
        clipboard.string = data;
    }
}

- (void)injectDataTransferGetData {
    UIPasteboard *pasteBoard = [UIPasteboard generalPasteboard];
    NSArray<NSDictionary<NSString *, id> *> *items = [pasteBoard items];
    NSString *htmlString = @"";
    for (NSDictionary *item in items) {
        NSData *archiveData = [item objectForKey:RNAdvancedWebViewHtmlType];
        if (archiveData) {
            NSError* error = nil;
            id webArchive = [NSPropertyListSerialization propertyListWithData:(NSData *)archiveData
                                                                      options:NSPropertyListImmutable
                                                                       format:NULL error:&error];
            NSData *webResourceData = [[webArchive objectForKey:@"WebMainResource"] objectForKey:@"WebResourceData"];
            htmlString = [[NSString alloc] initWithData:webResourceData encoding:NSUTF8StringEncoding];
            htmlString = [htmlString stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
        }
    }
    
    // Override DataTransfer.prototype.getData
    NSString *dataTransferInjection = [NSString stringWithFormat:
                                       @"(function () {"
                                       "if (!window.originDataTransferGetData) {"
                                       "  window.originDataTransferGetData = DataTransfer.prototype.getData;"
                                       "}"
                                       "DataTransfer.prototype.getData = function (type, data) {"
                                       "  if (type === 'text/html') {"
                                       "    return '%@';"
                                       "  } else {"
                                       "    return window.originDataTransferGetData.call(this, type, data);"
                                       "  }"
                                       "};"
                                       "})();", htmlString];
    [_webView evaluateJavaScript:dataTransferInjection completionHandler:nil];
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(null_unspecified WKNavigation *)navigation {
    if (_hideAccessory) {
        [self doHideAccessory];
    }
    if (!_keyboardDisplayRequiresUserAction) {
        [self doKeyboardDisplayAutomatically];
    }
}

- (void)webView:(__unused WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    NSURLRequest *request = navigationAction.request;
    NSURL* url = request.URL;
    NSString* scheme = url.scheme;
    
    BOOL isJSNavigation = [scheme isEqualToString:RNAdvancedWebJSNavigationScheme];
    
    if (isJSNavigation) {
        NSURL *url = request.URL;
        NSString *data = url.query;
        data = [data stringByReplacingOccurrencesOfString:@"+" withString:@" "];
        data = [data stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        if ([url.host isEqualToString:RNAdvancedWebViewJSPostMessageHost]) {
            
            NSMutableDictionary<NSString *, id> *event = [self baseEvent];
            [event addEntriesFromDictionary: @{
                                               @"data": data,
                                               }];
            _onMessage(event);
        } else if ([url.host isEqualToString:RNAdvancedWebViewJSDataTransferSetHost]) {
            [self setDataToPasteboard:data];
        }
        

        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    } else {
        if (_onShouldStartLoadWithRequest) {
            NSMutableDictionary<NSString *, id> *event = [self baseEvent];
            [event addEntriesFromDictionary: @{
                                               @"url": (request.URL).absoluteString,
                                               @"navigationType": @(navigationAction.navigationType)
                                               }];
            if (![self.delegate webView:self
              shouldStartLoadForRequest:event
                           withCallback:_onShouldStartLoadWithRequest]) {
                decisionHandler(WKNavigationActionPolicyCancel);
                return;
            }
        }
        
        if ([self externalAppRequiredToOpenURL:url]) {
            if ([[UIApplication sharedApplication] canOpenURL:url]) {
                [[UIApplication sharedApplication] openURL:url];
                decisionHandler(WKNavigationActionPolicyCancel);
                return;
            }
        } else {
            if (!navigationAction.targetFrame) {
                [webView loadRequest:navigationAction.request];
                decisionHandler(WKNavigationActionPolicyCancel);
                return;
            }
        }
        
        if (_onLoadingStart) {
            // We have this check to filter out iframe requests and whatnot
            BOOL isTopFrame = [url isEqual:request.mainDocumentURL];
            if (isTopFrame) {
                NSMutableDictionary<NSString *, id> *event = [self baseEvent];
                [event addEntriesFromDictionary: @{
                                                   @"url": url.absoluteString,
                                                   @"navigationType": @(navigationAction.navigationType)
                                                   }];
                _onLoadingStart(event);
            }
        }
    }
    decisionHandler(WKNavigationActionPolicyAllow);
}

- (void)webView:(__unused WKWebView *)webView didFailProvisionalNavigation:(__unused WKNavigation *)navigation withError:(NSError *)error
{
    if (_onLoadingError) {
        if ([error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorCancelled) {
            // NSURLErrorCancelled is reported when a page has a redirect OR if you load
            // a new URL in the WebView before the previous one came back. We can just
            // ignore these since they aren't real errors.
            // http://stackoverflow.com/questions/1024748/how-do-i-fix-nsurlerrordomain-error-999-in-iphone-3-0-os
            return;
        }

        NSMutableDictionary<NSString *, id> *event = [self baseEvent];
        [event addEntriesFromDictionary:@{
                                          @"domain": error.domain,
                                          @"code": @(error.code),
                                          @"description": error.localizedDescription,
                                          }];
        _onLoadingError(event);
    }
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(__unused WKNavigation *)navigation
{
    _navigationFinished = YES;
    [_pendingMessages enumerateObjectsUsingBlock:^(NSString * message, NSUInteger idx, BOOL * _Nonnull stop) {
        [self postMessage:message];
    }];
    _pendingMessages = [[NSMutableArray alloc] init];
    
    if (self.messagingEnabled) {
        NSString *source = [NSString stringWithFormat:
                            @"(function() {"
                            "var isNative = window.postMessage.length !== 1;"
                            "if (!isNative) {return}"
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
        [webView evaluateJavaScript:source completionHandler:nil];
    }
    
    // Polyfill for Clipboard API
    NSString *dataTransferInjection = [NSString stringWithFormat:
                                       @"(function () {;"
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
                                       "DataTransfer.prototype.setData = function (type, data) {"
                                       "  messageStack.push('%@://%@?' + encodeURIComponent(type + ',' + data));"
                                       "  if (!executing) executeStack();"
                                       "};"
                                       "})();", RNAdvancedWebJSNavigationScheme, RNAdvancedWebViewJSDataTransferSetHost];
    [webView evaluateJavaScript:dataTransferInjection completionHandler:nil];
    if (_injectedJavaScript) {
        if (_onLoadingFinish) {
            [webView evaluateJavaScript:_injectedJavaScript completionHandler:^(id result, NSError *error) {
                NSMutableDictionary<NSString *, id> *event = [self baseEvent];
                event[@"jsEvaluationValue"] = [NSString stringWithFormat:@"%@", result];
                _onLoadingFinish(event);
            }];
        }
    }
    // we only need the final 'finishLoad' call so only fire the event when we're actually done loading.
    else if (_onLoadingFinish && !webView.loading && ![webView.URL.absoluteString isEqualToString:@"about:blank"]) {
        _onLoadingFinish([self baseEvent]);
    }
}

#pragma mark - WKUIDelegate

- (void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(void))completionHandler {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:message message:nil preferredStyle:UIAlertControllerStyleAlert];

    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Close", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        completionHandler();
    }]];
    UIViewController *presentingController = RCTPresentedViewController();
    [presentingController presentViewController:alertController animated:YES completion:nil];
}

- (void)webView:(WKWebView *)webView runJavaScriptConfirmPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(BOOL))completionHandler {

    // TODO We have to think message to confirm "YES"
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:message message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        completionHandler(YES);
    }]];
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        completionHandler(NO);
    }]];
    UIViewController *presentingController = RCTPresentedViewController();
    [presentingController presentViewController:alertController animated:YES completion:nil];
}

- (void)webView:(WKWebView *)webView runJavaScriptTextInputPanelWithPrompt:(NSString *)prompt defaultText:(NSString *)defaultText initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(NSString *))completionHandler {

    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:prompt message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.text = defaultText;
    }];

    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *input = ((UITextField *)alertController.textFields.firstObject).text;
        completionHandler(input);
    }]];

    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        completionHandler(nil);
    }]];
    UIViewController *presentingController = RCTPresentedViewController();
    [presentingController presentViewController:alertController animated:YES completion:nil];
}

- (WKWebView *)webView:(WKWebView *)webView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration forNavigationAction:(WKNavigationAction *)navigationAction windowFeatures:(WKWindowFeatures *)windowFeatures
{
    NSString *scheme = navigationAction.request.URL.scheme;
    if ((navigationAction.targetFrame.isMainFrame || _openNewWindowInWebView) && ([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"])) {
        [webView loadRequest:navigationAction.request];
    } else {
        UIApplication *app = [UIApplication sharedApplication];
        NSURL *url = navigationAction.request.URL;
        if ([app canOpenURL:url]) {
            [app openURL:url];
        }
    }
    return nil;
}

#pragma mark - Notification

- (void)keyboardWillChange:(NSNotification*)aNotification
{
    if (_disableKeyboardAdjust) {
        // Disable Keyboard push up WebView.
        _originOffset = _webView.scrollView.contentOffset;
        _webView.scrollView.delegate = self;
    }
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (scrollView == _webView.scrollView) {
        float height = scrollView.frame.size.height;
        if (_originOffset.y + height <= scrollView.contentSize.height) {
            // Reset WebView's scrollView
            scrollView.contentOffset = _originOffset;
        }
        scrollView.delegate = nil;
    }
}

#pragma mark - Private

/**
 hide inputAccessoryView
 */
-(void)doHideAccessory
{
    UIView* subview;
    for (UIView* view in _webView.scrollView.subviews) {
        if([[view.class description] hasPrefix:@"WKContent"])
            subview = view;
    }

    if(subview == nil) return;

    NSString* name = [NSString stringWithFormat:@"%@_SwizzleHelperWK", subview.class.superclass];
    Class newClass = NSClassFromString(name);

    if(newClass == nil)
    {
        newClass = objc_allocateClassPair(subview.class, [name cStringUsingEncoding:NSASCIIStringEncoding], 0);
        if(!newClass) return;
        Method method = class_getInstanceMethod([_SwizzleHelperWK class], @selector(inputAccessoryView));
        class_addMethod(newClass, @selector(inputAccessoryView), method_getImplementation(method), method_getTypeEncoding(method));
        objc_registerClassPair(newClass);
    }
    object_setClass(subview, newClass);
}

- (void)doKeyboardDisplayAutomatically {
    Class class = NSClassFromString(@"WKContentView");
    NSOperatingSystemVersion iOS_11_3_0 = (NSOperatingSystemVersion){11, 3, 0};
    
    if ([[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion: iOS_11_3_0]) {
        SEL selector = sel_getUid("_startAssistingNode:userIsInteracting:blurPreviousNode:changingActivityState:userObject:");
        Method method = class_getInstanceMethod(class, selector);
        IMP original = method_getImplementation(method);
        IMP override = imp_implementationWithBlock(^void(id me, void* arg0, BOOL arg1, BOOL arg2, BOOL arg3, id arg4) {
            ((void (*)(id, SEL, void*, BOOL, BOOL, BOOL, id))original)(me, selector, arg0, TRUE, arg2, arg3, arg4);
        });
        method_setImplementation(method, override);
    } else {
        SEL selector = sel_getUid("_startAssistingNode:userIsInteracting:blurPreviousNode:userObject:");
        Method method = class_getInstanceMethod(class, selector);
        IMP original = method_getImplementation(method);
        IMP override = imp_implementationWithBlock(^void(id me, void* arg0, BOOL arg1, BOOL arg2, id arg3) {
            ((void (*)(id, SEL, void*, BOOL, BOOL, id))original)(me, selector, arg0, TRUE, arg2, arg3);
        });
        method_setImplementation(method, override);
    }
}

/**
 Whether need external app to open url
 @param URL URL description
 @return return value description
 */
- (BOOL)externalAppRequiredToOpenURL:(NSURL *)URL {
    NSString *scheme = URL.scheme;
    if (scheme.length) {
        return ![_validSchemes containsObject:URL.scheme];
    } else {
        return NO;
    }
}

@end
