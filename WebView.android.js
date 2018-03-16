import React, { cloneElement } from 'react';
import { WebView, UIManager, requireNativeComponent } from 'react-native';
import PropTypes from 'prop-types';

export default class extends WebView {

    static displayName = 'AdvancedWebView';

    static propTypes = {
        ...WebView.propTypes,
        keyboardDisplayRequiresUserAction: PropTypes.bool,
        allowFileAccessFromFileURLs: PropTypes.bool,
        hideAccessory: PropTypes.bool,
        webviewDebugEnabledWhenDev: PropTypes.number
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

    _onLoadingError = (event) => {
        event.persist(); // persist this event because we need to store it
        var {onError, onLoadEnd} = this.props;
        var result = onError && onError(event);
        onLoadEnd && onLoadEnd(event);
        console.warn('Encountered an error loading page', event.nativeEvent);

        result !== false && this.setState({
            lastErrorEvent: event.nativeEvent,
            viewState: 'ERROR'
        });
    };

    onLoadingError = (event) => {
        this._onLoadingError(event)
    };

    render() {
        const wrapper = super.render();
        const [webview,...children] = wrapper.props.children;
        const { hideAccessory, allowFileAccessFromFileURLs, keyboardDisplayRequiresUserAction,webviewDebugEnabledWhenDev} = this.props;

        const advancedWebview = (
            <RNAdvancedWebView
                {...webview.props}
                ref="webview"
                allowFileAccessFromFileURLs={allowFileAccessFromFileURLs}
                keyboardDisplayRequiresUserAction={keyboardDisplayRequiresUserAction}
                hideAccessory={hideAccessory}
                webviewDebugEnabledWhenDev={webviewDebugEnabledWhenDev}
            />
        );

        return cloneElement(wrapper, wrapper.props, advancedWebview, ...children);
    }
}

const RNAdvancedWebView = requireNativeComponent('RNAdvancedWebView', null, {
    nativeOnly: {
        allowFileAccessFromFileURLs: true,
        hideAccessory: true,
        keyboardDisplayRequiresUserAction: true,
        webviewDebugEnabledWhenDev: true
    }
})
