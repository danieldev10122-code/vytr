import Foundation

enum GeminiError: LocalizedError {
    case missingKey
    case http(status: Int, body: String)
    case noOutput(status: String)
    case badJSON(String)
    case transport(String)
    case timedOut

    var errorDescription: String? {
        switch self {
        case .missingKey:
            return "No API key saved. Add one in More > AI analysis."
        case .http(let status, let body):
            switch status {
            case 400: return "Gemini rejected the request (400). \(Self.firstLine(body))"
            case 401, 403: return "The API key was refused (\(status)). Check it in More > AI analysis."
            case 429: return "Free tier limit reached (429), even after retrying. Wait a minute and try again."
            case 500...599: return "Google's servers are busy (\(status)). VYTR retried several times and they stayed busy. Try again in a minute."
            default: return "Gemini returned \(status). \(Self.firstLine(body))"
            }
        case .noOutput(let status):
            return "Gemini returned no text (status: \(status))."
        case .badJSON(let detail):
            return "Could not read Gemini's answer. \(detail)"
        case .transport(let detail):
            return "Network problem. \(detail)"
        case .timedOut:
            return "Gemini took too long to answer. Tap Analyze again."
        }
    }

    /// Worth retrying. Google's guidance is to retry 408, 429 and 5xx and
    /// never 400 or 403, which are faults in the request itself.
    var isTransient: Bool {
        switch self {
        case .http(let status, _):
            return status == 408 || status == 429 || (500...599).contains(status)
        case .transport:
            return true
        case .timedOut:
            // Worth one more go now that a single attempt is capped at 45s
            // rather than two minutes.
            return true
        case .missingKey, .badJSON, .noOutput:
            return false
        }
    }

    /// Keeps an error readable on a phone screen.
    private static func firstLine(_ body: String) -> String {
        String(body.prefix(180))
    }
}

enum GeminiClient {

    /// Flash-Lite rather than 3.8 Flash. The docs recommend either for new
    /// projects, both are on the free tier and both accept images, but
    /// 3.8 Flash kept timing out or returning 503 on this account, and a
    /// lighter model answers faster and competes for less capacity.
    /// The diagnostic in Settings times both, so this is revisitable.
    static let model = "gemini-3.5-flash-lite"

    private static let endpoint = URL(string: "https://generativelanguage.googleapis.com/v1beta/interactions")!

    private static let prompt = """
    You are estimating nutrition from a photograph of a meal.

    You cannot weigh or measure this food, so every number you give is an \
    estimate, and you must present it as one. Identify each distinct food \
    item you can see. For each item give a short portion description in \
    everyday terms and a calorie range that honestly reflects how uncertain \
    you are: widen the range when the portion size, cooking method or \
    hidden ingredients such as oil or sauce are unclear.

    Never give a single exact calorie figure for an item or for the meal. \
    Give whole-meal totals as a range too, and give protein, carbohydrate \
    and fat in grams as your best single estimate.

    Set confidence to low when the picture is blurry, poorly lit, or the \
    food is hard to identify, and say why in notes. If you cannot see any \
    food at all, return an empty items array and set confidence to low.

    Always give all three macros in grams, even when you are unsure: a \
    best estimate is useful, a missing value is not. Only use zero when \
    the food genuinely contains none of that macronutrient.

    Keep names and portions short enough to read on a phone.
    """

    private static let schema: [String: Any] = [
        "type": "object",
        "properties": [
            "mealName": ["type": "string"],
            "confidence": ["type": "string", "enum": ["high", "medium", "low"]],
            "items": [
                "type": "array",
                "items": [
                    "type": "object",
                    "properties": [
                        "name": ["type": "string"],
                        "portion": ["type": "string"],
                        "caloriesMin": ["type": "integer"],
                        "caloriesMax": ["type": "integer"]
                    ],
                    "required": ["name", "portion", "caloriesMin", "caloriesMax"]
                ]
            ],
            "totalCaloriesMin": ["type": "integer"],
            "totalCaloriesMax": ["type": "integer"],
            "proteinGrams": ["type": "number"],
            "carbsGrams": ["type": "number"],
            "fatGrams": ["type": "number"],
            "notes": ["type": "string"]
        ],
        // The macros are required too. Left optional, the model simply
        // omitted them, they were stored as nil, and the day total then
        // rendered nil as "0g" - a sandwich with no carbs and no fat,
        // which reads as a measurement rather than a missing value.
        "required": [
            "mealName", "confidence", "items",
            "totalCaloriesMin", "totalCaloriesMax",
            "proteinGrams", "carbsGrams", "fatGrams"
        ]
    ]

    /// Sends one photo to Google and returns the parsed estimate.
    ///
    /// This is the only place in the app that talks to a network, and it
    /// is only ever called from an explicit tap.
    /// Google's own SDKs retry transient failures automatically. Calling
    /// REST directly means doing it here, with the backoff their docs
    /// prescribe: about a second, then doubling, with jitter so repeated
    /// taps do not line up.
    private static let maxAttempts = 4

    static func analyze(imageData: Data) async throws -> MealAnalysis {
        var lastError: Error = GeminiError.noOutput(status: "no attempt made")

        for attempt in 0..<maxAttempts {
            if attempt > 0 {
                let seconds = pow(2.0, Double(attempt - 1)) + Double.random(in: 0...0.4)
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            }

            do {
                return try await attemptAnalysis(imageData: imageData)
            } catch let error as GeminiError where error.isTransient {
                lastError = error
            }
        }

        throw lastError
    }

    private static func attemptAnalysis(imageData: Data) async throws -> MealAnalysis {
        guard let key = KeychainStore.read() else { throw GeminiError.missingKey }

        // A smaller copy is sent than the one stored locally: fewer image
        // tokens means a faster answer, and less of the photo leaves the
        // device.
        let payload = ImageProcessing.forAnalysis(imageData) ?? imageData

        let body: [String: Any] = [
            "model": model,
            "input": [
                ["type": "text", "text": prompt],
                ["type": "image", "data": payload.base64EncodedString(), "mime_type": "image/jpeg"]
            ],
            "response_format": [
                "type": "text",
                "mime_type": "application/json",
                "schema": schema
            ],
            // Gemini 3 models think before answering, and this one defaults
            // to "medium", which took longer than a phone user will wait.
            // "low" is the lowest level 3.8 Flash supports.
            "generation_config": [
                "thinking_level": "low"
            ]
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        // Short enough that a stuck request fails fast and the retry loop
        // gets another go, rather than one long hang with no second
        // chance. Four attempts at 45s is still under the patience of
        // someone holding a phone.
        request.timeoutInterval = 45

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as URLError where error.code == .timedOut {
            throw GeminiError.timedOut
        } catch {
            throw GeminiError.transport(error.localizedDescription)
        }

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw GeminiError.http(
                status: http.statusCode,
                body: String(data: data, encoding: .utf8) ?? ""
            )
        }

        let envelope = try decodeEnvelope(data)
        guard let text = envelope.modelText, !text.isEmpty else {
            throw GeminiError.noOutput(status: envelope.status ?? "unknown")
        }

        do {
            return try JSONDecoder().decode(MealAnalysis.self, from: Data(text.utf8))
        } catch {
            throw GeminiError.badJSON(String(text.prefix(180)))
        }
    }

    // MARK: - Response envelope

    private struct Envelope: Decodable {
        struct Step: Decodable {
            struct Content: Decodable {
                let type: String
                let text: String?
            }
            let type: String
            let content: [Content]?
        }

        let status: String?
        let steps: [Step]?

        /// The model's answer lives in the text parts of model_output steps.
        var modelText: String? {
            guard let steps else { return nil }
            let text = steps
                .filter { $0.type == "model_output" }
                .flatMap { $0.content ?? [] }
                .filter { $0.type == "text" }
                .compactMap(\.text)
                .joined()
            return text.isEmpty ? nil : text
        }
    }

    private static func decodeEnvelope(_ data: Data) throws -> Envelope {
        do {
            return try JSONDecoder().decode(Envelope.self, from: data)
        } catch {
            throw GeminiError.badJSON(String(decoding: data.prefix(180), as: UTF8.self))
        }
    }
}
