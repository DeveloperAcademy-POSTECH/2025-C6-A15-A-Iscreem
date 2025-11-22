// TrashView.swift
import SwiftUI
import SwiftData

//extension Notification.Name {
//    static let goBack = Notification.Name("GoBack")
//}

struct TrashView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var learningLogStore: LearningLogStore
    
    @Query private var allNotes: [Note]
    @Query private var allFolders: [Folder]
    
    @State private var selectedNotes = Set<PersistentIdentifier>()
    @State private var selectedFolders = Set<PersistentIdentifier>()
    @State private var selectionMode = false
    
    @State private var showAlert = false
    private enum TrashAlertKind { case deleteSelected, deleteAll, deleteSingleNote, deleteSingleFolder }
    @State private var alertKind: TrashAlertKind? = nil
    @State private var pendingNoteForDeletion: Note? = nil
    @State private var pendingFolderForDeletion: Folder? = nil
    
    private var trashedNotes: [Note] { allNotes.filter { $0.isTrashed } }
    private var trashedFolders: [Folder] { allFolders.filter { $0.isTrashed } }
    
    private var service: TrashService {
        TrashService(context: context, learningLogStore: learningLogStore)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(Color.borderColor)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !trashedFolders.isEmpty {
                        sectionHeader("폴더")
                        LazyVStack(spacing: 8) {
                            ForEach(trashedFolders) { f in
                                trashedFolderRow(f)
                            }
                        }
                    }
                    if !trashedNotes.isEmpty {
                        sectionHeader("노트")
                        LazyVStack(spacing: 8) {
                            ForEach(trashedNotes) { n in
                                trashedNoteRow(n)
                            }
                        }
                    }
                    if trashedNotes.isEmpty && trashedFolders.isEmpty {
                        Text("휴지통이 비어 있습니다.")
                            .foregroundStyle(Color.text3)
                            .padding(.vertical, 40)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding(16)
            }
        }
        .onAppear {
            // 선택: 7일 지난 항목 자동 영구 삭제
            service.purgeExpired(days: 7)
        }
        .alert(isPresented: $showAlert) {
            switch alertKind {
            case .deleteSelected:
                return Alert(
                    title: Text("삭제를 진행합니다"),
                    message: Text("선택한 항목을 영구 삭제합니다. 이 작업은 되돌릴 수 없습니다."),
                    primaryButton: .destructive(Text("영구 삭제")) {
                        let notes = trashedNotes.filter { selectedNotes.contains($0.persistentModelID) }
                        let folders = trashedFolders.filter { selectedFolders.contains($0.persistentModelID) }
                        service.deletePermanently(notes: notes)
                        for f in folders { service.deletePermanently(f) }
                        selectedNotes.removeAll()
                        selectedFolders.removeAll()
                    },
                    secondaryButton: .cancel(Text("취소"))
                )
            case .deleteAll:
                return Alert(
                    title: Text("삭제를 진행합니다"),
                    message: Text("휴지통의 모든 항목을 영구 삭제합니다. 이 작업은 되돌릴 수 없습니다."),
                    primaryButton: .destructive(Text("모두 영구 삭제")) {
                        service.deleteAllPermanently()
                    },
                    secondaryButton: .cancel(Text("취소"))
                )
            case .deleteSingleNote:
                let title = Text("삭제를 진행합니다")
                let message = Text("이 노트를 영구 삭제합니다. 되돌릴 수 없습니다.")
                return Alert(
                    title: title,
                    message: message,
                    primaryButton: .destructive(Text("영구 삭제")) {
                        if let note = pendingNoteForDeletion { service.deletePermanently(note) }
                        pendingNoteForDeletion = nil
                    },
                    secondaryButton: .cancel(Text("취소")) {
                        pendingNoteForDeletion = nil
                    }
                )
            case .deleteSingleFolder:
                let title = Text("삭제를 진행합니다")
                let message = Text("이 폴더를 영구 삭제합니다. 되돌릴 수 없습니다.")
                return Alert(
                    title: title,
                    message: message,
                    primaryButton: .destructive(Text("영구 삭제")) {
                        if let folder = pendingFolderForDeletion { service.deletePermanently(folder) }
                        pendingFolderForDeletion = nil
                    },
                    secondaryButton: .cancel(Text("취소")) {
                        pendingFolderForDeletion = nil
                    }
                )
            case .none:
                return Alert(title: Text(""))
            }
        }
    }
    
    private var header: some View {
        VStack(spacing: 0) {
            // 홈뷰와 일치하는 헤더 바
            HStack(spacing: 12) {
                // .compact 환경에서 뒤로가기 버튼 제공
#if os(iOS)
                if UIDevice.current.userInterfaceIdiom == .phone {
                    Button {
                        NotificationCenter.default.post(name: .hideTrash, object: nil)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .padding(8)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Circle())
                            .clipShape(Circle())
                            .tint(Color.text2)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("뒤로가기")
                }
#endif
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("휴지통")
                        .font(.system(size: 22, weight: .bold)) // ← 제목을 볼드로
                        .foregroundStyle(Color.text2)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .minimumScaleFactor(0.85)
                }
                Spacer()
                // 기존 우측 컨트롤(선택/삭제 토글)을 유지
                if selectionMode {
                    Button {
                        selectionMode = false; selectedNotes.removeAll(); selectedFolders.removeAll()
                    } label: {
                        GlassEffectContainer(spacing: 0) {
                            HStack(spacing: 6) {
                                Image(systemName: "xmark.circle")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("선택 해제")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .padding(.horizontal, 12)
                            .frame(height: 32)
                            .glassEffect()
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.28), lineWidth: 0.6))
                            .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
                        }
                    }
                    .buttonStyle(.plain)
                    Button {
                        guard !(selectedNotes.isEmpty && selectedFolders.isEmpty) else { return }
                        alertKind = .deleteSelected
                        showAlert = true
                    } label: {
                        GlassEffectContainer(spacing: 0) {
                            HStack(spacing: 6) {
                                Image(systemName: "trash")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("선택 삭제")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundStyle(Color.errorColor)
                            .padding(.horizontal, 12)
                            .frame(height: 32)
                            .glassEffect()
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.28), lineWidth: 0.6))
                            .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
                        }
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        selectionMode = true
                    } label: {
                        GlassEffectContainer(spacing: 0) {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("선택")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .padding(.horizontal, 12)
                            .frame(height: 32)
                            .glassEffect()
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.28), lineWidth: 0.6))
                            .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
                        }
                    }
                    .buttonStyle(.plain)
                    Button {
                        alertKind = .deleteAll
                        showAlert = true
                    } label: {
                        GlassEffectContainer(spacing: 0) {
                            HStack(spacing: 6) {
                                Image(systemName: "trash.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("전체 삭제")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundStyle(Color.errorColor)
                            .padding(.horizontal, 12)
                            .frame(height: 32)
                            .glassEffect()
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.28), lineWidth: 0.6))
                            .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .safeAreaPadding([.top, .horizontal])

            Divider().background(Color.borderColor)
        }
    }
    
    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.text2)
            Spacer()
        }
    }
    
    private func trashedFolderRow(_ f: Folder) -> some View {
        HStack {
            if selectionMode {
                Image(systemName: selectedFolders.contains(f.persistentModelID) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selectedFolders.contains(f.persistentModelID) ? Color.secondColor : Color.text3)
                    .onTapGesture {
                        toggleSelectionFolder(f)
                    }
            }
            Image(systemName: "folder.fill")
                .foregroundStyle(Color.text2)
            Text(f.name)
                .foregroundStyle(Color.text1)
            Spacer()
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.background1))
        .contextMenu {
            Button {
                    service.restore(f)
                } label: {
                    Label("복원", systemImage: "arrow.clockwise")
                }
            Button(role: .destructive) {
                pendingFolderForDeletion = f
                alertKind = .deleteSingleFolder
                showAlert = true
            } label: {
                Label("영구 삭제", systemImage: "trash")
            }
        }
        .onTapGesture {
            if selectionMode { toggleSelectionFolder(f) }
        }
    }
    
    private func trashedNoteRow(_ n: Note) -> some View {
        HStack {
            if selectionMode {
                Image(systemName: selectedNotes.contains(n.persistentModelID) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selectedNotes.contains(n.persistentModelID) ? Color.secondColor : Color.text3)
                    .onTapGesture {
                        toggleSelectionNote(n)
                    }
            }
            Image(systemName: "doc.text")
                .foregroundStyle(Color.text2)
            Text(n.title)
                .foregroundStyle(Color.text1)
            Spacer()
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.background1))
        .contextMenu {
            Button {
                    service.restore(n)
                } label: {
                    Label("복원", systemImage: "arrow.clockwise")
                }
            Button(role: .destructive) {
                pendingNoteForDeletion = n
                alertKind = .deleteSingleNote
                showAlert = true
            } label: {
                Label("영구 삭제", systemImage: "trash")
            }
        }
        .onTapGesture {
            if selectionMode { toggleSelectionNote(n) }
        }
    }
    
    private func toggleSelectionNote(_ n: Note) {
        let id = n.persistentModelID
        if selectedNotes.contains(id) { selectedNotes.remove(id) } else { selectedNotes.insert(id) }
    }
    private func toggleSelectionFolder(_ f: Folder) {
        let id = f.persistentModelID
        if selectedFolders.contains(id) { selectedFolders.remove(id) } else { selectedFolders.insert(id) }
    }
}
