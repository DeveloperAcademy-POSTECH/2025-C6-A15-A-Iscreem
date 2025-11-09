// TrashService.swift
import Foundation
import SwiftData

@MainActor
final class TrashService {
    let context: ModelContext
    let learningLogStore: LearningLogStore
    
    init(context: ModelContext, learningLogStore: LearningLogStore) {
        self.context = context
        self.learningLogStore = learningLogStore
    }
    
    func moveToTrash(_ note: Note) {
        note.isTrashed = true
        note.trashedAt = Date()
        try? context.save()
    }
    
    func moveToTrash(_ folder: Folder) {
        folder.isTrashed = true
        folder.trashedAt = Date()
        for n in folder.notes {
            n.isTrashed = true
            n.trashedAt = Date()
        }
        try? context.save()
    }
    
    func restore(_ note: Note) {
        note.isTrashed = false
        note.trashedAt = nil
        try? context.save()
    }
    
    func restore(_ folder: Folder) {
        folder.isTrashed = false
        folder.trashedAt = nil
        for n in folder.notes {
            n.isTrashed = false
            n.trashedAt = nil
        }
        try? context.save()
    }
    
    func deletePermanently(_ note: Note) {
        learningLogStore.deleteSessions(for: note)
        context.delete(note)
        try? context.save()
    }
    
    func deletePermanently(_ folder: Folder) {
        learningLogStore.deleteSessions(in: folder)
        context.delete(folder)
        try? context.save()
    }
    
    func deletePermanently(notes: [Note]) {
        if !notes.isEmpty {
            learningLogStore.deleteSessions(for: notes)
            for n in notes { context.delete(n) }
            try? context.save()
        }
    }
    
    func deleteAllPermanently() {
        let trashedNotes = (try? context.fetch(FetchDescriptor<Note>()))?.filter { $0.isTrashed } ?? []
        let trashedFolders = (try? context.fetch(FetchDescriptor<Folder>()))?.filter { $0.isTrashed } ?? []
        if !trashedNotes.isEmpty {
            learningLogStore.deleteSessions(for: trashedNotes)
            trashedNotes.forEach { context.delete($0) }
        }
        if !trashedFolders.isEmpty {
            trashedFolders.forEach { learningLogStore.deleteSessions(in: $0) }
            trashedFolders.forEach { context.delete($0) }
        }
        try? context.save()
    }
    
    func purgeExpired(days: Int = 7) {
        let cutoff = Date().addingTimeInterval(TimeInterval(-days * 24 * 3600))
        let trashedNotes = (try? context.fetch(FetchDescriptor<Note>()))?.filter { $0.isTrashed && ($0.trashedAt ?? .distantFuture) < cutoff } ?? []
        let trashedFolders = (try? context.fetch(FetchDescriptor<Folder>()))?.filter { $0.isTrashed && ($0.trashedAt ?? .distantFuture) < cutoff } ?? []
        if !trashedNotes.isEmpty {
            learningLogStore.deleteSessions(for: trashedNotes)
            trashedNotes.forEach { context.delete($0) }
        }
        if !trashedFolders.isEmpty {
            trashedFolders.forEach { learningLogStore.deleteSessions(in: $0) }
            trashedFolders.forEach { context.delete($0) }
        }
        try? context.save()
    }
}
