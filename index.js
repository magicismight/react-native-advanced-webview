import React, { PropTypes, cloneElement } from 'react';
import { WebView, UIManager, NativeModules } from 'react-native';
import createReactNativeComponentClass from 'react-native/Libraries/Renderer/src/renderers/native/createReactNativeComponentClass';

export default class extends WebView {

    static displayName = 'AdvancedWebView';

    static propTypes = {
        ...WebView.propTypes,
        initialJavaScript: PropTypes.string,
        allowFileAccessFromFileURLs: PropTypes.bool,
        enableMessageOnLoadStart: PropTypes.bool,
        hideAccessory: PropTypes.bool
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

    takeSnapshot = (options ?: {
        x ?: number,
        y ?: number,
        width ?: number,
        height ?: number,
        format ?: 'png' | 'jpeg',
        quality ?: number,
    }) => {
        return NativeModules.RNAdvancedWebViewManager.takeSnapshot(this.getWebViewHandle(), {...options});
    };

    injectJavaScript = (data) => {
        UIManager.dispatchViewManagerCommand(
            this.getWebViewHandle(),
            UIManager.RNAdvancedWebView.Commands.injectJavaScript,
            [data]
        );
    };

    render() {
        const wrapper = super.render();
        const [webview,...children] = wrapper.props.children;
        const { hideAccessory, initialJavaScript, allowFileAccessFromFileURLs, enableMessageOnLoadStart } = this.props;

        const advancedWebview = (
            <RNAdvancedWebView
                {...webview.props}
                ref="webview"
                initialJavaScript={initialJavaScript}
                allowFileAccessFromFileURLs={allowFileAccessFromFileURLs}
                enableMessageOnLoadStart={enableMessageOnLoadStart}
                hideAccessory={hideAccessory}
            />
        );

        return cloneElement(wrapper, wrapper.props, advancedWebview, ...children);
    }
}

const RNAdvancedWebView = createReactNativeComponentClass({
    validAttributes: {
        ...UIManager.RCTWebView.validAttributes,
        initialJavaScript: true,
        allowFileAccessFromFileURLs: true,
        enableMessageOnLoadStart: true,
        hideAccessory: true
    },
    uiViewClassName: 'RNAdvancedWebView'
});
