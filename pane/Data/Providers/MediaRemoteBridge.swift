import Foundation

/// Bridge to the private MediaRemote framework for universal now-playing info.
/// Works with any app that reports to macOS Now Playing: Spotify, Apple Music,
/// YouTube Music (in browsers), VLC, IINA, Plex, etc.
enum MediaRemoteBridge {

    // MARK: - Types

    struct NowPlayingInfo {
        var title: String?
        var artist: String?
        var album: String?
        var duration: TimeInterval?
        var elapsedTime: TimeInterval?
        var isPlaying: Bool
        var artworkData: Data?
    }

    enum Command: UInt32 {
        case play = 0
        case pause = 1
        case togglePlayPause = 2
        case stop = 3
        case nextTrack = 4
        case previousTrack = 5
    }

    // MARK: - Now Playing Info

    static func fetchNowPlaying() async -> NowPlayingInfo {
        guard let bundle = frameworkBundle else {
            return NowPlayingInfo(isPlaying: false)
        }

        async let infoResult: [String: Any] = withCheckedContinuation { continuation in
            guard let ptr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingInfo" as CFString) else {
                continuation.resume(returning: [:])
                return
            }
            typealias Fn = @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void
            let fn = unsafeBitCast(ptr, to: Fn.self)
            fn(.global(qos: .userInitiated)) { dict in
                continuation.resume(returning: dict)
            }
        }

        async let playingResult: Bool = withCheckedContinuation { continuation in
            guard let ptr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingApplicationIsPlaying" as CFString) else {
                continuation.resume(returning: false)
                return
            }
            typealias Fn = @convention(c) (DispatchQueue, @escaping (Bool) -> Void) -> Void
            let fn = unsafeBitCast(ptr, to: Fn.self)
            fn(.global(qos: .userInitiated)) { isPlaying in
                continuation.resume(returning: isPlaying)
            }
        }

        let info = await infoResult
        let isPlaying = await playingResult

        return NowPlayingInfo(
            title: info["kMRMediaRemoteNowPlayingInfoTitle"] as? String,
            artist: info["kMRMediaRemoteNowPlayingInfoArtist"] as? String,
            album: info["kMRMediaRemoteNowPlayingInfoAlbum"] as? String,
            duration: info["kMRMediaRemoteNowPlayingInfoDuration"] as? TimeInterval,
            elapsedTime: info["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? TimeInterval,
            isPlaying: isPlaying,
            artworkData: info["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data
        )
    }

    // MARK: - Now Playing Source

    static func fetchNowPlayingBundleID() async -> String? {
        guard let bundle = frameworkBundle,
              let ptr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingClient" as CFString) else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            typealias Fn = @convention(c) (DispatchQueue, @escaping (AnyObject?) -> Void) -> Void
            let fn = unsafeBitCast(ptr, to: Fn.self)
            fn(.global(qos: .userInitiated)) { client in
                guard let client = client else {
                    continuation.resume(returning: nil)
                    return
                }
                let obj = client as AnyObject
                if obj.responds(to: NSSelectorFromString("bundleIdentifier")) {
                    continuation.resume(returning: obj.value(forKey: "bundleIdentifier") as? String)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    // MARK: - Playback Commands

    static func sendCommand(_ command: Command) {
        guard let bundle = frameworkBundle,
              let ptr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteSendCommand" as CFString) else {
            return
        }
        typealias Fn = @convention(c) (UInt32, UnsafeMutableRawPointer?) -> Bool
        let fn = unsafeBitCast(ptr, to: Fn.self)
        _ = fn(command.rawValue, nil)
    }

    // MARK: - Seek

    static func setElapsedTime(_ time: TimeInterval) {
        guard let bundle = frameworkBundle,
              let ptr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteSetElapsedTime" as CFString) else {
            return
        }
        typealias Fn = @convention(c) (Double) -> Void
        let fn = unsafeBitCast(ptr, to: Fn.self)
        fn(time)
    }

    // MARK: - Availability

    static var isAvailable: Bool { frameworkBundle != nil }

    // MARK: - Private

    private static let frameworkBundle: CFBundle? = {
        let path = "/System/Library/PrivateFrameworks/MediaRemote.framework"
        guard let url = CFURLCreateWithFileSystemPath(
            kCFAllocatorDefault,
            path as CFString,
            .cfurlposixPathStyle,
            true
        ) else { return nil }
        return CFBundleCreate(kCFAllocatorDefault, url)
    }()

    // MARK: - Source Name Mapping

    static let sourceNames: [String: String] = [
        "com.spotify.client": "Spotify",
        "com.apple.Music": "Apple Music",
        "com.apple.iTunes": "iTunes",
        "com.google.Chrome": "Chrome",
        "com.google.Chrome.canary": "Chrome",
        "com.apple.Safari": "Safari",
        "org.mozilla.firefox": "Firefox",
        "com.microsoft.edgemac": "Edge",
        "com.brave.Browser": "Brave",
        "com.operasoftware.Opera": "Opera",
        "company.thebrowser.Browser": "Arc",
        "tv.plex.desktop": "Plex",
        "com.colliderli.iina": "IINA",
        "org.videolan.vlc": "VLC",
        "com.tidal.desktop": "Tidal",
        "com.amazon.music": "Amazon Music",
    ]
}
