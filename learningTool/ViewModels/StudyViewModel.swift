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
    @Published var showSettings = false
    
    // 키워드 선택 및 질문 자동 입력을 위한 프로퍼티
    @Published var selectedKeyword: String?
    @Published var shouldInsertKeyword: Bool = false
    @Published var shouldGenerateSuggestions: Bool = false  // 추천질문 자동 생성 트리거
    
    // 요약 컨텍스트 (추천 질문 생성용)
    @Published var summaryContext: String = ""
    
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
    
    /// 키워드 선택 처리 (자동으로 추천질문도 생성)
    func selectKeyword(_ keyword: String) {
        selectedKeyword = keyword
        shouldInsertKeyword = true
        shouldGenerateSuggestions = true  // 추천질문 자동 생성 트리거
    }
    
    /// 키워드 삽입 완료 처리
    func keywordInserted() {
        shouldInsertKeyword = false
    }
    
    /// 추천질문 생성 완료 처리
    func suggestionsGenerated() {
        shouldGenerateSuggestions = false
    }
    
    func settingsButtonTapped() {
        showSettings = true
    }
}
