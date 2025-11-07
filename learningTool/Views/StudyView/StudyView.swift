//
//  StudyView.swift
//  learningtool
//
//  Created by Mumin on 10/18/25.
//


import SwiftUI
import SwiftData

private struct VerticalSplitHandle: View {
    @Binding var ratio: CGFloat
    var totalWidth: CGFloat
    var minFraction: CGFloat = 0.2
    var maxFraction: CGFloat = 0.8
    @State private var startRatio: CGFloat = 0
    @State private var began: Bool = false
    var body: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.12))
            .overlay {
                VStack(spacing: 3) {
                    Capsule().fill(Color.secondary.opacity(0.6)).frame(width: 3, height: 18)
                    Capsule().fill(Color.secondary.opacity(0.6)).frame(width: 3, height: 18)
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        if !began {
                            began = true
                            startRatio = ratio
                        }
                        let dx = g.translation.width / max(1, totalWidth)
                        let new = startRatio + dx
                        ratio = min(max(minFraction, new), maxFraction)
                    }
                    .onEnded { _ in
                        began = false
                    }
            )
    }
}

private struct HorizontalSplitHandle: View {
    @Binding var ratio: CGFloat // top fraction 0...1
    var totalHeight: CGFloat
    var minFraction: CGFloat = 0.2
    var maxFraction: CGFloat = 0.8
    @State private var startRatio: CGFloat = 0
    @State private var began: Bool = false
    var body: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.12))
            .overlay {
                HStack(spacing: 6) {
                    Capsule().fill(Color.secondary.opacity(0.6)).frame(width: 18, height: 3)
                    Capsule().fill(Color.secondary.opacity(0.6)).frame(width: 18, height: 3)
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        if !began {
                            began = true
                            startRatio = ratio
                        }
                        let dy = g.translation.height / max(1, totalHeight)
                        let new = startRatio + dy
                        ratio = min(max(minFraction, new), maxFraction)
                    }
                    .onEnded { _ in
                        began = false
                    }
            )
    }
}

private struct CollapsiblePane<Content: View>: View {
    @Binding var isCollapsed: Bool
    let height: CGFloat
    let content: () -> Content
    
    var body: some View {
        content()
            .frame(maxWidth: .infinity)
            .overlay(alignment: .topTrailing) {
                Button(action: { isCollapsed.toggle() }) {
                    Image(systemName: isCollapsed ? "plus" : "minus")
                        .foregroundStyle(Color.text1)
                }
                .buttonStyle(.plain)
                .padding(8)
                .contentShape(Rectangle())
                .zIndex(10)
            }
            .frame(height: height)
    }
}

struct StudyView: View {
    @StateObject private var viewModel: StudyViewModel
    @Environment(\.modelContext) private var modelContext
    let onDismiss: (() -> Void)?
    @State private var showingAPISettings = false
    
    @EnvironmentObject private var captionAnalyzer: CaptionAnalyzer
    @Query private var notes: [Note]
    // ▼ 전역 질문 입력 바 상태 (키보드 상단 바)
    @StateObject private var questionVM = QuestionViewModel()
    @State private var showGlobalQuestionBar = false
    @FocusState private var globalQuestionFocus: Bool
    
    // Interactive split & collapse states
    @State private var isTopCollapsed: Bool = false
    @State private var isBottomCollapsed: Bool = false
    @State private var isLeftBottomCollapsed: Bool = false
    
    @State private var splitLR: CGFloat = 0.65        // left : right ratio
    @State private var leftTopRatio: CGFloat = 0.7     // left column top fraction
    @State private var rightTopRatio: CGFloat = 0.6    // right column top fraction
    
    // iPhone 전용 collapse 상태
    @State private var isPhoneSummaryCollapsed: Bool = false
    @State private var isPhoneQuestionCollapsed: Bool = false
    
    // 디바이스 타입 감지
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    
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
            
            /// 메인 콘텐츠 (디바이스별 레이아웃)
            GeometryReader { geometry in
                if isIPad {
                    // iPad: 기존 2열 레이아웃
                    iPadLayout(geometry: geometry)
                } else {
                    // iPhone: 단일 컬럼 세로 레이아웃
                    iPhoneLayout(geometry: geometry)
                }
            }
        }
        .background(Color.background2)
        .keyboardOverlay()
        // ▼ 전역 입력 바: 키보드 상단(StudyView 전체 너비) — 키보드 높이에 맞춰 자동 패딩
        .overlay(alignment: .bottom) {
            if showGlobalQuestionBar {
                VStack(spacing: 0) {
                    Divider().background(Color.borderColor)
                    QuestionInputBar(
                        text: $questionVM.currentMessage,
                        isEnabled: GeminiAPIService.shared.isAPIKeyConfigured() && !questionVM.isLoading,
                        isSending: questionVM.isLoading,
                        isGenerating: false,
                        focus: $globalQuestionFocus,
                        placeholder: GeminiAPIService.shared.isAPIKeyConfigured() ? "메시지를 입력하세요" : "API 키를 먼저 설정해주세요",
                        onTapLightbulb: { /* 전역 전구 버튼 필요 시 구현 */ },
                        onSend: {
                            if GeminiAPIService.shared.isAPIKeyConfigured() {
                                questionVM.sendMessage()
                                // 전송/접기 시 전역 바 닫기
                                globalQuestionFocus = false
                                showGlobalQuestionBar = false
                            }
                        }
                    )
                    .padding(16)
                }
                .background(Color.background1)
                .keyboardAdaptivePadding() // 키보드 높이만큼 위로 올리기
                .zIndex(1000)
                .onAppear { globalQuestionFocus = true } // 전역 바 등장 시 포커스
                .onChange(of: globalQuestionFocus) { _, focused in // 키보드 접힘 → 전역 바 닫기
                    if !focused { showGlobalQuestionBar = false }
                }
            }
        }
        .onAppear { captionAnalyzer.autoSummarizeEnabled = true }
        .onChange(of: captionAnalyzer.summaryStatus) { _, newValue in
            if case .ready = newValue {
                // CaptionAnalyzer가 바인딩된 Note에 캐시를 써 둔 뒤,
                // 컨텍스트를 저장하여 영구화
                try? modelContext.save()
            }
        }
        .sheet(isPresented: $showingAPISettings) {
            APISettingsView()
        }
    }
    
    // MARK: - iPad Layout
    @ViewBuilder
    private func iPadLayout(geometry: GeometryProxy) -> some View {
        HStack(spacing: 0) {
            let handleW: CGFloat = 10
            let handleH: CGFloat = 12
            let availW = geometry.size.width - handleW
            let leftW = max(0, availW * splitLR)
            let rightW = max(0, availW * (1 - splitLR))
            let bothCollapsed = isTopCollapsed && isBottomCollapsed
            
            if bothCollapsed {
                // Compute heights from the LEFT column so the top region spans full width
                let availableH = max(0, geometry.size.height - handleH)
                let leftCollapsed: CGFloat = 160
                let bottomLeftH: CGFloat = isLeftBottomCollapsed ? leftCollapsed : availableH * (1 - leftTopRatio)
                let topH: CGFloat = max(0, availableH - bottomLeftH)
                let collapsed: CGFloat = 80
                
                VStack(spacing: 0) {
                    // TOP — full-width MediaView (좌측 상단이 실제로 전체 너비로 확장)
                    MediaView(note: viewModel.currentNote, videoURL: resolvedVideoURL)
                        .frame(maxWidth: .infinity)
                        .frame(height: topH)
                    
                    // Middle horizontal handle spanning full width (controls leftTopRatio)
                    HorizontalSplitHandle(ratio: $leftTopRatio, totalHeight: availableH)
                        .frame(height: handleH)
                    
                    // BOTTOM — left bottom stays at leftW, right collapsed stack stays at rightW
                    HStack(spacing: 0) {
                        // LEFT bottom (KeywordView)
                        CollapsiblePane(isCollapsed: $isLeftBottomCollapsed, height: bottomLeftH) {
                            KeywordView(analyzer: captionAnalyzer, studyViewModel: viewModel)
                                .frame(maxWidth: .infinity)
                        }
                        .frame(width: leftW, height: bottomLeftH)
                        
                        // Vertical handle between left and right
                        VerticalSplitHandle(ratio: $splitLR, totalWidth: availW)
                            .frame(width: handleW)
                        
                        // RIGHT collapsed stack aligned to bottom-right
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            
                            CollapsiblePane(isCollapsed: $isTopCollapsed, height: collapsed) {
                                SummaryView()
                                    .frame(maxWidth: .infinity)
                            }
                            
                            CollapsiblePane(isCollapsed: $isBottomCollapsed, height: collapsed) {
                                QuestionView(
                                    studyViewModel: viewModel,
                                    viewModel: questionVM,
                                    isGlobalInputActive: $showGlobalQuestionBar
                                )
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .frame(width: rightW, height: bottomLeftH, alignment: .bottom)
                    }
                }
            } else {
                // Original two-column interactive layout (unchanged)
                // LEFT column: Media (top) | handle | Keyword (bottom, collapsible)
                VStack(spacing: 0) {
                    GeometryReader { leftGeo in
                        let total = leftGeo.size.height
                        let leftCollapsed: CGFloat = 160
                        let available = max(0, total - handleH)
                        let bottomHeight: CGFloat = isLeftBottomCollapsed ? leftCollapsed : available * (1 - leftTopRatio)
                        let topHeight: CGFloat = max(0, available - bottomHeight)
                        
                        VStack(spacing: 0) {
                            // MARK: MediaView (좌측 상단)
                            MediaView(note: viewModel.currentNote, videoURL: resolvedVideoURL)
                                .frame(maxWidth: .infinity)
                                .frame(height: topHeight)
                            
                            // 가로 핸들 (좌측 상/하 경계)
                            HorizontalSplitHandle(ratio: $leftTopRatio, totalHeight: available)
                                .frame(height: handleH)
                            
                            // MARK: KeywordView (좌측 하단, 접힘 지원)
                            CollapsiblePane(isCollapsed: $isLeftBottomCollapsed, height: bottomHeight) {
                                KeywordView(analyzer: captionAnalyzer, studyViewModel: viewModel)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    }
                }
                .frame(width: leftW)
                
                // 세로 핸들 (좌/우 경계)
                VerticalSplitHandle(ratio: $splitLR, totalWidth: availW)
                    .frame(width: handleW)
                
                // RIGHT column: Summary (top, collapsible) | handle | Question (bottom, collapsible)
                VStack(spacing: 0) {
                    GeometryReader { rightGeo in
                        let total = rightGeo.size.height
                        let collapsed: CGFloat = 80
                        let bothCollapsed = isTopCollapsed && isBottomCollapsed
                        let available = max(0, total - handleH)
                        
                        let topHeight: CGFloat = {
                            if bothCollapsed { return collapsed }
                            if isTopCollapsed { return collapsed }
                            if isBottomCollapsed { return available - collapsed }
                            return available * rightTopRatio
                        }()
                        
                        let bottomHeight: CGFloat = {
                            if bothCollapsed { return collapsed }
                            return max(0, available - topHeight)
                        }()
                        
                        VStack(spacing: 0) {
                            if bothCollapsed {
                                // 상단은 검정 사각형으로 채우고, 두 섹션은 하단에 접힘 상태로 배치
                                Rectangle()
                                    .fill(Color.black)
                                    .frame(maxHeight: .infinity)
                                
                                CollapsiblePane(isCollapsed: $isTopCollapsed, height: collapsed) {
                                    SummaryView()
                                        .frame(maxWidth: .infinity)
                                }
                                
                                // 가로 핸들 (우측 상/하 경계)
                                HorizontalSplitHandle(ratio: $rightTopRatio, totalHeight: available)
                                    .frame(height: handleH)
                                
                                CollapsiblePane(isCollapsed: $isBottomCollapsed, height: collapsed) {
                                    QuestionView(
                                        studyViewModel: viewModel,
                                        viewModel: questionVM,
                                        isGlobalInputActive: $showGlobalQuestionBar
                                    )
                                    .frame(maxWidth: .infinity)
                                }
                            } else {
                                CollapsiblePane(isCollapsed: $isTopCollapsed, height: topHeight) {
                                    SummaryView()
                                        .frame(maxWidth: .infinity)
                                }
                                
                                // 가로 핸들 (우측 상/하 경계)
                                HorizontalSplitHandle(ratio: $rightTopRatio, totalHeight: available)
                                    .frame(height: handleH)
                                
                                CollapsiblePane(isCollapsed: $isBottomCollapsed, height: bottomHeight) {
                                    QuestionView(
                                        studyViewModel: viewModel,
                                        viewModel: questionVM,
                                        isGlobalInputActive: $showGlobalQuestionBar
                                    )
                                    .frame(maxWidth: .infinity)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    }
                }
                .frame(width: rightW)
            }
        }
    }
    
    // MARK: - iPhone Layout
    @ViewBuilder
    private func iPhoneLayout(geometry: GeometryProxy) -> some View {
        let totalHeight = geometry.size.height
        let totalWidth = geometry.size.width
        
        // 가로 모드 감지 (너비 > 높이)
        let isLandscape = totalWidth > totalHeight
        
        // MediaView 높이 계산 (가로/세로 모드에 따라 다르게)
        let mediaHeight: CGFloat = {
            if isLandscape {
                // 가로 모드: 화면 높이의 50% 사용, 최소 200pt 보장
                return max(totalHeight * 0.5, 200)
            } else {
                // 세로 모드: 16:9 비율 또는 화면 높이의 30%
                return min(totalHeight * 0.3, totalWidth * 9 / 16)
            }
        }()
        
        let collapsedHeight: CGFloat = 80
        let summaryExpandedHeight: CGFloat = 250
        let questionExpandedHeight: CGFloat = 300
        
        ScrollView {
            VStack(spacing: 0) {
                // MARK: MediaView (상단)
                MediaView(note: viewModel.currentNote, videoURL: resolvedVideoURL)
                    .frame(height: mediaHeight)
                    .frame(maxWidth: .infinity)
                
                // MARK: KeywordView (중간)
                KeywordView(analyzer: captionAnalyzer, studyViewModel: viewModel)
                    .frame(minHeight: 200)
                    .frame(maxWidth: .infinity)
                
                // MARK: SummaryView (하단 1, 접기 가능)
                CollapsiblePane(
                    isCollapsed: $isPhoneSummaryCollapsed,
                    height: isPhoneSummaryCollapsed ? collapsedHeight : summaryExpandedHeight
                ) {
                    SummaryView()
                        .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity)
                
                // MARK: QuestionView (하단 2, 접기 가능)
                CollapsiblePane(
                    isCollapsed: $isPhoneQuestionCollapsed,
                    height: isPhoneQuestionCollapsed ? collapsedHeight : questionExpandedHeight
                ) {
                    QuestionView(
                        studyViewModel: viewModel,
                        viewModel: questionVM,
                        isGlobalInputActive: $showGlobalQuestionBar
                    )
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
    
    // MARK: - Helpers
    // 현재 노트의 유튜브 링크를 우선 사용하고,
    // 없으면 같은 제목의 노트를 SwiftData에서 찾아 링크를 사용합니다.
    private var resolvedVideoURL: String? {
        // 1) 현재 전달받은 노트의 비디오 링크 우선
        if let url = viewModel.currentNote?.videoURL, !url.isEmpty {
            return url
        }
        // 1-2) (이전 구조 호환) 썸네일 필드에 저장된 링크가 있다면 사용
        if let url = viewModel.currentNote?.thumbnailURL, !url.isEmpty {
            return url
        }
        // 2) 동일 제목의 노트를 찾아서 링크 사용 (폴백)
        if let title = viewModel.currentNote?.title,
           let matched = notes.first(where: { $0.title == title }) {
            if let v = matched.videoURL, !v.isEmpty { return v }
            if let t = matched.thumbnailURL, !t.isEmpty { return t }
        }
        return nil
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
