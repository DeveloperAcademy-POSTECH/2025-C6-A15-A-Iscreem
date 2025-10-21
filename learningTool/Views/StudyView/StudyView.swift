//
//  StudyView.swift
//  learningtool
//
//  Created by Mumin on 10/18/25.
//

import SwiftUI

struct StudyView: View {
    @StateObject private var viewModel: StudyViewModel
    let onDismiss: (() -> Void)?
    
    @EnvironmentObject private var captionAnalyzer: CaptionAnalyzer
    
    init(note: Note? = nil, onDismiss: (() -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: StudyViewModel(note: note))
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        VStack(spacing: 0) {
            /// 헤더
            HStack {
                Button(action: {
                    viewModel.closeButtonTapped()
                    onDismiss?()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.text2)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                VStack(spacing: 2) {
                    Text(
                        viewModel.currentNote?.title
                            ?? "데이터통신 제1장"
                    )
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.text1)
                    
                    Text("26:52/58:59")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.text3)
                }
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.text2)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color.background1)
            
            Divider()
                .background(Color.borderColor)
            
            /// 메인 콘텐츠 (2열 레이아웃)
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    /// 좌측: 미디어 + 키워드
                    VStack(spacing: 0) {
                        
                        //MARK: test용 임시 링크
                        MediaView(videoURL: "https://youtu.be/LBqJwmFMQHI?si=G1aD3hiMw5-ZSdWk")
                        
                        Divider()
                            .background(Color.borderColor)
                        
                        KeywordView()
                            .frame(height: 180)
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    
                    Divider()
                        .background(Color.borderColor)
                    
                    /// 우측: 요약 + 질문
                    VStack(spacing: 0) {
                        SummaryView()
                            .frame(maxHeight: .infinity)
                        
                        Divider()
                            .background(Color.borderColor)
                        
                        QuestionView()
                            .frame(maxHeight: .infinity)
                    }
                    .frame(
                        width: max(
                            350,
                            min(450, geometry.size.width * 0.35)
                        )
                    )
                }
            }
        }
        .background(Color.background2)
        .keyboardOverlay()
        .onAppear { captionAnalyzer.autoSummarizeEnabled = true }
    }
}

#Preview(traits: .landscapeLeft) {
    StudyView(
        note: Note(
            title: "데이터통신 제1장",
            lastRead: Date()
        )
    )
}
