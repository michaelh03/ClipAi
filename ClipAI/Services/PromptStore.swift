import Foundation
import SQLite

/// Service for managing SystemPrompt persistence and CRUD operations
@MainActor
class PromptStore: ObservableObject {
    
    // MARK: - Published Properties
    
    /// All available prompts (system + user)
    @Published private(set) var prompts: [SystemPrompt] = []
    
    /// System (built-in) prompts that cannot be deleted
    @Published private(set) var systemPrompts: [SystemPrompt] = []
    
    /// User-created prompts that can be modified/deleted
    @Published private(set) var userPrompts: [SystemPrompt] = []
    
    /// Whether the initial load is complete
    @Published private(set) var isInitialLoadComplete: Bool = false
    
    // MARK: - Private Properties
    
    private let db: Connection
    
    // Table and column definitions
    private let promptsTable = Table("prompts")
    private let idColumn = SQLite.Expression<String>("id")
    private let titleColumn = SQLite.Expression<String>("title")
    private let templateColumn = SQLite.Expression<String>("template")
    private let isSystemPromptColumn = SQLite.Expression<Bool>("is_system_prompt")
    private let createdAtColumn = SQLite.Expression<Date>("created_at")
    private let modifiedAtColumn = SQLite.Expression<Date>("modified_at")
    
    // Removed defaultPromptsURL - using only hardcoded prompts from SystemPrompt.swift
    
    // MARK: - Singleton
    
    static let shared = PromptStore()

    private init() {
        do {
            // Initialize database connection
            guard let applicationSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, 
                                                                       in: .userDomainMask).first else {
                fatalError("Could not locate Application Support directory")
            }
            
            let clipAIDirectory = applicationSupportURL.appendingPathComponent("ClipAI")
            let databaseURL = clipAIDirectory.appendingPathComponent("promptsV9.sqlite")
            
            // Create directory if it doesn't exist
            try FileManager.default.createDirectory(at: clipAIDirectory, 
                                                  withIntermediateDirectories: true, 
                                                  attributes: nil)
            
            self.db = try Connection(databaseURL.path)
            try createTableIfNeeded()
            
            Task {
                await loadPrompts()
            }
        } catch {
            fatalError("Failed to initialize PromptStore: \(error)")
        }
    }
    
    /// Create the prompts table if it doesn't exist
    private func createTableIfNeeded() throws {
        do {
            try db.run(promptsTable.create(ifNotExists: true) { t in
                t.column(idColumn, primaryKey: true)
                t.column(titleColumn)
                t.column(templateColumn)
                t.column(isSystemPromptColumn)
                t.column(createdAtColumn)
                t.column(modifiedAtColumn)
            })
        } catch {
            throw PromptStoreError.saveFailed("Failed to create prompts table: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Public Methods
    
    /// Load all prompts from bundle and user directory
    func loadPrompts() async {
        await loadSystemPrompts()
        await loadUserPrompts()
        updateCombinedPrompts()
        isInitialLoadComplete = true
    }
    
    /// Wait for the initial load to complete if it hasn't already
    func waitForInitialLoad() async {
        // If already loaded, return immediately
        guard !isInitialLoadComplete else { return }
        
        // Wait for the initial load to complete with a reasonable timeout
        let startTime = Date()
        let timeout: TimeInterval = 10.0 // 10 second timeout
        
        while !isInitialLoadComplete && Date().timeIntervalSince(startTime) < timeout {
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
        
        if !isInitialLoadComplete {
            AppLog("PromptStore initial load timed out after \(timeout) seconds", level: .warning, category: "Prompts")
        }
    }
    
    /// Create a new user prompt
    /// - Parameters:
    ///   - title: The title of the prompt
    ///   - template: The template string with placeholders
    /// - Returns: The created SystemPrompt
    /// - Throws: PromptStoreError if creation fails
    @discardableResult
    func createPrompt(title: String, template: String) async throws -> SystemPrompt {
        let prompt = SystemPrompt(title: title, template: template, isSystemPrompt: false)
        
        guard prompt.isValid() else {
            throw PromptStoreError.invalidPrompt("Title and template cannot be empty")
        }
        
        try await insertPromptToDatabase(prompt)
        userPrompts.append(prompt)
        updateCombinedPrompts()
        
        return prompt
    }
    
    /// Update an existing prompt
    /// - Parameters:
    ///   - id: The ID of the prompt to update
    ///   - title: New title
    ///   - template: New template
    /// - Throws: PromptStoreError if update fails
    func updatePrompt(id: UUID, title: String, template: String) async throws {
        guard let index = userPrompts.firstIndex(where: { $0.id == id }) else {
            throw PromptStoreError.promptNotFound("Prompt with ID \(id) not found")
        }
        
        var updatedPrompt = userPrompts[index]
        updatedPrompt.update(title: title, template: template)
        
        guard updatedPrompt.isValid() else {
            throw PromptStoreError.invalidPrompt("Title and template cannot be empty")
        }
        
        try await updatePromptInDatabase(updatedPrompt)
        userPrompts[index] = updatedPrompt
        updateCombinedPrompts()
    }
    
    /// Delete a user prompt
    /// - Parameter id: The ID of the prompt to delete
    /// - Throws: PromptStoreError if deletion fails
    func deletePrompt(id: UUID) async throws {
        guard let index = userPrompts.firstIndex(where: { $0.id == id }) else {
            throw PromptStoreError.promptNotFound("Prompt with ID \(id) not found")
        }
        
        let prompt = userPrompts[index]
        guard !prompt.isSystemPrompt else {
            throw PromptStoreError.cannotDeleteSystemPrompt("Cannot delete system prompt")
        }
        
        try await deletePromptFromDatabase(id)
        userPrompts.remove(at: index)
        updateCombinedPrompts()
    }
    
    /// Get a prompt by ID
    /// - Parameter id: The ID of the prompt
    /// - Returns: The SystemPrompt if found, nil otherwise
    func getPrompt(by id: UUID) -> SystemPrompt? {
        return prompts.first { $0.id == id }
    }
    
    /// Get prompts matching a search query
    /// - Parameter query: Search query to match against title and template
    /// - Returns: Array of matching prompts
    func searchPrompts(query: String) -> [SystemPrompt] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return prompts
        }
        
        let lowercaseQuery = query.lowercased()
        return prompts.filter { prompt in
            prompt.title.lowercased().contains(lowercaseQuery) ||
            prompt.template.lowercased().contains(lowercaseQuery)
        }
    }
    
    /// Reset to default prompts (for testing or reset functionality)
    func resetToDefaults() async throws {
        try await clearUserPromptsFromDatabase()
        userPrompts.removeAll()
        updateCombinedPrompts()
    }
    
    // MARK: - Private Methods
    
    /// Load system prompts from database, seeding from bundle/defaults if needed
    private func loadSystemPrompts() async {
        do {
            // Try to load system prompts from database first
            let systemPromptsFromDB = try await loadSystemPromptsFromDatabase()
            
            if systemPromptsFromDB.isEmpty {
                // No system prompts in database, seed them
                await seedSystemPromptsToDatabase()
                systemPrompts = try await loadSystemPromptsFromDatabase()
            } else {
                systemPrompts = systemPromptsFromDB
            }
            
            AppLog("Loaded \(systemPrompts.count) system prompts from database", level: .info, category: "Prompts")
        } catch {
            AppLog("Failed to load system prompts from database: \(error)", level: .warning, category: "Prompts")
            // Fallback to in-memory defaults
            systemPrompts = SystemPrompt.defaultPrompts
        }
    }
    
    /// Load system prompts from the database
    private func loadSystemPromptsFromDatabase() async throws -> [SystemPrompt] {
        return try await Task {
            do {
                let query = promptsTable.filter(isSystemPromptColumn == true)
                var prompts: [SystemPrompt] = []
                
                for row in try db.prepare(query) {
                    let prompt = SystemPrompt(
                        id: UUID(uuidString: row[idColumn]) ?? UUID(),
                        title: row[titleColumn],
                        template: row[templateColumn],
                        isSystemPrompt: row[isSystemPromptColumn],
                        createdAt: row[createdAtColumn],
                        modifiedAt: row[modifiedAtColumn]
                    )
                    prompts.append(prompt)
                }
                
                return prompts
            } catch {
                throw PromptStoreError.loadFailed("Failed to load system prompts from database: \(error.localizedDescription)")
            }
        }.value
    }
    
    /// Seed system prompts to database from hardcoded defaults
    private func seedSystemPromptsToDatabase() async {
        // Use hardcoded defaults from SystemPrompt.swift
        let promptsToSeed = SystemPrompt.defaultPrompts
        AppLog("Using \(promptsToSeed.count) hardcoded default prompts for seeding", level: .info, category: "Prompts")
        
        // Insert system prompts into database using batch operation
        do {
            try await batchInsertPromptsToDatabase(promptsToSeed)
            AppLog("Seeded \(promptsToSeed.count) system prompts to database", level: .info, category: "Prompts")
        } catch {
            AppLog("Failed to seed system prompts to database: \(error)", level: .error, category: "Prompts")
        }
    }
    
    /// Migrate existing JSON data to SQLite if needed
    private func migrateFromJSONIfNeeded() async {
        // Check if JSON file exists
        guard let applicationSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, 
                                                                   in: .userDomainMask).first else {
            return
        }
        
        let clipAIDirectory = applicationSupportURL.appendingPathComponent("ClipAI")
        let jsonURL = clipAIDirectory.appendingPathComponent("user_prompts.json")
        
        guard FileManager.default.fileExists(atPath: jsonURL.path) else {
            return // No JSON file to migrate
        }
        
        do {
            // Load prompts from JSON
            let data = try Data(contentsOf: jsonURL)
            let jsonPrompts = try JSONDecoder().decode([SystemPrompt].self, from: data)
            
            // Check if database already has user prompts (avoid double migration)
            let existingUserPrompts = try await loadUserPromptsFromDatabase()
            
            if existingUserPrompts.isEmpty && !jsonPrompts.isEmpty {
                // Migrate JSON prompts to database
                for prompt in jsonPrompts {
                    try await insertPromptToDatabase(prompt)
                }
                AppLog("Migrated \(jsonPrompts.count) prompts from JSON to SQLite", level: .info, category: "Prompts")
                
                // Optionally remove JSON file after successful migration
                try FileManager.default.removeItem(at: jsonURL)
                AppLog("Removed old JSON file after migration", level: .info, category: "Prompts")
            }
        } catch {
            AppLog("Failed to migrate prompts from JSON: \(error)", level: .warning, category: "Prompts")
        }
    }
    
    /// Load user prompts from SQLite database
    private func loadUserPrompts() async {
        do {
            userPrompts = try await loadUserPromptsFromDatabase()
            AppLog("Loaded \(userPrompts.count) user prompts from database", level: .info, category: "Prompts")
        } catch {
            AppLog("Failed to load user prompts from database: \(error)", level: .warning, category: "Prompts")
            userPrompts = []
        }
    }
    
    /// Load user prompts from the database
    private func loadUserPromptsFromDatabase() async throws -> [SystemPrompt] {
        return try await Task {
            do {
                let query = promptsTable.filter(isSystemPromptColumn == false)
                var prompts: [SystemPrompt] = []
                
                for row in try db.prepare(query) {
                    let prompt = SystemPrompt(
                        id: UUID(uuidString: row[idColumn]) ?? UUID(),
                        title: row[titleColumn],
                        template: row[templateColumn],
                        isSystemPrompt: row[isSystemPromptColumn],
                        createdAt: row[createdAtColumn],
                        modifiedAt: row[modifiedAtColumn]
                    )
                    prompts.append(prompt)
                }
                
                return prompts
            } catch {
                throw PromptStoreError.loadFailed("Failed to load prompts from database: \(error.localizedDescription)")
            }
        }.value
    }
    
    /// Insert a prompt into the database
    private func insertPromptToDatabase(_ prompt: SystemPrompt) async throws {
        try await Task {
            do {
                let insert = promptsTable.insert(
                    idColumn <- prompt.id.uuidString,
                    titleColumn <- prompt.title,
                    templateColumn <- prompt.template,
                    isSystemPromptColumn <- prompt.isSystemPrompt,
                    createdAtColumn <- prompt.createdAt,
                    modifiedAtColumn <- prompt.modifiedAt
                )
                try db.run(insert)
            } catch {
                throw PromptStoreError.saveFailed("Failed to insert prompt to database: \(error.localizedDescription)")
            }
        }.value
    }
    
    /// Batch insert multiple prompts into the database efficiently
    private func batchInsertPromptsToDatabase(_ prompts: [SystemPrompt]) async throws {
        try await Task {
            do {
                try db.transaction {
                    for prompt in prompts {
                        let insert = promptsTable.insert(
                            idColumn <- prompt.id.uuidString,
                            titleColumn <- prompt.title,
                            templateColumn <- prompt.template,
                            isSystemPromptColumn <- prompt.isSystemPrompt,
                            createdAtColumn <- prompt.createdAt,
                            modifiedAtColumn <- prompt.modifiedAt
                        )
                        try db.run(insert)
                    }
                }
            } catch {
                throw PromptStoreError.saveFailed("Failed to batch insert prompts to database: \(error.localizedDescription)")
            }
        }.value
    }
    
    /// Update a prompt in the database
    private func updatePromptInDatabase(_ prompt: SystemPrompt) async throws {
        try await Task {
            do {
                let promptToUpdate = promptsTable.filter(idColumn == prompt.id.uuidString)
                let update = promptToUpdate.update(
                    titleColumn <- prompt.title,
                    templateColumn <- prompt.template,
                    modifiedAtColumn <- prompt.modifiedAt
                )
                try db.run(update)
            } catch {
                throw PromptStoreError.saveFailed("Failed to update prompt in database: \(error.localizedDescription)")
            }
        }.value
    }
    
    /// Delete a prompt from the database
    private func deletePromptFromDatabase(_ id: UUID) async throws {
        try await Task {
            do {
                let promptToDelete = promptsTable.filter(idColumn == id.uuidString)
                try db.run(promptToDelete.delete())
            } catch {
                throw PromptStoreError.saveFailed("Failed to delete prompt from database: \(error.localizedDescription)")
            }
        }.value
    }
    
    /// Clear all user prompts from the database
    private func clearUserPromptsFromDatabase() async throws {
        try await Task {
            do {
                let userPromptsToDelete = promptsTable.filter(isSystemPromptColumn == false)
                try db.run(userPromptsToDelete.delete())
            } catch {
                throw PromptStoreError.saveFailed("Failed to clear user prompts from database: \(error.localizedDescription)")
            }
        }.value
    }
    
    /// Update the combined prompts array
    private func updateCombinedPrompts() {
        prompts = systemPrompts + userPrompts
    }
}

// MARK: - Error Types

enum PromptStoreError: LocalizedError {
    case promptNotFound(String)
    case cannotDeleteSystemPrompt(String)
    case invalidPrompt(String)
    case loadFailed(String)
    case saveFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .promptNotFound(let message),
             .cannotDeleteSystemPrompt(let message),
             .invalidPrompt(let message),
             .loadFailed(let message),
             .saveFailed(let message):
            return message
        }
    }
}
