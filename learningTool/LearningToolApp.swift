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
    @StateObject private var learningLogStore = LearningLogStore()

    var body: some Scene {
        WindowGroup {
//            ContentView()
            HomeView.AppRootView()
                .environmentObject(captionAnalyzer)
                .environmentObject(learningLogStore)
        }
        .modelContainer(for: [Folder.self, Note.self])
    }
}

