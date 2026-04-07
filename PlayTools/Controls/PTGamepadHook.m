//
//  PTGamepadHook.m
//  PlayTools
//

#import "PTGamepadHook.h"
#import <GameController/GameController.h>
#import <objc/runtime.h>

static NSArray<GCController *>* (*original_controllers)(id, SEL);

@implementation PTGamepadHook

+ (void)activate {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class gcClass = NSClassFromString(@"GCController");
        if (!gcClass) return;
        
        SEL originalSelector = @selector(controllers);
        Method originalMethod = class_getClassMethod(gcClass, originalSelector);
        if (!originalMethod) return;
        
        // 核心修复：直接保存原方法的 C 函数指针，避免跨类 Exchange 引起的无限递归（死循环）！
        original_controllers = (void *)method_getImplementation(originalMethod);
        
        // 拿到我们的假实现方法
        Method swizzledMethod = class_getClassMethod(self, @selector(pt_controllers));
        
        // 暴力将原系统方法指针替换成我们的假实现
        method_setImplementation(originalMethod, method_getImplementation(swizzledMethod));
        
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
    // 1. 设置当前线程防无限递归保护！
    // 很多系统 API 或 Swift 初始化会间接触发 controllers，造成死循环
    NSMutableDictionary *threadDict = [[NSThread currentThread] threadDictionary];
    if ([threadDict objectForKey:@"pt_controllers_guard"]) {
        // 如果发生递归返回，直接短路到原函数
        if (original_controllers) {
            Class gcClass = NSClassFromString(@"GCController");
            return original_controllers(gcClass, _cmd);
        }
        return @[];
    }
    
    // 设置访问锁
    [threadDict setObject:@YES forKey:@"pt_controllers_guard"];
    
    // 2. 强制调用保存的原实现 C 函数指针
    NSArray<GCController *> *original = nil;
    if (original_controllers) {
        // 【核心修复】必须传原本的 GCController 类作为上下文，而不是当前的 PTGamepadHook 类！
        Class gcClass = NSClassFromString(@"GCController");
        original = original_controllers(gcClass, _cmd);
    }
    
    NSMutableArray *mut = [NSMutableArray arrayWithArray:original ?: @[]];
    
    // 3. 动态调用 Swift 中的虚拟手柄
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
    
    // 释放锁
    [threadDict removeObjectForKey:@"pt_controllers_guard"];
    
    return [mut copy];
}

@end
