##### OC消息转发

oc中的调用对象或者类不存在的方法,会执行一遍消息转发流程.消息转发主要包括4步

1. 首先调用`+ (BOOL)resolveInstanceMethod:(SEL)sel` 或者 `+ (BOOL)resolveClassMethod:(SEL)sel`方法, 前者是找不到示例方法实现时调用, 后者是找不到类方法实现时调用

    
```
// Car.m

void travel(id self, SEL _cmd){
    NSLog(@"travel");
}

+ (BOOL)resolveInstanceMethod:(SEL)sel{
    
    NSString *selStr = NSStringFromSelector(sel);
    NSLog(@"resolveInstanceMethod: %@", selStr);
    
    if ([selStr isEqualToString:@"travel"]){
        class_addMethod([self class], sel, (IMP)travel, "V@:");
        return  YES;
    }
    
    
    return [super resolveInstanceMethod:sel];
    
}
```
当Car示例调用travel方式且真实未实现`- (void)travel`方法时, 会触发`+ (BOOL)resolveInstanceMethod:(SEL)sel`, 该方法需要返回一个Bool类型的返回值, 我们可以使用runtime动态的为该类添加一个方法并且返回YES. `ps:一定记得对未特殊处理的方法调用, 需要执行[super resolveInstanceMethod:sel] 让其走消息转发后续方法.`

打印结果:
    
```
resolveInstanceMethod: travel
travel
```

讨论: 该方法返回YES后后续执行了什么操作了?
    从上述打印结果可知确实执行了travel函数,
    当我们注释掉
```
//        class_addMethod([self class], sel, (IMP)travel, "V@:");
```
改行再执行时,控制台输出日志:
```
-[Car travel]: unrecognized selector sent to instance 0x60400001d2e0
*** Terminating app due to uncaught exception 'NSInvalidArgumentException', reason: '-[Car travel]: unrecognized selector sent to instance 0x60400001d2e0'
```
    推测结论:
        该方法返回YES后,会再执行一次`travel`方法调用流程;

2. 让Car示例执行`fly`方法,观察消息转发第二步`- (id)forwardingTargetForSelector:(SEL)aSelector`方法

```
// Car.m
- (id)forwardingTargetForSelector:(SEL)aSelector{
    NSString *selStr = NSStringFromSelector(aSelector);
    NSLog(@"forwardingTargetForSelector: %@", selStr);
    
    if ([selStr isEqualToString:@"fly"]){
        Plane *plane = [[Plane alloc] init];
        
        return plane;
    }
    
    return [super forwardingTargetForSelector:aSelector];
}

// Plane.m

- (void)fly{
    NSLog(@"%s",__func__);
}

```
在该方法中, 我们可以将消息转发给一个其他示例的对象, 新对象执行fly方法
打印结果:
    
```
2018-04-11 10:03:20.659910+0800 MsgFoward[1506:68168] resolveInstanceMethod: fly
2018-04-11 10:03:20.660417+0800 MsgFoward[1506:68168] forwardingTargetForSelector: fly
2018-04-11 10:03:20.661090+0800 MsgFoward[1506:68168] -[Plane fly]
```
讨论:
    该步有什么实际运用没?
    全局NSTimer target? ~~后续补充~~
    实际运用:
    [iOS 基于消息转发机制实现弱引用计时器](https://www.jianshu.com/p/061fbb08057b)
3. 如果第二步还没有补救的话,会执行第三步, 主要包含两个方法`- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector` `- (void)forwardInvocation:(NSInvocation *)anInvocation`
让Car示例对象执行`sail`方法

```
// Car.m
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
```

打印结果:

```
2018-04-11 10:22:18.984898+0800 MsgFoward[1711:81257] resolveInstanceMethod: sail
2018-04-11 10:22:18.985109+0800 MsgFoward[1711:81257] forwardingTargetForSelector: sail
2018-04-11 10:22:18.985424+0800 MsgFoward[1711:81257] methodSignatureForSelector: sail
2018-04-11 10:22:18.985736+0800 MsgFoward[1711:81257] resolveInstanceMethod: _forwardStackInvocation:
2018-04-11 10:22:18.985982+0800 MsgFoward[1711:81257] forwardInvocation: sail
2018-04-11 10:22:18.986165+0800 MsgFoward[1711:81257] -[Ship sail]
```
`- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector`方法需要返回一个方法签名, 如果该方法未处理,是不会执行后续的`- (void)forwardInvocation:(NSInvocation *)anInvocation`方法的

`- (void)forwardInvocation:(NSInvocation *)anInvocation`方法中可以 指定其他Target来执行anInvocation中的Sel

4. 如果还未处理的话, 会执行最后一步`- (void)doesNotRecognizeSelector:(SEL)aSelector`

    如果重写该方法,并不执行父类的该方法, 所有的`unrecognized selector sent to instance`的报错都不会导致实际的crash, 但是苹果强烈反对我们这么做.在程序运行角度来说, 方法调用流程执行到这步实际已经没有什么补救的措施了, 也应该抛出异常,即使这个地方不抛出异常也可能导致程序后续执行出现问题.
    讨论:
        那这方法有什么实际的用处吗 ?
        实际我们可以在该方法里面做一些记录日志输出之类的, 帮组我们定位线上的问题.

[demo](https://github.com/starmoon007/MsgFoward)


