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
    
    @EnvironmentObject private var captionAnalyzer: CaptionAnalyzer
    @EnvironmentObject private var learningLogStore: LearningLogStore
    @EnvironmentObject private var localizationManager: LocalizationManager
    @Query private var notes: [Note]
    
    @AppStorage("hasSeenStudyOnboarding") private var hasSeenStudyOnboarding: Bool = false
    @State private var studyOnboardingStep: StudyOnboardingStep = .media
    
    // 뒤로가기 제스처 상태
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false
    
    // 접기/펼치기 상태
    @State private var isSummaryExpanded: Bool = true
    @State private var isKeywordExpanded: Bool = true
    
    // 디바이스 타입 감지
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    // iPad 고정 비율
    private let mainWidthRatio: CGFloat = 0.65
    private let rightSidebarWidthRatio: CGFloat = 0.35
    private let mainTopMediaHeightRatio: CGFloat = 0.6
    private let mainBottomKeywordHeightRatio: CGFloat = 0.4
    
    // iPhone 고정 높이
    private let phoneSummaryHeight: CGFloat = 360
    private let phoneSummaryCollapsedHeight: CGFloat = 60
    private let phoneKeywordHeight: CGFloat = 360
    private let phoneKeywordCollapsedHeight: CGFloat = 60
    private let phoneQuestionHeight: CGFloat = 360
    
    // iPad 레이아웃 기준 해상도 (13인치 가로형 1366x1024)
    private let baseIPadLandscapeSize = CGSize(width: 1366, height: 1024)
    
    // 사이드바 탭 (키워드/요약 전환)
    private enum SidebarTab: String, CaseIterable {
        case keywords = "keywords"
        case summary = "summary"
        
        var displayName: String {
            switch self {
            case .keywords:
                return LocalizedText(korean: "키워드", english: "Keywords").text
            case .summary:
                return LocalizedText(korean: "요약", english: "Summary").text
            }
        }
    }
    @State private var sidebarTab: SidebarTab = .summary
    @State private var isSidebarCollapsed: Bool = false
    
    // 전역 입력 상태 관리
    @State private var isGlobalInputActive: Bool = false
    
    init(note: Note? = nil, onDismiss: (() -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: StudyViewModel(note: note))
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: 헤더
            HStack {
                Button(action: {
                    performDismiss()
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
                        ?? LocalizedText(korean: "노트의 제목", english: "Note Title").text
                    )
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.text1)
                    
                    Text(headerProgressText)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.text3)
                }
                
                Spacer()
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
        .offset(x: dragOffset)
        .overlay(
            Color.black.opacity(isDragging ? 0.1 : 0)
                .animation(.easeOut(duration: 0.2), value: isDragging)
                .allowsHitTesting(false)
        )
        .gesture(swipeBackGesture)
        .keyboardOverlay()
        .overlayPreferenceValue(StudyTargetBoundsKey.self) { map in
            if !hasSeenStudyOnboarding {
                StudyCoachOverlay(step: $studyOnboardingStep, map: map) {
                    hasSeenStudyOnboarding = true
                }
            }
        }
        .onAppear { captionAnalyzer.autoSummarizeEnabled = true }
        
        .onChange(of: captionAnalyzer.vttStatus) { _, newValue in
            if case .ready = newValue {
                if let note = viewModel.currentNote {
                    let total = captionAnalyzer.vttCues.map(\.end).max()
                    note.totalDurationSeconds = total
                    try? modelContext.save()
                }
            }
        }
        
        .onChange(of: captionAnalyzer.summaryStatus) { _, newValue in
            if case .ready = newValue {
                try? modelContext.save()
            }
        }
    }
    
    // MARK: - Swipe Back Gesture
    private var swipeBackGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if value.startLocation.x < 30 && value.translation.width > 0 {
                    isDragging = true
                    dragOffset = value.translation.width
                }
            }
            .onEnded { value in
                if value.translation.width > 120 && value.startLocation.x < 30 {
                    performDismiss()
                } else {
                    withAnimation(.easeOut(duration: 0.2)) {
                        dragOffset = 0
                        isDragging = false
                    }
                }
            }
    }
    
    private func performDismiss() {
        withAnimation(.easeOut(duration: 0.25)) {
            dragOffset = UIScreen.main.bounds.width
        }
        
        viewModel.closeButtonTapped()
        NotificationCenter.default.post(name: .persistPlaybackPosition, object: viewModel.currentNote)
        NotificationCenter.default.post(name: .pausePlaybackRequested, object: nil)
        UserDefaults.standard.set(true, forKey: "TriggerPostHomeOnboarding")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            onDismiss?()
        }
    }
    
    // MARK: - Header Helpers
    private var headerProgressText: String {
        let last = lastPositionFromLogs() ?? viewModel.currentNote?.lastPositionSeconds
        let total = captionAnalyzer.vttCues.map(\.end).max()
        let leftText = formatDurationString(last)
        let rightText = formatDurationString(total)
        let lastText = LocalizedText(korean: "마지막 학습 위치", english: "Last Position").text
        let totalText = LocalizedText(korean: "전체 학습 길이", english: "Total Length").text
        return "\(lastText): \(leftText) / \(totalText): \(rightText)"
    }
    
    private func lastPositionFromLogs() -> Double? {
        guard let note = viewModel.currentNote else { return nil }
        let nid = String(describing: note.id)
        let url = note.videoURL ?? resolvedVideoURL
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
    
    
    // MARK: - iPad Layout
    @ViewBuilder
    private func iPadLayout(geometry: GeometryProxy) -> some View {
        let totalW = geometry.size.width
        let totalH = geometry.size.height
        
        let scaler = BaseLayoutScaler(proxy: geometry, base: baseIPadLandscapeSize)
        
        let sideW = isSidebarCollapsed ? 0 : totalW * rightSidebarWidthRatio
        let mainW = totalW - sideW
        
        let sidebarTopBarVPad: CGFloat = scaler.h(8)
        let sidebarControlHeight: CGFloat = scaler.h(32)
        
        HStack(spacing: 0) {
            // MAIN (좌측)
            VStack(spacing: 0) {
                let mediaH = totalH * mainTopMediaHeightRatio
                let keywordH = max(0, totalH - mediaH)
                
                let embedBaseWidthWhenSidebarOpen = totalW * mainWidthRatio
                let embedWidth = isSidebarCollapsed ? embedBaseWidthWhenSidebarOpen : mainW
                
                // MediaView
                ZStack {
                    MediaView(note: viewModel.currentNote, videoURL: resolvedVideoURL)
                        .frame(width: embedWidth, height: mediaH)
                        .clipped()
                        .tagStudyTarget(.media)
                }
                .frame(width: mainW, height: mediaH, alignment: .center)
                .frame(maxWidth: .infinity, alignment: .top)
                
                // Summary/Keyword container
                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        Picker("", selection: $sidebarTab) {
                            Text(SidebarTab.summary.displayName).tag(SidebarTab.summary)
                            Text(SidebarTab.keywords.displayName).tag(SidebarTab.keywords)
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, sidebarTopBarVPad)
                    .tagStudyTarget(.sidebar)
                    
                    Divider().background(Color.borderColor)
                    
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
                .frame(width: mainW, height: keywordH)
                .frame(maxWidth: .infinity, alignment: .bottom)
                .background(Color.background1)
            }
            .frame(width: mainW, height: totalH)
            
            // RIGHT SIDEBAR
            if sideW > 0 {
                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        Spacer()
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isSidebarCollapsed = true
                            }
                        } label: {
                            Image(systemName: "sidebar.right")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.text2)
                                .frame(width: scaler.w(32), height: sidebarControlHeight)
                                .background(Color.background2)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, sidebarTopBarVPad)
                    
                    Divider().background(Color.borderColor)
                    
                    QuestionView(
                        studyViewModel: viewModel,
                        viewModel: viewModel.questionViewModel,
                        isGlobalInputActive: $isGlobalInputActive
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.background1)
                    .tagStudyTarget(.question)
                }
                .frame(width: sideW, height: totalH)
                .background(Color.background1)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .frame(width: totalW, height: totalH)
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
                        Text(LocalizedText(korean: "사이드바 열기", english: "Open Sidebar").text)
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(Color.text2)
                    .padding(.horizontal, 10)
                    .frame(height: sidebarControlHeight)
                    .background(Color.background1)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10).stroke(Color.borderColor, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 10)
                .padding(.top, sidebarTopBarVPad)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isSidebarCollapsed)
    }
    
    // MARK: - iPhone Layout (단일 컬럼) - 수정됨
    @ViewBuilder
    private func iPhoneLayout(geometry: GeometryProxy) -> some View {
        let totalHeight = geometry.size.height
        let totalWidth = geometry.size.width
        
        let isLandscape = totalWidth > totalHeight
        
        let mediaHeight: CGFloat = {
            if isLandscape {
                return max(totalHeight * 0.5, 200)
            } else {
                return min(totalHeight * 0.3, totalWidth * 9 / 16)
            }
        }()
        
        VStack(spacing: 0) {
            // MediaView (상단 고정 - 스크롤되지 않음)
            MediaView(note: viewModel.currentNote, videoURL: resolvedVideoURL)
                .frame(height: mediaHeight)
                .frame(maxWidth: .infinity)
                .tagStudyTarget(.media)
            
            // 나머지 콘텐츠는 스크롤 가능
            ScrollView {
                VStack(spacing: 0) {
                    // SummaryView (중간) - Binding 전달 + 동적 높이
                    SummaryView(isExpanded: $isSummaryExpanded)
                        .frame(maxWidth: .infinity)
                        .frame(height: isSummaryExpanded ? nil : phoneSummaryCollapsedHeight)
                        .animation(.easeInOut(duration: 0.2), value: isSummaryExpanded)
                        .tagStudyTarget(.sidebar)
                    
                    // KeywordView (요약 아래) - Binding 전달 + 동적 높이
                    KeywordView(
                        analyzer: captionAnalyzer,
                        studyViewModel: viewModel,
                        isExpanded: $isKeywordExpanded
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: isKeywordExpanded ? nil : phoneKeywordCollapsedHeight)
                    .animation(.easeInOut(duration: 0.2), value: isKeywordExpanded)
                    .background(Color.background1)
                    .tagStudyTarget(.sidebarBottom)
                    
                    // QuestionView (하단)
                    QuestionView(
                        studyViewModel: viewModel,
                        viewModel: viewModel.questionViewModel,
                        isGlobalInputActive: $isGlobalInputActive
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: phoneQuestionHeight)
                    .background(Color.background1)
                    .tagStudyTarget(.question)
                }
            }
        }
    }
    
    // MARK: - Helpers
    private var resolvedVideoURL: String? {
        if let url = viewModel.currentNote?.videoURL, !url.isEmpty {
            return url
        }
        if let url = viewModel.currentNote?.thumbnailURL, !url.isEmpty {
            return url
        }
        if let title = viewModel.currentNote?.title,
           let matched = notes.first(where: { $0.title == title }) {
            if let v = matched.videoURL, !v.isEmpty { return v }
            if let t = matched.thumbnailURL, !t.isEmpty { return t }
        }
        return nil
    }
}

// MARK: - Study Onboarding Coach Marks

enum StudyOnboardingStep: Int, CaseIterable {
    case media
    case sidebar
    case question
    case done
}

enum StudyCoachTarget: Hashable {
    case media
    case sidebar
    case sidebarBottom
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
            let highlightPadding: CGFloat = 12
            let highlightRect = rect.insetBy(dx: -highlightPadding, dy: -highlightPadding)
            
            let bubbleWidth: CGFloat = min(360.0, proxy.size.width - 40.0)
            let rightEdgeClose = rect.maxX > proxy.size.width - 60
            let placeAbove = (step == .question)
            
            let xBelow = min(max(rect.midX, bubbleWidth/2 + 20), proxy.size.width - bubbleWidth/2 - 20)
            let xLeft  = max(bubbleWidth/2 + 20, rect.minX - 16 - bubbleWidth/2)
            let bubbleX = (placeAbove && rightEdgeClose) ? xLeft : xBelow
            
            let yBelow = min(rect.maxY + 90, proxy.size.height - 80)
            let yAbove = max(rect.minY - 90, 100)
            let bubbleY = placeAbove ? yAbove : yBelow
            
            ZStack {
                Rectangle()
                    .fill(Color.black.opacity(0.45))
                    .ignoresSafeArea()
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .frame(width: highlightRect.width, height: highlightRect.height)
                            .position(x: highlightRect.midX, y: highlightRect.midY)
                            .blendMode(.destinationOut)
                    )
                    .compositingGroup()
                
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.clear, lineWidth: 2)
                    .frame(width: highlightRect.width, height: highlightRect.height)
                    .position(x: highlightRect.midX, y: highlightRect.midY)
                
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
                        Button(LocalizedText(korean: "건너뛰기", english: "Skip").text) { onFinish() }
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
        case .question, .done: return LocalizedText(korean: "완료", english: "Done").text
        default: return LocalizedText(korean: "다음", english: "Next").text
        }
    }
    
    private var title: String {
        switch step {
        case .media:   return LocalizedText(korean: "영상 재생", english: "Video Playback").text
        case .sidebar: return LocalizedText(korean: "요약 · 키워드", english: "Summary · Keywords").text
        case .question:return LocalizedText(korean: "질문하기(채팅)", english: "Ask Questions (Chat)").text
        case .done:    return ""
        }
    }
    
    private var message: String {
        switch step {
        case .media:
            return LocalizedText(korean: "여기서 영상이 재생돼요.", english: "Videos play here.").text
        case .sidebar:
            return LocalizedText(korean: "영상에 맞춰 요약과 키워드가 자동으로 표시돼요.", english: "Summaries and keywords are automatically displayed based on the video.").text
        case .question:
            return LocalizedText(korean: "모르는 건 채팅으로 질문해보세요. 대화는 학습 기록에 남길 수 있어요.", english: "Ask questions in chat about anything you don't know. Conversations can be saved to your learning history.").text
        case .done:
            return ""
        }
    }
    
    private func targetRect(in: GeometryProxy) -> CGRect {
        func rect(for key: StudyCoachTarget) -> CGRect? {
            guard let anchor = map[key] else { return nil }
            return `in`[anchor]
        }
        switch step {
        case .media:
            return rect(for: .media) ?? fallback(`in`)
            
        case .sidebar:
            if let top = rect(for: .sidebar), let bottom = rect(for: .sidebarBottom) {
                return union(top, bottom)
            }
            if let top = rect(for: .sidebar) {
                return top
            }
            if let bottom = rect(for: .sidebarBottom) {
                return bottom
            }
            return fallback(`in`)
            
        case .question:
            return rect(for: .question) ?? fallback(`in`)
            
        case .done:
            return fallback(`in`)
        }
    }
    
    private func fallback(_ proxy: GeometryProxy) -> CGRect {
        CGRect(x: proxy.size.width/2 - 80, y: proxy.size.height/2 - 40, width: 160, height: 80)
    }
    
    private func union(_ r1: CGRect, _ r2: CGRect) -> CGRect {
        let minX = min(r1.minX, r2.minX)
        let minY = min(r1.minY, r2.minY)
        let maxX = max(r1.maxX, r2.maxX)
        let maxY = max(r1.maxY, r2.maxY)
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
