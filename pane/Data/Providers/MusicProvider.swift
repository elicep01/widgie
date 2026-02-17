import Foundation

struct MusicProvider {
    func fetch() -> MusicSnapshot {
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
            updatedAt: Date()
        )
    }

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
