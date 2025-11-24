//
//  LocalizationManager.swift
//  AINO
//
//  언어 설정 관리를 위한 매니저 클래스
//

import SwiftUI
import Foundation
import Combine

class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    
    @Published var currentLanguage: String {
        didSet {
            UserDefaults.standard.set(currentLanguage, forKey: "selectedLanguage")
            // 언어를 수동으로 변경했음을 표시 (시스템 언어 자동 변경 비활성화)
            UserDefaults.standard.set(true, forKey: "languageManuallySet")
            UserDefaults.standard.synchronize()
            updateLocale()
        }
    }
    
    private var bundle: Bundle = Bundle.main
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // UserDefaults에서 저장된 언어 설정 로드
        let languageManuallySet = UserDefaults.standard.bool(forKey: "languageManuallySet")
        
        if languageManuallySet, let savedLanguage = UserDefaults.standard.string(forKey: "selectedLanguage") {
            // 사용자가 수동으로 설정한 경우 그대로 사용
            self.currentLanguage = savedLanguage
        } else {
            // 시스템 언어 감지 및 자동 설정
            let systemLanguage = Self.detectSystemLanguage()
            self.currentLanguage = systemLanguage
            UserDefaults.standard.set(systemLanguage, forKey: "selectedLanguage")
            UserDefaults.standard.set(false, forKey: "languageManuallySet")
            UserDefaults.standard.synchronize()
        }
        updateLocale()
        
        // 시스템 언어 변경 알림 구독 (Combine 사용)
        NotificationCenter.default.publisher(for: .languageDidChange)
            .sink { [weak self] _ in
                self?.handleLanguageChange()
            }
            .store(in: &cancellables)
    }
    
    private func handleLanguageChange() {
        // 사용자가 수동으로 설정하지 않은 경우에만 시스템 언어 변경 반영
        let languageManuallySet = UserDefaults.standard.bool(forKey: "languageManuallySet")
        if !languageManuallySet {
            let systemLanguage = Self.detectSystemLanguage()
            if currentLanguage != systemLanguage {
                currentLanguage = systemLanguage
            }
        }
    }
    
    // 시스템 언어 감지 (static 메서드로 변경하여 init에서 호출 가능)
    private static func detectSystemLanguage() -> String {
        // 시스템의 기본 언어 코드 가져오기
        let preferredLanguage = Locale.preferredLanguages.first ?? "ko"
        
        // 언어 코드에서 기본 언어 추출 (예: "en-US" -> "en", "ko-KR" -> "ko")
        let languageCode = preferredLanguage.prefix(2).lowercased()
        
        // 영어면 "english", 그 외는 "korean" (기본값)
        if languageCode == "en" {
            return "english"
        } else {
            return "korean"
        }
    }
    
    private func updateLocale() {
        let languageCode: String
        switch currentLanguage {
        case "english":
            languageCode = "en"
        case "korean":
            languageCode = "ko"
        default:
            languageCode = "ko"
        }
        
        // 번들 경로 설정
        if let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            self.bundle = bundle
        } else {
            self.bundle = Bundle.main
        }
    }
    
    func localizedString(for key: String, defaultValue: String? = nil) -> String {
        let localizedString = bundle.localizedString(forKey: key, value: nil, table: nil)
        
        // 번역이 없으면 기본값 또는 키 자체를 반환
        if localizedString == key {
            return defaultValue ?? key
        }
        return localizedString
    }
    
    // 언어별 기본 텍스트 제공 (번역 파일이 없을 때 사용)
    func getLocalizedText(korean: String, english: String) -> String {
        switch currentLanguage {
        case "english":
            return english
        case "korean":
            return korean
        default:
            return korean
        }
    }
}

// SwiftUI에서 사용할 수 있는 확장
extension String {
    func localized(defaultValue: String? = nil) -> String {
        return LocalizationManager.shared.localizedString(for: self, defaultValue: defaultValue)
    }
}

// 언어별 텍스트를 쉽게 사용할 수 있는 구조체
struct LocalizedText {
    let korean: String
    let english: String
    
    var text: String {
        LocalizationManager.shared.getLocalizedText(korean: korean, english: english)
    }
}
