//
//  StudySettingsView.swift
//  learningtool
//
//  Created by Mumin on 10/21/25.
//

import SwiftUI

struct StudySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var captionAnalyzer: CaptionAnalyzer
    
    @AppStorage("playbackSpeed") private var playbackSpeed: Double = 1.0
    @AppStorage("autoSummaryEnabled") private var autoSummaryEnabled: Bool = true
    @AppStorage("showSubtitles") private var showSubtitles: Bool = true
    
    var body: some View {
        NavigationView {
            Form {
                // 재생 설정
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("재생 속도")
                                .font(.system(size: 15))
                                .foregroundStyle(Color.text1)
                            Spacer()
                            Text(String(format: "%.1fx", playbackSpeed))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.primaryColor)
                        }
                        
                        Slider(value: $playbackSpeed, in: 0.5...2.0, step: 0.25)
                            .tint(Color.primaryColor)
                        
                        HStack {
                            Text("0.5x")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.text3)
                            Spacer()
                            Text("2.0x")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.text3)
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("미디어")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.text2)
                }
                
                // 자막 설정
                Section {
                    Toggle(isOn: $showSubtitles) {
                        HStack {
                            Image(systemName: "captions.bubble")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.primaryColor)
                                .frame(width: 24)
                            Text("자막 표시")
                                .font(.system(size: 15))
                                .foregroundStyle(Color.text1)
                        }
                    }
                    .tint(Color.primaryColor)
                } header: {
                    Text("자막")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.text2)
                }
                
                // AI 설정
                Section {
                    Toggle(isOn: $autoSummaryEnabled) {
                        HStack {
                            Image(systemName: "sparkles")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.secondColor)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("자동 요약 생성")
                                    .font(.system(size: 15))
                                    .foregroundStyle(Color.text1)
                                Text("영상 로드 시 AI가 자동으로 요약을 생성합니다")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.text3)
                            }
                        }
                    }
                    .tint(Color.secondColor)
                    .onChange(of: autoSummaryEnabled) { _, newValue in
                        captionAnalyzer.autoSummarizeEnabled = newValue
                    }
                    
                    Button(action: {
                        Task {
                            await captionAnalyzer.summarizeNow()
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.secondColor)
                                .frame(width: 24)
                            Text("지금 요약 다시 생성")
                                .font(.system(size: 15))
                                .foregroundStyle(Color.text1)
                            Spacer()
                            if captionAnalyzer.summaryStatus == .summarizing {
                                ProgressView()
                                    .tint(Color.secondColor)
                            }
                        }
                    }
                    .disabled(captionAnalyzer.summaryStatus == .summarizing)
                } header: {
                    Text("AI 요약")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.text2)
                } footer: {
                    if case .ready = captionAnalyzer.vttStatus {
                        Text("자막: \(captionAnalyzer.vttCues.count)개 로드됨")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.text3)
                    } else if case .failed(let msg) = captionAnalyzer.vttStatus {
                        Text("자막 오류: \(msg)")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.errorColor)
                    }
                }
                
                // 정보
                Section {
                    HStack {
                        Image(systemName: "info.circle")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.text3)
                            .frame(width: 24)
                        Text("버전")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.text1)
                        Spacer()
                        Text("1.0.0")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.text3)
                    }
                } header: {
                    Text("앱 정보")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.text2)
                }
            }
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("완료") {
                        dismiss()
                    }
                    .foregroundStyle(Color.primaryColor)
                }
            }
        }
        .onAppear {
            captionAnalyzer.autoSummarizeEnabled = autoSummaryEnabled
        }
    }
}

#Preview {
    StudySettingsView()
        .environmentObject(CaptionAnalyzer())
}

