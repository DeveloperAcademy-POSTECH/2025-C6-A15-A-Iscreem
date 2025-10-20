//
//  ContentView.swift
//  learningtool
//
//  Created by Mumin on 10/18/25.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedNote: Note?
    @State private var showStudyView = false
    
    var body: some View {
        ZStack {
            if showStudyView, let note = selectedNote {
                StudyView(note: note) {
                    showStudyView = false
                    selectedNote = nil
                }
            } else {
                HomeView(
                    onNoteSelected: { note in
                        selectedNote = note
                        withAnimation {
                            showStudyView = true
                        }
                    },
                    onNoteCreated: { note in
                        selectedNote = note
                        withAnimation {
                            showStudyView = true
                        }
                    }
                )
            }
        }
        .keyboardOverlay()
    }
}

#Preview(traits: .landscapeLeft) {
    ContentView()
}
