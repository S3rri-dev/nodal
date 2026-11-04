// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit

extension AppDelegate {
    func accessibilityPreferences()->Object {
        let workspace=NSWorkspace.shared
        return ["reduceTransparency":workspace.accessibilityDisplayShouldReduceTransparency,
                "reduceMotion":workspace.accessibilityDisplayShouldReduceMotion,
                "increaseContrast":workspace.accessibilityDisplayShouldIncreaseContrast]
    }
    func applyNativeAppearance() throws {
        switch try store.setting("theme") {
        case "dark":NSApp.appearance=NSAppearance(named:.darkAqua)
        case "light":NSApp.appearance=NSAppearance(named:.aqua)
        default:NSApp.appearance=nil
        }
    }
    @objc func accessibilityOptionsChanged(_ notification:Notification) {
        guard let text=try? json(accessibilityPreferences()) else{return}
        web.evaluateJavaScript("window.accessibilityUpdate?.(\(text))")
    }
}
