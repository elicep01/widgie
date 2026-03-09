import Foundation

final class RSSProvider: NSObject {
    /// Well-known reliable RSS feeds used as fallbacks when the primary feed fails.
    static let fallbackFeeds: [String] = [
        "https://feeds.bbci.co.uk/news/rss.xml",
        "https://rss.nytimes.com/services/xml/rss/nyt/HomePage.xml",
        "https://feeds.npr.org/1001/rss.xml",
        "http://rss.cnn.com/rss/edition.rss",
        "https://www.theguardian.com/world/rss",
    ]

    func fetch(feedURL: String, maxItems: Int) async throws -> [NewsHeadlineSnapshot] {
        // Try the requested feed first, then fallbacks
        var feedsToTry = [feedURL]
        for fallback in Self.fallbackFeeds where fallback != feedURL {
            feedsToTry.append(fallback)
        }

        var lastError: Error = URLError(.badURL)
        for feed in feedsToTry {
            do {
                let items = try await fetchSingle(feedURL: feed, maxItems: maxItems)
                if !items.isEmpty { return items }
            } catch {
                print("[RSS] Feed failed (\(feed)): \(error.localizedDescription)")
                lastError = error
            }
        }
        throw lastError
    }

    /// Fetch from multiple feeds in parallel, merge & shuffle results.
    func fetchMultiple(feedURLs: [String], maxPerFeed: Int, totalMax: Int) async -> [NewsHeadlineSnapshot] {
        await withTaskGroup(of: [NewsHeadlineSnapshot].self) { group in
            for url in feedURLs {
                group.addTask { [self] in
                    (try? await self.fetchSingle(feedURL: url, maxItems: maxPerFeed)) ?? []
                }
            }
            var all: [NewsHeadlineSnapshot] = []
            for await batch in group {
                all.append(contentsOf: batch)
            }
            // Deduplicate by title similarity
            var seen = Set<String>()
            all = all.filter { item in
                let key = item.title.lowercased().prefix(60)
                guard !seen.contains(String(key)) else { return false }
                seen.insert(String(key))
                return true
            }
            return Array(all.shuffled().prefix(totalMax))
        }
    }

    private func fetchSingle(feedURL: String, maxItems: Int) async throws -> [NewsHeadlineSnapshot] {
        guard let url = URL(string: feedURL) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let parserDelegate = RSSParserDelegate(maxItems: max(1, maxItems))
        let parser = XMLParser(data: data)
        parser.delegate = parserDelegate
        parser.parse()

        // abortParsing() causes parse() to return false even on success,
        // so check items directly instead of the return value.
        guard !parserDelegate.items.isEmpty else {
            throw URLError(.cannotParseResponse)
        }

        return parserDelegate.items
    }
}

private final class RSSParserDelegate: NSObject, XMLParserDelegate {
    private let maxItems: Int
    private var currentElement = ""
    private var currentTitle = ""
    private var currentLink = ""
    private var currentSource = ""
    private var insideItem = false
    private var insideChannel = false
    private var channelTitle = ""
    private var channelTitleDone = false

    private(set) var items: [NewsHeadlineSnapshot] = []

    init(maxItems: Int) {
        self.maxItems = maxItems
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
        if elementName == "channel" || elementName == "feed" {
            insideChannel = true
        } else if elementName == "item" || elementName == "entry" {
            insideItem = true
            currentTitle = ""
            currentLink = ""
            currentSource = ""
        }

        // Atom feeds use <link href="..."/> as a self-closing element
        if insideItem, elementName == "link", let href = attributeDict["href"] {
            currentLink = href
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        appendContent(string)
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        guard let string = String(data: CDATABlock, encoding: .utf8) else { return }
        appendContent(string)
    }

    private func appendContent(_ string: String) {
        // Capture channel/feed title as source name
        if !insideItem, insideChannel, !channelTitleDone, currentElement == "title" {
            channelTitle += string
            return
        }

        guard insideItem else { return }
        switch currentElement {
        case "title":
            currentTitle += string
        case "link":
            currentLink += string
        case "source":
            currentSource += string
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        // Mark channel title done after the first </title> inside <channel>
        if !insideItem, insideChannel, elementName == "title" {
            channelTitleDone = true
        }

        if (elementName == "item" || elementName == "entry"), insideItem {
            let title = currentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            if !title.isEmpty {
                let source = currentSource.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                    ?? channelTitle.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                items.append(
                    NewsHeadlineSnapshot(
                        id: UUID().uuidString,
                        title: title,
                        source: source,
                        link: currentLink.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                        publishedAt: nil
                    )
                )
            }
            insideItem = false
            if items.count >= maxItems {
                parser.abortParsing()
            }
        }
        currentElement = ""
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
