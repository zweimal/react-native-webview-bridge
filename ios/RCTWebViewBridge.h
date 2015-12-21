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

#import "RCTView.h"
@import WebKit;

@class RCTWebViewBridge;

@interface RCTWebViewBridge : RCTView

@property (nonatomic, strong) NSURL * URL;
@property (nonatomic, assign) UIEdgeInsets contentInset;
@property (nonatomic, assign) BOOL automaticallyAdjustContentInsets;
@property (nonatomic, copy) NSString *injectedJavaScript;

- (void) goForward;
- (void) goBack;
- (void) reload;
//- (void) evaluateJS: (NSString *)javaScriptString completionHandler: (RCTDirectEventBlock)completionHandler;
- (void) sendMessageToJS: (id)object;

@end
