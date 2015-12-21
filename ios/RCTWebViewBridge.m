/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * Copyright (c) 2015-present, Ali Najafizadeh (github.com/alinz)
 * All rights reserved
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "RCTWebViewBridge.h"

@import WebKit;

#import "RCTAutoInsetsProtocol.h"
#import "RCTEventDispatcher.h"
#import "RCTLog.h"
#import "RCTUtils.h"
#import "RCTView.h"

//This is a very elegent way of defining multiline string in objective-c.
//source: http://stackoverflow.com/a/23387659/828487
#define NSStringMultiline(...) [[NSString alloc] initWithCString:#__VA_ARGS__ encoding:NSUTF8StringEncoding]

void (^nullBlock)(id, NSError *)  = ^(id outcome, NSError * error) {};


@interface RCTWebViewBridge () <WKScriptMessageHandler, WKNavigationDelegate, RCTAutoInsetsProtocol>

@property (nonatomic, copy) RCTDirectEventBlock onLoadingStart;
@property (nonatomic, copy) RCTDirectEventBlock onLoadingFinish;
@property (nonatomic, copy) RCTDirectEventBlock onLoadingError;
@property (nonatomic, copy) RCTDirectEventBlock onNativeMessage;

@end

@implementation RCTWebViewBridge
{
  WKWebView *_webView;
  NSString *_injectedJavaScript;
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if ((self = [super initWithFrame:frame])) {
    super.backgroundColor = [UIColor clearColor];
    _automaticallyAdjustContentInsets = YES;
    _contentInset = UIEdgeInsetsZero;
    WKUserContentController *userController = [[WKUserContentController alloc] init];
    [userController addUserScript: [
      [WKUserScript alloc] initWithSource: self.webViewBridgeScript
        injectionTime: WKUserScriptInjectionTimeAtDocumentStart
        forMainFrameOnly: TRUE
      ]
    ];
    [userController addScriptMessageHandler: self name: @"bridgeMessage"];
      
    WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
    configuration.userContentController = userController;
    _webView = [[WKWebView alloc] initWithFrame:self.bounds configuration:configuration];
    _webView.navigationDelegate = self;
    [self addSubview:_webView];
  }
  return self;
}

RCT_NOT_IMPLEMENTED(- (instancetype)initWithCoder:(NSCoder *)aDecoder)

- (void)goForward
{
  [_webView goForward];
}

- (void)goBack
{
  [_webView goBack];
}

- (void)reload
{
  [_webView reload];
}

- (void) evaluateJS: (NSString *)javaScriptString completionHandler: (id)completionHandler
{
  [_webView evaluateJavaScript:javaScriptString completionHandler: completionHandler];
}

- (void) sendMessageToJS: (id)message
{
  [self evaluateJS: [self objectToJsonString: message] completionHandler: nullBlock];
}

- (NSString*)objectToJsonString:(id)object
{
  NSError *error;
  NSData *jsonData = [NSJSONSerialization dataWithJSONObject:object
                                                     options: 0
                                                       error:&error];

  if (! jsonData) {
    NSLog(@"objectToJsonString: error: %@", error.localizedDescription);
    return @"";
  } else {
    NSString *json = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    return [NSString stringWithFormat:@"WebViewBridge.receive(%@);", json];
  }

}


- (NSURL *)URL
{
  return _webView.URL;
}

- (void)setURL:(NSURL *)URL
{
  // Because of the way React works, as pages redirect, we actually end up
  // passing the redirect urls back here, so we ignore them if trying to load
  // the same url. We'll expose a call to 'reload' to allow a user to load
  // the existing page.
  if ([URL isEqual:_webView.URL]) {
    return;
  }
  if (!URL) {
    // Clear the webview
    [_webView loadHTMLString:@"" baseURL:nil];
    return;
  }
  [_webView loadRequest:[NSURLRequest requestWithURL:URL]];
}

- (void)setHTML:(NSString *)HTML
{
  [_webView loadHTMLString:HTML baseURL:nil];
}

- (void)layoutSubviews
{
  [super layoutSubviews];
  _webView.frame = self.bounds;
}

- (void)setContentInset:(UIEdgeInsets)contentInset
{
  _contentInset = contentInset;
  [RCTView autoAdjustInsetsForView:self
                    withScrollView:_webView.scrollView
                      updateOffset:NO];
}

- (void)setBackgroundColor:(UIColor *)backgroundColor
{
  CGFloat alpha = CGColorGetAlpha(backgroundColor.CGColor);
  self.opaque = _webView.opaque = (alpha == 1.0);
  _webView.backgroundColor = backgroundColor;
}

- (UIColor *)backgroundColor
{
  return _webView.backgroundColor;
}

- (NSMutableDictionary<NSString *, id> *)baseEvent
{
  NSMutableDictionary<NSString *, id> *event = [[NSMutableDictionary alloc] initWithDictionary:@{
    @"url": _webView.URL.absoluteString ?: @"",
    @"loading" : @(_webView.loading),
    @"title": _webView.title,
    @"canGoBack": @(_webView.canGoBack),
    @"canGoForward" : @(_webView.canGoForward),
  }];

  return event;
}

- (void)refreshContentInset
{
  [RCTView autoAdjustInsetsForView:self
                    withScrollView:_webView.scrollView
                      updateOffset:YES];
}


#pragma mark - WKScriptMessageHandler
- (void) userContentController: (WKUserContentController *)userContentController didReceiveScriptMessage: (WKScriptMessage *)message
{
    if (_onNativeMessage) {
      NSMutableDictionary<NSString *, id> *event = [self baseEvent];
      [event addEntriesFromDictionary: @{
        @"message": message.body
      }];
      
      _onNativeMessage(event);
    }
}

#pragma mark - WKNavigationDelegate

- (void) webView: (WKWebView *)webView didStartProvisionalNavigation: (WKNavigation *)navigation
{
  NSURL* url = webView.URL;

  if (_onLoadingStart) {
    NSMutableDictionary<NSString *, id> *event = [self baseEvent];
    [event addEntriesFromDictionary: @{
      @"url": url.absoluteString
    }];
    _onLoadingStart(event);
  }
}

- (void) webView: (WKWebView *)webView didFailProvisionalNavigation: (WKNavigation *)navigation withError: (NSError *)error
{
  if (_onLoadingError) {
    if ([error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorCancelled) {
      // NSURLErrorCancelled is reported when a page has a redirect OR if you load
      // a new URL in the WebView before the previous one came back. We can just
      // ignore these since they aren't real errors.
      // http://stackoverflow.com/questions/1024748/how-do-i-fix-nsurlerrordomain-error-999-in-iphone-3-0-os
      return;
    }

    NSMutableDictionary<NSString *, id> *event = [self baseEvent];
    [event addEntriesFromDictionary:@{
      @"domain": error.domain,
      @"code": @(error.code),
      @"description": error.localizedDescription,
    }];
    _onLoadingError(event);
  }
}



- (void) webView: (WKWebView *)webView didFinishNavigation: (WKNavigation *)navigation
{
  //injecting WebViewBridge Script
  if (_injectedJavaScript != nil) {
    [webView evaluateJavaScript:_injectedJavaScript
      completionHandler:^(id outcome, NSError *error) {
        NSMutableDictionary<NSString *, id> *event = [self baseEvent];
        event[@"jsEvaluationValue"] = outcome;
     
        _onLoadingFinish(event);
      }
    ];
  }
  // we only need the final 'finishLoad' call so only fire the event when we're actually done loading.
  else if (_onLoadingFinish && !webView.loading && ![webView.URL.absoluteString isEqualToString:@"about:blank"]) {
    _onLoadingFinish([self baseEvent]);
  }
  
}

//since there is no easy way to load the static lib resource in ios,
//we are loading the script from this method.
- (NSString *) webViewBridgeScript {

  return NSStringMultiline(
    (function (window) {
      'use strict';

      //Make sure that if WebViewBridge already in scope we don't override it.
      if (window.WebViewBridge) {
        return;
      }

      function callFunc(func, message) {
        if ('function' === typeof func) {
          func(message);
        }
      }

      var WebViewBridge = {
        
        receive: function (message) {
          callFunc(WebViewBridge.onMessageReceived, message);
        },
          
        send: function (message) {
          window.webkit.messageHandlers.bridgeMessage.postMessage(message);
          callFunc(this.onMessageSent, message);
        },
        onMessageReceived: null,
        onMessageSent: null,
      };

      window.WebViewBridge = WebViewBridge;

      //dispatch event
      var customEvent = doc.createEvent('Event');
      customEvent.initEvent('WebViewBridge', true, true);
      window.document.dispatchEvent(customEvent);
    }(window));
  );
}

@end
