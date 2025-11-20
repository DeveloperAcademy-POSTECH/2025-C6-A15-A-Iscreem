//
//  LearningToolApp.swift
//  learningTool
//
//  Created by Mumin on 10/18/25.
//

import SwiftUI
import SwiftData
import UIKit

final class LearningToolAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        // iPad: landscape only, iPhone: portrait only
        switch UIDevice.current.userInterfaceIdiom {
        case .pad:
            return [.landscapeLeft, .landscapeRight]
        case .phone:
            return [.portrait]
        default:
            // 기본은 iPhone과 동일하게 세로 고정
            return [.portrait]
        }
    }
}

@main
struct LearningToolApp: App {
    @UIApplicationDelegateAdaptor(LearningToolAppDelegate.self) private var appDelegate
    
    @StateObject private var captionAnalyzer = CaptionAnalyzer()
    @StateObject private var learningLogStore: LearningLogStore

    private let modelContainer: ModelContainer

    // Build the container outside of init to avoid escaping-autoclosure issues.
    private static func makeModelContainer() -> ModelContainer {
        do {
            let schema = Schema([StudySession.self, StudyQAPair.self, Note.self, Folder.self])
            return try ModelContainer(for: schema)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    init() {
        let container = Self.makeModelContainer()
        self.modelContainer = container

        // Initialize LearningLogStore with the container's main context.
        let store = LearningLogStore(context: container.mainContext)
        _learningLogStore = StateObject(wrappedValue: store)
    }

    var body: some Scene {
        WindowGroup {
            HomeView.AppRootView()
                .environmentObject(captionAnalyzer)
                .environmentObject(learningLogStore)
        }
        // Attach the same container to the Scene so Views get @Environment(\.modelContext)
        .modelContainer(modelContainer)
    }
}
