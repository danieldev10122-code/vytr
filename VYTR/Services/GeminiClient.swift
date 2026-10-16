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
            case 429: return "Free tier limit reached (429). Try again later."
            case 500...599: return "Google's service is having trouble (\(status)). Try again shortly."
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

    /// Keeps an error readable on a phone screen.
    private static func firstLine(_ body: String) -> String {
        String(body.prefix(180))
    }
}

enum GeminiClient {

    /// Chosen because the docs recommend 3.8 Flash for new projects and it
    /// is listed on the free tier. All Gemini models accept image input.
    static let model = "gemini-3.8-flash"

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
        "required": ["mealName", "confidence", "items", "totalCaloriesMin", "totalCaloriesMax"]
    ]

    /// Sends one photo to Google and returns the parsed estimate.
    ///
    /// This is the only place in the app that talks to a network, and it
    /// is only ever called from an explicit tap.
    static func analyze(imageData: Data) async throws -> MealAnalysis {
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
        request.timeoutInterval = 120

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
