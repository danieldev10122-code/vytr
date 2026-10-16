import Foundation
import UIKit

/// Isolates which ingredient of an analysis request is slow or failing.
///
/// The real call sends four things at once: a model, a long prompt, a JSON
/// schema and an image. When it hangs, that is four suspects and no
/// evidence. These probes add one ingredient at a time and time each, so
/// the culprit is measured instead of guessed.
enum GeminiDiagnostics {

    struct Result: Identifiable {
        let id = UUID()
        let step: String
        let outcome: String
        let ok: Bool
    }

    private static let endpoint = URL(string: "https://generativelanguage.googleapis.com/v1beta/interactions")!

    /// Short on purpose: a probe that hangs for two minutes teaches
    /// nothing that a thirty second one does not.
    private static let probeTimeout: TimeInterval = 30

    static func run() async -> [Result] {
        guard let key = KeychainStore.read() else {
            return [Result(step: "API key", outcome: "No key saved", ok: false)]
        }

        var results: [Result] = []

        for model in [GeminiClient.model, "gemini-3.8-flash"] {
            results.append(
                await probe(
                    "1. Text only - \(model)",
                    key: key,
                    body: [
                        "model": model,
                        "input": "Reply with the single word OK.",
                        "generation_config": ["thinking_level": "low"]
                    ]
                )
            )
        }

        results.append(
            await probe(
                "2. Text + JSON schema",
                key: key,
                body: [
                    "model": GeminiClient.model,
                    "input": "Return the word OK in the text field.",
                    "generation_config": ["thinking_level": "low"],
                    "response_format": [
                        "type": "text",
                        "mime_type": "application/json",
                        "schema": [
                            "type": "object",
                            "properties": ["text": ["type": "string"]],
                            "required": ["text"]
                        ]
                    ]
                ]
            )
        )

        if let tiny = tinyImage() {
            results.append(
                await probe(
                    "3. Text + schema + small image (\(tiny.count / 1024)KB)",
                    key: key,
                    body: [
                        "model": GeminiClient.model,
                        "input": [
                            ["type": "text", "text": "Name one thing you see. Put it in the text field."],
                            ["type": "image", "data": tiny.base64EncodedString(), "mime_type": "image/jpeg"]
                        ],
                        "generation_config": ["thinking_level": "low"],
                        "response_format": [
                            "type": "text",
                            "mime_type": "application/json",
                            "schema": [
                                "type": "object",
                                "properties": ["text": ["type": "string"]],
                                "required": ["text"]
                            ]
                        ]
                    ]
                )
            )
        }

        return results
    }

    private static func probe(_ step: String, key: String, body: [String: Any]) async -> Result {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
        request.timeoutInterval = probeTimeout

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            return Result(step: step, outcome: "Could not build request", ok: false)
        }

        let start = Date()
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let seconds = String(format: "%.1fs", Date().timeIntervalSince(start))
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0

            if (200...299).contains(code) {
                return Result(step: step, outcome: "\(code) in \(seconds)", ok: true)
            }

            let detail = String(decoding: data.prefix(120), as: UTF8.self)
                .replacingOccurrences(of: "\n", with: " ")
            return Result(step: step, outcome: "\(code) in \(seconds) - \(detail)", ok: false)
        } catch let error as URLError where error.code == .timedOut {
            return Result(step: step, outcome: "timed out after \(Int(probeTimeout))s", ok: false)
        } catch {
            let seconds = String(format: "%.1fs", Date().timeIntervalSince(start))
            return Result(step: step, outcome: "failed in \(seconds) - \(error.localizedDescription)", ok: false)
        }
    }

    /// A 64x64 solid square, a couple of kilobytes, so step 3 differs from
    /// step 2 only by the presence of an image and not by its size.
    private static func tinyImage() -> Data? {
        let size = CGSize(width: 64, height: 64)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true

        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.systemGreen.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return image.jpegData(compressionQuality: 0.8)
    }
}
