//
//  paneTests.swift
//  paneTests
//
//  Created by Elice Priyadarshini on 16/2/26.
//

import Foundation
import Testing
@testable import pane

struct paneTests {
    @Test func promptExampleRetrieverSelectsMostRelevantExample() {
        let retriever = PromptExampleRetriever(examples: [
            PromptExample(
                id: "crypto",
                prompt: "need bitcoin stock and ethereum stock changes live updates",
                intentSummary: "Crypto live row",
                keySignals: ["bitcoin stock", "ethereum stock", "live updates"],
                categories: ["market"],
                outputHints: ["crypto BTC ETH"],
                expectedJSON: nil,
                expectedFile: nil
            ),
            PromptExample(
                id: "clock",
                prompt: "just show me the time, nothing else, keep it tiny",
                intentSummary: "Tiny clock",
                keySignals: ["time", "tiny"],
                categories: ["time"],
                outputHints: ["clock only"],
                expectedJSON: nil,
                expectedFile: nil
            )
        ])

        let selected = retriever.retrieveExamples(
            for: "need bitcoin stock and ethereum stock changes live updates",
            limit: 1
        )
        #expect(selected.first?.id == "crypto")
    }

    @Test func schemaValidatorExtractsFirstBalancedJSONObject() throws {
        let validator = SchemaValidator()
        let valid = makeWidgetJSON(
            name: "Balanced Extract",
            description: "Parse valid object from mixed text",
            contentJSON: #"{"type":"text","content":"Hello","font":"sf-pro","size":14,"color":"primary"}"#
        )
        let raw = """
        some non-json preface
        \(valid)
        trailing note {"foo":"bar"}
        """

        let config = try validator.parseAndValidateWidgetConfig(from: raw)
        #expect(config.name == "Balanced Extract")
        #expect(config.content.type == ComponentType.text)
    }
    
    @Test func generationPipelineRepairsInvalidSchemaWithinBudget() async throws {
        let pipeline = GenerationPipeline(
            promptBuilder: PromptBuilder(componentSchema: "{}"),
            validator: SchemaValidator(),
            callTimeoutSeconds: 1.0,
            totalPipelineTimeoutSeconds: 10.0
        )
        let client = SequencedAIClient(responses: [
            .success(makeWidgetJSON(
                name: "Broken 1",
                description: "Invalid type",
                contentJSON: #"{"type":"ticker","symbol":"BTC"}"#
            )),
            .success(makeWidgetJSON(
                name: "Broken 2",
                description: "Still invalid type",
                contentJSON: #"{"type":"stocks","symbol":"ETH"}"#
            )),
            .success(makeWidgetJSON(
                name: "Crypto Live",
                description: "Recovered schema",
                contentJSON: #"{"type":"crypto","symbol":"BTC","currency":"USD","showPrice":true,"showChange":true,"showChart":false}"#
            ))
        ])
        let context = PromptContext(
            currentDate: Date(),
            userTimezone: "America/Chicago",
            userLocation: "Tempe, AZ, USA"
        )
        
        let config = try await pipeline.generate(
            prompt: "need bitcoin stock and ethereum stock changes live updates",
            defaultTheme: .obsidian,
            context: context,
            generationClient: client
        )
        
        #expect(config.name == "Crypto Live")
        #expect(config.content.type == ComponentType.crypto)
        #expect(client.callCount >= 3)
    }
    
    @Test func generationPipelineReturnsValidConfigWhenVerificationFailsWithoutBudget() async throws {
        let pipeline = GenerationPipeline(
            promptBuilder: PromptBuilder(componentSchema: "{}"),
            validator: SchemaValidator(),
            callTimeoutSeconds: 1.0,
            totalPipelineTimeoutSeconds: 10.0
        )
        let client = SequencedAIClient(responses: [
            .success(makeWidgetJSON(
                name: "Broken retry",
                description: "Invalid first attempt",
                contentJSON: #"{"type":"ticker","symbol":"BTC"}"#
            )),
            .success(makeWidgetJSON(
                name: "Recovered on retry",
                description: "Valid second attempt",
                contentJSON: #"{"type":"crypto","symbol":"ETH","currency":"USD","showPrice":true,"showChange":true,"showChart":false}"#
            )),
            .success("""
            FAIL
            - Issue 1: Missing second asset row.
            - Fix 1: Add another crypto component.
            """)
        ])
        let context = PromptContext(
            currentDate: Date(),
            userTimezone: "America/Chicago",
            userLocation: "Tempe, AZ, USA"
        )
        
        let config = try await pipeline.generate(
            prompt: "bitcoin and ethereum live changes",
            defaultTheme: .obsidian,
            context: context,
            generationClient: client
        )
        
        #expect(config.name == "Recovered on retry")
        #expect(config.content.type == ComponentType.crypto)
        #expect(client.callCount >= 3)
    }

    @Test func generationPipelineReturnsFallbackWidgetAfterExhaustingRecovery() async throws {
        let pipeline = GenerationPipeline(
            promptBuilder: PromptBuilder(componentSchema: "{}"),
            validator: SchemaValidator(),
            callTimeoutSeconds: 1.0,
            totalPipelineTimeoutSeconds: 10.0
        )
        let client = SequencedAIClient(responses: [
            .failure(AIWidgetServiceError.requestFailed("Timed out while waiting for OpenAI response.")),
            .failure(AIWidgetServiceError.requestFailed("Timed out while waiting for OpenAI response."))
        ])
        let context = PromptContext(
            currentDate: Date(),
            userTimezone: "America/Chicago",
            userLocation: "Tempe, AZ, USA"
        )

        let config = try await pipeline.generate(
            prompt: "bitcoin and ethereum live changes",
            defaultTheme: .obsidian,
            context: context,
            generationClient: client
        )

        // With heuristic recovery enabled, failures should still yield a useful widget when possible.
        #expect(config.description == "bitcoin and ethereum live changes")
        #expect(config.refreshInterval <= 120)
        #expect(config.size.width > config.size.height)

        let rootType = config.content.type
        #expect(rootType == .hstack || rootType == .vstack || rootType == .crypto)
        #expect(client.callCount == 2)
    }

}

private final class SequencedAIClient: AIProviderClient {
    private var responses: [Result<String, Error>]
    private(set) var callCount = 0
    
    init(responses: [Result<String, Error>]) {
        self.responses = responses
    }
    
    func generateJSON(systemPrompt: String, userPrompt: String) async throws -> String {
        callCount += 1
        guard !responses.isEmpty else {
            throw AIWidgetServiceError.requestFailed("No mock response available.")
        }
        let next = responses.removeFirst()
        return try next.get()
    }
}

private func makeWidgetJSON(
    name: String,
    description: String,
    contentJSON: String,
    width: Int = 320,
    height: Int = 180
) -> String {
    """
    {
      "version": "1.0",
      "id": "11111111-1111-1111-1111-111111111111",
      "name": "\(name)",
      "description": "\(description)",
      "size": { "width": \(width), "height": \(height) },
      "theme": "obsidian",
      "background": {
        "type": "blur",
        "material": "hudWindow",
        "tintColor": "#0D1117",
        "tintOpacity": 0.72
      },
      "cornerRadius": 20,
      "padding": { "top": 16, "bottom": 16, "leading": 16, "trailing": 16 },
      "refreshInterval": 60,
      "content": \(contentJSON)
    }
    """
}
