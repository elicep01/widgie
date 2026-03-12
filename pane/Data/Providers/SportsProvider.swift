import Foundation

struct SportsProvider {
    // TheSportsDB — free tier, no key required for basic endpoints
    private let baseURL = "https://www.thesportsdb.com/api/v1/json/3"

    func fetchLiveScores(sport: String) async throws -> [SportsScoreSnapshot] {
        let sportID = mapSportToLeague(sport)
        let url = URL(string: "\(baseURL)/eventspastleague.php?id=\(sportID)")!
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(SportsDBEventsResponse.self, from: data)
        guard let events = decoded.events else { return [] }

        return events.prefix(8).map { event in
            SportsScoreSnapshot(
                id: event.idEvent,
                league: event.strLeague ?? sport,
                homeTeam: event.strHomeTeam ?? "Home",
                awayTeam: event.strAwayTeam ?? "Away",
                homeScore: event.intHomeScore.flatMap { Int($0) },
                awayScore: event.intAwayScore.flatMap { Int($0) },
                status: event.strStatus ?? "FT",
                dateEvent: event.dateEvent ?? "",
                sport: event.strSport ?? sport,
                updatedAt: Date()
            )
        }
    }

    func searchTeam(name: String) async throws -> SportsTeamSnapshot? {
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        let url = URL(string: "\(baseURL)/searchteams.php?t=\(encoded)")!
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(SportsDBTeamsResponse.self, from: data)
        guard let team = decoded.teams?.first else { return nil }

        return SportsTeamSnapshot(
            id: team.idTeam,
            name: team.strTeam ?? name,
            sport: team.strSport ?? "",
            league: team.strLeague ?? "",
            country: team.strCountry ?? "",
            badgeURL: team.strBadge,
            updatedAt: Date()
        )
    }

    private func mapSportToLeague(_ sport: String) -> String {
        switch sport.lowercased() {
        case "soccer", "football", "premier league", "epl": return "4328"
        case "nba", "basketball": return "4387"
        case "nfl", "american football": return "4391"
        case "mlb", "baseball": return "4424"
        case "nhl", "hockey", "ice hockey": return "4380"
        case "f1", "formula 1", "formula one": return "4370"
        case "mls": return "4346"
        case "la liga", "laliga": return "4335"
        case "bundesliga": return "4331"
        case "serie a": return "4332"
        case "ligue 1": return "4334"
        case "champions league", "ucl": return "4480"
        default: return "4328"  // default to Premier League
        }
    }
}

private struct SportsDBEventsResponse: Codable {
    let events: [SportsDBEvent]?
}

private struct SportsDBEvent: Codable {
    let idEvent: String
    let strLeague: String?
    let strHomeTeam: String?
    let strAwayTeam: String?
    let intHomeScore: String?
    let intAwayScore: String?
    let strStatus: String?
    let dateEvent: String?
    let strSport: String?
}

private struct SportsDBTeamsResponse: Codable {
    let teams: [SportsDBTeam]?
}

private struct SportsDBTeam: Codable {
    let idTeam: String
    let strTeam: String?
    let strSport: String?
    let strLeague: String?
    let strCountry: String?
    let strBadge: String?
}
