import SwiftSyntax

public struct TrailingSemicolonRule: SwiftSyntaxCorrectableRule, ConfigurationProviderRule {
    public var configuration = SeverityConfiguration(.warning)

    public init() {}

    public static let description = RuleDescription(
        identifier: "trailing_semicolon",
        name: "Trailing Semicolon",
        description: "Lines should not have trailing semicolons.",
        kind: .idiomatic,
        nonTriggeringExamples: [
            Example("let a = 0\n"),
            Example("let a = 0; let b = 0")
        ],
        triggeringExamples: [
            Example("let a = 0↓;\n"),
            Example("let a = 0↓;\nlet b = 1\n")
        ],
        corrections: [
            Example("let a = 0↓;\n"): Example("let a = 0\n"),
            Example("let a = 0↓;\nlet b = 1\n"): Example("let a = 0\nlet b = 1\n")
        ]
    )

    public func makeVisitor(file: SwiftLintFile) -> ViolationsSyntaxVisitor? {
        Visitor(viewMode: .sourceAccurate)
    }

    public func makeRewriter(file: SwiftLintFile) -> ViolationsSyntaxRewriter? {
        Rewriter(
            locationConverter: file.locationConverter,
            disabledRegions: disabledRegions(file: file)
        )
    }
}

private extension TrailingSemicolonRule {
    final class Visitor: ViolationsSyntaxVisitor {
        override func visitPost(_ node: TokenSyntax) {
            if node.isTrailingSemicolon {
                violations.append(node.positionAfterSkippingLeadingTrivia)
            }
        }
    }

    final class Rewriter: SyntaxRewriter, ViolationsSyntaxRewriter {
        private(set) var correctionPositions: [AbsolutePosition] = []
        let locationConverter: SourceLocationConverter
        let disabledRegions: [SourceRange]

        init(locationConverter: SourceLocationConverter, disabledRegions: [SourceRange]) {
            self.locationConverter = locationConverter
            self.disabledRegions = disabledRegions
        }

        override func visit(_ node: TokenSyntax) -> Syntax {
            guard
                node.isTrailingSemicolon,
                !node.isContainedIn(regions: disabledRegions, locationConverter: locationConverter)
            else {
                return super.visit(node)
            }

            correctionPositions.append(node.positionAfterSkippingLeadingTrivia)
            // Is there a better way to remove a node? Should we somehow keep trailing trivia?
            return super.visit(TokenSyntax(.semicolon, presence: .missing))
        }
    }
}

private extension TokenSyntax {
    var isTrailingSemicolon: Bool {
        tokenKind == .semicolon &&
            (trailingTrivia.containsNewlines() || (nextToken?.leadingTrivia.containsNewlines() == true))
    }
}

private extension Trivia {
    func containsNewlines() -> Bool {
        contains { piece in
            if case .newlines = piece {
                return true
            } else {
                return false
            }
        }
    }
}
