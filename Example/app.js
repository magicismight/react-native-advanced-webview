import React, { Component } from 'react';
import { AppRegistry, StyleSheet } from 'react-native';

import AdvancedWebView from 'react-native-advanced-webview';

const initialJavaScript = `
document.body.style.background = 'red';
var span = document.createElement('span');
span.innerHTML = 'aaaa';
document.body.appendChild(span)
`;
const injectedJavaScript = `
document.write(document.cookie);
`;


export default class webview extends Component {
    render() {

        return (
            <AdvancedWebView
                style={styles.webview}
                ref="webviewbridge"
                initialJavaScript={initialJavaScript}
                injectedJavaScript={injectedJavaScript}
                source={{uri: 'http://shimo.im'}}
            />
        );
    }
}

const styles = StyleSheet.create({
    webview: {
        flex: 1
    }
});

AppRegistry.registerComponent('webview', () => webview);
