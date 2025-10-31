import SwiftUI
import SwiftData

struct SettingsDetailView: View {
    @Binding var showResetConfirm: Bool
    @State private var isHelpPresented: Bool = false
    @State private var isFolderDeletePresented: Bool = false
    @State private var folderIDsPendingDelete = Set<PersistentIdentifier>()
    @State private var selectedTheme: SettingView.ThemeOption = .system
    @State private var selectedLanguage: SettingView.LanguageOption = .korean
    
    @Environment(\.modelContext) private var modelContext
    @Query private var folders: [Folder]
    @Query private var notes: [Note]
    
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
                                ThemeButton(title: "시스템 설정 사용", isSelected: selectedTheme == .system) { selectedTheme = .system }
                                ThemeButton(title: "라이트 모드",   isSelected: selectedTheme == .light)  { selectedTheme = .light }
                                ThemeButton(title: "다크 모드",     isSelected: selectedTheme == .dark)   { selectedTheme = .dark }
                            }
                            .padding(4)
                            .background(Color.background2)
                            .cornerRadius(18)
                            .frame(width: 370, height: 36)
                        }
                        
                        // 언어 설정
                        HStack(alignment: .top, spacing: 20) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("언어")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(Color.text1)
                                Text("{%app_name}으로 학습할 언어를 설정해세요!")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundStyle(Color.text3)
                            }
                            
                            Spacer()
                            
                            HStack(spacing: 4) {
                                LanguageButton(title: "한국어 (Korean)", isSelected: selectedLanguage == .korean)  { selectedLanguage = .korean }
                                LanguageButton(title: "영어 (English)",  isSelected: selectedLanguage == .english) { selectedLanguage = .english }
                            }
                            .padding(4)
                            .background(Color.background2)
                            .cornerRadius(18)
                            .frame(width: 370, height: 36)
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
                            Text("{%app_name}에서 작성한 모든 노트가 초기화 됩니다.")
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
}

struct SettingView: View {
    enum ThemeOption { case system, light, dark }
    enum LanguageOption { case korean, english }
    @State private var showResetConfirm: Bool = false
    
    var body: some View {
        NavigationSplitView {
            SidebarView(onFolderSelected: { _ in }, isHelpPresented: .constant(false), requestDeleteConfirmation: { _ in })
                .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 400)
                .toolbar(.hidden, for: .navigationBar)
        } detail: {
            SettingsDetailView(showResetConfirm: $showResetConfirm)
        }
    }
}

// 테마 버튼 컴포넌트
struct ThemeButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.text1)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(isSelected ? Color.white : Color.clear)
                .cornerRadius(14)
        }
        .buttonStyle(.plain)
    }
}

// 언어 버튼 컴포넌트
struct LanguageButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.text1)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(isSelected ? Color.white : Color.clear)
                .cornerRadius(14)
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
