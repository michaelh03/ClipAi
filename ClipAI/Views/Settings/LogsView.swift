//
//  LogsView.swift
//  ClipAI
//
//  Displays app logs captured by AppLogger
//

import SwiftUI

struct LogsView: View {
    @ObservedObject private var logger = AppLogger.shared
    @State private var selectedLevel: AppLogger.Level? = nil
    @State private var searchText: String = ""

    var body: some View {
        VStack(spacing: 8) {
            // Controls
            HStack(spacing: 8) {
                Picker("Level", selection: $selectedLevel) {
                    Text("All").tag(AppLogger.Level?.none)
                    ForEach(AppLogger.Level.allCases) { level in
                        Text(level.rawValue).tag(AppLogger.Level?.some(level))
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 320)

                TextField("Search", text: $searchText)
                    .textFieldStyle(.roundedBorder)

                Spacer()

                Button {
                    AppLogger.shared.copyAllToPasteboard()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }

                Button(role: .destructive) {
                    AppLogger.shared.clear()
                } label: {
                    Label("Clear", systemImage: "trash")
                }

                Button {
                    AppLogger.shared.revealLogFileInFinder()
                } label: {
                    Label("Reveal", systemImage: "folder")
                }
            }

            Divider()

            // Log output
            ScrollViewReader { proxy in
                ScrollView {
                    Text(logText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .font(.system(.body, design: .monospaced))
                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .onChange(of: logger.allEntries.count) { _ in
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
                .onAppear {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private var filteredEntries: [AppLogger.LogEntry] {
        logger.allEntries.filter { entry in
            let levelPass = selectedLevel == nil || entry.level == selectedLevel
            if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return levelPass }
            let haystack = "\(entry.message) \(entry.category) \(entry.file)"
            return levelPass && haystack.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var logText: String {
        filteredEntries.map { entry in
            let categoryPart = entry.category.isEmpty ? "" : " [\(entry.category)]"
            return "\(dateString(entry.timestamp)) [\(entry.level.rawValue)]\(categoryPart) \(entry.message) (\(entry.file):\(entry.line))"
        }.joined(separator: "\n")
    }

    private func dateString(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss.SSS"
        return df.string(from: date)
    }
}

#Preview {
    LogsView()
        .frame(width: 600, height: 400)
}


