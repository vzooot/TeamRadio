import Foundation

/// "Ask the race engineer": questions go to the Worker, which grounds them in
/// this weekend's real data and asks Azure OpenAI (server/src/ask.js). The AI
/// key never ships in the app.
enum AskService {
    private static let endpoint = URL(string: "https://teamradio-push.eam-adio.workers.dev/ask")!

    private struct Reply: Decodable {
        let answer: String?
        let error: String?
    }

    /// Emily's answer. Limits and outages come back as an in-character line.
    static func ask(_ question: String, user: String) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 40
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["question": question, "user": user])
        let (data, _) = try await URLSession.shared.data(for: request)
        let reply = try JSONDecoder().decode(Reply.self, from: data)
        guard let answer = reply.answer else { throw URLError(.badServerResponse) }
        return answer
    }
}
