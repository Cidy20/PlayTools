//
//  PTGamepadHook.h
//  PlayTools
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PTGamepadHook : NSObject

/// 手动激活 Gamepad 钩子（规避 +load 框架时序问题）
+ (void)activate;

@end

NS_ASSUME_NONNULL_END
