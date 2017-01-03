package im.shimo.react.webview;

import android.graphics.Bitmap;
import android.os.Build;
import android.text.TextUtils;
import android.view.ViewGroup;
import android.webkit.GeolocationPermissions;
import android.webkit.WebChromeClient;
import android.webkit.WebView;

import com.facebook.react.common.build.ReactBuildConfig;
import com.facebook.react.uimanager.ThemedReactContext;
import com.facebook.react.views.webview.ReactWebViewManager;
import com.facebook.react.uimanager.annotations.ReactProp;
import com.facebook.react.views.webview.WebViewConfig;
import java.util.Map;

import javax.annotation.Nullable;

public class AdvancedWebViewManager extends ReactWebViewManager {

    private static final String REACT_CLASS = "RNAdvancedWebView";

    private WebViewConfig mWebViewConfig;

    public AdvancedWebViewManager() {
        super();
        mWebViewConfig = new WebViewConfig() {
            public void configWebView(WebView webView) {
            }
        };
    }

    protected static class AdvancedWebViewClient extends ReactWebViewClient {
        @Override
        public void onPageStarted(WebView webView, String url, Bitmap favicon) {
            AdvancedWebView advancedWebView = (AdvancedWebView) webView;
            advancedWebView.callInitialJavaScript();
            super.onPageStarted(webView, url, favicon);
        }
    }

    protected static class AdvancedWebView extends ReactWebView {

        public AdvancedWebView(ThemedReactContext reactContext) {
            super(reactContext);
        }

        private @Nullable String mInitialJS;

        public void setInitialJavaScript(@Nullable String js) {
            mInitialJS = js;
        }

        public void callInitialJavaScript() {
            if (getSettings().getJavaScriptEnabled() &&
                    mInitialJS != null &&
                    !TextUtils.isEmpty(mInitialJS)) {
                loadUrl("javascript:(function() {\n" + mInitialJS + ";\n})();");
            }
        }
    }

    @ReactProp(name = "initialJavaScript")
    public void setInitialJavaScript(WebView view, @Nullable String initialJavaScript) {
        ((AdvancedWebView) view).setInitialJavaScript(initialJavaScript);
    }

    @Override
    public String getName() {
        return REACT_CLASS;
    }

    @Override
    public
    @Nullable
    Map<String, Integer> getCommandsMap() {
        Map<String, Integer> commandsMap = super.getCommandsMap();
        return commandsMap;
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

    @ReactProp(name = "allowFileAccessFromFileURLs")
    public void setAllowFileAccessFromFileURLs(WebView root, boolean allows) {
        root.getSettings().setAllowFileAccessFromFileURLs(allows);
    }

    @Override
    protected void addEventEmitters(ThemedReactContext reactContext, WebView view) {
        // Do not register default touch emitter and let WebView implementation handle touches
        view.setWebViewClient(new AdvancedWebViewClient());
    }
}
