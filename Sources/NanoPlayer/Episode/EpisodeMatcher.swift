import Foundation

/// Pure, side-effect-free episode/series recognition for the "binge next episode"
/// feature. No mpv calls, no @Published mutation — just string parsing and a single
/// directory listing in `episodes(for:)`. Safe to call from any queue.
enum EpisodeMatcher {

    struct Parsed {
        let seriesKey: String
        let season: Int?
        let episode: Int
    }

    // Patterns are tried in priority order; the first match wins. The capture
    // groups carry season/episode, and `range(at: 0)` of the match marks where the
    // "episode token" begins so everything before it becomes the series key.
    private struct Pattern {
        let regex: NSRegularExpression
        let seasonGroup: Int   // 0 = no season group
        let episodeGroup: Int
    }

    private static func re(_ p: String) -> NSRegularExpression {
        // Patterns are authored constants; force-try is acceptable here.
        return try! NSRegularExpression(pattern: p, options: [.caseInsensitive])
    }

    // Ordered by priority. Comments map to the spec's P1/P1b/P2/P2b/P3.
    private static let patterns: [Pattern] = [
        // P1  SxxExx  ->  season + episode
        Pattern(regex: re(#"[Ss](\d{1,2})[\s._-]*[Ee](\d{1,3})"#), seasonGroup: 1, episodeGroup: 2),
        // P1b 1x04    ->  season + episode
        Pattern(regex: re(#"(?<![0-9])(\d{1,2})x(\d{1,3})(?![0-9])"#), seasonGroup: 1, episodeGroup: 2),
        // P2  E04/EP04 -> episode (season nil)
        Pattern(regex: re(#"(?<![A-Za-z])[Ee][Pp]?(\d{1,3})(?![0-9])"#), seasonGroup: 0, episodeGroup: 1),
        // P2b 中文 第04集 -> episode (season nil)
        Pattern(regex: re(#"第\s*(\d{1,3})\s*[集话話章]"#), seasonGroup: 0, episodeGroup: 1),
        // P3  fallback: last 1-3 digit group -> episode (season nil)
        Pattern(regex: re(#"(\d{1,3})(?!.*\d)"#), seasonGroup: 0, episodeGroup: 1),
    ]

    /// Parse a media file URL into series/season/episode, or nil if no number found.
    static func parse(_ url: URL) -> Parsed? {
        let name = url.deletingPathExtension().lastPathComponent
        let ns = name as NSString
        let full = NSRange(location: 0, length: ns.length)

        for p in patterns {
            guard let m = p.regex.firstMatch(in: name, options: [], range: full) else { continue }

            // Episode number (required).
            let epRange = m.range(at: p.episodeGroup)
            guard epRange.location != NSNotFound,
                  let episode = Int(ns.substring(with: epRange)) else { continue }

            // Season number (optional).
            var season: Int? = nil
            if p.seasonGroup > 0 {
                let sRange = m.range(at: p.seasonGroup)
                if sRange.location != NSNotFound {
                    season = Int(ns.substring(with: sRange))
                }
            }

            // Everything before the matched token is the series key.
            let tokenStart = m.range(at: 0).location
            let rawKey = ns.substring(to: tokenStart)
            let seriesKey = normalizeKey(rawKey)
            return Parsed(seriesKey: seriesKey, season: season, episode: episode)
        }
        return nil
    }

    /// Normalize a raw series prefix into a stable comparison key:
    /// strip [..] and (..) groups, turn separators into spaces, collapse spaces,
    /// trim, lowercase.
    static func normalizeKey(_ raw: String) -> String {
        var s = raw
        s = s.replacingOccurrences(of: #"\[[^\]]*\]"#, with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\([^)]*\)"#, with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: #"[._\-]+"#, with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return s.lowercased()
    }

    /// Given an "anchor" file the user opened, find all episodes of the same series
    /// in the same directory. If the anchor itself can't be parsed, just return it.
    static func episodes(for anchor: URL, allowedExtensions: Set<String>) -> [URL] {
        guard let anchorParsed = parse(anchor) else { return [anchor] }

        let allowedLower = Set(allowedExtensions.map { $0.lowercased() })
        let dir = anchor.deletingLastPathComponent()

        let contents: [URL]
        do {
            contents = try FileManager.default.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles])
        } catch {
            return [anchor]
        }

        struct Candidate {
            let url: URL
            let season: Int
            let episode: Int
            let name: String
        }

        var candidates: [Candidate] = []
        var seenPaths = Set<String>()

        for url in contents {
            let ext = url.pathExtension.lowercased()
            guard allowedLower.contains(ext) else { continue }
            guard let p = parse(url) else { continue }
            guard p.seriesKey == anchorParsed.seriesKey else { continue }
            let key = url.standardizedFileURL.path
            guard seenPaths.insert(key).inserted else { continue }
            candidates.append(Candidate(url: url,
                                        season: p.season ?? 0,
                                        episode: p.episode,
                                        name: url.lastPathComponent))
        }

        // Numeric sort: (season, episode, then natural filename as a tiebreaker).
        candidates.sort { a, b in
            if a.season != b.season { return a.season < b.season }
            if a.episode != b.episode { return a.episode < b.episode }
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }

        var result = candidates.map { $0.url }

        // Guarantee the anchor is present (e.g. if it slipped through filtering).
        let anchorPath = anchor.standardizedFileURL.path
        if !result.contains(where: { $0.standardizedFileURL.path == anchorPath }) {
            result.append(anchor)
        }
        return result
    }
}
