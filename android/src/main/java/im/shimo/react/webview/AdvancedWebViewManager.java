package im.shimo.react.webview;

import android.annotation.SuppressLint;
import android.content.Context;
import android.os.Build;
import android.support.annotation.Nullable;
import android.text.InputType;
import android.view.ActionMode;
import android.view.KeyEvent;
import android.view.Menu;
import android.view.MenuItem;
import android.view.ViewGroup;
import android.view.inputmethod.BaseInputConnection;
import android.view.inputmethod.EditorInfo;
import android.view.inputmethod.InputConnection;
import android.view.inputmethod.InputConnectionWrapper;
import android.view.inputmethod.InputMethodManager;
import android.webkit.GeolocationPermissions;
import android.webkit.JavascriptInterface;
import android.webkit.WebChromeClient;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.ReadableArray;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.ReadableMapKeySetIterator;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.modules.core.DeviceEventManagerModule.RCTDeviceEventEmitter;
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

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.LinkedList;

public class AdvancedWebViewManager extends ReactWebViewManager {

    private static final String REACT_CLASS = "RNAdvancedWebView";
    private static final String BRIDGE_NAME = "__REACT_WEB_VIEW_BRIDGE";

    /**
     * 便于调用销毁方法
     */
    private static AdvancedWebViewManager INSTANCE;
    /**
     * 存储从一个webview内新启的另一些webview，按顺序存储
     */
    private LinkedList<AdvancedWebView> mWebviews;

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
            "       if (document.activeElement !== document.body && anchorNode && (isDescendant(document.activeElement, anchorNode) || this === anchorNode)) {";
    private static String URL_KEYBOARD_B = ".showKeyboard();" + // Show soft input manually, can't show soft input via javascript
            "       }" +
            "   };" +
            "   var blur = HTMLElement.prototype.blur;" +
            "   HTMLElement.prototype.blur = function() {" +
            "       if (isDescendant(document.activeElement, this) || this === document.activeElement) {";
    private static String URL_KEYBOARD_C = ".hideKeyboard();" +
            "       }" +
            "       blur.call(this);" +
            "   };" +
            "   document.dispatchEvent(new CustomEvent('ReactNativeContextReady'));" +
            "})()";
    private LinkedHashMap<Integer, String> mMenuIdTitles;
    private ArrayList<String> mWhiteList;
    /**
     * 手动打开debug的标记，当遇到prop设置时，以prop设置为准
     */
    public static boolean DEBUG_MODEL = false;
    /**
     * prop设置参数
     */
    private int mEnvValue;

    public AdvancedWebViewManager() {
        super();
        mWebViewConfig = new WebViewConfig() {
            public void configWebView(WebView webView) {
            }
        };
        mWebviews = new LinkedList<>();
        INSTANCE = this;
    }

    public static AdvancedWebViewManager getInstance() {
        return SingHolder.INSTANCE;
    }

    public LinkedHashMap<Integer, String> getMenuIdTitles() {
        return mMenuIdTitles;
    }

    public ArrayList<String> getMenuIdTitlesWhiteList() {
        return mWhiteList;
    }

    private static class SingHolder {
        private static final AdvancedWebViewManager INSTANCE = AdvancedWebViewManager.INSTANCE;
    }


    @SuppressLint("ViewConstructor")
    protected static class AdvancedWebView extends ReactWebView {
        private static final String ACTION_MENU_SELECTED = "actionMenuSelected";
        private final RCTDeviceEventEmitter mEventEmitter;
        private ActionMode mActionMode;
        private boolean mMessagingEnabled = false;
        private boolean mKeyboardDisplayRequiresUserAction = false;
        private InputMethodManager mInputMethodManager = (InputMethodManager) getContext().getSystemService(Context.INPUT_METHOD_SERVICE);
        private UIManagerModule mNativeModule;

        public AdvancedWebView(ThemedReactContext reactContext) {
            super(reactContext);
            mNativeModule = reactContext.getNativeModule(UIManagerModule.class);
            mEventEmitter = reactContext.getJSModule(RCTDeviceEventEmitter.class);
        }

        public WebViewClient getWebViewClient() {
            return mReactWebViewClient;
        }

        /**
         * 解决4.4以下图片无法删除的bug，其实就是把键盘的删除事件拦截以后自己处理
         *
         * @param outAttrs
         * @return
         */
        @Override
        public InputConnection onCreateInputConnection(EditorInfo outAttrs) {
            if (Build.VERSION.SDK_INT <= Build.VERSION_CODES.KITKAT) {
                outAttrs.actionLabel = null;
                outAttrs.inputType = InputType.TYPE_NULL;
                final InputConnection baseConnet = new BaseInputConnection(this, false);
                final InputConnection orignalConnet = super.onCreateInputConnection(outAttrs);
                if(orignalConnet!=null) {
                    InputConnectionWrapper inputConnectionWrapper = new InputConnectionWrapper(
                            super.onCreateInputConnection(outAttrs), true) {
                        @Override
                        public boolean deleteSurroundingText(int beforeLength, int afterLength) {
                            if (beforeLength == 1 && afterLength == 0) {
                                return this.sendKeyEvent(new KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_DEL))
                                        && this.sendKeyEvent(new KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_DEL));
                            }
                            return super.deleteSurroundingText(beforeLength, afterLength);
                        }

                        @Override
                        public boolean sendKeyEvent(KeyEvent event) {
                            if (event.getKeyCode() == KeyEvent.KEYCODE_DEL) {
                                return baseConnet.sendKeyEvent(event);
                            } else {
                                return super.sendKeyEvent(event);
                            }
                        }

                        @Override
                        public boolean finishComposingText() {
                            try {
                                return super.finishComposingText();
                            } catch (Exception e) {
                                return true;
                            } finally {
                                if (baseConnet != null) {
                                    return baseConnet.finishComposingText();
                                }
                            }
                        }
                    };
                    return inputConnectionWrapper;
                } else {
                    return orignalConnet;
                }
            } else {
                return super.onCreateInputConnection(outAttrs);
            }
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
                        AdvancedWebView.this.requestFocus();
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
                    //切入前台恢复使用cpu
                    onResume();
                    resumeTimers();
                    getSettings().setJavaScriptEnabled(true);
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
                        if (getInstance().mEnvValue == 1 || DEBUG_MODEL || BuildConfig.DEBUG) {
                            WebView.setWebContentsDebuggingEnabled(true);
                        } else {
                            WebView.setWebContentsDebuggingEnabled(false);
                        }
                    }
                } else {
                    //切入后台释放cpu
                    onPause();
                    pauseTimers();
                    getSettings().setJavaScriptEnabled(false);
                }
                mVisibility = visibility;
            }
        }

        @Override
        public ActionMode startActionMode(ActionMode.Callback callback) {
            ActionMode actionMode = super.startActionMode(callback);
            if (getInstance().getMenuIdTitles() == null && getInstance().getMenuIdTitlesWhiteList() == null) {
                //既没有设置自定义item也没有设置白名单就不用处理
                return actionMode;
            }
            return resolveActionMode(actionMode);
        }

        @Override
        public ActionMode startActionMode(ActionMode.Callback callback, int type) {
            ActionMode actionMode = super.startActionMode(callback, type);
            if (getInstance().getMenuIdTitles() == null && getInstance().getMenuIdTitlesWhiteList() == null) {
                //既没有设置自定义item也没有设置白名单就不用处理
                return actionMode;
            }
            return resolveActionMode(actionMode);
        }

        /**
         * 处理item，处理点击
         *
         * @param actionMode
         */
        private ActionMode resolveActionMode(ActionMode actionMode) {
            if (actionMode != null) {
                final Menu menu = actionMode.getMenu();
                //删除系统自带item
                deleteOtherItem(actionMode);
                //配置点击事件
                configMenuItem(menu);
            }
            mActionMode = actionMode;
            return actionMode;
        }

        private void deleteOtherItem(ActionMode actionMode) {
            ArrayList<String> whiteLists = getInstance().getMenuIdTitlesWhiteList();
            Menu oldMenu = actionMode.getMenu();
            if (whiteLists == null || whiteLists.isEmpty()) {
                //没有设置白名单或者白名单本身就是空数据，系统的全删除
                oldMenu.clear();
            } else {
                for (int i = 0; i < oldMenu.size(); i++) {
                    MenuItem item = oldMenu.getItem(i);
                    String titleStr = item.getTitle().toString();
                    if (isToDelete(whiteLists, titleStr)) {
                        oldMenu.removeItem(item.getItemId());
                        i--;
                    }
                }
            }
        }

        private void configMenuItem(Menu menu) {
            int index = 0;
            LinkedHashMap<Integer, String> menuIdTitles = getInstance().getMenuIdTitles();
            if (menuIdTitles == null || menuIdTitles.isEmpty()) {
                //没有添加自定义item
                return;
            }
            for (Integer id : menuIdTitles.keySet()) {
                menu.add(0, id, index, menuIdTitles.get(id));
                MenuItem menuItem = menu.getItem(index);
                menuItem.setOnMenuItemClickListener(new MenuItem.OnMenuItemClickListener() {
                    @Override
                    public boolean onMenuItemClick(MenuItem item) {
                        //事件传递
                        sendEvent(item);
                        releaseAction();
                        return true;
                    }
                });
                index++;
            }
        }


        /**
         * 白名单的保留
         *
         * @param whiteLists
         * @param titleStr
         */
        private boolean isToDelete(ArrayList<String> whiteLists, String titleStr) {
            if (whiteLists.indexOf(titleStr) >= 0) {
                return false;
            } else {
                return true;
            }
        }

        private void sendEvent(MenuItem menuItem) {
            WritableMap params = Arguments.createMap();
            params.putString("menuId", String.valueOf(menuItem.getItemId()));
            params.putString("menuTitle", menuItem.getTitle().toString());
            mEventEmitter.emit(ACTION_MENU_SELECTED, params);
        }

        /**
         * 隐藏消失Action
         */
        private void releaseAction() {
            if (mActionMode != null) {
                mActionMode.finish();
                mActionMode = null;
            }
        }

    }

    @ReactProp(name = "webviewDebugEnabledWhenDev", defaultInt = 0)
    public void setWebviewDebugModel(WebView view, int env) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            if (env == 1) {
                WebView.setWebContentsDebuggingEnabled(true);
                DEBUG_MODEL = true;
            } else {
                if (mEnvValue == 1) {
                    //从Dev环境切回别的环境，这个值有可能会变化
                    WebView.setWebContentsDebuggingEnabled(false);
                    DEBUG_MODEL = false;
                }
            }
        }
        mEnvValue = env;
    }


    /**
     * 此方法在退出web界面时或回退到上一个webview界面时调用，应用程序在前台显示
     *
     * @param webView
     */
    @Override
    public void onDropViewInstance(WebView webView) {
        if (mWebviews.size() == 1) {
            //全部退出了，只剩下默认webview，休眠并保留它
            dumpWebView(webView);
        } else if (mWebviews.size() > 1) {
            //多页面覆盖方式，所以需要把默认的角标从最上层移至下一层
            //先取出最上层
            mWebviews.remove(webView);
            //将最上层销毁
            dumpWebView(webView);
            ((AdvancedWebViewClient) ((AdvancedWebView) webView).getWebViewClient()).mPendingMessages = new ArrayList<>();
            super.onDropViewInstance(webView);
            //设置下一层为默认webview
            //唤醒下一层
            resumeWebview(mWebviews.getLast());
        } else {
            dumpWebView(webView);
            super.onDropViewInstance(webView);
        }
    }

    @SuppressLint("SetJavaScriptEnabled")
    private void resumeWebview(WebView webView) {
        webView.onResume();
        webView.resumeTimers();
        webView.getSettings().setJavaScriptEnabled(true);
    }

    private void pauseBefores() {
        for (int i = 0; i < mWebviews.size(); i++) {
            final WebView view = mWebviews.get(i);
            view.onPause();
            view.getSettings().setJavaScriptEnabled(false);
        }
    }


    /**
     * 此方法在程序销毁时调用
     */
    public static void webviewOnDestroy() {
        if (getInstance() != null) {
            if (getInstance().mWebviews != null && !getInstance().mWebviews.isEmpty()) {
                for (int i = 0; i < getInstance().mWebviews.size(); i++) {
                    final WebView webView = getInstance().mWebviews.get(i);
                    getInstance().dumpWebView(webView);
                    webView.destroy();
                }
                getInstance().mWebviews.clear();
            }
            INSTANCE = null;
        }
    }

    /**
     * 父类已经做了clear和destroy操作，这里不必重复
     *
     * @param webView
     */
    private void dumpWebView(WebView webView) {
        webView.stopLoading();
        webView.getSettings().setJavaScriptEnabled(false);
        webView.clearCache(false);
        webView.clearHistory();
        webView.loadUrl(BLANK_URL);
        webView.removeAllViews();
        callParentDropMe(webView);
        webView.onPause();
        webView.setWebChromeClient(null);
        webView.setWebViewClient(null);
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
    @SuppressLint("SetJavaScriptEnabled")
    @Override
    protected WebView createViewInstance(ThemedReactContext reactContext) {
        AdvancedWebView webView = null;
        int size = mWebviews.size();
        if (size == 0) {//首次打开
            //新建webview
            webView = initWebview(reactContext);
            //将webview加入队列
            mWebviews.add(webView);
        } else if (size == 1 && mWebviews.get(0).getParent() == null) {
            //曾经打开过，再重新打开
            //将webview队列仅存的一个设置为默认
            //赋值
            webView = mWebviews.get(0);
            reConfigWebview(webView);
            resumeWebview(webView);
        } else if (mWebviews.getLast().getParent() != null) {
            //非首次打开，文档中开启文档
            //休眠其它的webview
            pauseBefores();
            //新建webview
            webView = initWebview(reactContext);
            //设置它为默认
            //将webview加入队列
            mWebviews.add(webView);
        }
        if (webView == null) {
            //解决多次创建webview的bug，此处有个隐患，目前RN多次重复创建都会有销毁动作，但是未来
            //如果只有创建没有销毁动作，有可能会有多个界面
            webView = initWebview(reactContext);
            pauseBefores();
            mWebviews.add(webView);
        }
        return webView;
    }

    private void reConfigWebview(AdvancedWebView webView) {
        webView.setWebChromeClient(new WebChromeClient() {
            @Override
            public void onGeolocationPermissionsShowPrompt(String origin, GeolocationPermissions.Callback callback) {
                callback.invoke(origin, true, false);
            }
        });
        webView.setWebViewClient(new AdvancedWebViewClient());
    }

    /**
     * 重置页面，解决第二次加载失败的bug
     *
     * @param webView
     */
    private void resetPage(WebView webView) {
        // 禁用 JavaScript 防止有脚本阻止了页面的重置
        // 在重置页面之后不需要再次调用 .setJavaScriptEnabled(true)
        // 下个 ReactWebView 在初始化的时候会去主动调用父类的 setJavaScriptEnabled
        webView.stopLoading();
        webView.getSettings().setJavaScriptEnabled(false);
        webView.loadUrl(BLANK_URL);
    }

    /**
     * 初始化webview实例，刷新document
     *
     * @param reactContext
     * @return
     */
    @SuppressLint("SetJavaScriptEnabled")
    public AdvancedWebView initWebview(final ThemedReactContext reactContext) {
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
        webView.getSettings().setDomStorageEnabled(true);
        mWebViewConfig.configWebView(webView);
        reactContext.addLifecycleEventListener(webView);
        // Fixes broken full-screen modals/galleries due to body height being 0.
        webView.setLayoutParams(
                new ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT,
                        ViewGroup.LayoutParams.MATCH_PARENT));

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            if (mEnvValue == 1 || DEBUG_MODEL || BuildConfig.DEBUG) {
                WebView.setWebContentsDebuggingEnabled(true);
            } else {
                WebView.setWebContentsDebuggingEnabled(false);
            }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            // chromium, enable hardware acceleration
            webView.setLayerType(WebView.LAYER_TYPE_HARDWARE, null);
        } else {
            // older android version, disable hardware acceleration
            webView.setLayerType(WebView.LAYER_TYPE_SOFTWARE, null);
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            webView.getSettings().setMixedContentMode(WebSettings.MIXED_CONTENT_ALWAYS_ALLOW);
        }
        return webView;
    }

    protected class AdvancedWebViewClient extends ReactWebViewClient {
        protected ArrayList<String> mPendingMessages = new ArrayList<>();
        protected volatile boolean mPageFinished = false;

        @Override
        public void onPageFinished(WebView webView, String url) {
            super.onPageFinished(webView, url);
            mPageFinished = true;
            AdvancedWebView reactWebView = (AdvancedWebView) webView;
            reactWebView.linkBridge();

            for (String message : mPendingMessages) {
                webView.evaluateJavascript(message, null);
            }
            mPendingMessages.clear();
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
                    String message = "(function () {" +
                            "var event;" +
                            "var data = " + eventInitDict.toString() + ";" +
                            "try {" +
                            "event = new MessageEvent('message', data);" +
                            "} catch (e) {" +
                            "event = document.createEvent('MessageEvent');" +
                            "event.initMessageEvent('message', true, true, data.data, data.origin, data.lastEventId, data.source);" +
                            "}" +
                            "document.dispatchEvent(event);" +
                            "})();";
                    AdvancedWebViewClient webViewClient = (AdvancedWebViewClient)((AdvancedWebView) root).getWebViewClient();
                    if (webViewClient.mPageFinished) {
                        root.evaluateJavascript(message, null);
                    } else {
                        webViewClient.mPendingMessages.add(message);
                    }
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

    /**
     * 焦点变化时调用（既没有设置自定义item也没有是设置白名单<mMenuIdTitles==null&&mWhiteList==null>，即为不使用自定义ActionMode）
     * <p>
     * 对页面小白条的初始化工作,存储顺序即为展现顺序,id必须唯一且最好用数字字符串，不要从10以内的数字开始
     *
     * @param idTitles key:每个item所对应的id，value:每个item的title
     */
    @ReactMethod
    public void setActionModeMenu(ReadableMap idTitles) {
        if (mMenuIdTitles != null) {
            mMenuIdTitles.clear();
        }
        if (idTitles == null) {
            return;
        }
        ReadableMapKeySetIterator it = idTitles.keySetIterator();
        while (it.hasNextKey()) {
            String key = it.nextKey();
            String title = idTitles.getString(key);
            int id = Integer.valueOf(key);
            mMenuIdTitles.put(id, title);
        }
    }

    /**
     * 焦点变化时调用，或者界面的规则一致时只调用一次即可（既没有设置自定义item也没有是设置白名单<mMenuIdTitles==null&&mWhiteList==null>，即为不使用自定义ActionMode）
     * <p>
     * 对页面小白条的初始化工作,加入进来的title，如果系统本身自带的title与之相同将不会被删除
     * 例如"复制"，传入的列表内包含"复制"，那么系统的将被保留，如果不包含，系统所带的"复制"将被删除
     *
     * @param titles 白名单列表
     */
    @ReactMethod
    public void setActionModeMenuWhitelist(ReadableArray titles) {
        if (mWhiteList != null) {
            mWhiteList.clear();
        }
        if (titles == null) {
            return;
        }
        for (Object title :
                titles.toArrayList()) {
            mWhiteList.add((String) title);
        }
    }
}
