# iPad: [Project/App Name]
[Logo/Cover Image]
<img width="4096" height="4096" alt="Main" src="https://github.com/user-attachments/assets/ee94215f-bde7-4403-9682-b74f73522d14" />

## [App statement]

아이패드로 유튜브 강의를 들으며 공부하는 대학생의 몰입이 깨지지 않도록 AI가 요약하고 핵심 키워드를 보여주면서 바로 질문할 수 있는 앱

## [App statement][Eng]

An app designed for university students studying with YouTube lectures on iPad — it helps maintain focus by using AI to summarize content, highlight key concepts, and enable instant questions without breaking immersion.




### :Apple Intelligence (On-Device) Requirements:
This app’s AI summarization uses Apple’s on-device foundation model (Apple Intelligence).

- **iPhone:** iPhone 16 lineup, iPhone 15 Pro/Pro Max  
- **iPad:** iPad mini (A17 Pro), iPad models with **M1 or later**  
- **Mac:** **M1 or later**  
- Make sure **Apple Intelligence is enabled** and **Siri + device language** are set to a supported language (e.g., Korean).

> On devices that don’t meet these requirements, the app may fall back to server summarization (if configured) or disable summarization.

Refs: Apple Newsroom availability notes.  [oai_citation:5‡Apple](https://www.apple.com/newsroom/2025/06/apple-elevates-the-iphone-experience-with-ios-26/)




## :다이어그램:

Attach photos if you are available
<img width="1582" height="2271" alt="analyzer_flow" src="https://github.com/user-attachments/assets/238ce3af-27cb-4030-8f53-83b29f9fa35b" />
<img width="2016" height="1422" alt="async_sequence" src="https://github.com/user-attachments/assets/99cd58ab-af15-43d5-b17a-64f5c8b1f6a7" />

## :framed_picture: Demo (optional)

Attach videos if you are available
<img width="1472" height="1183" alt="스크린샷 2025-10-20 오후 6 41 10" src="https://github.com/user-attachments/assets/7c78688e-6fa6-46d1-aa60-d2966a4be2e8" />
<img width="964" height="714" alt="스크린샷 2025-10-22 오후 6 42 02" src="https://github.com/user-attachments/assets/f1964cf2-90f7-489a-ad17-66748b5a1bb9" />

<video src="https://github.com/user-attachments/assets/3f8f7ee3-317a-417a-b368-a337a972d227" width="920" controls playsinline></video>
<video src="https://raw.githubusercontent.com/<USER>/<REPO>/<BRANCH>/assets/KakaoTalk_Video_2025-10-28-17-52-00.mp4"
       width="920" autoplay loop muted playsinline></video>


## :pushpin: Features

- 영상 강의(유튜브 한정) 노트 저장
- 폴더별 노트 관리
- 강의 내용 구간별 요약
- 구간 요약시 맥락에 맞게 도출되는 주요 키워드
- 제미나이(이용자 api key 설정 후)AI를 통한 채팅 질문
- 키워드에 호버하여 빠른 채팅 입력
- 키워드 입력시 적당한 질문을 생성해주는 질문 생성 기능



## Tree

.
├── learningTool
│   ├── Assets.xcassets
│   │   ├── AccentColor.colorset
│   │   │   └── Contents.json
│   │   ├── AppIcon.appiconset
│   │   │   └── Contents.json
│   │   └── Contents.json
│   ├── Components
│   │   ├── HeaderComponents.swift
│   │   ├── HelpView.swift
│   │   ├── KeywordViewComponent.swift
│   │   ├── NoteComponent.swift
│   │   └── QuestionBubbleComponent.swift
│   ├── Extensions
│   │   ├── Color+Extension.swift
│   │   ├── Font+Extension.swift
│   │   ├── View+Corners.swift
│   │   └── View+Keyboard.swift
│   ├── LearningToolApp.swift
│   ├── Models
│   │   ├── ChatMessage.swift
│   │   ├── Folder.swift
│   │   └── Note.swift
│   ├── Services
│   │   └── GeminiAPIService.swift
│   ├── ViewModels
│   │   ├── CaptionAnalyzer
│   │   │   ├── AppleFMSummarizer.swift
│   │   │   ├── CaptionAnalyzerViewModel.swift
│   │   │   ├── HTTPSummarizer.swift
│   │   │   └── Summarizer.swift
│   │   ├── ContentViewModel.swift
│   │   ├── HomeViewModel.swift
│   │   ├── QuestionViewModel.swift
│   │   ├── SidebarViewModel.swift
│   │   └── StudyViewModel.swift
│   ├── Views
│   │   ├── ContentView.swift
│   │   ├── HomeView
│   │   │   ├── CreateNoteView.swift
│   │   │   ├── FolderDeleteView.swift
│   │   │   ├── GridMode.swift
│   │   │   ├── Helpers.swift
│   │   │   ├── HomeView.swift
│   │   │   ├── ListMode.swift
│   │   │   ├── Overlay.swift
│   │   │   ├── SettingView.swift
│   │   │   ├── SidebarView.swift
│   │   │   ├── Utils
│   │   │   │   ├── KoreanSearchUtils.swift
│   │   │   │   └── NoteFormattingUtils.swift
│   │   │   └── ViewModelToggle.swift
│   │   └── StudyView
│   │       ├── ChatAreaView.swift
│   │       ├── ChatBubble.swift
│   │       ├── KeywordView.swift
│   │       ├── MediaView.swift
│   │       ├── QuestionHeaderBar.swift
│   │       ├── QuestionInputBar.swift
│   │       ├── QuestionView.swift
│   │       ├── StudyView.swift
│   │       ├── SuggestionsSheetView.swift
│   │       └── SummaryView.swift
│   └── Web
│       ├── YouTubeThumbnail.swift
│       ├── YouTubeWebViewHost.swift
│       └── YouTubeWebViewRepresentable..swift
├── learningTool.xcodeproj
│   ├── project.pbxproj
│   ├── project.xcworkspace
│   │   ├── contents.xcworkspacedata
│   │   ├── xcshareddata
│   │   │   └── swiftpm
│   │   │       └── configuration
│   │   └── xcuserdata
│   │       ├── coulson.xcuserdatad
│   │       │   └── UserInterfaceState.xcuserstate
│   │       └── mumin.xcuserdatad
│   │           └── UserInterfaceState.xcuserstate
│   └── xcuserdata
│       ├── coulson.xcuserdatad
│       │   ├── xcdebugger
│       │   │   └── Breakpoints_v2.xcbkptlist
│       │   └── xcschemes
│       │       └── xcschememanagement.plist
│       └── mumin.xcuserdatad
│           └── xcschemes
│               └── xcschememanagement.plist
├── LICENSE
└── README.md



## :sparkles: Skills & Tech Stack

<img src="https://img.shields.io/badge/Swift-FA7343?style=flat&logo=Swift&logoColor=white"/>, SwiftUI

위와 같이 배지를 사용하여 더 풍성한 Readme를 만들 수 있습니다.
[참조](https://shields.io/)


## :사용 기술:

	•	언어/런타임: Swift 5.x, Swift Concurrency(async/await, Task, @MainActor)
	•	UI: SwiftUI (NavigationSplitView, UIViewRepresentable로 WKWebView 브리지)
	•	데이터: SwiftData (@Model, ModelContext, 영속화/캐시)
	•	웹: WebKit (WKWebView, WKUserScript, WKScriptMessageHandler로 JS ↔︎ 네이티브 브릿지)
	•	요약/지능(옵션): Foundation Models 기반 요약(SystemLanguageModel 사용 가능 환경에서), 증분 요약 + 최종 병합
	•	기반 프레임워크: Foundation(네트워킹 등), OSLog(로깅)
	•	패키징: Swift Package Manager

![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20iPadOS-000000?logo=apple&logoColor=white)
![Target](https://img.shields.io/badge/Target-iOS%2018%2B-000000)
![Swift](https://img.shields.io/badge/Swift-5.x-F05138?logo=swift&logoColor=white)
![SwiftUI](https://img.shields.io/badge/SwiftUI-UI-0C7BDC)
![SwiftData](https://img.shields.io/badge/SwiftData-Persistence-0C7BDC)
![WebKit](https://img.shields.io/badge/WebKit-WKWebView-1F8A70)


## :👥 Team:

| Member | GitHub |
|---|---|
| Skyler | [![yulimmmm](https://img.shields.io/badge/GitHub-yulimmmm-181717?logo=github&logoColor=white)](https://github.com/yulimmmm) |
| Coulson | [![kimminung](https://img.shields.io/badge/GitHub-kimminung-181717?logo=github&logoColor=white)](https://github.com/kimminung) |
| Romak | [![Zunhokim](https://img.shields.io/badge/GitHub-Zunhokim-181717?logo=github&logoColor=white)](https://github.com/Zunhokim) |
| Emma | [![hbeen0129](https://img.shields.io/badge/GitHub-hbeen0129-181717?logo=github&logoColor=white)](https://github.com/hbeen0129) |
| Eifer | [![seungjaeyuu](https://img.shields.io/badge/GitHub-seungjaeyuu-181717?logo=github&logoColor=white)](https://github.com/seungjaeyuu) |
| Moomin | [![namoomin](https://img.shields.io/badge/GitHub-namoomin-181717?logo=github&logoColor=white)](https://github.com/namoomin) |



