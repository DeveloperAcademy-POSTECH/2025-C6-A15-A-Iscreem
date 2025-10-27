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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(captionAnalyzer)
        }
        .modelContainer(for: [Folder.self, Note.self])
    }
}

