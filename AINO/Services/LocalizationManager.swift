//
//  LocalizationManager.swift
//  AINO
//
//  언어 설정 관리를 위한 매니저 클래스
//

import SwiftUI
import Foundation

class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    
    @Published var currentLanguage: String {
        didSet {
            UserDefaults.standard.set(currentLanguage, forKey: "selectedLanguage")
            UserDefaults.standard.synchronize()
            updateLocale()
        }
    }
    
    private var bundle: Bundle = Bundle.main
    
    private init() {
        // UserDefaults에서 저장된 언어 설정 로드
        self.currentLanguage = UserDefaults.standard.string(forKey: "selectedLanguage") ?? "korean"
        updateLocale()
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
