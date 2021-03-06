# React Native WebView Javascript Bridge
I have been testing and reading a lot of way to safely create a bridge between react-native and webview. I'm happy to announced that the wait is over and from **React-Native 0.16 and above**, the bridge is fully functional.



## Installation

In order to use this extension, you have to do the following steps:

1. in your react-native project, run `npm install react-native-webview-bridge`
2. go to xcode's `Project Navigator` tab
<p align="center">
    <img src ="https://raw.githubusercontent.com/alinz/react-native-webview-bridge/master/doc/assets/01.png" />
</p>
3. right click on `Libraries`
4. select `Add Files to ...` option
<p align="center">
    <img src ="https://raw.githubusercontent.com/alinz/react-native-webview-bridge/master/doc/assets/02.png" />
</p>
5. navigate to `node_modules/react-native-webview-bridge/ios` and add `React-Native-Webview-Bridge.xcodeproj` folder
<p align="center">
    <img src ="https://raw.githubusercontent.com/alinz/react-native-webview-bridge/master/doc/assets/03.png" />
</p>
6. on project `Project Navigator` tab, click on your project's name and select Target's name and from there click on `Build Phases`
<p align="center">
    <img src ="https://raw.githubusercontent.com/alinz/react-native-webview-bridge/master/doc/assets/04.png" />
</p>
7. expand `Link Binary With Libraries` and click `+` sign to add a new one.
8. select `libReact-Native-Webviwe-Bridge.a` and click `Add` button.
<p align="center">
    <img src ="https://raw.githubusercontent.com/alinz/react-native-webview-bridge/master/doc/assets/05.png" />
</p>
9. clean compile to make sure your project can compile and build.

## Usage

just import the module with one of your choices way:

** CommonJS style **

```js
var WebViewBridge = require('react-native-webview-bridge');
```

** ES6/ES2015 style **

```js
import WebViewBridge from 'react-native-webview-bridge';
```

`WebViewBridge` is an extension of `WebView`. It injects special script into any pages once it loads. Also it extends the functionality of `WebView` by adding 1 new method and 1 new props.

#### sendToBridge(message)
the message must be in string. because this is the only way to send data back and forth between native and webview.


#### onBridgeMessage
this is a prop that needs to be a function. it will be called once a message is received from webview. The type of received message is also in string.


## Bridge Script

bridge script is a special script which injects into all the webview. It automatically register a global variable called `WebViewBridge`. It has 2 optional methods to implement and one method to send message to native side.

#### send(message)

this method sends a message to native side. the message must be in string type or `onError` method will be called.

#### onMessage

this method needs to be implemented. it will be called once a message arrives from native side. The type of message is in string.

#### onError

this is an error reporting method. It will be called if there is an error happens during sending a message. It receives a error message in string type.

## Notes

> a special bridge script will be injected once the page is going to different URL. So you don't have to manage when it needs to be injected.

> You can still pass your own javascript to be injected into webview. However, Bridge script will be injected first and then your custom script.


## Simple Example
This example can be found in `examples` folder.

```js
const injectScript = `
  function webViewBridgeReady(cb) {
    //checks whether WebViewBirdge exists in global scope.
    if (window.WebViewBridge) {
      cb(window.WebViewBridge);
      return;
    }

    function handler() {
      //remove the handler from listener since we don't need it anymore
      document.removeEventListener('WebViewBridge', handler, false);
      //pass the WebViewBridge object to the callback
      cb(window.WebViewBridge);
    }

    //if WebViewBridge doesn't exist in global scope attach itself to document
    //event system. Once the code is being injected by extension, the handler will
    //be called.
    document.addEventListener('WebViewBridge', handler, false);
  }

  webViewBridgeReady(function (webViewBridge) {
    WebViewBridge.onMessage = function (message) {
      alert('got a message from Native: ' + message);

      WebViewBridge.send("message from webview");
    };
  });
`;

var Sample2 = React.createClass({
  componentDidMount() {
    setTimeout(() => {
      this.refs.webviewbridge.sendToBridge("hahaha");
    }, 5000);
  },
  onBridgeMessage: function (message) {
    console.log(message);
  },
  render: function() {
    return (
      <WebViewBridge
        ref="webviewbridge"
        onBridgeMessage={this.onBridgeMessage}
        injectedJavaScript={injectScript}
        url={"http://google.com"}/>
    );
  }
});
```
