package im.shimo.react.webview;

import android.content.Context;
import android.os.Build;
import android.util.Log;
import android.view.ViewGroup;
import android.view.inputmethod.InputMethodManager;
import android.webkit.GeolocationPermissions;
import android.webkit.JavascriptInterface;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.webkit.WebView;

import com.facebook.common.logging.FLog;
import com.facebook.react.bridge.NativeModule;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.common.ReactConstants;
import com.facebook.react.common.build.ReactBuildConfig;
import com.facebook.react.uimanager.NativeViewHierarchyManager;
import com.facebook.react.uimanager.ThemedReactContext;
import com.facebook.react.uimanager.UIBlock;
import com.facebook.react.uimanager.UIManagerModule;
import com.facebook.react.views.webview.ReactWebViewManager;
import com.facebook.react.uimanager.annotations.ReactProp;
import com.facebook.react.views.webview.WebViewConfig;

public class AdvancedWebViewManager extends ReactWebViewManager {

    private static final String REACT_CLASS = "RNAdvancedWebView";
    private static final String BRIDGE_NAME = "__REACT_WEB_VIEW_BRIDGE";

    private WebViewConfig mWebViewConfig;

    public AdvancedWebViewManager() {
        super();
        mWebViewConfig = new WebViewConfig() {
            public void configWebView(WebView webView) {
            }
        };
    }

    protected static class AdvancedWebView extends ReactWebView {
        private boolean mMessagingEnabled = false;
        private boolean mkeyboardDisplayRequiresUserAction = true;
        private InputMethodManager mInputMethodManager = (InputMethodManager) getContext().getSystemService(Context.INPUT_METHOD_SERVICE);
        private UIManagerModule mNativeModule;

        public AdvancedWebView(ThemedReactContext reactContext) {
            super(reactContext);
            mNativeModule = reactContext.getNativeModule(UIManagerModule.class);
        }

        private class ReactWebViewBridge {
            ReactWebView mContext;

            ReactWebViewBridge(ReactWebView c) {
                mContext = c;
            }

            @JavascriptInterface
            public void postMessage(String message) {
                mContext.onMessage(message);
            }

            @JavascriptInterface
            public void showKeyboard() {
                mNativeModule.addUIBlock(new UIBlock() {
                    @Override
                    public void execute(NativeViewHierarchyManager nativeViewHierarchyManager) {
                        AdvancedWebView.this.requestFocus();
                        mInputMethodManager.showSoftInput(AdvancedWebView.this, InputMethodManager.SHOW_IMPLICIT);
                    }
                });
            }

            @JavascriptInterface
            public void hideKeyboard() {
                mNativeModule.addUIBlock(new UIBlock() {
                    @Override
                    public void execute(NativeViewHierarchyManager nativeViewHierarchyManager) {
                        mInputMethodManager.hideSoftInputFromWindow(AdvancedWebView.this.getWindowToken(), InputMethodManager.HIDE_NOT_ALWAYS);
                    }
                });

            }
        }

        public void setKeyboardDisplayRequiresUserAction(boolean keyboardDisplayRequiresUserAction) {
            mkeyboardDisplayRequiresUserAction = keyboardDisplayRequiresUserAction;
        }

        @Override
        public void setMessagingEnabled(boolean enabled) {
            if (mMessagingEnabled == enabled) {
                return;
            }

            mMessagingEnabled = enabled;
            if (enabled) {
                addJavascriptInterface(new AdvancedWebView.ReactWebViewBridge(this), BRIDGE_NAME);
            } else {
                removeJavascriptInterface(BRIDGE_NAME);
            }
        }

        @Override
        public void linkBridge() {
            if (mMessagingEnabled) {

                loadUrl("javascript:" +
                        "(function () {" +
                        "   if (window.originalPostMessage) {return;}" +
                        "   window.originalPostMessage = window.postMessage," +
                        "   window.postMessage = function(data) {" +
                                BRIDGE_NAME + ".postMessage(String(data));" +
                        "   };" +
                        "   document.dispatchEvent(new CustomEvent('ReactNativeContextReady'));" +
                        "})()");
            }

            if (mkeyboardDisplayRequiresUserAction) {
                loadUrl("javascript:" +
                        "(function () {" +
                        "   function isDescendant(parent, child) {" +
                        "     var node = child.parentNode;" +
                        "     while (node) {" +
                        "         if (node == parent) {" +
                        "             return true;" +
                        "         }" +
                        "         node = node.parentNode;" +
                        "     }" +
                        "     return false;" +
                        "   }" +
                        "   var focus = HTMLElement.prototype.focus;" +
                        "   HTMLElement.prototype.focus = function() {" +
                        "       focus.call(this);" +
                        "       var selection = document.getSelection();" +
                        "       var anchorNode = selection && selection.anchorNode;" +
                        "       if (anchorNode && isDescendant(this, anchorNode) || this === anchorNode) {" +
                        BRIDGE_NAME + ".showKeyboard();" + // Show soft input manually, can't show soft input via javascript
                        "       }" +
                        "   };" +
                        "   var blur = HTMLElement.prototype.blur;" +
                        "   HTMLElement.prototype.blur = function() {" +
                        "       if (isDescendant(document.activeElement, this)) {" +
                        BRIDGE_NAME + ".hideKeyboard();" +
                        "       }" +
                        "       blur.call(this);" +
                        "   };" +
                        "   document.dispatchEvent(new CustomEvent('ReactNativeContextReady'));" +
                        "})()");
            }
        }
    }


    @Override
    public String getName() {
        return REACT_CLASS;
    }

    @Override
    protected WebView createViewInstance(ThemedReactContext reactContext) {
        ReactWebView webView = new AdvancedWebView(reactContext);
        webView.setWebChromeClient(new WebChromeClient() {
            @Override
            public void onGeolocationPermissionsShowPrompt(String origin, GeolocationPermissions.Callback callback) {
                callback.invoke(origin, true, false);
            }
        });

        reactContext.addLifecycleEventListener(webView);
        mWebViewConfig.configWebView(webView);
        webView.getSettings().setBuiltInZoomControls(true);
        webView.getSettings().setDisplayZoomControls(false);

        // Fixes broken full-screen modals/galleries due to body height being 0.
        webView.setLayoutParams(
                new ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT,
                        ViewGroup.LayoutParams.MATCH_PARENT));

        if (ReactBuildConfig.DEBUG && Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            WebView.setWebContentsDebuggingEnabled(true);
        }

        return webView;
    }

    protected static class AdvancedWebViewClient extends ReactWebViewClient {
        @Override
        public void doUpdateVisitedHistory(WebView webView, String url, boolean isReload) {
            if (isReload) {
                super.doUpdateVisitedHistory(webView, url, true);
            }
        }
    }

    @Override
    protected void addEventEmitters(ThemedReactContext reactContext, WebView view) {
        // Do not register default touch emitter and let WebView implementation handle touches
        view.setWebViewClient(new AdvancedWebViewClient());
    }

    @ReactProp(name = "allowFileAccessFromFileURLs")
    public void setAllowFileAccessFromFileURLs(WebView root, boolean allows) {
        root.getSettings().setAllowFileAccessFromFileURLs(allows);
    }

    @ReactProp(name = "keyboardDisplayRequiresUserAction")
    public void setKeyboardDisplayRequiresUserAction(WebView root, boolean keyboardDisplayRequiresUserAction) {
        ((AdvancedWebView) root).setKeyboardDisplayRequiresUserAction(keyboardDisplayRequiresUserAction);
    }

}
