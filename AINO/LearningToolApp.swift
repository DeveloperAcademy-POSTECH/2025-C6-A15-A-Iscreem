//
//  LearningToolApp.swift
//  learningTool
//
//  Created by Mumin on 10/18/25.
//

import SwiftUI
import SwiftData
import UIKit

final class LearningToolAppDelegate: NSObject, UIApplicationDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        print("🚀 [Main App] Application didFinishLaunchingWithOptions")
        print("🚀 [Main App] Bundle ID: \(Bundle.main.bundleIdentifier ?? "nil")")
        return true
    }
    
    // 앱이 포그라운드로 돌아올 때마다 호출
    func applicationWillEnterForeground(_ application: UIApplication) {
        print("🔄 [Main App] ========== applicationWillEnterForeground 호출됨 ==========")
        print("🔄 [Main App] 앱이 포그라운드로 돌아오는 중...")
        print("🔄 [Main App] NotificationCenter를 통해 알림 전송 중...")
        // NotificationCenter를 통해 알림 전송
        NotificationCenter.default.post(name: .appWillEnterForeground, object: nil)
        print("🔄 [Main App] ✅ 알림 전송 완료")
    }
    
    // 앱이 활성화될 때마다 호출 (최초 실행 포함)
    func applicationDidBecomeActive(_ application: UIApplication) {
        print("✅ [Main App] ========== applicationDidBecomeActive 호출됨 ==========")
        print("✅ [Main App] 앱이 활성화되었습니다.")
        
        // 시스템 언어 변경 감지 및 업데이트
        checkAndUpdateSystemLanguage()
        
        print("✅ [Main App] NotificationCenter를 통해 알림 전송 중...")
        // NotificationCenter를 통해 알림 전송
        NotificationCenter.default.post(name: .appDidBecomeActive, object: nil)
        print("✅ [Main App] ✅ 알림 전송 완료")
    }
    
    // 시스템 언어 확인 및 업데이트
    private func checkAndUpdateSystemLanguage() {
        // 사용자가 수동으로 언어를 설정하지 않은 경우에만 시스템 언어를 따름
        let languageManuallySet = UserDefaults.standard.bool(forKey: "languageManuallySet")
        
        if !languageManuallySet {
            let preferredLanguage = Locale.preferredLanguages.first ?? "ko"
            let languageCode = preferredLanguage.prefix(2).lowercased()
            let systemLanguage = languageCode == "en" ? "english" : "korean"
            
            // 현재 설정과 다르면 업데이트
            let currentLanguage = UserDefaults.standard.string(forKey: "selectedLanguage") ?? "korean"
            if currentLanguage != systemLanguage {
                UserDefaults.standard.set(systemLanguage, forKey: "selectedLanguage")
                UserDefaults.standard.synchronize()
                // LocalizationManager에 변경 알림
                NotificationCenter.default.post(name: .languageDidChange, object: nil)
                print("🌐 [Main App] System language changed to: \(systemLanguage)")
            }
        }
    }
    
    // 앱이 백그라운드로 이동할 때 호출
    func applicationDidEnterBackground(_ application: UIApplication) {
        print("🔙 [Main App] ========== applicationDidEnterBackground 호출됨 ==========")
        print("🔙 [Main App] 앱이 백그라운드로 이동했습니다.")
    }
    
    // 앱이 비활성화될 때 호출
    func applicationWillResignActive(_ application: UIApplication) {
        print("⏸️ [Main App] ========== applicationWillResignActive 호출됨 ==========")
        print("⏸️ [Main App] 앱이 비활성화되었습니다.")
    }
    
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        // iPad: landscape only, iPhone: portrait only
        switch UIDevice.current.userInterfaceIdiom {
        case .pad:
            return [.landscapeLeft, .landscapeRight]
        case .phone:
            return [.portrait]
        default:
            // 기본은 iPhone과 동일하게 세로 고정
            return [.portrait]
        }
    }
    
    // URL Scheme을 통한 URL 처리 (onOpenURL과 함께 작동)
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        print("🔗 [Main App] ========== application(_:open:options:) CALLED ==========")
        print("🔗 [Main App] Received URL: \(url.absoluteString)")
        print("🔗 [Main App] URL Scheme: \(url.scheme ?? "nil")")
        print("🔗 [Main App] URL Host: \(url.host ?? "nil")")
        print("🔗 [Main App] URL Path: \(url.path)")
        print("🔗 [Main App] URL Query: \(url.query ?? "nil")")
        
        // aino://share?url=...&title=... 형식 처리
        if url.scheme == "aino" && url.host == "share" {
            print("✅ [Main App] URL matches aino://share pattern")
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let queryItems = components.queryItems,
               let encodedURL = queryItems.first(where: { $0.name == "url" })?.value {
                // URL 디코딩
                let sharedURL = encodedURL.removingPercentEncoding ?? encodedURL
                print("📝 Decoded URL: \(sharedURL)")
                
                // 제목도 함께 가져오기
                let encodedTitle = queryItems.first(where: { $0.name == "title" })?.value
                let sharedTitle = encodedTitle?.removingPercentEncoding ?? ""
                print("📝 Decoded Title: \(sharedTitle)")
                
                // URL과 제목을 NotificationCenter를 통해 HomeView에 전달
                // 약간의 지연을 두어 앱이 완전히 활성화된 후 전달
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    var userInfo: [String: Any] = ["url": sharedURL]
                    if !sharedTitle.isEmpty {
                        userInfo["title"] = sharedTitle
                    }
                    print("📤 Posting notification with userInfo: \(userInfo)")
                    NotificationCenter.default.post(
                        name: .handleYouTubeURL,
                        object: nil,
                        userInfo: userInfo
                    )
                    print("📤 Notification posted")
                }
                return true
            }
        }
        
        // 일반 URL 처리 (직접 YouTube URL인 경우)
        let urlString = url.absoluteString
        if urlString.contains("youtube.com") || urlString.contains("youtu.be") {
            print("📝 Direct YouTube URL: \(urlString)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NotificationCenter.default.post(
                    name: .handleYouTubeURL,
                    object: nil,
                    userInfo: ["url": urlString]
                )
            }
            return true
        }
        
        return false
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let appWillEnterForeground = Notification.Name("AppWillEnterForeground")
    static let appDidBecomeActive = Notification.Name("AppDidBecomeActive")
    static let languageDidChange = Notification.Name("LanguageDidChange")
}

@main
struct LearningToolApp: App {
    @UIApplicationDelegateAdaptor(LearningToolAppDelegate.self) private var appDelegate
    
    @StateObject private var captionAnalyzer = CaptionAnalyzer()
    @StateObject private var learningLogStore: LearningLogStore
    @StateObject private var localizationManager = LocalizationManager.shared

    private let modelContainer: ModelContainer
    
    // 마지막으로 처리한 타임스탬프를 추적하여 중복 처리 방지
    // UserDefaults에 저장하여 앱 재시작 후에도 유지
    private var lastProcessedTimestamp: Double {
        get {
            UserDefaults.standard.double(forKey: "lastProcessedYouTubeTimestamp")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "lastProcessedYouTubeTimestamp")
            UserDefaults.standard.synchronize()
        }
    }

    // Build the container outside of init to avoid escaping-autoclosure issues.
    private static func makeModelContainer() -> ModelContainer {
        do {
            let schema = Schema([StudySession.self, StudyQAPair.self, Note.self, Folder.self])
            return try ModelContainer(for: schema)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    init() {
        let container = Self.makeModelContainer()
        self.modelContainer = container

        // Initialize LearningLogStore with the container's main context.
        let store = LearningLogStore(context: container.mainContext)
        _learningLogStore = StateObject(wrappedValue: store)
        
        // 앱 시작 시 UserDefaults에서 공유된 URL 확인
        print("🚀 [Main App] Init - App starting...")
    }
    
    private func checkForSharedURL() {
        // TODO: Xcode에서 App Group 설정 필요 (APP_GROUP_SETUP.md 참고)
        let userDefaults = UserDefaults(suiteName: "group.site.eifer.app.learningTool")
        print("🔍 [Main App] ========== checkForSharedURL START ==========")
        print("🔍 [Main App] Checking App Group UserDefaults for sharedYouTubeURL...")
        
        if userDefaults == nil {
            print("❌ [Main App] WARNING: App Group UserDefaults is nil!")
            print("   This means App Group 'group.site.eifer.app.learningTool' is not configured.")
            print("   See APP_GROUP_SETUP.md for setup instructions.")
            print("🔍 [Main App] ========== checkForSharedURL END (No App Group) ==========")
            return
        }
        
        guard let sharedURL = userDefaults?.string(forKey: "sharedYouTubeURL") else {
            print("🔍 [Main App] No shared URL found in App Group UserDefaults")
            print("🔍 [Main App] ========== checkForSharedURL END (No Data) ==========")
            return
        }
        
        let sharedTitle = userDefaults?.string(forKey: "sharedYouTubeTitle") ?? ""
        let timestamp = userDefaults?.double(forKey: "sharedYouTubeTimestamp") ?? 0
        
        print("📬 [Main App] ✅ Found shared URL in App Group UserDefaults!")
        print("📬 [Main App] URL: \(sharedURL)")
        print("📬 [Main App] Title: '\(sharedTitle)'")
        print("📬 [Main App] Timestamp: \(Date(timeIntervalSince1970: timestamp))")
        print("📬 [Main App] Last Processed Timestamp: \(Date(timeIntervalSince1970: lastProcessedTimestamp))")
        
        // 이미 처리한 데이터인지 확인 (중복 처리 방지)
        if timestamp > 0 && timestamp <= lastProcessedTimestamp {
            print("⚠️ [Main App] This URL was already processed (timestamp: \(timestamp) <= \(lastProcessedTimestamp))")
            print("   Skipping duplicate processing")
            print("🔍 [Main App] ========== checkForSharedURL END (Already Processed) ==========")
            return
        }
        
        // 처리 전에 즉시 UserDefaults에서 데이터 삭제 (중복 방지)
        print("🗑️ [Main App] Removing shared data from App Group UserDefaults...")
        userDefaults?.removeObject(forKey: "sharedYouTubeURL")
        userDefaults?.removeObject(forKey: "sharedYouTubeTitle")
        userDefaults?.removeObject(forKey: "sharedYouTubeTimestamp")
        userDefaults?.synchronize()
        print("🗑️ [Main App] ✅ Shared data removed from UserDefaults")
        
        // 마지막 처리 타임스탬프 업데이트 (UserDefaults에 저장)
        let newTimestamp = timestamp > 0 ? timestamp : Date().timeIntervalSince1970
        UserDefaults.standard.set(newTimestamp, forKey: "lastProcessedYouTubeTimestamp")
        UserDefaults.standard.synchronize()
        print("📝 [Main App] Updated lastProcessedTimestamp to: \(newTimestamp)")
        
        // NotificationCenter를 통해 전달
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            var userInfo: [String: Any] = ["url": sharedURL]
            if !sharedTitle.isEmpty {
                userInfo["title"] = sharedTitle
            }
            print("📤 [Main App] Posting notification with userInfo: \(userInfo)")
            NotificationCenter.default.post(
                name: .handleYouTubeURL,
                object: nil,
                userInfo: userInfo
            )
            print("📤 [Main App] ✅ Notification posted successfully")
        }
        
        print("🔍 [Main App] ========== checkForSharedURL END (Success) ==========")
    }

    var body: some Scene {
        WindowGroup {
            HomeView.AppRootView()
                .environmentObject(captionAnalyzer)
                .environmentObject(learningLogStore)
                .environmentObject(localizationManager)
                .onAppear {
                    print("📱 [Main App] HomeView onAppear - Initial appearance")
                    // 앱이 나타날 때마다 공유된 URL 확인
                    checkForSharedURL()
                }
        }
        // Attach the same container to the Scene so Views get @Environment(\.modelContext)
        .modelContainer(modelContainer)
    }
}
