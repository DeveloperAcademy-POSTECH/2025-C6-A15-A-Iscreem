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


#if DEBUG

// MARK: - UI-Only Placeholders for Previews (no media/LLM work)

private struct _MediaPlaceholder: View {
    var body: some View {
        Rectangle()
            .fill(Color.background3)
            .aspectRatio(16/9, contentMode: .fit)
            .overlay(
                VStack(spacing: 8) {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.white.opacity(0.9))
                    Text("Media 16:9")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.7))
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct _KeywordPlaceholder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("이 강의에서 자주 언급되는 핵심 키워드들이 나열됩니다.")
                .font(.system(size: 14))
                .foregroundStyle(Color.text2)
                .padding(.horizontal, 16)
                .padding(.top, 12)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(0..<6, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.background2)
                            .overlay(
                                Text("Keyword")
                                    .font(.system(size: 15))
                                    .foregroundStyle(Color.text3)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.borderColor, lineWidth: 1)
                            )
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 12)
        }
        .background(Color.background1)
    }
}

private struct _SummaryCardPlaceholder: View {
    let index: Int
    let title: String
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("#\(index). \(title)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.text1)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.text3)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(0..<4, id: \.self) { _ in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•").foregroundStyle(Color.text3)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.background3.opacity(0.6))
                            .frame(height: 14)
                    }
                }
            }
            .padding(.top, 8)
        }
        .padding(16)
        .background(Color.background2)
        .cornerRadius(12)
    }
}

private struct _SummaryPlaceholder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("AI가 구간별 요약을 제공합니다.")
                .font(.system(size: 15))
                .foregroundStyle(Color.text2)
                .padding(16)

            Divider().background(Color.borderColor)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    _SummaryCardPlaceholder(index: 1, title: "제목 생성 중…")
                        .padding(16)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Color.background1)
    }
}

private struct _QuestionPlaceholder: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("AI에게 무엇이든 물어보세요!")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.text2)
                Spacer()
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.text3.opacity(0.6))
            }
            .padding(16)

            Divider().background(Color.borderColor)

            // Chat area placeholder
            ScrollView {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.background2)
                    .frame(height: 120)
                    .padding(16)
            }

            Divider().background(Color.borderColor)

            // Input area placeholder
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.background2)
                    .frame(height: 44)
                    .overlay(
                        HStack {
                            Text("메시지를 입력하세요")
                                .font(.system(size: 15))
                                .foregroundStyle(Color.text3)
                                .padding(.horizontal, 16)
                            Spacer()
                        }
                    )

                Circle()
                    .fill(Color.orange)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(.white)
                    )

                Circle()
                    .fill(Color.secondColor)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "paperplane.fill")
                            .foregroundStyle(.white)
                    )
            }
            .padding(16)
            .background(Color.background1)
        }
        .background(Color.background1)
    }
}

private struct _SplitOutlinePreview: View {
    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                // Left: Media + Keyword
                VStack(spacing: 0) {
                    _MediaPlaceholder()

                    Divider().background(Color.borderColor)

                    _KeywordPlaceholder()
                        .frame(height: 180)

                    Spacer()
                }
                .frame(maxWidth: .infinity)

                Divider().background(Color.borderColor)

                // Right: Summary + Question (width clamp 350...450 ~ 35%)
                VStack(spacing: 0) {
                    _SummaryPlaceholder()
                        .frame(maxHeight: .infinity)

                    Divider().background(Color.borderColor)

                    _QuestionPlaceholder()
                        .frame(maxHeight: .infinity)
                }
                .frame(width: max(350, min(450, geo.size.width * 0.35)))
            }
        }
        .background(Color.background2)
    }
}

// MARK: - Previews


// 프리뷰는 오른쪽 판넬에 미리보기용으로 짜여지는 코드입니다.


// 주의사항: 키워드뷰의 내용 부분에 쌓일 키워드 자체 컴포넌트, 기타 나머지 뷰의 요소로 쓰일 컴퓨넌트에 관한 윤곽은 컴포넌트 완성시마다 프리뷰용 코드에 첨부해줘야 확인할 수 있습니다.


// 프리뷰용 로직이 짜있는 상황이므로 정식 시뮬레이터나 기기에서도 보이게 하려면, 이 "struct StudyView: View"의 body에 코드를 배치해줘야 앱에서 코드가 작동됩니다. - 코르손 -



#Preview("StudyView · UI Outline (Static)", traits: .landscapeLeft) {
    _SplitOutlinePreview()
}

#Preview("Component · Media 16:9", traits: .landscapeLeft) {
    _MediaPlaceholder()
        .padding()
        .background(Color.background2)
}

#Preview("Component · Keyword 180h", traits: .landscapeLeft) {
    _KeywordPlaceholder()
        .frame(height: 180)
        .padding()
        .background(Color.background2)
}

#Preview("Component · Summary", traits: .landscapeLeft) {
    _SummaryPlaceholder()
        .padding()
        .background(Color.background2)
}

#Preview("Component · Question", traits: .landscapeLeft) {
    _QuestionPlaceholder()
        .padding()
        .background(Color.background2)
}

#endif
