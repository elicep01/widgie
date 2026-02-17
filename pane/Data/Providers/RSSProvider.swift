import Foundation

final class RSSProvider: NSObject {
    func fetch(feedURL: String, maxItems: Int) async throws -> [NewsHeadlineSnapshot] {
        guard let url = URL(string: feedURL) else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let parserDelegate = RSSParserDelegate(maxItems: max(1, maxItems))
        let parser = XMLParser(data: data)
        parser.delegate = parserDelegate

        guard parser.parse() else {
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

    private(set) var items: [NewsHeadlineSnapshot] = []

    init(maxItems: Int) {
        self.maxItems = maxItems
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
        if elementName == "item" || elementName == "entry" {
            insideItem = true
            currentTitle = ""
            currentLink = ""
            currentSource = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
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
        if (elementName == "item" || elementName == "entry"), insideItem {
            let title = currentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            if !title.isEmpty {
                items.append(
                    NewsHeadlineSnapshot(
                        id: UUID().uuidString,
                        title: title,
                        source: currentSource.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
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
