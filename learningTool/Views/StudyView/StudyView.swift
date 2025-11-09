//
//  StudyView.swift
//  learningtool
//
//  Created by Mumin on 10/18/25.
//


import SwiftUI
import SwiftData

struct StudyView: View {
    @StateObject private var viewModel: StudyViewModel
    @Environment(\.modelContext) private var modelContext
    let onDismiss: (() -> Void)?
    @State private var showingAPISettings = false
    
    @EnvironmentObject private var captionAnalyzer: CaptionAnalyzer
    @EnvironmentObject private var learningLogStore: LearningLogStore
    @Query private var notes: [Note]
    // ▼ 전역 질문 입력 바 상태 (키보드 상단 바)
    @StateObject private var questionVM = QuestionViewModel()
    @State private var showGlobalQuestionBar = false
    @FocusState private var globalQuestionFocus: Bool
    
    @AppStorage("hasSeenStudyOnboarding") private var hasSeenStudyOnboarding: Bool = false
    @State private var studyOnboardingStep: StudyOnboardingStep = .media
    
    // 디바이스 타입 감지
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    // iPad 고정 비율
    private let mainWidthRatio: CGFloat = 0.65          // 메인 영역(좌측)
    private let rightSidebarWidthRatio: CGFloat = 0.35  // 우측 사이드바(기본 펼침)
    private let mainTopMediaHeightRatio: CGFloat = 0.6  // 메인 내부: Media(상) 비율
    private let mainBottomQuestionHeightRatio: CGFloat = 0.4 // 메인 내부: Question(하) 비율
    
    // iPhone 고정 높이
    private let phoneSummaryHeight: CGFloat = 250
    private let phoneQuestionHeight: CGFloat = 300
    
    // 사이드바 탭 (키워드/요약 전환)
    private enum SidebarTab: String, CaseIterable {
        case keywords = "키워드"
        case summary = "요약"
    }
    @State private var sidebarTab: SidebarTab = .keywords
    // 사이드바 접힘 상태
    @State private var isSidebarCollapsed: Bool = false
    
    init(note: Note? = nil, onDismiss: (() -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: StudyViewModel(note: note))
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: 헤더 (유지)
            HStack {
                Button(action: {
                    viewModel.closeButtonTapped()
                    // ▶︎ 1) 뒤로가기 직전에 현재 재생 위치 저장 요청
                    NotificationCenter.default.post(name: .persistPlaybackPosition, object: viewModel.currentNote)
                    // ▶︎ 2) 즉시 일시정지/정지 요청 (재생 중지)
                    NotificationCenter.default.post(name: .pausePlaybackRequested, object: nil)
                    // JS 질의가 완료될 수 있도록 아주 짧게 지연 후 닫기
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        onDismiss?()
                    }
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
                        ?? "노트의 제목"
                    )
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.text1)
                    
                    Text(headerProgressText)
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
                    iPadLayout(geometry: geometry)
                } else {
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
        .overlayPreferenceValue(StudyTargetBoundsKey.self) { map in
            if !hasSeenStudyOnboarding {
                StudyCoachOverlay(step: $studyOnboardingStep, map: map) {
                    hasSeenStudyOnboarding = true
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
    
    // MARK: - Header Helpers
    private var headerProgressText: String {
        // 1) 학습 로그에 저장된 마지막 재생 위치 우선
        let last = lastPositionFromLogs() ?? viewModel.currentNote?.lastPositionSeconds
        // 2) 전체 시간: 자막 큐가 준비된 경우, 가장 큰 end 값을 사용
        let total = captionAnalyzer.vttCues.map(\.end).max()
        let leftText = formatTime(last)
        let rightText = formatTime(total)
        return "마지막 학습 시간: \(leftText) / 전체 학습 시간: \(rightText)"
    }
    
    private func lastPositionFromLogs() -> Double? {
        guard let note = viewModel.currentNote else { return nil }
        let nid = String(describing: note.id)
        let url = note.videoURL ?? resolvedVideoURL
        // LearningLogStore의 매칭 정책과 동일: 식별자 우선, 없으면 제목+URL
        if let s = learningLogStore.sessions.first(where: { sess in
            if let sid = sess.noteIdentifier, sid == nid { return true }
            if sess.noteTitle == note.title {
                if let v1 = sess.videoURL, let v2 = url, v1 == v2 { return true }
                if url == nil { return true }
            }
            return false
        }) {
            return s.lastPosition
        }
        return nil
    }
    
    private func formatTime(_ seconds: Double?) -> String {
        guard let s = seconds, s > 0 else { return "—" }
        let total = Int(s.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        let sec = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, sec)
        } else {
            return String(format: "%d:%02d", m, sec)
        }
    }
    
    // MARK: - iPad Layout
    @ViewBuilder
    private func iPadLayout(geometry: GeometryProxy) -> some View {
        let totalW = geometry.size.width
        let totalH = geometry.size.height
        
        let sideW = isSidebarCollapsed ? 0 : totalW * rightSidebarWidthRatio
        let mainW = totalW - sideW
        
        // 사이드바 상단 바의 레이아웃 기준(세로 패딩 + 컨트롤 높이)
        let sidebarTopBarVPad: CGFloat = 8
        let sidebarControlHeight: CGFloat = 32
        
        HStack(spacing: 0) {
            // MAIN (좌측)
            VStack(spacing: 0) {
                let mediaH = totalH * mainTopMediaHeightRatio
                let questionH = max(0, totalH - mediaH)
                
                // 사이드바가 접혀도 임베드(플레이어) 너비는
                // "사이드바 펼침 시의 메인 영역 너비"를 유지
                let embedBaseWidthWhenSidebarOpen = totalW * mainWidthRatio
                let embedWidth = isSidebarCollapsed ? embedBaseWidthWhenSidebarOpen : mainW
                
                // MediaView를 고정 임베드 너비로 중앙 배치
                ZStack {
                    MediaView(note: viewModel.currentNote, videoURL: resolvedVideoURL)
                        .frame(width: embedWidth, height: mediaH)
                        .clipped() // 임베드 영역 밖 컨텐츠 숨김(보강)
                        .tagStudyTarget(.media)
                }
                .frame(width: mainW, height: mediaH, alignment: .center)
                .frame(maxWidth: .infinity, alignment: .top)
                
                QuestionView(
                    studyViewModel: viewModel,
                    viewModel: questionVM,
                    isGlobalInputActive: $showGlobalQuestionBar
                )
                .frame(width: mainW, height: questionH)
                .frame(maxWidth: .infinity, alignment: .bottom)
                .tagStudyTarget(.question)
            }
            .frame(width: mainW, height: totalH)
            
            // RIGHT SIDEBAR (우측) — Segmented + Collapse 버튼
            if sideW > 0 {
                VStack(spacing: 0) {
                    // 상단 바: Segmented(요약, 키워드) + 접기 버튼
                    HStack(spacing: 8) {
                        Picker("", selection: $sidebarTab) {
                            // 요구: "요약", "키워드" 순서
                            Text(SidebarTab.summary.rawValue).tag(SidebarTab.summary)
                            Text(SidebarTab.keywords.rawValue).tag(SidebarTab.keywords)
                        }
                        .pickerStyle(.segmented)
                        
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isSidebarCollapsed = true
                            }
                        } label: {
                            Image(systemName: "sidebar.right")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.text2)
                                .frame(width: 32, height: sidebarControlHeight)
                                .background(Color.background2)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, sidebarTopBarVPad)
                    .tagStudyTarget(.sidebar)
                    
                    Divider().background(Color.borderColor)
                    
                    // Content
                    switch sidebarTab {
                    case .keywords:
                        KeywordView(analyzer: captionAnalyzer, studyViewModel: viewModel)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.background1)
                    case .summary:
                        SummaryView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.background1)
                    }
                }
                .frame(width: sideW, height: totalH)
                .background(Color.background1)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .frame(width: totalW, height: totalH)
        // 접힌 상태에서 펼치기 버튼(우측 상단, 사이드바 상단바 높이에 맞춤)
        .overlay(alignment: .topTrailing) {
            if isSidebarCollapsed {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isSidebarCollapsed = false
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sidebar.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("사이드바 열기")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(Color.text2)
                    .padding(.horizontal, 10)
                    .frame(height: sidebarControlHeight) // 숨김 버튼과 동일 높이
                    .background(Color.background1)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 10)
                .padding(.top, sidebarTopBarVPad) // 상단 바의 세로 패딩과 동일 높이에서 표시
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isSidebarCollapsed)
    }
    
    // MARK: - iPhone Layout (기존 단일 컬럼 유지)
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
                    .tagStudyTarget(.sidebar)
                
                // MARK: SummaryView (하단 1)
                SummaryView()
                    .frame(maxWidth: .infinity)
                    .frame(height: phoneSummaryHeight)
                
                // MARK: QuestionView (하단 2)
                QuestionView(
                    studyViewModel: viewModel,
                    viewModel: questionVM,
                    isGlobalInputActive: $showGlobalQuestionBar
                )
                .frame(maxWidth: .infinity)
                .frame(height: phoneQuestionHeight)
                .tagStudyTarget(.question)
            }
        }
    }
    
    // MARK: - Helpers
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


// MARK: - Study Onboarding Coach Marks

enum StudyOnboardingStep: Int, CaseIterable {
    case media       // 영상 재생 영역
    case sidebar     // 요약/키워드 영역(또는 iPad의 세그먼트 바)
    case question    // 질문(채팅) 영역
    case done
}

enum StudyCoachTarget: Hashable {
    case media
    case sidebar
    case question
}

struct StudyTargetBoundsKey: PreferenceKey {
    static var defaultValue: [StudyCoachTarget: Anchor<CGRect>] = [:]
    static func reduce(value: inout [StudyCoachTarget: Anchor<CGRect>], nextValue: () -> [StudyCoachTarget: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

extension View {
    func tagStudyTarget(_ target: StudyCoachTarget) -> some View {
        anchorPreference(key: StudyTargetBoundsKey.self, value: .bounds) { [target: $0] }
    }
}

struct StudyCoachOverlay: View {
    @Binding var step: StudyOnboardingStep
    let map: [StudyCoachTarget: Anchor<CGRect>]
    let onFinish: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let rect = targetRect(in: proxy)
            // Bubble size and smart positioning
            let bubbleWidth: CGFloat = min(360.0, proxy.size.width - 40.0)
            let rightEdgeClose = rect.maxX > proxy.size.width - 60
            let placeAbove = (step == .question)

            // X positions
            let xBelow = min(max(rect.midX, bubbleWidth/2 + 20), proxy.size.width - bubbleWidth/2 - 20)
            let xLeft  = max(bubbleWidth/2 + 20, rect.minX - 16 - bubbleWidth/2)
            let bubbleX = (placeAbove && rightEdgeClose) ? xLeft : xBelow

            // Y positions
            let yBelow = min(rect.maxY + 90, proxy.size.height - 80)
            let yAbove = max(rect.minY - 90, 100)
            let bubbleY = placeAbove ? yAbove : yBelow

            ZStack {
                Color.black.opacity(0.45).ignoresSafeArea()

                RoundedRectangle(cornerRadius: 12)
                    .stroke(.white.opacity(0.95), lineWidth: 2)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)

                VStack(spacing: 10) {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(message)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(maxWidth: .infinity)
                    HStack {
                        Button("건너뛰기") { onFinish() }
                        Spacer()
                        Button(nextButtonTitle) { next() }
                            .buttonStyle(.borderedProminent)
                    }
                }
                .padding(16)
                .frame(width: bubbleWidth)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                .position(x: bubbleX, y: bubbleY)
            }
        }
    }

    private func next() {
        switch step {
        case .media:   step = .sidebar
        case .sidebar: step = .question
        case .question, .done:
            onFinish()
        }
    }

    private var nextButtonTitle: String {
        switch step {
        case .question, .done: return "완료"
        default: return "다음"
        }
    }

    private var title: String {
        switch step {
        case .media:   return "영상 재생"
        case .sidebar: return "요약 · 키워드"
        case .question:return "질문하기(채팅)"
        case .done:    return ""
        }
    }

    private var message: String {
        switch step {
        case .media:
            return "여기서 영상이 재생돼요."
        case .sidebar:
            return "영상에 맞춰 요약과 키워드가 자동으로 표시돼요."
        case .question:
            return "모르는 건 채팅으로 질문해보세요. 대화는 학습 기록에 남길 수 있어요."
        case .done:
            return ""
        }
    }

    private func targetRect(in proxy: GeometryProxy) -> CGRect {
        func rect(for key: StudyCoachTarget) -> CGRect? {
            guard let anchor = map[key] else { return nil }
            return proxy[anchor]
        }
        switch step {
        case .media:    return rect(for: .media)    ?? fallback(proxy)
        case .sidebar:  return rect(for: .sidebar)  ?? fallback(proxy)
        case .question: return rect(for: .question) ?? fallback(proxy)
        case .done:     return fallback(proxy)
        }
    }

    private func fallback(_ proxy: GeometryProxy) -> CGRect {
        CGRect(x: proxy.size.width/2 - 80, y: proxy.size.height/2 - 40, width: 160, height: 80)
    }
}
