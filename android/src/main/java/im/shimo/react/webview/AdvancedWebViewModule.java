package im.shimo.react.webview;

import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.uimanager.NativeViewHierarchyManager;
import com.facebook.react.uimanager.UIBlock;
import com.facebook.react.uimanager.UIManagerModule;

public class AdvancedWebViewModule extends ReactContextBaseJavaModule {

    public AdvancedWebViewModule(ReactApplicationContext reactContext) {
        super(reactContext);
    }

    @Override
    public String getName() {
        return "RNAdvancedWebViewManager";
    }

    @ReactMethod
    public void evaluateJavaScript(final int tag, final String script, final Promise promise) {
        getReactApplicationContext().getNativeModule(UIManagerModule.class).addUIBlock(new UIBlock() {
            public void execute (NativeViewHierarchyManager manager) {
                AdvancedWebViewManager.AdvancedWebView webView = (AdvancedWebViewManager.AdvancedWebView) manager.resolveView(tag);
                webView.loadUrl("javascript:(function() {\n" + script + ";\n})();");
                promise.resolve(true);
            }
        });
    }
}
