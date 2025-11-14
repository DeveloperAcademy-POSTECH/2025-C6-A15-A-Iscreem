# 🔑 개발자 API 키 설정 가이드

## ⚠️ 중요 보안 주의사항

**이 파일은 개발팀 내부용입니다. 절대 공개하지 마세요!**

## 🛠️ ChatGPT API 키 설정

### 1. API 키 발급
1. https://platform.openai.com 접속
2. API Keys 메뉴에서 새 키 생성
3. 생성된 키 복사

### 2. 로컬 설정
`AINO/ViewModels/QuestionViewModel.swift` 파일의 18번째 줄을 수정:

```swift
// 현재 (플레이스홀더)
static let openAI = "YOUR_OPENAI_API_KEY_HERE"

// 실제 키로 변경
static let openAI = "sk-proj-여기에실제키입력"
```

### 3. 보안 체크리스트
- [ ] API 키가 실제 키로 설정됨
- [ ] .gitignore에 보호 설정 확인됨
- [ ] 로컬에서만 사용, 커밋하지 않음

## 💰 비용 관리

### GPT-4o-mini 요금
- Input: $0.00015/1K tokens
- Output: $0.0006/1K tokens
- 예상 월 비용: $1-5

### 사용량 모니터링
- OpenAI Platform → Usage 메뉴
- 예산 알림 설정 권장

## 🚨 문제 해결

### "API 키가 설정되지 않았습니다" 오류
1. QuestionViewModel.swift 18번째 줄 확인
2. 실제 API 키로 교체했는지 확인
3. 앱 재빌드

### GitHub Secret Detection 오류
1. 절대 실제 API 키를 커밋하지 마세요
2. 플레이스홀더 키만 커밋
3. 로컬에서만 실제 키 사용

## 📝 팀 협업 가이드

### 새 팀원 온보딩
1. 이 문서 공유
2. 개인 OpenAI 계정 생성 안내
3. 로컬 API 키 설정 도움

### 배포 시 주의사항
1. 앱스토어 배포 전 API 키 확인
2. 실제 키가 포함되지 않았는지 검증
3. 플레이스홀더 상태로 커밋
