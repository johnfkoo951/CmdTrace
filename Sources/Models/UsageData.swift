import SwiftUI

// MARK: - Supporting Types
enum UsageViewMode: String, CaseIterable {
    case daily = "일일"
    case monthly = "월간"
    case blocks = "5시간 블록"
}

struct UsageData {
    let totalCost: Double
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationTokens: Int
    let cacheReadTokens: Int
    let totalTokens: Int
    let dailyUsage: [DailyUsage]
    let monthlyUsage: [MonthlyUsage]
    let blockUsage: [BlockUsage]
    var maxDailyCost: Double { dailyUsage.map { $0.cost }.max() ?? 1.0 }
    var maxMonthlyCost: Double { monthlyUsage.map { $0.cost }.max() ?? 1.0 }
    var maxBlockCost: Double { blockUsage.map { $0.cost }.max() ?? 1.0 }

    struct DailyUsage: Identifiable {
        let id = UUID()
        let date: String
        let cost: Double
        let inputTokens: Int
        let outputTokens: Int
        let totalTokens: Int
        let modelsUsed: [String]
        let modelBreakdowns: [ModelBreakdown]
    }

    struct MonthlyUsage: Identifiable {
        let id = UUID()
        let month: String
        let cost: Double
        let inputTokens: Int
        let outputTokens: Int
        let totalTokens: Int
        let modelsUsed: [String]
        let modelBreakdowns: [ModelBreakdown]
    }

    struct BlockUsage: Identifiable {
        let id = UUID()
        let blockId: String
        let startTime: String
        let endTime: String
        let isActive: Bool
        let cost: Double
        let totalTokens: Int
        let models: [String]
    }

    struct ModelBreakdown: Identifiable {
        let id = UUID()
        let modelName: String
        let inputTokens: Int
        let outputTokens: Int
        let cacheCreationTokens: Int
        let cacheReadTokens: Int
        let cost: Double
    }

    static func parseModelBreakdowns(_ breakdowns: [[String: Any]]?) -> [ModelBreakdown] {
        guard let breakdowns = breakdowns else { return [] }
        return breakdowns.map { b in
            ModelBreakdown(
                modelName: b["modelName"] as? String ?? "",
                inputTokens: b["inputTokens"] as? Int ?? 0,
                outputTokens: b["outputTokens"] as? Int ?? 0,
                cacheCreationTokens: b["cacheCreationTokens"] as? Int ?? 0,
                cacheReadTokens: b["cacheReadTokens"] as? Int ?? 0,
                cost: b["cost"] as? Double ?? 0
            )
        }
    }

    init(dailyJson: [String: Any]?, monthlyJson: [String: Any]?, blocksJson: [String: Any]?) {
        var totalCostSum: Double = 0
        var totalInputTokens: Int = 0
        var totalOutputTokens: Int = 0
        var totalCacheCreation: Int = 0
        var totalCacheRead: Int = 0
        var allTokens: Int = 0
        var dailyList: [DailyUsage] = []
        var monthlyList: [MonthlyUsage] = []
        var blockList: [BlockUsage] = []

        // Parse daily data
        if let daily = dailyJson?["daily"] as? [[String: Any]] {
            for day in daily {
                let date = day["date"] as? String ?? ""
                let cost = day["totalCost"] as? Double ?? 0
                let input = day["inputTokens"] as? Int ?? 0
                let output = day["outputTokens"] as? Int ?? 0
                let cacheCreation = day["cacheCreationTokens"] as? Int ?? 0
                let cacheRead = day["cacheReadTokens"] as? Int ?? 0
                let tokens = day["totalTokens"] as? Int ?? 0
                let models = day["modelsUsed"] as? [String] ?? []
                let breakdowns = Self.parseModelBreakdowns(day["modelBreakdowns"] as? [[String: Any]])

                totalCostSum += cost
                totalInputTokens += input
                totalOutputTokens += output
                totalCacheCreation += cacheCreation
                totalCacheRead += cacheRead
                allTokens += tokens

                dailyList.append(DailyUsage(
                    date: date, cost: cost, inputTokens: input, outputTokens: output,
                    totalTokens: tokens, modelsUsed: models, modelBreakdowns: breakdowns
                ))
            }
        }

        // Parse monthly data
        if let monthly = monthlyJson?["monthly"] as? [[String: Any]] {
            for month in monthly {
                let monthStr = month["month"] as? String ?? ""
                let cost = month["totalCost"] as? Double ?? 0
                let input = month["inputTokens"] as? Int ?? 0
                let output = month["outputTokens"] as? Int ?? 0
                let tokens = month["totalTokens"] as? Int ?? 0
                let models = month["modelsUsed"] as? [String] ?? []
                let breakdowns = Self.parseModelBreakdowns(month["modelBreakdowns"] as? [[String: Any]])

                monthlyList.append(MonthlyUsage(
                    month: monthStr, cost: cost, inputTokens: input, outputTokens: output,
                    totalTokens: tokens, modelsUsed: models, modelBreakdowns: breakdowns
                ))
            }
        }

        // Parse blocks data
        if let blocks = blocksJson?["blocks"] as? [[String: Any]] {
            for block in blocks {
                let blockId = block["id"] as? String ?? ""
                let startTime = block["startTime"] as? String ?? ""
                let endTime = block["endTime"] as? String ?? ""
                let isActive = block["isActive"] as? Bool ?? false
                let cost = block["costUSD"] as? Double ?? 0
                let tokens = block["totalTokens"] as? Int ?? 0
                let models = block["models"] as? [String] ?? []

                blockList.append(BlockUsage(
                    blockId: blockId, startTime: startTime, endTime: endTime,
                    isActive: isActive, cost: cost, totalTokens: tokens, models: models
                ))
            }
        }

        self.totalCost = totalCostSum
        self.inputTokens = totalInputTokens
        self.outputTokens = totalOutputTokens
        self.cacheCreationTokens = totalCacheCreation
        self.cacheReadTokens = totalCacheRead
        self.totalTokens = allTokens
        self.dailyUsage = dailyList
        self.monthlyUsage = monthlyList
        self.blockUsage = blockList
    }
}

