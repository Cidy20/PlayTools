//
//  PTGamepadHook.m
//  PlayTools
//

#import "PTGamepadHook.h"
#import <GameController/GameController.h>
#import <objc/runtime.h>

@implementation PTGamepadHook

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // 自动注入：在 PlayTools 框架加载时（早于游戏运行）立刻 Hook
        Class gcClass = NSClassFromString(@"GCController");
        if (!gcClass) return;
        
        SEL originalSelector = @selector(controllers);
        SEL swizzledSelector = @selector(pt_controllers);
        
        Method originalMethod = class_getClassMethod(gcClass, originalSelector);
        Method swizzledMethod = class_getClassMethod(self, swizzledSelector);
        
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
        
        NSLog(@"PlayTools: [SUCCESS] System +[GCController controllers] Hooked via +load!");
        
        // 挂载一个延迟任务，在主线程启动后再发广播
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            Class virtualGamepadClass = NSClassFromString(@"GCVirtualGamepad");
            if (virtualGamepadClass) {
                id sharedGamepad = [virtualGamepadClass performSelector:NSSelectorFromString(@"shared")];
                if (sharedGamepad) {
                    NSArray *fakeControllers = [sharedGamepad performSelector:NSSelectorFromString(@"controllers")];
                    if (fakeControllers.count > 0) {
                        GCController *fake = fakeControllers.firstObject;
                        [[NSNotificationCenter defaultCenter] postNotificationName:GCControllerDidConnectNotification object:fake];
                        NSLog(@"PlayTools: [SUCCESS] Broadcasted FAKE GCControllerDidConnectNotification!");
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
