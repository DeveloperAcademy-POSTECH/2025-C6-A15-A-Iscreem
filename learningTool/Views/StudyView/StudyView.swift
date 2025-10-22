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
    @State private var showingAPISettings = false
    
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
                
                Button(action: {
                    showingAPISettings = true
                }) {
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
                        
                        KeywordView(analyzer: captionAnalyzer)
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
                        
                        QuestionView(studyViewModel: viewModel)
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
        .sheet(isPresented: $showingAPISettings) {
            APISettingsView()
        }
    }
}

struct APISettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey: String = ""
    @State private var showingSuccessAlert = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 0) {
            /// 헤더
            HStack {
                Text("AI 설정")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.text1)
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.text2)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            
            Divider()
                .background(Color.borderColor)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    /// API 키 입력 섹션
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Gemini API 키")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.text1)
                        
                        Text("Google AI Studio에서 Gemini API 키를 발급받아 입력하세요.")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.text3)
                        
                        SecureField("API 키를 입력하세요", text: $apiKey)
                            .font(.system(size: 14))
                            .padding(12)
                            .background(Color.background2)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.borderColor, lineWidth: 1)
                            )
                    }
                    
                    /// 안내 섹션
                    VStack(alignment: .leading, spacing: 12) {
                        Text("API 키 발급 방법")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.text1)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            InfoRow(number: "1", text: "Google AI Studio (ai.google.dev)에 접속")
                            InfoRow(number: "2", text: "Google 계정으로 로그인")
                            InfoRow(number: "3", text: "'Get API key' 버튼 클릭")
                            InfoRow(number: "4", text: "생성된 API 키 복사 후 위에 입력")
                        }
                    }
                    
                    /// 현재 상태
                    HStack {
                        Image(systemName: GeminiAPIService.shared.isAPIKeyConfigured() 
                              ? "checkmark.circle.fill" 
                              : "exclamationmark.circle.fill")
                            .foregroundStyle(GeminiAPIService.shared.isAPIKeyConfigured() 
                                           ? Color.green 
                                           : Color.orange)
                        
                        Text(GeminiAPIService.shared.isAPIKeyConfigured() 
                             ? "API 키가 설정되어 있습니다" 
                             : "API 키가 설정되지 않았습니다")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.text2)
                        
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.background2)
                    .cornerRadius(8)
                    
                    Spacer()
                }
                .padding(20)
            }
            
            Divider()
                .background(Color.borderColor)
            
            /// 버튼 영역
            HStack(spacing: 12) {
                if GeminiAPIService.shared.isAPIKeyConfigured() {
                    Button(action: deleteAPIKey) {
                        Text("API 키 삭제")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.errorColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.errorColor.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                
                Button(action: saveAPIKey) {
                    Text("저장")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(apiKey.isEmpty ? Color.text3 : Color.primaryColor)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(apiKey.isEmpty)
            }
            .padding(20)
        }
        .frame(width: 500, height: 600)
        .background(Color.background1)
        .onAppear {
            if let existingKey = GeminiAPIService.shared.getAPIKey() {
                apiKey = existingKey
            }
        }
        .alert("저장 완료", isPresented: $showingSuccessAlert) {
            Button("확인", role: .cancel) {
                dismiss()
            }
        } message: {
            Text("API 키가 성공적으로 저장되었습니다.")
        }
        .alert("오류", isPresented: $showingErrorAlert) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    private func saveAPIKey() {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            errorMessage = "API 키를 입력해주세요."
            showingErrorAlert = true
            return
        }
        
        GeminiAPIService.shared.saveAPIKey(trimmedKey)
        showingSuccessAlert = true
    }
    
    private func deleteAPIKey() {
        GeminiAPIService.shared.deleteAPIKey()
        apiKey = ""
        errorMessage = "API 키가 삭제되었습니다."
        showingErrorAlert = true
    }
}

struct InfoRow: View {
    let number: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(number)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Color.secondColor)
                .clipShape(Circle())
            
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(Color.text2)
            
            Spacer()
        }
    }
}

#Preview(traits: .landscapeLeft) {
    StudyView(
        note: Note(
            title: "데이터통신 제1장",
            lastRead: Date()
        )
        )
        .environmentObject(CaptionAnalyzer())
}
