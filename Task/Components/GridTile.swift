import SwiftUI

struct GridTile: View {
    let title: String
    var subtitle: String? = nil
    var systemImage: String? = nil
    var iconText: String? = nil
    var imageAsset: String? = nil
    var dotColor: Color? = nil
    var tintColor: Color = .accentColor
    var isSelected: Bool = false

    var body: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .topTrailing) {
                if let imageAsset {
                    Image(imageAsset)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                } else {
                    Group {
                        if let iconText {
                            Text(iconText)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(tintColor)
                                .minimumScaleFactor(0.6)
                                .lineLimit(1)
                        } else if let systemImage {
                            Image(systemName: systemImage)
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundColor(tintColor)
                        } else if let dotColor {
                            Circle()
                                .fill(dotColor)
                                .frame(width: 22, height: 22)
                        }
                    }
                    .frame(width: 60, height: 60)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(tintColor.opacity(0.16))
                    )
                }

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, tintColor)
                        .background(Circle().fill(Color(.systemBackground)))
                        .offset(x: 6, y: -6)
                }
            }

            VStack(spacing: 2) {
                Text(title)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .aspectRatio(0.92, contentMode: .fit)
        .taskCardBackground(cornerRadius: 22)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(isSelected ? tintColor.opacity(0.5) : Color.clear, lineWidth: 1.5)
        )
        .scaleEffect(isSelected ? 1.02 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.78), value: isSelected)
    }
}

