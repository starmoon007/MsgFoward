//
//  Car.m
//  MsgFoward
//
//  Created by NULL on 2018/4/11.
//  Copyright © 2018年 NULL. All rights reserved.
//

#import "Car.h"
#import <objc/runtime.h>

#import "Plane.h"
#import "Ship.h"
@implementation Car


void travel(id self, SEL _cmd){
    NSLog(@"travel");
}

//+ (BOOL)resolveClassMethod:(SEL)sel{
//
//}


+ (BOOL)resolveInstanceMethod:(SEL)sel{
    
    NSString *selStr = NSStringFromSelector(sel);
    NSLog(@"resolveInstanceMethod: %@", selStr);
    
    if ([selStr isEqualToString:@"travel"]){
        class_addMethod([self class], sel, (IMP)travel, "V@:");
        return  YES;
    }
    
    
    return [super resolveInstanceMethod:sel];
    
}


- (id)forwardingTargetForSelector:(SEL)aSelector{
    NSString *selStr = NSStringFromSelector(aSelector);
    NSLog(@"forwardingTargetForSelector: %@", selStr);
    
    if ([selStr isEqualToString:@"fly"]){
        Plane *plane = [[Plane alloc] init];
        
        return plane;
    }
    
    return [super forwardingTargetForSelector:aSelector];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector{
    
    NSString *selStr = NSStringFromSelector(aSelector);
    NSLog(@"methodSignatureForSelector: %@", selStr);
    if ([selStr isEqualToString:@"sail"]){
        
        return  [NSMethodSignature signatureWithObjCTypes:"V@:@:"];
    }
    
    return [super methodSignatureForSelector:aSelector];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation{
    NSString *selStr = NSStringFromSelector([anInvocation selector]);
    NSLog(@"forwardInvocation: %@", selStr);
    if ([selStr isEqualToString:@"sail"]){
        Ship *ship = [[Ship alloc] init];
        [anInvocation invokeWithTarget:ship];
        return;
    }
    
    
    return [super forwardInvocation:anInvocation];
}

- (void)doesNotRecognizeSelector:(SEL)aSelector{
    
    NSLog(@"%s",__func__);
    [super doesNotRecognizeSelector:aSelector];
    
}

@end
