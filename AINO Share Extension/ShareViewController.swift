//
//  ShareViewController.swift
//  AINO Share Extension
//
//  Created for YouTube URL sharing
//

import UIKit
import UniformTypeIdentifiers
import os.log

@objc(ShareViewController)
class ShareViewController: UIViewController {
    
    private var sharedURL: String?
    private var noteTitle: String = ""
    
    // UI Components
    private let containerView = UIView()
    private let titleLabel = UILabel()
    private let urlTextField = UITextField()
    private let titleTextField = UITextField()
    private let createButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        print("🔵 [Share Extension] init(coder:) called")
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        print("🔵 [Share Extension] init(nibName:bundle:) called")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("🔵 [Share Extension] ========== viewDidLoad START ==========")
        print("🔵 [Share Extension] extensionContext: \(extensionContext != nil ? "exists" : "nil")")
        print("🔵 [Share Extension] Bundle: \(Bundle.main.bundleIdentifier ?? "nil")")
        print("🔵 [Share Extension] Class name: \(NSStringFromClass(type(of: self)))")
        
        // extensionContext가 nil이면 Share Extension이 제대로 로드되지 않은 것
        guard extensionContext != nil else {
            print("❌ [Share Extension] CRITICAL: extensionContext is nil!")
            print("❌ [Share Extension] This means the Share Extension is not properly initialized")
            return
        }
        
        setupUI()
        loadSharedContent()
        print("🔵 [Share Extension] ========== viewDidLoad END ==========")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print("🔵 [Share Extension] viewWillAppear called")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("🔵 [Share Extension] viewDidAppear called")
    }
    
    private func setupUI() {
        // AINO 메인 컬러 (primaryColor: 3A506B)로 배경 설정
        view.backgroundColor = UIColor(hex: "3A506B")
        
        // Container View
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(hex: "121314") : UIColor(hex: "F7F8FA")
        }
        containerView.layer.cornerRadius = 16
        containerView.layer.borderWidth = 1
        
        // Border color 설정
        let borderColor = UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(white: 1.0, alpha: 0.18) : UIColor(hex: "D0D4D8")
        }
        containerView.layer.borderColor = borderColor.cgColor
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOpacity = 0.1
        containerView.layer.shadowRadius = 10
        containerView.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.addSubview(containerView)
        
        // Title Label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "AINO"
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = UIColor { trait in
            trait.userInterfaceStyle == .dark ? .white : UIColor(hex: "1A1A1A")
        }
        containerView.addSubview(titleLabel)
        
        // URL TextField
        urlTextField.translatesAutoresizingMaskIntoConstraints = false
        urlTextField.placeholder = "YouTube 링크를 입력하세요!"
        urlTextField.font = .systemFont(ofSize: 16)
        urlTextField.textColor = UIColor { trait in
            trait.userInterfaceStyle == .dark ? .white : UIColor(hex: "1A1A1A")
        }
        urlTextField.backgroundColor = .clear
        urlTextField.borderStyle = .none
        urlTextField.autocorrectionType = .no
        urlTextField.autocapitalizationType = .none
        urlTextField.keyboardType = .URL
        containerView.addSubview(urlTextField)
        
        // Divider
        let divider = UIView()
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.backgroundColor = UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(white: 1.0, alpha: 0.18) : UIColor(hex: "D0D4D8")
        }
        containerView.addSubview(divider)
        
        // Title TextField
        titleTextField.translatesAutoresizingMaskIntoConstraints = false
        titleTextField.placeholder = "저장할 노트 제목을 입력하세요!"
        titleTextField.font = .systemFont(ofSize: 16)
        titleTextField.textColor = UIColor { trait in
            trait.userInterfaceStyle == .dark ? .white : UIColor(hex: "1A1A1A")
        }
        titleTextField.backgroundColor = .clear
        titleTextField.borderStyle = .none
        titleTextField.returnKeyType = .done
        titleTextField.delegate = self
        containerView.addSubview(titleTextField)
        
        // Cancel Button
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.setTitle("취소", for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .regular)
        cancelButton.setTitleColor(UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(white: 0.85, alpha: 1.0) : UIColor(hex: "555555")
        }, for: .normal)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        view.addSubview(cancelButton)
        
        // Create Button
        createButton.translatesAutoresizingMaskIntoConstraints = false
        createButton.setTitle("노트 생성", for: .normal)
        createButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        createButton.setTitleColor(.white, for: .normal)
        createButton.backgroundColor = UIColor(hex: "5BC0BE")
        createButton.layer.cornerRadius = 20
        createButton.layer.borderWidth = 1
        createButton.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        createButton.addTarget(self, action: #selector(createTapped), for: .touchUpInside)
        createButton.isEnabled = false
        createButton.alpha = 0.5
        view.addSubview(createButton)
        
        // Layout Constraints
        NSLayoutConstraint.activate([
            // Container
            containerView.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor, constant: -60),
            containerView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            containerView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            containerView.heightAnchor.constraint(equalToConstant: 180),
            
            // Title Label
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            
            // URL TextField
            urlTextField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            urlTextField.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            urlTextField.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            urlTextField.heightAnchor.constraint(equalToConstant: 40),
            
            // Divider
            divider.topAnchor.constraint(equalTo: urlTextField.bottomAnchor, constant: 8),
            divider.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            divider.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            divider.heightAnchor.constraint(equalToConstant: 1),
            
            // Title TextField
            titleTextField.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 8),
            titleTextField.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            titleTextField.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            titleTextField.heightAnchor.constraint(equalToConstant: 40),
            
            // Cancel Button
            cancelButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            cancelButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            
            // Create Button
            createButton.topAnchor.constraint(equalTo: containerView.bottomAnchor, constant: 20),
            createButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            createButton.widthAnchor.constraint(equalToConstant: 120),
            createButton.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        // TextField observers
        urlTextField.addTarget(self, action: #selector(textFieldChanged), for: .editingChanged)
        titleTextField.addTarget(self, action: #selector(textFieldChanged), for: .editingChanged)
    }
    
    private func loadSharedContent() {
        print("🔵 [Share Extension] ========== loadSharedContent START ==========")
        os_log("🔵 [Share Extension] loadSharedContent called", log: OSLog.default, type: .default)
        
        guard let extensionContext = extensionContext else {
            print("❌ [Share Extension] extensionContext is nil in loadSharedContent")
            os_log("❌ [Share Extension] extensionContext is nil", log: OSLog.default, type: .error)
            return
        }
        
        guard let extensionItem = extensionContext.inputItems.first as? NSExtensionItem else {
            print("❌ [Share Extension] No extension items")
            os_log("❌ [Share Extension] No extension items", log: OSLog.default, type: .error)
            return
        }
        
        guard let itemProviders = extensionItem.attachments else {
            print("❌ [Share Extension] No attachments")
            os_log("❌ [Share Extension] No attachments", log: OSLog.default, type: .error)
            return
        }
        
        print("✅ [Share Extension] Found \(itemProviders.count) item provider(s)")
        os_log("✅ [Share Extension] Found %d item provider(s)", log: OSLog.default, type: .default, itemProviders.count)
        
        for provider in itemProviders {
            // URL 타입 확인
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                print("✅ [Share Extension] Provider supports URL type")
                provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] (item, error) in
                    DispatchQueue.main.async {
                        if let error = error {
                            print("❌ [Share Extension] Error loading URL item: \(error)")
                            return
                        }
                        if let url = item as? URL {
                            let urlString = url.absoluteString
                            print("✅ [Share Extension] Received URL: \(urlString)")
                            os_log("✅ [Share Extension] Received URL: %@", log: OSLog.default, type: .default, urlString)
                            self?.sharedURL = urlString
                            self?.urlTextField.text = urlString
                            self?.updateCreateButton()
                            print("✅ [Share Extension] URL set, button state: \(self?.createButton.isEnabled ?? false)")
                        } else if let urlString = item as? String {
                            print("✅ [Share Extension] Received URL string: \(urlString)")
                            os_log("✅ [Share Extension] Received URL string: %@", log: OSLog.default, type: .default, urlString)
                            self?.sharedURL = urlString
                            self?.urlTextField.text = urlString
                            self?.updateCreateButton()
                            print("✅ [Share Extension] URL string set, button state: \(self?.createButton.isEnabled ?? false)")
                        } else {
                            print("❌ [Share Extension] Unknown item type: \(type(of: item))")
                            os_log("❌ [Share Extension] Unknown item type", log: OSLog.default, type: .error)
                        }
                    }
                }
            }
            // 텍스트 타입 확인
            else if provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
                print("✅ [Share Extension] Provider supports Text type")
                provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { [weak self] (item, error) in
                    DispatchQueue.main.async {
                        if let error = error {
                            print("❌ [Share Extension] Error loading text item: \(error)")
                            return
                        }
                        if let text = item as? String {
                            print("✅ [Share Extension] Received text: \(text)")
                            let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                            if self?.isYouTubeURL(trimmedText) == true {
                                print("✅ [Share Extension] Text is YouTube URL: \(trimmedText)")
                                os_log("✅ [Share Extension] Text is YouTube URL: %@", log: OSLog.default, type: .default, trimmedText)
                                self?.sharedURL = trimmedText
                                self?.urlTextField.text = trimmedText
                                self?.updateCreateButton()
                                print("✅ [Share Extension] YouTube URL set, button state: \(self?.createButton.isEnabled ?? false)")
                            } else {
                                print("❌ [Share Extension] Text is not a YouTube URL: \(trimmedText)")
                                os_log("❌ [Share Extension] Text is not YouTube URL: %@", log: OSLog.default, type: .error, trimmedText)
                            }
                        } else {
                            print("❌ [Share Extension] Unknown text item type: \(type(of: item))")
                        }
                    }
                }
            } else {
                print("❌ [Share Extension] Provider does not support URL or Text type")
                print("   Available type identifiers: \(provider.registeredTypeIdentifiers)")
                os_log("❌ [Share Extension] Provider does not support URL or Text", log: OSLog.default, type: .error)
            }
        }
        print("🔵 [Share Extension] ========== loadSharedContent END ==========")
    }
    
    @objc private func textFieldChanged() {
        sharedURL = urlTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        noteTitle = titleTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        updateCreateButton()
    }
    
    private func updateCreateButton() {
        let isValid = sharedURL != nil && isYouTubeURL(sharedURL ?? "")
        createButton.isEnabled = isValid
        createButton.alpha = isValid ? 1.0 : 0.5
        print("🔵 [Share Extension] updateCreateButton: isValid=\(isValid), sharedURL=\(sharedURL ?? "nil")")
        os_log("🔵 [Share Extension] Button state updated: enabled=%d", log: OSLog.default, type: .default, isValid)
    }
    
    @objc private func cancelTapped() {
        print("🔵 [Share Extension] cancelTapped called")
        os_log("🔵 [Share Extension] cancelTapped called", log: OSLog.default, type: .default)
        extensionContext?.cancelRequest(withError: NSError(domain: "com.aino.share", code: 0, userInfo: nil))
    }
    
    @objc private func createButtonTouched() {
        print("🔵 [Share Extension] createButtonTouched (touchDown) called")
        os_log("🔵 [Share Extension] Button touched", log: OSLog.default, type: .default)
    }
    
    @objc private func createTapped() {
        // 로그를 os_log로도 출력하여 디버깅 용이하게
        os_log("🔵 [Share Extension] createTapped called", log: OSLog.default, type: .default)
        print("🔵 [Share Extension] ========== createTapped START ==========")
        print("🔵 [Share Extension] sharedURL: \(sharedURL ?? "nil")")
        print("🔵 [Share Extension] extensionContext: \(extensionContext != nil ? "exists" : "nil")")
        
        // extensionContext 확인
        guard let context = extensionContext else {
            print("❌ [Share Extension] CRITICAL: extensionContext is nil!")
            os_log("❌ [Share Extension] extensionContext is nil", log: OSLog.default, type: .error)
            return
        }
        
        // URL 확인
        guard let url = sharedURL, !url.isEmpty else {
            print("❌ [Share Extension] sharedURL is nil or empty")
            print("   urlTextField.text: \(urlTextField.text ?? "nil")")
            os_log("❌ [Share Extension] sharedURL is nil or empty", log: OSLog.default, type: .error)
            context.completeRequest(returningItems: [], completionHandler: nil)
            return
        }
        
        // YouTube URL 확인
        guard isYouTubeURL(url) else {
            print("❌ [Share Extension] URL is not a YouTube URL: \(url)")
            os_log("❌ [Share Extension] URL is not YouTube: %@", log: OSLog.default, type: .error, url)
            context.completeRequest(returningItems: [], completionHandler: nil)
            return
        }
        
        print("✅ [Share Extension] Valid YouTube URL: \(url)")
        
        // 제목 가져오기
        let title = titleTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        print("✅ [Share Extension] Title: '\(title)'")
        
        // URLComponents를 사용하여 안전하게 URL Scheme 생성
        var components = URLComponents()
        components.scheme = "aino"
        components.host = "share"
        components.path = ""
        
        var queryItems: [URLQueryItem] = []
        queryItems.append(URLQueryItem(name: "url", value: url))
        if !title.isEmpty {
            queryItems.append(URLQueryItem(name: "title", value: title))
        }
        components.queryItems = queryItems
        
        guard let urlScheme = components.url else {
            print("❌ [Share Extension] Failed to create URL from components")
            os_log("❌ [Share Extension] Failed to create URL scheme", log: OSLog.default, type: .error)
            context.completeRequest(returningItems: [], completionHandler: nil)
            return
        }
        
        print("🔗 [Share Extension] URL Scheme created: \(urlScheme.absoluteString)")
        os_log("🔗 [Share Extension] Opening URL scheme: %@", log: OSLog.default, type: .default, urlScheme.absoluteString)
        
        // 메인 앱 열기
        // extensionContext?.open()이 실패할 수 있으므로, UserDefaults를 통한 대체 방법도 시도
        if #available(iOS 13.0, *) {
            print("🔵 [Share Extension] Calling extensionContext?.open()...")
            
            // UserDefaults에 데이터 저장 (App Group 사용)
            // TODO: Xcode에서 App Group 설정 필요 (APP_GROUP_SETUP.md 참고)
            let userDefaults = UserDefaults(suiteName: "group.com.kimminung.aino")
            userDefaults?.set(url, forKey: "sharedYouTubeURL")
            userDefaults?.set(title, forKey: "sharedYouTubeTitle")
            userDefaults?.set(Date().timeIntervalSince1970, forKey: "sharedYouTubeTimestamp")
            userDefaults?.synchronize()
            print("✅ [Share Extension] Saved to App Group UserDefaults: url=\(url), title=\(title)")
            
            if userDefaults == nil {
                print("❌ [Share Extension] WARNING: App Group UserDefaults is nil!")
                print("   This means App Group 'group.com.kimminung.aino' is not configured.")
                print("   See APP_GROUP_SETUP.md for setup instructions.")
            }
            
            context.open(urlScheme, completionHandler: { [weak self] success in
                DispatchQueue.main.async {
                    if success {
                        print("✅ [Share Extension] Successfully opened main app via URL scheme!")
                        print("   URL: \(url)")
                        print("   Title: \(title)")
                        os_log("✅ [Share Extension] Successfully opened main app", log: OSLog.default, type: .default)
                    } else {
                        print("❌ [Share Extension] Failed to open main app via URL scheme!")
                        print("   URL Scheme: \(urlScheme.absoluteString)")
                        print("   This is normal on iOS - Share Extensions cannot directly open apps")
                        print("   Data has been saved to App Group UserDefaults")
                        print("   User needs to manually open AINO app to create the note")
                        os_log("❌ [Share Extension] Failed to open main app (expected)", log: OSLog.default, type: .info)
                    }
                    
                    // Share Extension 종료 전에 사용자에게 메시지 표시
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        // 성공 메시지를 보여주고 종료
                        let alert = UIAlertController(
                            title: "저장 완료",
                            message: "AINO 앱을 열어 노트를 확인하세요.",
                            preferredStyle: .alert
                        )
                        alert.addAction(UIAlertAction(title: "확인", style: .default) { _ in
                            self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
                        })
                        self?.present(alert, animated: true)
                        print("🔵 [Share Extension] ========== createTapped END ==========")
                    }
                }
            })
        } else {
            print("❌ [Share Extension] iOS version too old (< iOS 13)")
            context.completeRequest(returningItems: [], completionHandler: nil)
        }
    }
    
    private func isYouTubeURL(_ urlString: String) -> Bool {
        let lowercased = urlString.lowercased()
        return lowercased.contains("youtube.com") ||
               lowercased.contains("youtu.be") ||
               lowercased.contains("youtube.com/watch") ||
               lowercased.contains("youtube.com/shorts") ||
               lowercased.contains("youtube.com/live")
    }
}

// MARK: - UITextFieldDelegate
extension ShareViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == titleTextField {
            // 엔터를 누르면 키보드 닫고 노트 생성 버튼 실행
            textField.resignFirstResponder()
            if createButton.isEnabled {
                createTapped()
            }
            return true
        }
        return false
    }
}

// MARK: - UIColor Extension
extension UIColor {
    convenience init(hex: String) {
        let hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanHex = hexString.hasPrefix("#") ? String(hexString.dropFirst()) : hexString
        var rgb: UInt64 = 0
        Scanner(string: cleanHex).scanHexInt64(&rgb)
        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
