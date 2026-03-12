import Foundation

struct DictionaryProvider {
    // Free Dictionary API — no key required
    func lookup(word: String) async throws -> WordSnapshot {
        let encoded = word.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? word
        let url = URL(string: "https://api.dictionaryapi.dev/api/v2/entries/en/\(encoded)")!
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode([DictionaryEntry].self, from: data)
        guard let entry = decoded.first else { throw URLError(.cannotParseResponse) }

        let definitions = entry.meanings.flatMap { meaning in
            meaning.definitions.prefix(2).map { def in
                WordDefinition(
                    partOfSpeech: meaning.partOfSpeech,
                    definition: def.definition,
                    example: def.example
                )
            }
        }

        return WordSnapshot(
            word: entry.word,
            phonetic: entry.phonetic ?? entry.phonetics?.first?.text,
            definitions: Array(definitions.prefix(4)),
            updatedAt: Date()
        )
    }

    func randomWord() async throws -> WordSnapshot {
        // Use a curated list of interesting words
        let words = [
            "serendipity", "ephemeral", "petrichor", "luminous", "mellifluous",
            "sonder", "aurora", "ethereal", "cascade", "halcyon",
            "wanderlust", "euphoria", "labyrinth", "nebula", "solstice",
            "iridescent", "vellichor", "chrysalism", "fernweh", "natsukashii"
        ]
        let word = words.randomElement()!
        return try await lookup(word: word)
    }
}

private struct DictionaryEntry: Codable {
    let word: String
    let phonetic: String?
    let phonetics: [Phonetic]?
    let meanings: [Meaning]
}

private struct Phonetic: Codable {
    let text: String?
}

private struct Meaning: Codable {
    let partOfSpeech: String
    let definitions: [Definition]
}

private struct Definition: Codable {
    let definition: String
    let example: String?
}
