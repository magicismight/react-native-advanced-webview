//
//  UIScrollView+adjustedContentInset.m
//  RNAdvancedWebView
//
//  Created by Bell Zhong on 2018/5/3.
//  Copyright © 2018年 shimo. All rights reserved.
//

#import "UIScrollView+adjustedContentInset.h"
#import <objc/runtime.h>

/**
 fix: `_webView.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;` do not work
 */
@implementation UIScrollView (adjustedContentInset)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method originMethod = class_getInstanceMethod(self, @selector(adjustedContentInset));
        Method presentMethod = class_getInstanceMethod(self, @selector(shm_adjustedContentInset));
        method_exchangeImplementations(originMethod, presentMethod);
    });
}

- (UIEdgeInsets)shm_adjustedContentInset {
    if ([self isKindOfClass:NSClassFromString(@"WKScrollView")]) {
       return UIEdgeInsetsZero;
    } else {
        return [self shm_adjustedContentInset];
    }
}

@end
