import SwiftUI

// MARK: - Interaction View (AI Features)
struct InteractionView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Session Summaries", systemImage: "doc.text.magnifyingglass")
                            .font(.headline)
                        
                        Text("AI-powered summaries of your coding sessions. Get key insights and suggestions.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        if appState.settings.anthropicKey.isEmpty {
                            Text("Configure API keys in Settings to enable AI features")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Smart Suggestions", systemImage: "lightbulb")
                            .font(.headline)
                        
                        Text("Get AI-powered suggestions based on your recent sessions.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        ForEach(0..<3, id: \.self) { i in
                            HStack {
                                Image(systemName: "sparkle")
                                    .foregroundStyle(.yellow)
                                Text("Suggestion placeholder \(i + 1)")
                                    .font(.subheadline)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.quaternary)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Session Reminders", systemImage: "bell")
                            .font(.headline)
                        
                        Toggle("Enable reminders", isOn: .constant(appState.settings.enableReminders))
                        
                        Text("Get reminded about sessions you haven't revisited in \(appState.settings.reminderHours) hours.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
        }
    }
}

// MARK: - AI Inspector Panel
struct AIInspectorPanel: View {
    @Environment(AppState.self) private var appState
    
    private var summaryCount: Int {
        appState.sessionSummaries.count
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                GroupBox("AI Configuration") {
                    VStack(alignment: .leading, spacing: 12) {
                        LabeledContent("Summary Provider") {
                            Picker("", selection: .constant(appState.settings.summaryProvider)) {
                                ForEach(AIProvider.allCases, id: \.self) { provider in
                                    Text(provider.rawValue).tag(provider)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 120)
                        }
                        
                        LabeledContent("Suggestion Provider") {
                            Picker("", selection: .constant(appState.settings.suggestionProvider)) {
                                ForEach(AIProvider.allCases, id: \.self) { provider in
                                    Text(provider.rawValue).tag(provider)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 120)
                        }
                    }
                    .font(.caption)
                }
                
                GroupBox("API Status") {
                    VStack(alignment: .leading, spacing: 8) {
                        APIStatusRow(name: "Anthropic", hasKey: !appState.settings.anthropicKey.isEmpty)
                        APIStatusRow(name: "OpenAI", hasKey: !appState.settings.openaiKey.isEmpty)
                        APIStatusRow(name: "Gemini", hasKey: !appState.settings.geminiKey.isEmpty)
                        APIStatusRow(name: "Grok", hasKey: !appState.settings.grokKey.isEmpty)
                    }
                }
                
                GroupBox("Summaries") {
                    VStack(alignment: .leading, spacing: 8) {
                        LabeledContent("Generated", value: "\(summaryCount)")
                        
                        if summaryCount > 0 {
                            Button("Clear All Summaries") {
                                // TODO: Implement clear
                            }
                            .font(.caption)
                            .foregroundStyle(.red)
                        }
                    }
                    .font(.caption)
                }
                
                GroupBox("Reminders") {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Enable", isOn: .constant(appState.settings.enableReminders))
                            .font(.caption)
                        
                        LabeledContent("Interval") {
                            Picker("", selection: .constant(appState.settings.reminderHours)) {
                                Text("12 hours").tag(12)
                                Text("24 hours").tag(24)
                                Text("48 hours").tag(48)
                                Text("72 hours").tag(72)
                            }
                            .labelsHidden()
                            .frame(width: 100)
                        }
                        .font(.caption)
                    }
                }
            }
            .padding()
        }
    }
}

struct APIStatusRow: View {
    let name: String
    let hasKey: Bool
    
    var body: some View {
        HStack {
            Image(systemName: hasKey ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(hasKey ? .green : .secondary)
            Text(name)
                .font(.caption)
            Spacer()
            Text(hasKey ? "Configured" : "Not set")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

