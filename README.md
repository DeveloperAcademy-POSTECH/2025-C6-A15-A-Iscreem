### ℹ️📋 [learningTool/AINO]
## [Logo/Cover Image]
![Main](https://github.com/user-attachments/assets/1ec39b2d-e1db-4db9-9c27-77a1559c7cf5)

[Dark-teal]
<img width="128" height="128" alt="tinted_teal" src="https://github.com/user-attachments/assets/5452a8e8-dd1e-4ca6-8fbe-5b58bd3d9a4e" />
[Dark-purple]
<img width="128" height="128" alt="tinted_purple" src="https://github.com/user-attachments/assets/3fba02bb-2151-445d-9862-53f1268f1daa" />
[Dark-amber]
<img width="128" height="128" alt="tinted_amber" src="https://github.com/user-attachments/assets/4f640957-db60-423d-95b8-a9756e85c43f" />


## [App statement]

아이패드로 유튜브 강의를 들으며 공부하는 대학생의 몰입이 깨지지 않도록 AI가 요약하고 핵심 키워드를 보여주면서 바로 질문할 수 있는 앱

## [App statement][Eng]

An app designed for university students studying with YouTube lectures on iPad — it helps maintain focus by using AI to summarize content, highlight key concepts, and enable instant questions without breaking immersion.




### 📞 Apple Intelligence (On-Device) Requirements
This app’s AI summarization uses Apple’s on-device foundation model (Apple Intelligence).

- **iPhone:** iPhone 16 lineup, iPhone 15 Pro/Pro Max  
- **iPad:** iPad mini (A17 Pro), iPad models with **M1 or later**  
- **Mac:** **M1 or later**  
- Make sure **Apple Intelligence is enabled** and **Siri + device language** are set to a supported language (e.g., Korean).

> On devices that don’t meet these requirements, the app may fall back to server summarization (if configured) or disable summarization.

Refs: Apple Newsroom availability notes.  [oai_citation:5‡Apple](https://www.apple.com/newsroom/2025/06/apple-elevates-the-iphone-experience-with-ios-26/)

## 👨🏻‍💻👩🏻‍💻

| ![iPad 01](iPad/iPad Pro 11_ - 1.png) | ![iPad 02](iPad/iPad Pro 11_ - 2.png) | ![iPad 03](iPad/iPad Pro 11_ - 3.png) |
|---|---|---|
| ![iPad 04](iPad/iPad Pro 11_ - 4.png) | ![iPad 05](iPad/iPad Pro 11_ - 5.png) |  |

| ![iPhone 01](iPhone/iPhone 16 - 1.png) | ![iPhone 02](iPhone/iPhone 16 - 2.png) | ![iPhone 03](iPhone/iPhone 16 - 3.png) |
|---|---|---|
| ![iPhone 04](iPhone/iPhone 16 - 4.png) | ![iPhone 05](iPhone/iPhone 16 - 5.png) |  |

## :pushpin: Features

- 영상 강의(유튜브 한정) 노트 저장
- 폴더별 노트 관리
- 강의 내용 구간별 요약
- 구간 요약시 맥락에 맞게 도출되는 주요 키워드
- 제미나이(이용자 api key 설정 후)AI를 통한 채팅 질문
- 키워드에 호버하여 빠른 채팅 입력
- 키워드 입력시 적당한 질문을 생성해주는 질문 생성 기능



## 🌿 Tree
```
.
├── architecture.svg
├── data-model.svg
├── flowchart-home-note-study-history-return.svg
├── learningTool
│   ├── Assets.xcassets
│   │   ├── AccentColor.colorset
│   │   │   └── Contents.json
│   │   ├── AppIcon.appiconset
│   │   │   ├── Contents.json
│   │   │   ├── Main_1024.jpg
│   │   │   ├── tinted_amber.png
│   │   │   └── tinted_teal.png
│   │   ├── Contents.json
│   │   └── GlassBackdrop.imageset
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
│   │   ├── LearningLogStore.swift
│   │   └── Note.swift
│   ├── Services
│   │   └── GeminiAPIService.swift
│   ├── ViewModels
│   │   ├── CaptionAnalyzer
│   │   │   ├── AppleFMSummarizer.swift
│   │   │   ├── CaptionAnalyzerViewModel.swift
│   │   │   ├── HTTPSummarizer.swift
│   │   │   ├── KeywordExtractor.swift
│   │   │   ├── SummaizerEngine.swift
│   │   │   ├── Summarizer.swift
│   │   │   └── VTTParser.swift
│   │   ├── HomeViewModel.swift
│   │   ├── QuestionViewModel.swift
│   │   ├── SidebarViewModel.swift
│   │   └── StudyViewModel.swift
│   ├── Views
│   │   ├── HomeView
│   │   │   ├── BaseLayoutScaler.swift
│   │   │   ├── CreateNoteView.swift
│   │   │   ├── DestructiveConfirmAlertView.swift
│   │   │   ├── FolderDeleteView.swift
│   │   │   ├── GridMode.swift
│   │   │   ├── Helpers.swift
│   │   │   ├── HomeView.swift
│   │   │   ├── ListMode.swift
│   │   │   ├── Overlay.swift
│   │   │   ├── SettingView.swift
│   │   │   ├── SidebarView.swift
│   │   │   ├── TrashService.swift
│   │   │   ├── TrashView.swift
│   │   │   ├── Utils
│   │   │   │   ├── KoreanSearchUtils.swift
│   │   │   │   └── NoteFormattingUtils.swift
│   │   │   └── ViewModelToggle.swift
│   │   ├── StudyHistoryView
│   │   │   └── StudyHistoryView.swift
│   │   └── StudyView
│   │       ├── ChatAreaView.swift
│   │       ├── ChatBubble.swift
│   │       ├── ChatBubbleView.swift
│   │       ├── KeywordView.swift
│   │       ├── MediaView.swift
│   │       ├── QuestionHeaderBar.swift
│   │       ├── QuestionInputBar.swift
│   │       ├── QuestionView.swift
│   │       ├── StudyView.swift
│   │       ├── SuggestionsSheetView.swift
│   │       ├── SummaryView.swift
│   │       └── UIEffects.swift
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
├── README.md
├── sequenceDiagram.svg
└── StudyView-flowchart.svg



```

# 📊 Diagrams

빠르게 훑어보기:
- [Architecture](#architecture)
- [Data Model](#data-model)
- [App Flow (Home→Note→Study→History→Return)](#app-flow-homenotenotestudyhistoryreturn)
- [Sequence Diagram](#sequence-diagram)
- [StudyView Flow](#studyview-flow)

---

## Architecture
### 아키텍처(클래스/뷰/서비스) 다이어그램 소스
![Architecture Diagram](./architecture.svg "Architecture")

## Data Model
### 데이터/모델 다이어그램 소스
![Data Model Diagram](./data-model.svg "Data Model")

## App Flow (Home→Note→Study→History→Return)
### 홈 → 노트 선택 → 스터디(미디어/요약/키워드/질문) → 학습기록/복귀 흐름
![App Flow Diagram](./flowchart-home-note-study-history-return.svg "App Flow")

## StudyView Flow
### 자막 확보부터 요약·키워드·학습기록 저장까지
![StudyView Flowchart](./StudyView-flowchart.svg "StudyView Flow")

## Sequence Diagram
### 홈 → 노트 선택 → 스터디(미디어/요약/키워드/질문) → 학습기록/복귀
![Sequence Diagram](./sequenceDiagram.svg "Sequence Diagram")


## :framed_picture: Demo

Attach videos if you are available
<img width="1472" height="1183" alt="스크린샷 2025-10-20 오후 6 41 10" src="https://github.com/user-attachments/assets/7c78688e-6fa6-46d1-aa60-d2966a4be2e8" />
<img width="964" height="714" alt="스크린샷 2025-10-22 오후 6 42 02" src="https://github.com/user-attachments/assets/f1964cf2-90f7-489a-ad17-66748b5a1bb9" />


<video src="https://raw.githubusercontent.com/<USER>/<REPO>/<BRANCH>/assets/KakaoTalk_Video_2025-10-28-17-52-00.mp4"
       width="920" autoplay loop muted playsinline></video>


https://github.com/user-attachments/assets/e98da29a-7157-47d5-a971-de8b2e455354


https://github.com/user-attachments/assets/dd83c9b4-400e-451e-8281-f5bc6a1d1a1e



https://github.com/user-attachments/assets/8d3b2d55-5ce6-4507-8468-94ee9e7dae59


## :sparkles: Skills & Tech Stack

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




## 👥 Team

| Member | GitHub |
|---|---|
| Skyler | [![yulimmmm](https://img.shields.io/badge/GitHub-yulimmmm-181717?logo=github&logoColor=white)](https://github.com/yulimmmm) |
| Coulson | [![kimminung](https://img.shields.io/badge/GitHub-kimminung-181717?logo=github&logoColor=white)](https://github.com/kimminung) |
| Romak | [![Zunhokim](https://img.shields.io/badge/GitHub-Zunhokim-181717?logo=github&logoColor=white)](https://github.com/Zunhokim) |
| Emma | [![hbeen0129](https://img.shields.io/badge/GitHub-hbeen0129-181717?logo=github&logoColor=white)](https://github.com/hbeen0129) |
| Eifer | [![seungjaeyuu](https://img.shields.io/badge/GitHub-seungjaeyuu-181717?logo=github&logoColor=white)](https://github.com/seungjaeyuu) |
| Moomin | [![namoomin](https://img.shields.io/badge/GitHub-namoomin-181717?logo=github&logoColor=white)](https://github.com/namoomin) |



