import React, { PropTypes, cloneElement } from 'react';
import { WebView, UIManager, NativeModules } from 'react-native';
import createReactNativeComponentClass from 'react-native/Libraries/Renderer/src/renderers/native/createReactNativeComponentClass';

const AdvancedWebViewManager = NativeModules.RNAdvancedWebViewManager;

export default class extends WebView {

    static displayName = 'AdvancedWebView';

    static propTypes = {
        ...WebView.propTypes,
        keyboardDisplayRequiresUserAction: PropTypes.bool,
        allowFileAccessFromFileURLs: PropTypes.bool,
        hideAccessory: PropTypes.bool,
        validSchemes: PropTypes.array
    };

    goForward = () => {
        UIManager.dispatchViewManagerCommand(
            this.getWebViewHandle(),
            UIManager.RNAdvancedWebView.Commands.goForward,
            null
        );
    };

    goBack = () => {
        UIManager.dispatchViewManagerCommand(
            this.getWebViewHandle(),
            UIManager.RNAdvancedWebView.Commands.goBack,
            null
        );
    };

    reload = () => {
        UIManager.dispatchViewManagerCommand(
            this.getWebViewHandle(),
            UIManager.RNAdvancedWebView.Commands.reload,
            null
        );
    };

    stopLoading = () => {
        UIManager.dispatchViewManagerCommand(
            this.getWebViewHandle(),
            UIManager.RNAdvancedWebView.Commands.stopLoading,
            null
        );
    };

    postMessage = (data) => {
        UIManager.dispatchViewManagerCommand(
            this.getWebViewHandle(),
            UIManager.RNAdvancedWebView.Commands.postMessage,
            [String(data)]
        );
    };

    injectJavaScript = (data) => {
        UIManager.dispatchViewManagerCommand(
            this.getWebViewHandle(),
            UIManager.RNAdvancedWebView.Commands.injectJavaScript,
            [data]
        );
    };

    /**
     * Indicating whether there is a back item in the back-forward list that can be navigated to
     */
    canGoBack = () => {
        return AdvancedWebViewManager.canGoBack(this.getWebViewHandle());
    };

    /**
     * Indicating whether there is a forward item in the back-forward list that can be navigated to
     */
    canGoForward = () => {
        return AdvancedWebViewManager.canGoForward(this.getWebViewHandle());
    };

    evaluateJavaScript = (js) => {
        return AdvancedWebViewManager.evaluateJavaScript(this.getWebViewHandle(), js);
    };

    _onLoadingError = (event) => {
        event.persist(); // persist this event because we need to store it
        var { onError, onLoadEnd } = this.props;
        var result = onError && onError(event);
        onLoadEnd && onLoadEnd(event);
        console.warn('Encountered an error loading page', event.nativeEvent);

        result !== false && this.setState({
            lastErrorEvent: event.nativeEvent,
            viewState: 'ERROR'
        });
    };

    onLoadingError = (event) => {
        this._onLoadingError(event);
    };

    render() {
        const wrapper = super.render();
        const [webview, ...children] = wrapper.props.children;
        const { hideAccessory, allowFileAccessFromFileURLs, keyboardDisplayRequiresUserAction } = this.props;

        const advancedWebview = (
            <RNAdvancedWebView
                {...webview.props}
                ref="webview"
                allowFileAccessFromFileURLs={allowFileAccessFromFileURLs}
                keyboardDisplayRequiresUserAction={keyboardDisplayRequiresUserAction}
                hideAccessory={hideAccessory}
            />
        );

        return cloneElement(wrapper, wrapper.props, advancedWebview, ...children);
    }
}

const RNAdvancedWebView = createReactNativeComponentClass({
    validAttributes: {
        ...UIManager.RCTWebView.validAttributes,
        allowFileAccessFromFileURLs: true,
        hideAccessory: true,
        keyboardDisplayRequiresUserAction: true
    },
    uiViewClassName: 'RNAdvancedWebView'
});
