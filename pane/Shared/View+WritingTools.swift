import SwiftUI

extension View {
    @ViewBuilder
    func withoutWritingTools() -> some View {
        if #available(macOS 15.0, *) {
            self.writingToolsBehavior(.disabled)
        } else {
            self
        }
    }
}
