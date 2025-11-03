import XCTest
import Foundation
import ArgumentParser
@testable import XamrockCLI

final class FixtureAnalyzeCommandTests: XCTestCase {

    var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FixtureAnalyzeCommandTests-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if FileManager.default.fileExists(atPath: tempDirectory.path) {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        super.tearDown()
    }

    // MARK: - Argument Parsing Tests

    func testParseResultsDirectory() throws {
        // Given: Results directory argument
        let args = ["--results-dir", tempDirectory.path]

        // When: Parsing command
        let command = try FixtureAnalyzeCommand.parse(args)

        // Then: Should parse path correctly
        XCTAssertEqual(command.resultsDir, tempDirectory.path)
    }

    func testParseOutputPath() throws {
        // Given: Output path argument
        let outputPath = tempDirectory.appendingPathComponent("suggested.json").path
        let args = ["--output", outputPath]

        // When: Parsing command
        let command = try FixtureAnalyzeCommand.parse(args)

        // Then: Should parse output path
        XCTAssertEqual(command.outputPath, outputPath)
    }

    func testParseMinConfidence() throws {
        // Given: Minimum confidence argument
        let args = ["--min-confidence", "0.5"]

        // When: Parsing command
        let command = try FixtureAnalyzeCommand.parse(args)

        // Then: Should parse confidence threshold
        XCTAssertEqual(command.minConfidence, 0.5)
    }

    func testParseDefaultMinConfidence() throws {
        // Given: No min-confidence argument
        let args: [String] = []

        // When: Parsing command
        let command = try FixtureAnalyzeCommand.parse(args)

        // Then: Should default to 0.7
        XCTAssertEqual(command.minConfidence, 0.7)
    }

    // MARK: - Exploration Result Parsing Tests

    func testAnalyzeExplorationResults() throws {
        // Given: Mock exploration results with low-confidence values
        let resultsDir = tempDirectory.appendingPathComponent("scout-results")
        try FileManager.default.createDirectory(at: resultsDir, withIntermediateDirectories: true)

        let explorationJSON = createMockExplorationResult()
        let explorationFile = resultsDir.appendingPathComponent("exploration-result.json")
        try explorationJSON.write(to: explorationFile, atomically: true, encoding: .utf8)

        // When: Analyzing results
        let analyzer = FixtureAnalyzer()
        let suggestions = try analyzer.analyze(resultsDirectory: resultsDir, minConfidence: 0.7)

        // Then: Should identify fields needing fixtures
        XCTAssertFalse(suggestions.isEmpty)
        XCTAssertTrue(suggestions.contains { $0.priority == .high })
    }

    func testIdentifyFallbackValues() throws {
        // Given: Exploration with fallback values
        let resultsDir = createMockResultsWithFallbacks()

        // When: Analyzing results
        let analyzer = FixtureAnalyzer()
        let suggestions = try analyzer.analyze(resultsDirectory: resultsDir, minConfidence: 0.7)

        // Then: Should prioritize fallback fields as high priority
        let highPriority = suggestions.filter { $0.priority == .high }
        XCTAssertFalse(highPriority.isEmpty)
        XCTAssertTrue(highPriority.allSatisfy { $0.source == "fallback" })
    }

    func testIdentifyAIGeneratedValues() throws {
        // Given: Exploration with AI-generated values
        let resultsDir = createMockResultsWithAIValues()

        // When: Analyzing results
        let analyzer = FixtureAnalyzer()
        let suggestions = try analyzer.analyze(resultsDirectory: resultsDir, minConfidence: 0.7)

        // Then: Should classify AI-generated as medium priority
        let mediumPriority = suggestions.filter { $0.priority == .medium }
        XCTAssertFalse(mediumPriority.isEmpty)
    }

    func testSuggestPatternTypes() throws {
        // Given: Field identifiers from exploration
        let analyzer = FixtureAnalyzer()

        // When: Suggesting pattern types for various fields
        let emailSuggestion = analyzer.suggestPattern(for: "emailField", value: "test@example.com")
        let passwordSuggestion = analyzer.suggestPattern(for: "confirmPasswordField", value: "TestPass123")
        let numberFieldSuggestion = analyzer.suggestPattern(for: "apartmentNumber", value: "12B")

        // Then: Should suggest appropriate pattern types
        XCTAssertTrue(emailSuggestion.contains("email"))
        XCTAssertTrue(passwordSuggestion.contains("password"))
        XCTAssertTrue(numberFieldSuggestion.contains("number")) // Detects "number" keyword
    }

    func testGroupSuggestionsByScreenType() throws {
        // Given: Exploration with multiple screen types
        let resultsDir = createMockResultsMultipleScreens()

        // When: Analyzing results
        let analyzer = FixtureAnalyzer()
        let suggestions = try analyzer.analyze(resultsDirectory: resultsDir, minConfidence: 0.7)

        // Then: Should group suggestions by screen
        let loginSuggestions = suggestions.filter { $0.screenType == "login" }
        let checkoutSuggestions = suggestions.filter { $0.screenType == "checkout" }

        XCTAssertFalse(loginSuggestions.isEmpty)
        XCTAssertFalse(checkoutSuggestions.isEmpty)
    }

    // MARK: - Suggestion Generation Tests

    func testGenerateFixtureFromSuggestions() throws {
        // Given: Analyzed suggestions
        let suggestions = [
            FixtureSuggestion(
                fieldId: "emailField",
                value: "test@example.com",
                patternSuggestion: "emailField",
                priority: .high,
                source: "fallback",
                screenType: "login",
                frequency: 5
            ),
            FixtureSuggestion(
                fieldId: "passwordField",
                value: "TestPass123",
                patternSuggestion: "pattern:contains:password",
                priority: .high,
                source: "fallback",
                screenType: "login",
                frequency: 5
            )
        ]

        // When: Generating fixture
        let generator = FixtureSuggestionEngine()
        let fixture = generator.generateFixture(from: suggestions, name: "Suggested Fixture")

        // Then: Should create valid fixture structure
        XCTAssertEqual(fixture["version"] as? String, "1.0")
        XCTAssertEqual(fixture["name"] as? String, "Suggested Fixture")

        let patterns = fixture["patterns"] as? [String: String]
        XCTAssertNotNil(patterns)
        XCTAssertEqual(patterns?["emailField"], "test@example.com")
        XCTAssertTrue(patterns?.keys.contains("pattern:contains:password") ?? false)
    }

    func testMergeWithExistingFixture() throws {
        // Given: Existing fixture and new suggestions
        let existingFixturePath = tempDirectory.appendingPathComponent("existing.json")
        let existingJSON = """
        {
          "version": "1.0",
          "patterns": {
            "oldField": "old value"
          },
          "defaults": {},
          "fallbackMode": "aiGenerated"
        }
        """
        try existingJSON.write(to: existingFixturePath, atomically: true, encoding: .utf8)

        let suggestions = [
            FixtureSuggestion(
                fieldId: "newField",
                value: "new value",
                patternSuggestion: "newField",
                priority: .high,
                source: "fallback",
                screenType: nil,
                frequency: 3
            )
        ]

        // When: Merging suggestions with existing fixture
        let generator = FixtureSuggestionEngine()
        let merged = try generator.merge(suggestions: suggestions, with: existingFixturePath)

        // Then: Should preserve old entries and add new ones
        let patterns = merged["patterns"] as? [String: String]
        XCTAssertEqual(patterns?["oldField"], "old value")
        XCTAssertEqual(patterns?["newField"], "new value")
    }

    func testPrioritizeSuggestionsByFrequency() throws {
        // Given: Multiple fields with different frequencies
        let suggestions = [
            FixtureSuggestion(fieldId: "field1", value: "val1", patternSuggestion: "field1",
                            priority: .medium, source: "aiGenerated", screenType: nil, frequency: 10),
            FixtureSuggestion(fieldId: "field2", value: "val2", patternSuggestion: "field2",
                            priority: .medium, source: "aiGenerated", screenType: nil, frequency: 1)
        ]

        // When: Sorting suggestions
        let sorted = suggestions.sorted { $0.frequency > $1.frequency }

        // Then: Should prioritize by frequency
        XCTAssertEqual(sorted.first?.fieldId, "field1")
        XCTAssertEqual(sorted.last?.fieldId, "field2")
    }

    // MARK: - Output Format Tests

    func testGenerateJSONOutput() throws {
        // Given: Analysis command with JSON format
        let resultsDir = createMockResultsWithFallbacks()
        let outputPath = tempDirectory.appendingPathComponent("output.json")

        let args = [
            "--results-dir", resultsDir.path,
            "--output", outputPath.path,
            "--format", "json"
        ]
        let command = try FixtureAnalyzeCommand.parse(args)

        // When: Running analysis
        try command.runAnalysis()

        // Then: Should create JSON file
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputPath.path))

        let data = try Data(contentsOf: outputPath)
        let json = try JSONSerialization.jsonObject(with: data)
        XCTAssertNotNil(json)
    }

    func testGenerateInteractiveSummary() throws {
        // Given: Suggestions with various priorities
        let suggestions = [
            FixtureSuggestion(fieldId: "field1", value: "val1", patternSuggestion: "field1",
                            priority: .high, source: "fallback", screenType: nil, frequency: 5),
            FixtureSuggestion(fieldId: "field2", value: "val2", patternSuggestion: "field2",
                            priority: .medium, source: "aiGenerated", screenType: nil, frequency: 3)
        ]

        // When: Generating summary
        let formatter = SuggestionFormatter()
        let summary = formatter.formatInteractiveSummary(suggestions: suggestions)

        // Then: Should include priority groups
        XCTAssertTrue(summary.contains("High Priority"))
        XCTAssertTrue(summary.contains("Medium Priority"))
        XCTAssertTrue(summary.contains("field1"))
        XCTAssertTrue(summary.contains("field2"))
    }

    func testEmptyResults() throws {
        // Given: Empty results directory
        let emptyDir = tempDirectory.appendingPathComponent("empty-results")
        try FileManager.default.createDirectory(at: emptyDir, withIntermediateDirectories: true)

        // When: Analyzing empty results
        let analyzer = FixtureAnalyzer()
        let suggestions = try analyzer.analyze(resultsDirectory: emptyDir, minConfidence: 0.7)

        // Then: Should return empty suggestions
        XCTAssertTrue(suggestions.isEmpty)
    }

    func testAllHighConfidenceValues() throws {
        // Given: Results with all high-confidence fixture values
        let resultsDir = createMockResultsAllHighConfidence()

        // When: Analyzing results
        let analyzer = FixtureAnalyzer()
        let suggestions = try analyzer.analyze(resultsDirectory: resultsDir, minConfidence: 0.7)

        // Then: Should return empty or minimal suggestions
        XCTAssertTrue(suggestions.isEmpty || suggestions.allSatisfy { $0.priority == .low })
    }

    // MARK: - Helper Methods

    private func createMockExplorationResult() -> String {
        return """
        {
          "steps": [
            {
              "action": {
                "type": "type",
                "elementId": "apartmentNumber",
                "value": "test input",
                "valueSource": {
                  "type": "fallback"
                }
              },
              "screenType": "checkout"
            },
            {
              "action": {
                "type": "type",
                "elementId": "emailField",
                "value": "user@example.com",
                "valueSource": {
                  "type": "aiGenerated",
                  "context": "login"
                }
              },
              "screenType": "login"
            }
          ]
        }
        """
    }

    private func createMockResultsWithFallbacks() -> URL {
        let resultsDir = tempDirectory.appendingPathComponent("fallback-results")
        try! FileManager.default.createDirectory(at: resultsDir, withIntermediateDirectories: true)

        let json = createMockExplorationResult()
        let file = resultsDir.appendingPathComponent("exploration-result.json")
        try! json.write(to: file, atomically: true, encoding: .utf8)

        return resultsDir
    }

    private func createMockResultsWithAIValues() -> URL {
        let resultsDir = tempDirectory.appendingPathComponent("ai-results")
        try! FileManager.default.createDirectory(at: resultsDir, withIntermediateDirectories: true)

        let json = """
        {
          "steps": [
            {
              "action": {
                "type": "type",
                "elementId": "bioField",
                "value": "This is a bio",
                "valueSource": {
                  "type": "aiGenerated",
                  "context": "profile"
                }
              },
              "screenType": "profile"
            }
          ]
        }
        """
        let file = resultsDir.appendingPathComponent("exploration-result.json")
        try! json.write(to: file, atomically: true, encoding: .utf8)

        return resultsDir
    }

    private func createMockResultsMultipleScreens() -> URL {
        let resultsDir = tempDirectory.appendingPathComponent("multi-screen-results")
        try! FileManager.default.createDirectory(at: resultsDir, withIntermediateDirectories: true)

        let json = """
        {
          "steps": [
            {
              "action": {
                "type": "type",
                "elementId": "loginEmail",
                "value": "test input",
                "valueSource": { "type": "fallback" }
              },
              "screenType": "login"
            },
            {
              "action": {
                "type": "type",
                "elementId": "checkoutEmail",
                "value": "test input",
                "valueSource": { "type": "fallback" }
              },
              "screenType": "checkout"
            }
          ]
        }
        """
        let file = resultsDir.appendingPathComponent("exploration-result.json")
        try! json.write(to: file, atomically: true, encoding: .utf8)

        return resultsDir
    }

    private func createMockResultsAllHighConfidence() -> URL {
        let resultsDir = tempDirectory.appendingPathComponent("high-conf-results")
        try! FileManager.default.createDirectory(at: resultsDir, withIntermediateDirectories: true)

        let json = """
        {
          "steps": [
            {
              "action": {
                "type": "type",
                "elementId": "emailField",
                "value": "admin@app.com",
                "valueSource": {
                  "type": "fixtureExact",
                  "pattern": "emailField"
                }
              },
              "screenType": "login"
            }
          ]
        }
        """
        let file = resultsDir.appendingPathComponent("exploration-result.json")
        try! json.write(to: file, atomically: true, encoding: .utf8)

        return resultsDir
    }
}
