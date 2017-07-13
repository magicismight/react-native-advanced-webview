#import <WebKit/WebKit.h>
#import <React/RCTView.h>

@class RNAdvancedWebView;

/**
 * Special scheme used to pass messages to the injectedJavaScript
 * code without triggering a page load. Usage:
 *
 *   window.location.href = RCTJSNavigationScheme + '://hello'
 */
extern NSString *const RCTJSNavigationScheme;

@protocol RNAdvancedWebViewDelegate <NSObject>

- (BOOL)webView:(RNAdvancedWebView *)webView
shouldStartLoadForRequest:(NSMutableDictionary<NSString *, id> *)request
   withCallback:(RCTDirectEventBlock)callback;

@end

@interface RNAdvancedWebView : RCTView

- (instancetype)initWithProcessPool:(WKProcessPool *)processPool;

@property (nonatomic, weak) id<RNAdvancedWebViewDelegate> delegate;

@property (nonatomic, copy) NSDictionary *source;
@property (nonatomic, assign) UIEdgeInsets contentInset;
@property (nonatomic, assign) BOOL automaticallyAdjustContentInsets;
@property (nonatomic, assign) BOOL openNewWindowInWebView;
@property (nonatomic, copy) NSString *injectedJavaScript;

#pragma mark - missing properties

@property (nonatomic, assign) BOOL messagingEnabled;

/**
 WKWebView does not support by default
 */
@property (nonatomic, assign) BOOL scalesPageToFit;

#pragma mark - added properties

@property (nonatomic, assign) BOOL hideKeyboardAccessoryView;
@property (nonatomic, assign) BOOL hideAccessory;

/**
 WKWebView does not support by default
 see: https://stackoverflow.com/questions/32407185/wkwebview-cant-open-keyboard-for-input-field
 */
@property (nonatomic, assign) BOOL keyboardDisplayRequiresUserAction;

- (void)goForward;
- (void)goBack;
- (void)reload;
- (void)stopLoading;

#pragma mark - missing methods

- (void)postMessage:(NSString *)message;
- (void)injectJavaScript:(NSString *)script;

#pragma mark - added methods

- (BOOL)canGoBack;
- (BOOL)canGoForward;
- (void)evaluateJavaScript:(NSString *)javaScriptString completionHandler:(void (^)(id, NSError *error))completionHandler;

@end
