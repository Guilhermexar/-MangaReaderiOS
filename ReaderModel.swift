import Foundation
import SwiftUI

struct Chapter: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let url: URL
}

@MainActor
final class ReaderModel: ObservableObject {
    @Published var urlText = ""
    @Published var title = ""
    @Published var pages: [URL] = []
    @Published var chapters: [Chapter] = []
    @Published var nextChapterURL: URL?
    @Published var currentURL: URL?
    @Published var currentPage = 0
    @Published var isLoading = false
    @Published var showChapters = false

    private let defaults = UserDefaults.standard

    func load(urlString: String) async {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
        await load(url: url)
    }

    func load(url: URL) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let html = String(data: data, encoding: .utf8),
                  let http = response as? HTTPURLResponse,
                  (200...399).contains(http.statusCode) else {
                return
            }

            let base = url.deletingLastPathComponent()
            let result = HTMLChapterParser.parse(html: html, baseURL: base)

            title = result.title
            pages = result.pages
            chapters = result.chapters
            nextChapterURL = result.nextChapterURL
            currentURL = url
            currentPage = defaults.integer(forKey: progressKey(url))
            urlText = url.absoluteString
            saveChapter(url: url, title: result.title)

        } catch {
            print("Load error:", error)
        }
    }

    func saveProgress(page: Int) {
        guard let url = currentURL else { return }
        currentPage = page
        defaults.set(page, forKey: progressKey(url))
    }

    func goToNextPage() {
        currentPage = min(currentPage + 1, max(0, pages.count - 1))
    }

    func goToPreviousPage() {
        currentPage = max(0, currentPage - 1)
    }

    private func progressKey(_ url: URL) -> String {
        "progress:" + url.absoluteString
    }

    private func saveChapter(url: URL, title: String) {
        var saved = defaults.array(forKey: "savedChapters") as? [[String: String]] ?? []
        saved.removeAll { $0["url"] == url.absoluteString }
        saved.insert(["url": url.absoluteString, "title": title], at: 0)
        defaults.set(Array(saved.prefix(50)), forKey: "savedChapters")
    }
}

enum HTMLChapterParser {
    struct Result {
        let title: String
        let pages: [URL]
        let chapters: [Chapter]
        let nextChapterURL: URL?
    }

    static func parse(html: String, baseURL: URL) -> Result {
        let title = firstMatch(
            pattern: #"<h1[^>]*>\s*(.*?)\s*</h1>"#,
            in: html
        )?
        .strippingHTML()
        ?? "Capítulo"

        var pages: [URL] = []
        let imagePattern = #"<img[^>]+(?:src|data-src|data-lazy-src)=["']([^"']+)["'][^>]*>"#
        if let regex = try? NSRegularExpression(pattern: imagePattern, options: [.caseInsensitive]) {
            let ns = html as NSString
            let matches = regex.matches(in: html, range: NSRange(location: 0, length: ns.length))
            for match in matches {
                guard match.numberOfRanges > 1 else { continue }
                let raw = ns.substring(with: match.range(at: 1))
                if let u = URL(string: raw, relativeTo: baseURL)?.absoluteURL,
                   ["jpg","jpeg","png","webp"].contains(u.pathExtension.lowercased()),
                   !pages.contains(u) {
                    pages.append(u)
                }
            }
        }

        // Keep only likely chapter-reader images. This avoids logos/icons when possible.
        pages = pages.filter {
            let p = $0.absoluteString.lowercased()
            return p.contains("uploads") || p.contains("chapter") || p.contains("cap-") || p.contains("page")
        }

        var chapters: [Chapter] = []
        let linkPattern = #"<a[^>]+href=["']([^"']+)["'][^>]*>(.*?)</a>"#
        if let regex = try? NSRegularExpression(pattern: linkPattern, options: [.caseInsensitive]) {
            let ns = html as NSString
            for match in regex.matches(in: html, range: NSRange(location: 0, length: ns.length)) {
                guard match.numberOfRanges > 2 else { continue }
                let href = ns.substring(with: match.range(at: 1))
                let text = ns.substring(with: match.range(at: 2)).strippingHTML()
                guard text.localizedCaseInsensitiveContains("capítulo"),
                      let u = URL(string: href, relativeTo: baseURL)?.absoluteURL else { continue }
                if !chapters.contains(where: { $0.url == u }) {
                    chapters.append(Chapter(name: text, url: u))
                }
            }
        }

        let nextText = firstMatch(
            pattern: #"(?is)<a[^>]+href=["']([^"']+)["'][^>]*>\s*Próximo Capítulo\s*</a>"#,
            in: html
        )
        let nextURL = nextText.flatMap { URL(string: $0, relativeTo: baseURL)?.absoluteURL }

        return Result(
            title: title,
            pages: pages,
            chapters: chapters,
            nextChapterURL: nextURL
        )
    }

    private static func firstMatch(pattern: String, in html: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(location: 0, length: (html as NSString).length)
        guard let match = regex.firstMatch(in: html, range: range),
              match.numberOfRanges > 1 else { return nil }
        return (html as NSString).substring(with: match.range(at: 1))
    }
}

private extension String {
    func strippingHTML() -> String {
        replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
