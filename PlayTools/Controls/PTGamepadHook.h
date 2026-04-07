//
//  PTGamepadHook.h
//  PlayTools
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PTGamepadHook : NSObject

/// 开始强行劫持系统的 GameController API
+ (void)inject;

@end

NS_ASSUME_NONNULL_END
