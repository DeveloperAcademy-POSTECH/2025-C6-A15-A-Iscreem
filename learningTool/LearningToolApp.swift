//
//  LearningToolApp.swift
//  learningTool
//
//  Created by Mumin on 10/18/25.
//

import SwiftUI
import SwiftData

@main
struct LearningToolApp: App {
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
