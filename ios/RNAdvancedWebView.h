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
@property (nonatomic, assign) NSInteger contentInsetAdjustmentBehavior;
@property (nonatomic, copy) NSString *injectedJavaScript;

/**
 supported schemes, others will use openURL。 default is @[@"http", @"https", @"file", @"ftp", @"ws"]
 */
@property (nonatomic, strong) NSArray *validSchemes;

/**
 Whether support postMessage
 */
@property (nonatomic, assign) BOOL messagingEnabled;

@property (nonatomic, assign) BOOL hideAccessory;

@property (nonatomic, assign) BOOL keyboardDisplayRequiresUserAction;

@property (nonatomic, assign) BOOL disableKeyboardAdjust;

- (void)goForward;
- (void)goBack;
- (void)reload;
- (void)stopLoading;

- (void)postMessage:(NSString *)message;
- (void)injectJavaScript:(NSString *)script;

- (BOOL)canGoBack;
- (BOOL)canGoForward;
- (void)evaluateJavaScript:(NSString *)javaScriptString completionHandler:(void (^)(id, NSError *error))completionHandler;

@end
