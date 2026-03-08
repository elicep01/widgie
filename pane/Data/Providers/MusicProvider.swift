import AppKit
import Foundation

struct MusicProvider {

    // MARK: - Fetch Now Playing (Universal)

    func fetch() async -> MusicSnapshot {
        // Try MediaRemote first — works with YouTube Music, Spotify, Apple Music, VLC, etc.
        if MediaRemoteBridge.isAvailable {
            async let info = MediaRemoteBridge.fetchNowPlaying()
            async let bundleID = MediaRemoteBridge.fetchNowPlayingBundleID()

            let nowPlaying = await info
            let clientBundleID = await bundleID

            if let title = nowPlaying.title, !title.isEmpty {
                let progress: Double?
                if let elapsed = nowPlaying.elapsedTime, let duration = nowPlaying.duration, duration > 0 {
                    progress = max(0, min(1, elapsed / duration))
                } else {
                    progress = nil
                }

                let source = sourceName(for: clientBundleID)

                return MusicSnapshot(
                    title: title,
                    artist: nowPlaying.artist,
                    album: nowPlaying.album,
                    progress: progress,
                    isPlaying: nowPlaying.isPlaying,
                    source: source,
                    updatedAt: Date()
                )
            }
        }

        // Fallback: AppleScript for Spotify / Apple Music
        if isSpotifyRunning {
            return fetchSpotifyViaAppleScript()
        }
        if isMusicRunning {
            return fetchAppleMusicViaAppleScript()
        }

        return MusicSnapshot(
            title: nil,
            artist: nil,
            album: nil,
            progress: nil,
            isPlaying: false,
            source: nil,
            updatedAt: Date()
        )
    }

    // MARK: - Playback Controls (Universal)

    func playPause() {
        if MediaRemoteBridge.isAvailable {
            MediaRemoteBridge.sendCommand(.togglePlayPause)
        } else if isSpotifyRunning {
            runAppleScript("tell application \"Spotify\" to playpause")
        } else if isMusicRunning {
            runAppleScript("tell application \"Music\" to playpause")
        }
    }

    func nextTrack() {
        if MediaRemoteBridge.isAvailable {
            MediaRemoteBridge.sendCommand(.nextTrack)
        } else if isSpotifyRunning {
            runAppleScript("tell application \"Spotify\" to next track")
        } else if isMusicRunning {
            runAppleScript("tell application \"Music\" to next track")
        }
    }

    func previousTrack() {
        if MediaRemoteBridge.isAvailable {
            MediaRemoteBridge.sendCommand(.previousTrack)
        } else if isSpotifyRunning {
            runAppleScript("tell application \"Spotify\" to previous track")
        } else if isMusicRunning {
            runAppleScript("tell application \"Music\" to back track")
        }
    }

    // MARK: - Source Name

    private func sourceName(for bundleID: String?) -> String? {
        guard let id = bundleID else { return nil }
        if let known = MediaRemoteBridge.sourceNames[id] { return known }
        // Fall back to the app's display name.
        return NSRunningApplication.runningApplications(withBundleIdentifier: id).first?.localizedName
    }

    // MARK: - AppleScript Fallbacks

    private func fetchSpotifyViaAppleScript() -> MusicSnapshot {
        let title = runAppleScript("""
        tell application "Spotify"
            if player state is playing or player state is paused then
                return name of current track
            end if
            return ""
        end tell
        """)

        let artist = runAppleScript("""
        tell application "Spotify"
            if player state is playing or player state is paused then
                return artist of current track
            end if
            return ""
        end tell
        """)

        let album = runAppleScript("""
        tell application "Spotify"
            if player state is playing or player state is paused then
                return album of current track
            end if
            return ""
        end tell
        """)

        let state = runAppleScript("""
        tell application "Spotify"
            return player state as string
        end tell
        """)

        let position = Double(runAppleScript("""
        tell application "Spotify"
            return player position as string
        end tell
        """) ?? "")

        let trackDuration = Double(runAppleScript("""
        tell application "Spotify"
            if player state is playing or player state is paused then
                return (duration of current track) / 1000 as string
            end if
            return "0"
        end tell
        """) ?? "")

        let progress: Double?
        if let position, let trackDuration, trackDuration > 0 {
            progress = max(0, min(1, position / trackDuration))
        } else {
            progress = nil
        }

        return MusicSnapshot(
            title: title?.isEmpty == true ? nil : title,
            artist: artist?.isEmpty == true ? nil : artist,
            album: album?.isEmpty == true ? nil : album,
            progress: progress,
            isPlaying: (state ?? "").lowercased().contains("playing"),
            source: "Spotify",
            updatedAt: Date()
        )
    }

    private func fetchAppleMusicViaAppleScript() -> MusicSnapshot {
        let title = runAppleScript("""
        tell application "Music"
            if player state is playing or player state is paused then
                return name of current track
            end if
            return ""
        end tell
        """)

        let artist = runAppleScript("""
        tell application "Music"
            if player state is playing or player state is paused then
                return artist of current track
            end if
            return ""
        end tell
        """)

        let album = runAppleScript("""
        tell application "Music"
            if player state is playing or player state is paused then
                return album of current track
            end if
            return ""
        end tell
        """)

        let state = runAppleScript("""
        tell application "Music"
            return (player state as string)
        end tell
        """)

        let position = Double(runAppleScript("""
        tell application "Music"
            return player position as string
        end tell
        """) ?? "")

        let trackDuration = Double(runAppleScript("""
        tell application "Music"
            if player state is playing or player state is paused then
                return duration of current track as string
            end if
            return "0"
        end tell
        """) ?? "")

        let progress: Double?
        if let position, let trackDuration, trackDuration > 0 {
            progress = max(0, min(1, position / trackDuration))
        } else {
            progress = nil
        }

        return MusicSnapshot(
            title: title?.isEmpty == true ? nil : title,
            artist: artist?.isEmpty == true ? nil : artist,
            album: album?.isEmpty == true ? nil : album,
            progress: progress,
            isPlaying: (state ?? "").lowercased().contains("playing"),
            source: "Apple Music",
            updatedAt: Date()
        )
    }

    // MARK: - Helpers

    private var isSpotifyRunning: Bool {
        !NSRunningApplication
            .runningApplications(withBundleIdentifier: "com.spotify.client")
            .isEmpty
    }

    private var isMusicRunning: Bool {
        let musicRunning = !NSRunningApplication
            .runningApplications(withBundleIdentifier: "com.apple.Music")
            .isEmpty
        let iTunesRunning = !NSRunningApplication
            .runningApplications(withBundleIdentifier: "com.apple.iTunes")
            .isEmpty
        return musicRunning || iTunesRunning
    }

    @discardableResult
    private func runAppleScript(_ script: String) -> String? {
        guard let appleScript = NSAppleScript(source: script) else {
            return nil
        }
        var error: NSDictionary?
        let output = appleScript.executeAndReturnError(&error)
        if error != nil {
            return nil
        }
        return output.stringValue
    }
}
