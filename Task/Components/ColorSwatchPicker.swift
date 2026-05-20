import SwiftUI

struct ColorSwatchPicker: View {
    @Binding var selection: ColorKey

    var body: some View {
        HStack(spacing: 10) {
            ForEach(ColorKey.allCases) { key in
                Button {
                    selection = key
                } label: {
                    ZStack {
                        Circle()
                            .fill(key.background)
                            .frame(width: 32, height: 32)
                        Circle()
                            .fill(key.dot)
                            .frame(width: 14, height: 14)
                        if selection == key {
                            Circle()
                                .stroke(key.foreground, lineWidth: 2)
                                .frame(width: 32, height: 32)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(key.rawValue)
            }
        }
    }
}
