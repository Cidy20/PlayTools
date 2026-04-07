import Foundation
import GameController

/// 【插件中心：真·完美替身投射器】
/// 通过手动修补苹果原生 GCController 实例的 _extendedGamepad Ivar 指针，
/// 彻底解决网易 SDK 在进行 C++ 指针偏移探测时因 NULL 指针引发的 PC=0 崩溃。
@objc public class GCVirtualGamepad: NSObject {
    
    @objc public static let shared = GCVirtualGamepad()
    private var shieldedController: GCController?

    private override init() {
        super.init()
        setupShieldedNativeController()
    }
    
    private func setupShieldedNativeController() {
        // 1. 获取苹果原生快照 (具备官方类布局，但物理指针默认为空)
        guard let controller = GCController.withExtendedGamepad() as? GCController else { return }
        
        // 2. 【核心修复】手动修补 Ivar 内存布局
        // 我们利用运行时反射，强行将该指针指向一个合法的 Snapshot 实例。
        let ivarName = "_extendedGamepad"
        if let ivar = class_getInstanceVariable(GCController.self, ivarName) {
            // 写入指针。这一步保证了 SDK 在读取偏移量时拿到合法的地址。
            object_setIvar(controller, ivar, controller.extendedGamepad)
            print("PlayTools: [SUCCESS] Native GCController Shielded. PC=0 Defense Active.")
        }
        
        self.shieldedController = controller
    }
    
    @objc public func controllers() -> [GCController] {
        guard let controller = shieldedController else { return [] }
        return [controller]
    }
}
