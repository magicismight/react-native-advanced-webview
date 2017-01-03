import React, { PropTypes, cloneElement } from 'react';
import { WebView, requireNativeComponent } from 'react-native';

export default class AdvancedWebView extends WebView {
    static displayName = 'AdvancedWebview';
    static propTypes = {
        ...WebView.propTypes,
        initialJavaScript: PropTypes.string,
        allowFileAccessFromFileURLs: PropTypes.bool
    };

    render() {
        const wrapper = super.render();
        const [webview,...children] = wrapper.props.children;
        const { allowFileAccessFromFileURLs, initialJavaScript } = this.props;

        const advancedWebview = (
            <RNAdvancedWebView
                {...webview.props}
                initialJavaScript={initialJavaScript}
                allowFileAccessFromFileURLs={allowFileAccessFromFileURLs}
            />
        );

        return cloneElement(wrapper, wrapper.props, advancedWebview, ...children);
    }
}

const RNAdvancedWebView = requireNativeComponent('RNAdvancedWebView', AdvancedWebView, {
    nativeOnly: {
        messagingEnabled: PropTypes.bool
    }
});
