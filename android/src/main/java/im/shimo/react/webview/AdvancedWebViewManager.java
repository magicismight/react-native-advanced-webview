package im.shimo.react.webview;

import android.annotation.SuppressLint;
import android.content.Context;
import android.os.Build;
import android.os.SystemClock;
import android.support.annotation.Nullable;
import android.view.ViewGroup;
import android.view.inputmethod.InputMethodManager;
import android.webkit.GeolocationPermissions;
import android.webkit.JavascriptInterface;
import android.webkit.WebChromeClient;
import android.webkit.WebView;

import com.facebook.react.bridge.ReadableArray;
import com.facebook.react.common.build.ReactBuildConfig;
import com.facebook.react.uimanager.NativeViewHierarchyManager;
import com.facebook.react.uimanager.ThemedReactContext;
import com.facebook.react.uimanager.UIBlock;
import com.facebook.react.uimanager.UIManagerModule;
import com.facebook.react.uimanager.annotations.ReactProp;
import com.facebook.react.views.view.ReactViewGroup;
import com.facebook.react.views.webview.ReactWebViewManager;
import com.facebook.react.views.webview.WebViewConfig;

import org.json.JSONException;
import org.json.JSONObject;

import java.util.LinkedList;

public class AdvancedWebViewManager extends ReactWebViewManager {

    private static final String REACT_CLASS = "RNAdvancedWebView";
    private static final String BRIDGE_NAME = "__REACT_WEB_VIEW_BRIDGE";

    /**
     * 第一个文档打开后所保留的单例
     */
    private volatile AdvancedWebView mWebView;
    /**
     * 便于调用销毁方法
     */
    private static AdvancedWebViewManager INSTANCE;
    /**
     * 存储从一个webview内新启的另一些webview，按顺序存储
     */
    private LinkedList<WebView> mWebviews;

    private static final String URL_A = "javascript:" +
        "(function () {" +
        "   if (window.originalPostMessage) {return;}" +
        "   window.originalPostMessage = window.postMessage," +
        "   window.postMessage = function(data) {";
    private static final String URL_B = ".postMessage(String(data));" +
        "   };" +
        "   document.dispatchEvent(new CustomEvent('ReactNativeContextReady'));" +
        "})()";
    private static String URL_KEYBOARD_A = "javascript:" +
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
        "       if (document.activeElement !== document.body && anchorNode && (isDescendant(this, anchorNode) || this === anchorNode)) {";
    private static String URL_KEYBOARD_B = ".showKeyboard();" + // Show soft input manually, can't show soft input via javascript
        "       }" +
        "   };" +
        "   var blur = HTMLElement.prototype.blur;" +
        "   HTMLElement.prototype.blur = function() {" +
        "       if (isDescendant(document.activeElement, this)) {";
    private static String URL_KEYBOARD_C = ".hideKeyboard();" +
        "       }" +
        "       blur.call(this);" +
        "   };" +
        "   document.dispatchEvent(new CustomEvent('ReactNativeContextReady'));" +
        "})()";

    public AdvancedWebViewManager() {
        super();
        mWebViewConfig = new WebViewConfig() {
            public void configWebView(WebView webView) {
            }
        };
        mWebviews = new LinkedList<>();
        INSTANCE = this;
    }


    @SuppressLint("ViewConstructor")
    protected static class AdvancedWebView extends ReactWebView {
        private boolean mMessagingEnabled = false;
        private boolean mKeyboardDisplayRequiresUserAction = false;
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
            mKeyboardDisplayRequiresUserAction = keyboardDisplayRequiresUserAction;
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
            if (getOriginalUrl().equals(BLANK_URL)) {
                return;
            }
            if (mMessagingEnabled) {
                loadUrl(URL_A + BRIDGE_NAME + URL_B);
            }
            if (!mKeyboardDisplayRequiresUserAction) {
                loadUrl(URL_KEYBOARD_A + BRIDGE_NAME + URL_KEYBOARD_B + BRIDGE_NAME + URL_KEYBOARD_C);
            }
        }


        /**
         * 是否显示在界面上
         */
        private int mVisibility = -1;

        @Override
        protected void onWindowVisibilityChanged(int visibility) {
            super.onWindowVisibilityChanged(visibility);
            if (visibility != mVisibility) {
                if (visibility == VISIBLE) {
                    resumeTimers();
                } else {
                    pauseTimers();
                }
                mVisibility = visibility;
            }
        }

    }


    /**
     * 此方法在退出web界面时或回退到上一个webview界面时调用，应用程序在前台显示
     *
     * @param webView
     */
    @Override
    public void onDropViewInstance(WebView webView) {
        if (!mWebView.equals(webView)) {
            //恢复即将被销毁的webview所遮盖的webview状态
            int index = resumeBeforeWeb();
            //毁掉退出的webview
            if (index > 0 && index < mWebviews.size()) {
                destroyWebView(mWebviews.get(index));
            }
            super.onDropViewInstance(webView);
        } else {//如果是退出第一个Dwebview页面,返回主界面
            resetPage();
            callParentDropMe(webView);
        }
    }

    private int resumeBeforeWeb() {
        int size = mWebviews.size();
        int index = size - 1;
        if (size > 1) {
            final WebView fweb = mWebviews.get(index - 1);
            if (fweb != null) {
                fweb.resumeTimers();
            }
        }
        return index;
    }


    private void pauseBefores() {
        mWebView.pauseTimers();
        for (int i = 0; i < mWebviews.size(); i++) {
            final WebView view = mWebviews.get(i);
            view.pauseTimers();
        }
    }


    /**
     * 此方法在程序销毁时调用
     */
    public static void webviewOnDestroy() {
        if (INSTANCE != null) {
            if (INSTANCE.mWebView != null) {
                INSTANCE.mWebView.removeAllViews();
                INSTANCE.callParentDropMe(INSTANCE.mWebView);
                INSTANCE.mWebView = null;
            }
            if (INSTANCE.mWebviews != null && !INSTANCE.mWebviews.isEmpty()) {
                for (int i = 0; i < INSTANCE.mWebviews.size(); i++) {
                    INSTANCE.mWebviews.get(i).removeAllViews();
                    INSTANCE.callParentDropMe(INSTANCE.mWebviews.get(i));
                }
                INSTANCE.mWebviews.clear();
            }
            INSTANCE = null;
        }
    }

    private void destroyWebView(WebView webView) {
        webView.removeAllViews();
        callParentDropMe(webView);
    }


    /**
     * 把自己从绑定界面上移除掉
     *
     * @param webView
     * @return
     */
    private void callParentDropMe(WebView webView) {
        final ReactViewGroup parent = (ReactViewGroup) webView.getParent();
        if (parent != null) {
            parent.removeView(webView);
        }
    }

    @Override
    public String getName() {
        return REACT_CLASS;
    }


    /**
     * 创建
     *
     * @param reactContext
     * @return
     */
    @Override
    protected WebView createViewInstance(ThemedReactContext reactContext) {
        WebView webView = null;

        if (mWebView == null) {//首次打开
            mWebView = initWebview(reactContext);
            webView = mWebView;
        } else if (mWebView.getParent() == null) {//曾经打开过，再重新打开
            webView = mWebView;
        } else if (mWebView.getParent() != null) {//非首次打开
            pauseBefores();
            webView = initWebview(reactContext);
            mWebviews.add(webView);
        }
        return webView;
    }

    /**
     * 重置页面，解决第二次加载失败的bug
     */
    private void resetPage() {
        mWebView.loadUrl(BLANK_URL);
        mWebviews.clear();
    }

    /**
     * 初始化webview实例，刷新document
     *
     * @param reactContext
     * @return
     */
    @SuppressLint("SetJavaScriptEnabled")
    public AdvancedWebView initWebview(ThemedReactContext reactContext) {
        AdvancedWebView webView = new AdvancedWebView(reactContext);
        webView.setWebChromeClient(new WebChromeClient() {
            @Override
            public void onGeolocationPermissionsShowPrompt(String origin, GeolocationPermissions.Callback callback) {
                callback.invoke(origin, true, false);
            }
        });

        webView.getSettings().setBuiltInZoomControls(true);
        webView.getSettings().setDisplayZoomControls(false);
        webView.getSettings().setJavaScriptEnabled(true);
        mWebViewConfig.configWebView(webView);
        reactContext.addLifecycleEventListener(webView);
        // Fixes broken full-screen modals/galleries due to body height being 0.
        webView.setLayoutParams(
            new ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT));

        if (ReactBuildConfig.DEBUG && Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            WebView.setWebContentsDebuggingEnabled(true);
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            // chromium, enable hardware acceleration
            webView.setLayerType(WebView.LAYER_TYPE_HARDWARE, null);
        } else {
            // older android version, disable hardware acceleration
            webView.setLayerType(WebView.LAYER_TYPE_SOFTWARE, null);
        }
        return webView;
    }

    protected class AdvancedWebViewClient extends ReactWebViewClient {

        @Override
        public void onPageFinished(WebView webView, String url) {
            super.onPageFinished(webView, url);
        }

        @Override
        public void doUpdateVisitedHistory(WebView webView, String url, boolean isReload) {
            if (isReload) {
                super.doUpdateVisitedHistory(webView, url, true);
            }
        }

    }

    @Override
    public void receiveCommand(WebView root, int commandId, @Nullable ReadableArray args) {
        switch (commandId) {
            case COMMAND_GO_BACK:
                root.goBack();
                break;
            case COMMAND_GO_FORWARD:
                root.goForward();
                break;
            case COMMAND_RELOAD:
                root.reload();
                break;
            case COMMAND_STOP_LOADING:
                root.stopLoading();
                break;
            case COMMAND_POST_MESSAGE:
                try {
                    JSONObject eventInitDict = new JSONObject();
                    eventInitDict.put("data", args.getString(0));
                    root.evaluateJavascript("(function () {" +
                        "var event;" +
                        "var data = " + eventInitDict.toString() + ";" +
                        "try {" +
                        "event = new MessageEvent('message', data);" +
                        "} catch (e) {" +
                        "event = document.createEvent('MessageEvent');" +
                        "event.initMessageEvent('message', true, true, data.data, data.origin, data.lastEventId, data.source);" +
                        "}" +
                        "document.dispatchEvent(event);" +
                        "})();", null);
                } catch (JSONException e) {
                    throw new RuntimeException(e);
                }
                break;
            case COMMAND_INJECT_JAVASCRIPT:
                root.evaluateJavascript(args.getString(0), null);
                break;
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
