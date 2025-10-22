//
//  StudyViewModel.swift
//  learningtool
//
//  Created by Mumin on 10/18/25.
//

import SwiftUI
import Combine

class StudyViewModel: ObservableObject {
    @Published var selectedTab = StudyTab.media
    @Published var currentNote: Note?
    
    enum StudyTab: String, CaseIterable {
        case media = "미디어"
        case keyword = "키워드"
        case summary = "요약"
        case question = "질문"
        
        var icon: String {
            switch self {
            case .media: return "play.rectangle.fill"
            case .keyword: return "tag.fill"
            case .summary: return "doc.text.fill"
            case .question: return "questionmark.circle.fill"
            }
        }
    }
    
    init(note: Note? = nil) {
        self.currentNote = note
    }
    
    func tabTapped(_ tab: StudyTab) {
        selectedTab = tab
    }
    
    func closeButtonTapped() {
        print("Close button tapped")
    }
}