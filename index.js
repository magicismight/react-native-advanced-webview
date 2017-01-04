import React, { PropTypes, cloneElement } from 'react';
import { WebView, UIManager } from 'react-native';
import createReactNativeComponentClass from 'react-native/Libraries/Renderer/src/renderers/native/createReactNativeComponentClass';

export default class extends WebView {

    static displayName = 'AdvancedWebView';

    static propTypes = {
        ...WebView.propTypes,
        initialJavaScript: PropTypes.string,
        allowFileAccessFromFileURLs: PropTypes.bool
    };

    render() {
        const wrapper = super.render();
        const [webview,...children] = wrapper.props.children;

        const advancedWebview = (
            <RNAdvancedWebView
                {...webview.props}
                initialJavaScript={this.props.initialJavaScript}
                allowFileAccessFromFileURLs={this.props.allowFileAccessFromFileURLs}
            />
        );

        return cloneElement(wrapper, wrapper.props, advancedWebview, ...children);
    }
}

const RNAdvancedWebView = createReactNativeComponentClass({
    validAttributes: {
        ...UIManager.RCTWebView.validAttributes,
        initialJavaScript: true,
        allowFileAccessFromFileURLs: true
    },
    uiViewClassName: 'RNAdvancedWebView'
});
