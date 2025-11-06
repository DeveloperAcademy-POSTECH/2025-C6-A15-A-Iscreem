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
                            
                            HStack(spacing: 4) {
                                ThemeButton(
                                    title: "시스템 설정 사용",
                                    isSelected: selectedTheme == "system",
                                    useVibrancy: useVibrancy
                                ) {
                                    selectedTheme = "system"
                                }
                                ThemeButton(
                                    title: "라이트 모드",
                                    isSelected: selectedTheme == "light",
                                    useVibrancy: useVibrancy
                                ) {
                                    selectedTheme = "light"
                                }
                                ThemeButton(
                                    title: "다크 모드",
                                    isSelected: selectedTheme == "dark",
                                    useVibrancy: useVibrancy
                                ) {
                                    selectedTheme = "dark"
                                }
                            }
                            .padding(4)
                            .background {
                                vibrancyBackground(useVibrancy: useVibrancy)
                            }
                            .cornerRadius(18)
                            .frame(width: 370, height: 36)
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
                            
                            HStack(spacing: 4) {
                                LanguageButton(
                                    title: "한국어 (Korean)",
                                    isSelected: selectedLanguage == "korean",
                                    useVibrancy: useVibrancy
                                ) {
                                    selectedLanguage = "korean"
                                }
                                LanguageButton(
                                    title: "영어 (English)",
                                    isSelected: selectedLanguage == "english",
                                    useVibrancy: useVibrancy
                                ) {
                                    selectedLanguage = "english"
                                }
                            }
                            .padding(4)
                            .background {
                                vibrancyBackground(useVibrancy: useVibrancy)
                            }
                            .cornerRadius(18)
                            .frame(width: 370, height: 36)
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
                        for id in folderIDsPendingDelete {
                            if let target = folders.first(where: { $0.persistentModelID == id }) {
                                modelContext.delete(target)
                            }
                        }
                        try? modelContext.save()
                        folderIDsPendingDelete.removeAll()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isFolderDeletePresented = false
                        }
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
    
    // 리퀴드 글래스 배경 생성 헬퍼 함수
    @ViewBuilder
    private func vibrancyBackground(useVibrancy: Bool) -> some View {
        if useVibrancy {
            // iOS 15+ Vibrancy effect
            if #available(iOS 15.0, *) {
                RoundedRectangle(cornerRadius: 18)
                    .fill(.ultraThinMaterial)
            } else {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.background2)
            }
        } else {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.background2)
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

// 테마 버튼 컴포넌트 - 리퀴드 글래스 효과 적용
struct ThemeButton: View {
    let title: String
    let isSelected: Bool
    let useVibrancy: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.text1)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background {
                    if isSelected {
                        if useVibrancy {
                            if #available(iOS 15.0, *) {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(.regularMaterial)
                                    .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 1)
                            } else {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.white.opacity(0.9))
                                    .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 1)
                            }
                        } else {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.white.opacity(0.9))
                                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                        }
                    }
                }
                .cornerRadius(14)
                .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

// 언어 버튼 컴포넌트 - 리퀴드 글래스 효과 적용
struct LanguageButton: View {
    let title: String
    let isSelected: Bool
    let useVibrancy: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.text1)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background {
                    if isSelected {
                        if useVibrancy {
                            if #available(iOS 15.0, *) {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(.regularMaterial)
                                    .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 1)
                            } else {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.white.opacity(0.9))
                                    .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 1)
                            }
                        } else {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.white.opacity(0.9))
                                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                        }
                    }
                }
                .cornerRadius(14)
                .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Reset Confirm Alert (Centered Card)
struct ResetConfirmAlertView: View {
    @Binding var isPresented: Bool
    var onConfirm: (() -> Void)? = nil
    
    @State private var confirmationText: String = ""
    private let requiredText = "초기화를 진행 하겠습니다."
    
    var body: some View {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(width: 360, height: 330)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.borderColor, lineWidth: 1))
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
