import SwiftUI
import SwiftData

struct SettingsDetailView: View {
    @Binding var showResetConfirm: Bool
    @State private var isHelpPresented: Bool = false
    @State private var isFolderDeletePresented: Bool = false
    @State private var folderIDsPendingDelete = Set<PersistentIdentifier>()
    
    // AppStorage를 사용하여 테마 설정을 영구적으로 저장
    @AppStorage("selectedTheme") private var selectedTheme: String = "system"
    @AppStorage("selectedLanguage") private var selectedLanguage: String = "korean"
    
    // 리퀴드 글래스 설정 (기본값: true)
    @AppStorage("useVibrancy") private var useVibrancy: Bool = true
    
    @Environment(\.modelContext) private var modelContext
    @Query private var folders: [Folder]
    @Query private var notes: [Note]
    @EnvironmentObject private var learningLogStore: LearningLogStore
    
    // 테마를 ColorScheme으로 변환
    private var colorScheme: ColorScheme? {
        switch selectedTheme {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SWAI")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Color.text1)
                    
                    Text("설정")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(Color.text2)
                }
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 16)
            
            // 메인 설정 영역
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 기본 설정 섹션
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("기본 설정")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(Color.text1)
                            
                            // 구분선
                            Rectangle()
                                .fill(Color.borderColor)
                                .frame(height: 1)
                        }
                        
                        // 테마 설정
                        HStack(alignment: .top, spacing: 20) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("테마")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(Color.text1)
                                Text("내 기기에서 SWAI의 모습을 바꿔보세요!")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundStyle(Color.text3)
                            }
                            
                            Spacer()
                            
                            ThemeModePicker(selection: $selectedTheme, useVibrancy: $useVibrancy)
                        }
                        
                        // 언어 설정
                        HStack(alignment: .top, spacing: 20) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("언어")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(Color.text1)
                                Text("SWAI로 학습할 언어를 설정하세요!")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundStyle(Color.text3)
                            }
                            
                            Spacer()
                            
                            LanguageModePicker(selection: $selectedLanguage, useVibrancy: $useVibrancy)
                        }
                    }
                    
                    // 외관 설정 섹션
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("외관 설정")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(Color.text1)
                            
                            // 구분선
                            Rectangle()
                                .fill(Color.borderColor)
                                .frame(height: 1)
                        }
                        
                        // 리퀴드 글래스 (Vibrancy) 설정
                        HStack(alignment: .top, spacing: 20) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("리퀴드 글래스 효과")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(Color.text1)
                                Text("반투명한 유리 같은 효과를 적용합니다.")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundStyle(Color.text3)
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: $useVibrancy)
                                .labelsHidden()
                                .toggleStyle(SwitchToggleStyle(tint: .blue))
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            
            // 푸터 영역 (Caution!)
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Caution!")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color.text1)
                        
                        // 구분선
                        Rectangle()
                            .fill(Color.borderColor)
                            .frame(height: 1)
                    }
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("노트 초기화")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color.text1)
                            Text("SWAI에서 작성한 모든 노트가 초기화 됩니다.")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(Color.text3)
                        }
                        
                        Spacer()
                        
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { showResetConfirm = true }
                        } label: {
                            Text("초기화")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.errorColor)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.borderColor, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .preferredColorScheme(colorScheme) // 테마 적용
        .overlay {
            if isFolderDeletePresented {
                FolderDeleteView(
                    onDelete: {
                        // 🔴 설정 화면에서 폴더 삭제 시에도 학습 로그 동시 정리
                        for id in folderIDsPendingDelete {
                            if let target = folders.first(where: { $0.persistentModelID == id }) {
                                learningLogStore.deleteSessions(in: target)
                                modelContext.delete(target)
                            }
                        }
                        try? modelContext.save()
                        folderIDsPendingDelete.removeAll()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isFolderDeletePresented = false
                        }
                        // 보수적 안전망
                        _ = learningLogStore.reconcileWithNotes(currentNotes: notes)
                    },
                    onCancel: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isFolderDeletePresented = false
                        }
                    }
                )
                .transition(.opacity.combined(with: .scale))
            }
        }
    }
}

struct SettingView: View {
    @State private var showResetConfirm: Bool = false
    @AppStorage("selectedTheme") private var selectedTheme: String = "system"
    
    // 테마를 ColorScheme으로 변환
    private var colorScheme: ColorScheme? {
        switch selectedTheme {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
    
    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let insets = proxy.safeAreaInsets
            let h = proxy.size.height - insets.top - insets.bottom
            
            NavigationSplitView {
                SidebarView(
                    onFolderSelected: { _ in },
                    isHelpPresented: .constant(false),
                    requestDeleteConfirmation: { _ in }
                )
                .frame(height: h)
                .navigationSplitViewColumnWidth(
                    min: w * 0.25,
                    ideal: w * 0.25,
                    max: w * 0.25
                )
                .toolbar(.hidden, for: .navigationBar)
            } detail: {
                SettingsDetailView(showResetConfirm: $showResetConfirm)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .preferredColorScheme(colorScheme) // 전체 앱에 테마 적용
        }
        .overlay {
            if showResetConfirm {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showResetConfirm = false
                        }
                    }
                
                ResetConfirmAlertView(
                    isPresented: $showResetConfirm,
                    onConfirm: {
                        // 실제 초기화 로직 구현 필요
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showResetConfirm = false
                        }
                    }
                )
                .transition(.opacity.combined(with: .scale))
            }
        }
    }
}

// 테마 선택 Picker 컴포넌트
struct ThemeModePicker: View {
    @Binding var selection: String
    @Binding var useVibrancy: Bool
    
    var body: some View {
        Picker("", selection: $selection) {
            Text("시스템")
                .tag("system")
            Text("라이트")
                .tag("light")
            Text("다크")
                .tag("dark")
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .background(.clear)
        // 고정폭(370) 제거 → 기기 폭에 따라 자연스럽게 확장/축소
        .frame(minWidth: 200, idealWidth: 320, maxWidth: 460)
        .background(.clear, in: Capsule())
        .overlay(Capsule().stroke(Color.borderColor.opacity(0.5), lineWidth: 1))
    }
    
    // Return a ShapeStyle so it matches the background(_:in:) overload.
    private var vibrancyBackground: AnyShapeStyle {
        if useVibrancy {
            if #available(iOS 15.0, *) {
                return AnyShapeStyle(.ultraThinMaterial)
            } else {
                return AnyShapeStyle(Color.background2)
            }
        } else {
            return AnyShapeStyle(Color.background2)
        }
    }
}

// 언어 선택 Picker 컴포넌트
struct LanguageModePicker: View {
    @Binding var selection: String
    @Binding var useVibrancy: Bool
    
    var body: some View {
        Picker("", selection: $selection) {
            Text("한국어")
                .tag("korean")
            Text("English")
                .tag("english")
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        // 고정폭(370) 제거 → 기기 폭에 따라 자연스럽게 확장/축소
        .frame(minWidth: 200, idealWidth: 320, maxWidth: 460)
        .background(.clear, in: Capsule())
        .overlay(Capsule().stroke(Color.borderColor.opacity(0.5), lineWidth: 1))
    }
    
    private var vibrancyBackground: AnyShapeStyle {
        if useVibrancy {
            if #available(iOS 15.0, *) {
                return AnyShapeStyle(.ultraThinMaterial)
            } else {
                return AnyShapeStyle(Color.background2)
            }
        } else {
            return AnyShapeStyle(Color.background2)
        }
    }
}

// MARK: - Reset Confirm Alert (Centered Card)
struct ResetConfirmAlertView: View {
    @Binding var isPresented: Bool
    var onConfirm: (() -> Void)? = nil
    
    @State private var confirmationText: String = ""
    private let requiredText = "초기화를 진행 하겠습니다."
    
    var body: some View {
        GeometryReader { geo in
            // 화면 크기에 따라 카드 크기 계산 (상한을 두어 과도한 확대 방지)
            let cardWidth = min(420, geo.size.width * 0.9)
            let cardHeight = min(380, geo.size.height * 0.6)
            
            VStack(spacing: 0) {
                // Title & description
                VStack(alignment: .leading, spacing: 12) {
                    Text("모든 노트가 초기화 됩니다!")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.text1)
                    
                    Text("이 작업은 실행 이후 복구할 수 없습니다.")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.text2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 22)
                
                Spacer(minLength: 8)
                
                // Input area
                VStack(alignment: .leading, spacing: 0) {
                    Text(requiredText)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.text1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Divider().background(Color.borderColor).padding(.vertical, 10)
                    
                    TextField("위 문장을 입력하세요.", text: $confirmationText, axis: .horizontal)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .font(.system(size: 15))
                        .foregroundStyle(Color.text1)
                        .padding(.vertical, 8)
                }
                .padding(16)
                .background(Color.background2)
                .cornerRadius(14)
                .padding(.horizontal, 20)
                
                Spacer(minLength: 8)
                
                // Buttons
                HStack(spacing: 12) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { isPresented = false }
                    } label: {
                        Text("취소")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.text1)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(14)
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        onConfirm?()
                    } label: {
                        Text("초기화")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(isValid ? Color.errorColor : Color.text3.opacity(0.5))
                            .cornerRadius(14)
                    }
                    .buttonStyle(.plain)
                    .disabled(!isValid)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .frame(width: cardWidth, height: cardHeight)
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.borderColor, lineWidth: 1))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
    
    private var isValid: Bool {
        confirmationText.trimmingCharacters(in: .whitespacesAndNewlines) == requiredText
    }
}

#Preview(traits: .landscapeLeft) {
    SettingView()
}

#Preview(traits: .landscapeLeft) {
    SettingsDetailView(showResetConfirm: .constant(false))
}
