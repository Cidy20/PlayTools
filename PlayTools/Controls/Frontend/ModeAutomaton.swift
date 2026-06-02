//
//  ModeAutomaton.swift
//  PlayTools
//
//  Created by 许沂聪 on 2023/9/17.
//

import Foundation
import UIKit

// This class manages control mode transitions

public class ModeAutomaton {
    static public func onOption() -> Bool {
        if mode == .editor || mode == .textInput {
            return false
        }
        if mode == .off {
            mode.set(.cameraRotate)

        } else if mode == .arbitraryClick && ActionDispatcher.cursorHideNecessary {
            mode.set(.cameraRotate)

        } else if mode == .cameraRotate {
            if PlaySettings.shared.noKMOnInput {
                mode.set(.arbitraryClick)
            } else {
                mode.set(.off)
            }
        }
        // Some people want option key act as touchpad-touchscreen mapper
        return false
    }

    static public func onCmdK() {
        guard settings.keymapping else {
            return
        }

        EditorController.shared.switchMode()

        if mode == .editor && !EditorController.shared.editorMode {
            mode.set(.cameraRotate)
            ActionDispatcher.build()
            Toucher.writeLog(logMessage: "editor closed")
        } else if EditorController.shared.editorMode {
            mode.set(.editor)
            Toucher.writeLog(logMessage: "editor opened")
        }
    }

    static public func onUITextInputBeginEdit() {
        if mode == .editor {
            return
        }
        mode.set(.textInput)
    }

    static public func onUITextInputEndEdit() {
        if mode == .editor {
            return
        }
        mode.set(.arbitraryClick)
    }

    static private var previousMode: ControlModeLiteral = .arbitraryClick
    static private var isTypingForceSuspended = false
    static private var proxyTextField: UITextField?

    static public func onToggleTextInput() {
        if mode == .cameraRotate {
            // 防御性拦截：如果是视角锁定模式，不应允许激活强制打字模式以防误触
            return
        }
        if isTypingForceSuspended {
            // 1. 关闭打字模式：释放隐藏文本框的焦点，并彻底从窗口移除
            if let field = proxyTextField {
                field.resignFirstResponder()
                field.removeFromSuperview()
                proxyTextField = nil
            }
            
            // 2. 切回先前的模式（如 arbitraryClick）
            mode.set(previousMode)
            isTypingForceSuspended = false
            Toucher.writeLog(logMessage: "Text input mode manually OFF. Restored to: \(previousMode)")
            Toast.showHint(title: "打字模式已关闭", text: ["按键映射已恢复"])
        } else {
            // 1. 开启打字模式：强行创建微小的隐藏原生 UITextField 获取焦点，强制唤起系统输入法！
            previousMode = mode.currentMode
            
            let field = UITextField(frame: CGRect(x: -10, y: -10, width: 1, height: 1))
            field.backgroundColor = .clear
            field.textColor = .clear
            field.keyboardType = .default
            field.autocorrectionType = .no
            field.autocapitalizationType = .none
            
            // 寻找当前的 KeyWindow 并挂载
            if let window = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap({ $0.windows })
                .first(where: { $0.isKeyWindow }) {
                
                window.addSubview(field)
                field.becomeFirstResponder()
                proxyTextField = field
            }
            
            // 2. 强行将模式切到 .textInput（在此模式下所有按键映射均被 100% 屏蔽）
            mode.set(.textInput)
            isTypingForceSuspended = true
            Toucher.writeLog(logMessage: "Text input mode manually ON (IME Proxy Active). Suspended mode: \(previousMode)")
            Toast.showHint(title: "打字模式已开启", text: ["按键映射已挂起，可正常打字"])
        }
    }
}
