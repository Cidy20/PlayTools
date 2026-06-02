//
//  ModeAutomaton.swift
//  PlayTools
//
//  Created by 许沂聪 on 2023/9/17.
//

import Foundation

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

    static public func onToggleTextInput() {
        if mode == .cameraRotate {
            // 防御性拦截：如果是视角锁定模式，不应允许激活强制打字模式以防误触
            return
        }
        if mode == .textInput {
            mode.set(previousMode)
            Toucher.writeLog(logMessage: "Text input mode manually OFF. Restored to: \(previousMode)")
            Toast.showHint(title: "打字模式已关闭", text: ["按键映射已恢复"])
        } else {
            previousMode = mode.currentMode
            mode.set(.textInput)
            Toucher.writeLog(logMessage: "Text input mode manually ON. Suspended mode: \(previousMode)")
            Toast.showHint(title: "打字模式已开启", text: ["按键映射已挂起，可正常打字"])
        }
    }
}
