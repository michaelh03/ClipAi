//
//  AppLogger.swift
//  ClipAI
//
//  Centralized app logging with in-memory buffer and optional file persistence.
//

import Foundation
import SwiftUI
#if os(macOS)
import AppKit
#endif
import Darwin

/// Centralized logger for the application
final class AppLogger: ObservableObject {
    static let shared = AppLogger()

    enum Level: String, CaseIterable, Identifiable {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARN"
        case error = "ERROR"

        var id: String { rawValue }
        var symbolName: String {
            switch self {
            case .debug: return "ladybug"
            case .info: return "info.circle"
            case .warning: return "exclamationmark.triangle"
            case .error: return "xmark.octagon"
            }
        }
        var color: Color {
            switch self {
            case .debug: return .secondary
            case .info: return .blue
            case .warning: return .orange
            case .error: return .red
            }
        }
    }

    struct LogEntry: Identifiable, Hashable {
        let id = UUID()
        let timestamp: Date
        let level: Level
        let category: String
        let message: String
        let file: String
        let function: String
        let line: Int
        let threadId: UInt64
    }

    /// Most recent log entries (bounded)
    @Published private(set) var entries: [LogEntry] = []

    /// Expose read-only public entries
    var allEntries: [LogEntry] { entries }

    private let queue = DispatchQueue(label: "AppLogger.queue", qos: .background)
    private let dateFormatter: DateFormatter
    private let maxEntries: Int = 2000
    private let fileURL: URL

    private init() {
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"

        // ~/Library/Logs/ClipAI/ClipAI.log
        let logsDir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("ClipAI", isDirectory: true)
        self.fileURL = logsDir.appendingPathComponent("ClipAI.log")

        // Ensure directory exists
        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)

        // Start a new session marker
        log("— App Launch —", level: .info, category: "Lifecycle")
    }

    func debug(_ message: String, category: String = "General", file: String = #fileID, function: String = #function, line: Int = #line) {
        log(message, level: .debug, category: category, file: file, function: function, line: line)
    }

    func info(_ message: String, category: String = "General", file: String = #fileID, function: String = #function, line: Int = #line) {
        log(message, level: .info, category: category, file: file, function: function, line: line)
    }

    func warn(_ message: String, category: String = "General", file: String = #fileID, function: String = #function, line: Int = #line) {
        log(message, level: .warning, category: category, file: file, function: function, line: line)
    }

    func error(_ message: String, category: String = "General", file: String = #fileID, function: String = #function, line: Int = #line) {
        log(message, level: .error, category: category, file: file, function: function, line: line)
    }

    func log(_ message: String, level: Level = .debug, category: String = "General", file: String = #fileID, function: String = #function, line: Int = #line) {
        let entry = LogEntry(
            timestamp: Date(),
            level: level,
            category: category,
            message: message,
            file: (file as NSString).lastPathComponent,
            function: function,
            line: line,
            threadId: UInt64(pthread_mach_thread_np(pthread_self()))
        )

        // Append in-memory and trim
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.entries.append(entry)
            if self.entries.count > self.maxEntries {
                self.entries.removeFirst(self.entries.count - self.maxEntries)
            }
        }

        // Persist to file asynchronously
        queue.async { [weak self] in
            self?.appendToFile(entry)
        }
    }

    func clear() {
        DispatchQueue.main.async { [weak self] in
            self?.entries.removeAll()
        }
        queue.async { [fileURL] in
            try? "".data(using: .utf8)?.write(to: fileURL, options: .atomic)
        }
    }

    func revealLogFileInFinder() {
        #if os(macOS)
        let url = fileURL
        DispatchQueue.main.async {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
        #endif
    }

    func copyAllToPasteboard() {
        #if os(macOS)
        let joined = entries.map { format($0) }.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(joined, forType: .string)
        #endif
    }

    private func appendToFile(_ entry: LogEntry) {
        let line = format(entry) + "\n"
        guard let data = line.data(using: .utf8) else { return }

        // Also mirror to Xcode console / stdout
        print(line, terminator: "")

        if FileManager.default.fileExists(atPath: fileURL.path) {
            if let handle = try? FileHandle(forWritingTo: fileURL) {
                defer { try? handle.close() }
                do { try handle.seekToEnd(); try handle.write(contentsOf: data) } catch { }
            }
        } else {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    private func format(_ entry: LogEntry) -> String {
        let ts = dateFormatter.string(from: entry.timestamp)
        let cat = entry.category.isEmpty ? "General" : entry.category
        return "\(ts) [\(entry.level.rawValue)] [\(cat)] \(entry.message) (\(entry.file):\(entry.line))"
    }
}

/// Convenience global helper
func AppLog(_ message: String, level: AppLogger.Level = .debug, category: String = "General", file: String = #fileID, function: String = #function, line: Int = #line) {
    AppLogger.shared.log(message, level: level, category: category, file: file, function: function, line: line)
}


