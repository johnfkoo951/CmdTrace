import Foundation
import CloudKit

actor CloudSyncService {
    static let shared = CloudSyncService()
    
    private var _container: CKContainer?
    private var _privateDatabase: CKDatabase?
    private var _zoneID: CKRecordZone.ID?
    private var _recordZone: CKRecordZone?
    
    private let metadataRecordType = "SessionMetadata"
    private let summaryRecordType = "SessionSummary"
    private let settingsRecordType = "AppSettings"
    private let tagRecordType = "TagInfo"
    
    private(set) var isSyncEnabled = false
    private(set) var lastSyncDate: Date?
    private(set) var syncStatus: SyncStatus = .idle
    
    private var isCloudKitAvailable = false
    
    enum SyncStatus: Equatable {
        case idle
        case syncing
        case success(Date)
        case error(String)
    }
    
    init() {}
    
    private func initializeCloudKit() throws {
        guard _container == nil else { return }
        
        _container = CKContainer(identifier: "iCloud.com.cmdspace.cmdtrace")
        _privateDatabase = _container?.privateCloudDatabase
        _zoneID = CKRecordZone.ID(zoneName: "CmdTraceZone", ownerName: CKCurrentUserDefaultName)
        if let zoneID = _zoneID {
            _recordZone = CKRecordZone(zoneID: zoneID)
        }
    }
    
    private var container: CKContainer {
        get throws {
            try initializeCloudKit()
            guard let c = _container else { throw CloudSyncError.notConfigured }
            return c
        }
    }
    
    private var privateDatabase: CKDatabase {
        get throws {
            try initializeCloudKit()
            guard let db = _privateDatabase else { throw CloudSyncError.notConfigured }
            return db
        }
    }
    
    private var zoneID: CKRecordZone.ID {
        get throws {
            try initializeCloudKit()
            guard let z = _zoneID else { throw CloudSyncError.notConfigured }
            return z
        }
    }
    
    private var recordZone: CKRecordZone {
        get throws {
            try initializeCloudKit()
            guard let r = _recordZone else { throw CloudSyncError.notConfigured }
            return r
        }
    }
    
    func setupZone() async throws {
        let zone = try recordZone
        let db = try privateDatabase
        do {
            _ = try await db.save(zone)
        } catch let error as CKError where error.code == .serverRecordChanged {
        }
    }
    
    func checkAccountStatus() async -> Bool {
        do {
            let c = try container
            let status = try await c.accountStatus()
            isCloudKitAvailable = (status == .available)
            return isCloudKitAvailable
        } catch {
            isCloudKitAvailable = false
            return false
        }
    }
    
    func enableSync() async throws {
        guard await checkAccountStatus() else {
            throw CloudSyncError.notSignedIn
        }
        try await setupZone()
        isSyncEnabled = true
    }
    
    func disableSync() {
        isSyncEnabled = false
    }
    
    func syncMetadata(_ metadata: [String: SessionMetadata]) async throws {
        guard isSyncEnabled else { return }
        syncStatus = .syncing
        
        let db = try privateDatabase
        let zone = try zoneID
        
        do {
            for (sessionId, meta) in metadata {
                let recordID = CKRecord.ID(recordName: "meta_\(sessionId)", zoneID: zone)
                let record = CKRecord(recordType: metadataRecordType, recordID: recordID)
                
                record["sessionId"] = sessionId
                record["isFavorite"] = meta.isFavorite
                record["isPinned"] = meta.isPinned
                record["customName"] = meta.customName
                record["tags"] = meta.tags
                
                try await db.save(record)
            }
            
            lastSyncDate = Date()
            syncStatus = .success(lastSyncDate!)
        } catch {
            syncStatus = .error(error.localizedDescription)
            throw error
        }
    }
    
    func fetchMetadata() async throws -> [String: SessionMetadata] {
        guard isSyncEnabled else { return [:] }
        
        let db = try privateDatabase
        let zone = try zoneID
        
        let query = CKQuery(recordType: metadataRecordType, predicate: NSPredicate(value: true))
        let results = try await db.records(matching: query, inZoneWith: zone)
        
        var metadata: [String: SessionMetadata] = [:]
        
        for result in results.matchResults {
            if case .success(let record) = result.1 {
                guard let sessionId = record["sessionId"] as? String else { continue }
                
                let meta = SessionMetadata(
                    isFavorite: record["isFavorite"] as? Bool ?? false,
                    isPinned: record["isPinned"] as? Bool ?? false,
                    customName: record["customName"] as? String,
                    tags: record["tags"] as? [String] ?? []
                )
                metadata[sessionId] = meta
            }
        }
        
        return metadata
    }
    
    func syncSummaries(_ summaries: [String: SessionSummary]) async throws {
        guard isSyncEnabled else { return }
        
        let db = try privateDatabase
        let zone = try zoneID
        
        for (sessionId, summary) in summaries {
            let recordID = CKRecord.ID(recordName: "summary_\(sessionId)", zoneID: zone)
            let record = CKRecord(recordType: summaryRecordType, recordID: recordID)
            
            record["sessionId"] = sessionId
            record["summary"] = summary.summary
            record["keyPoints"] = summary.keyPoints
            record["generatedAt"] = summary.generatedAt
            
            try await db.save(record)
        }
    }
    
    func fetchSummaries() async throws -> [String: SessionSummary] {
        guard isSyncEnabled else { return [:] }
        
        let db = try privateDatabase
        let zone = try zoneID
        
        let query = CKQuery(recordType: summaryRecordType, predicate: NSPredicate(value: true))
        let results = try await db.records(matching: query, inZoneWith: zone)
        
        var summaries: [String: SessionSummary] = [:]
        
        for result in results.matchResults {
            if case .success(let record) = result.1 {
                guard let sessionId = record["sessionId"] as? String,
                      let summaryText = record["summary"] as? String else { continue }
                
                let summary = SessionSummary(
                    sessionId: sessionId,
                    summary: summaryText,
                    keyPoints: record["keyPoints"] as? [String] ?? [],
                    suggestedNextSteps: record["suggestedNextSteps"] as? [String] ?? [],
                    tags: record["tags"] as? [String] ?? [],
                    generatedAt: record["generatedAt"] as? Date ?? Date(),
                    provider: .anthropic
                )
                summaries[sessionId] = summary
            }
        }
        
        return summaries
    }
    
    func syncTags(_ tags: [String: TagInfo]) async throws {
        guard isSyncEnabled else { return }
        
        let db = try privateDatabase
        let zone = try zoneID
        
        for (name, tagInfo) in tags {
            let recordID = CKRecord.ID(recordName: "tag_\(name)", zoneID: zone)
            let record = CKRecord(recordType: tagRecordType, recordID: recordID)
            
            record["name"] = tagInfo.name
            record["color"] = tagInfo.color
            record["isImportant"] = tagInfo.isImportant
            record["parentTag"] = tagInfo.parentTag
            
            try await db.save(record)
        }
    }
    
    func fetchTags() async throws -> [String: TagInfo] {
        guard isSyncEnabled else { return [:] }
        
        let db = try privateDatabase
        let zone = try zoneID
        
        let query = CKQuery(recordType: tagRecordType, predicate: NSPredicate(value: true))
        let results = try await db.records(matching: query, inZoneWith: zone)
        
        var tags: [String: TagInfo] = [:]
        
        for result in results.matchResults {
            if case .success(let record) = result.1 {
                guard let name = record["name"] as? String else { continue }
                
                let tagInfo = TagInfo(
                    name: name,
                    color: record["color"] as? String ?? "#3B82F6",
                    isImportant: record["isImportant"] as? Bool ?? false,
                    parentTag: record["parentTag"] as? String
                )
                tags[name] = tagInfo
            }
        }
        
        return tags
    }
    
    func performFullSync(
        metadata: [String: SessionMetadata],
        summaries: [String: SessionSummary],
        tags: [String: TagInfo]
    ) async throws -> (metadata: [String: SessionMetadata], summaries: [String: SessionSummary], tags: [String: TagInfo]) {
        guard isSyncEnabled else {
            throw CloudSyncError.syncDisabled
        }
        
        syncStatus = .syncing
        
        do {
            let remoteMetadata = try await fetchMetadata()
            let remoteSummaries = try await fetchSummaries()
            let remoteTags = try await fetchTags()
            
            let mergedMetadata = mergeMetadata(local: metadata, remote: remoteMetadata)
            let mergedSummaries = mergeSummaries(local: summaries, remote: remoteSummaries)
            let mergedTags = mergeTags(local: tags, remote: remoteTags)
            
            try await syncMetadata(mergedMetadata)
            try await syncSummaries(mergedSummaries)
            try await syncTags(mergedTags)
            
            lastSyncDate = Date()
            syncStatus = .success(lastSyncDate!)
            
            return (mergedMetadata, mergedSummaries, mergedTags)
        } catch {
            syncStatus = .error(error.localizedDescription)
            throw error
        }
    }
    
    private func mergeMetadata(local: [String: SessionMetadata], remote: [String: SessionMetadata]) -> [String: SessionMetadata] {
        var merged = remote
        for (key, value) in local {
            if let existing = merged[key] {
                merged[key] = SessionMetadata(
                    isFavorite: value.isFavorite || existing.isFavorite,
                    isPinned: value.isPinned || existing.isPinned,
                    customName: value.customName ?? existing.customName,
                    tags: Array(Set(value.tags + existing.tags))
                )
            } else {
                merged[key] = value
            }
        }
        return merged
    }
    
    private func mergeSummaries(local: [String: SessionSummary], remote: [String: SessionSummary]) -> [String: SessionSummary] {
        var merged = remote
        for (key, value) in local {
            if let existing = merged[key] {
                merged[key] = value.generatedAt > existing.generatedAt ? value : existing
            } else {
                merged[key] = value
            }
        }
        return merged
    }
    
    private func mergeTags(local: [String: TagInfo], remote: [String: TagInfo]) -> [String: TagInfo] {
        var merged = remote
        for (key, value) in local {
            merged[key] = value
        }
        return merged
    }
}

enum CloudSyncError: LocalizedError {
    case notSignedIn
    case syncDisabled
    case networkError
    case notConfigured
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "Please sign in to iCloud in System Settings"
        case .syncDisabled:
            return "Cloud sync is disabled"
        case .networkError:
            return "Network connection error"
        case .notConfigured:
            return "CloudKit container not configured"
        case .unknown(let message):
            return message
        }
    }
}
