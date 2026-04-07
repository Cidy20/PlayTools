//
//  PTGamepadHook.m
//  PlayTools
//

#import "PTGamepadHook.h"
#import <GameController/GameController.h>
#import <objc/runtime.h>

@implementation PTGamepadHook

+ (void)inject {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class gcClass = [GCController class];
        SEL originalSelector = @selector(controllers);
        SEL swizzledSelector = @selector(pt_controllers);
        
        Method originalMethod = class_getClassMethod(gcClass, originalSelector);
        Method swizzledMethod = class_getClassMethod(self, swizzledSelector);
        
        // 由于是类方法 (Class Method)，我们需要操作 MetaClass
        Class metaClass = object_getClass(gcClass);
        BOOL didAddMethod = class_addMethod(metaClass,
                                            swizzledSelector,
                                            method_getImplementation(swizzledMethod),
                                            method_getTypeEncoding(swizzledMethod));
        
        if (didAddMethod) {
            class_replaceMethod(metaClass,
                                originalSelector,
                                method_getImplementation(swizzledMethod),
                                method_getTypeEncoding(swizzledMethod));
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod);
        }
        
        NSLog(@"PlayTools: [SUCCESS] System +[GCController controllers] Hooked via Obj-C!");
        
        // 伪造系统级的“手柄接入广播”
        // 延迟一下，确保游戏代码里的 NotificationCenter 监听器已经挂载好了
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            Class virtualGamepadClass = NSClassFromString(@"GCVirtualGamepad");
            if (virtualGamepadClass) {
                // 通过反射调用 Swift 的单例 shared
                id sharedGamepad = [virtualGamepadClass performSelector:NSSelectorFromString(@"shared")];
                if (sharedGamepad) {
                    NSArray *fakeControllers = [sharedGamepad performSelector:NSSelectorFromString(@"controllers")];
                    if (fakeControllers.count > 0) {
                        GCController *fake = fakeControllers.firstObject;
                        [[NSNotificationCenter defaultCenter] postNotificationName:GCControllerDidConnectNotification object:fake];
                        NSLog(@"PlayTools: [SUCCESS] Broadcasted FAKE GCControllerDidConnectNotification to SDK.");
                    }
                }
            }
        });
    });
}

// 这是替换系统 `+[GCController controllers]` 的李鬼方法
+ (NSArray<GCController *> *)pt_controllers {
    // 调用 pt_controllers 其实会跑到系统的原生实现里（因为已经被 Swizzle 交换了）
    NSArray<GCController *> *original = [self pt_controllers];
    NSMutableArray *mut = [NSMutableArray arrayWithArray:original ?: @[]];
    
    // 动态调用 Swift 中的虚拟手柄
    Class virtualGamepadClass = NSClassFromString(@"GCVirtualGamepad");
    if (virtualGamepadClass) {
        id sharedGamepad = [virtualGamepadClass performSelector:NSSelectorFromString(@"shared")];
        if (sharedGamepad) {
            NSArray *fakeControllers = [sharedGamepad performSelector:NSSelectorFromString(@"controllers")];
            if (fakeControllers && fakeControllers.count > 0) {
                [mut addObjectsFromArray:fakeControllers];
            }
        }
    }
    
    return [mut copy];
}

@end
