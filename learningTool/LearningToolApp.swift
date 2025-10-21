//
//  LearningToolApp.swift
//  learningTool
//
//  Created by Mumin on 10/18/25.
//

import SwiftUI

@main
struct LearningToolApp: App {
    
    @StateObject private var CaptionAnalyzerViewModel = CaptionAnalyzer()

    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(CaptionAnalyzerViewModel)
        }
    }
}

