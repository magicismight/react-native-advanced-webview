#import <React/RCTView.h>

@class RNAdvancedWebView;

/**
 * Special scheme used to pass messages to the injectedJavaScript
 * code without triggering a page load. Usage:
 *
 *   window.location.href = RCTJSNavigationScheme + '://hello'
 */
extern NSString *const RNJSNavigationScheme;

@protocol RNAdvancedWebViewDelegate <NSObject>

- (BOOL)webView:(RNAdvancedWebView *)webView
shouldStartLoadForRequest:(NSMutableDictionary<NSString *, id> *)request
   withCallback:(RCTDirectEventBlock)callback;

@end

@interface RNAdvancedWebView : RCTView

@property (nonatomic, weak) id<RNAdvancedWebViewDelegate> delegate;

@property (nonatomic, copy) NSDictionary *source;
@property (nonatomic, assign) UIEdgeInsets contentInset;
@property (nonatomic, assign) BOOL automaticallyAdjustContentInsets;
@property (nonatomic, assign) BOOL messagingEnabled;
@property (nonatomic, copy) NSString *injectedJavaScript;
@property (nonatomic, assign) BOOL scalesPageToFit;
@property (nonatomic, assign) BOOL hideAccessory;
@property (nonatomic, assign) BOOL keyboardDisplayRequiresUserAction;

- (void)goForward;
- (void)goBack;
- (void)reload;
- (void)stopLoading;
- (void)postMessage:(NSString *)message;
- (void)injectJavaScript:(NSString *)script;

@end

