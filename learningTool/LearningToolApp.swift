//
//  LearningToolApp.swift
//  learningTool
//
//  Created by Mumin on 10/18/25.
//

import SwiftUI
import SwiftData
import ObjectiveC.runtime

#if DEBUG
private func debugCheckForUITextInputTraitsCollision() {
    // If a class exists with the name "UITextInputTraits", it likely shadows Apple's protocol and will crash text inputs.
    if let cls = NSClassFromString("UITextInputTraits") {
        print("⚠️ [Debug] Detected a runtime class named 'UITextInputTraits': \(cls).")
        print("⚠️ [Debug] This name collides with UIKit's 'UITextInputTraits' protocol and can crash when showing the keyboard.")
        print("⚠️ [Debug] Search your project for any custom type named 'UITextInputTraits' (class/struct/enum) or third-party headers declaring it, and rename/remove it.")
    }
}
#endif

#if DEBUG
private func debugPatchUITextInputTraitsShadowClass() {
    // If a stray class named "UITextInputTraits" exists (shadowing Apple's protocol),
    // patch a missing selector with a no-op to avoid crashes when the keyboard appears.
    guard let cls: AnyClass = NSClassFromString("UITextInputTraits") else { return }
    let sel = NSSelectorFromString("initializeTranslateGestureRecognizerIfNecessary")
    if !class_respondsToSelector(cls, sel) {
        let block: @convention(block) (AnyObject) -> Void = { _ in
            // no-op
        }
        let imp = imp_implementationWithBlock(block)
        // "v@:" = void return, takes (self, _cmd)
        class_addMethod(cls, sel, imp, "v@:")
        print("✅ [Debug] Patched 'UITextInputTraits' shadow class with no-op \(NSStringFromSelector(sel)).")
    }
}
#endif

@main
struct LearningToolApp: App {
    @StateObject private var captionAnalyzer = CaptionAnalyzer()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(captionAnalyzer)
                .onAppear {
#if DEBUG
                    debugCheckForUITextInputTraitsCollision()
                    debugPatchUITextInputTraitsShadowClass()
#endif
                }
        }
        .modelContainer(for: [Folder.self, Note.self])
    }
}

