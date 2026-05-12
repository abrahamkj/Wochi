import SwiftUI

/// A small circular avatar that displays the first letter of a member's display name
/// on top of their assigned avatar colour.
struct MemberAvatarView: View {
    let member: HouseholdMember
    var size: CGFloat = 36

    private var initial: String {
        String(member.displayName.prefix(1)).uppercased()
    }

    private var backgroundColor: Color {
        Color(hex: member.avatarColor)
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundColor)
                .frame(width: size, height: size)

            Text(initial)
                .font(.system(size: size * 0.45, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
        .accessibilityLabel(member.displayName)
    }
}

// MARK: - Preview

#Preview {
    let colors = ["#4ade80", "#60a5fa", "#f87171", "#fbbf24", "#a78bfa"]
    return HStack(spacing: 12) {
        ForEach(Array(zip(colors.indices, colors)), id: \.0) { index, color in
            let member = HouseholdMember(
                appleUserID: "user-\(index)",
                displayName: "Nutzer \(index + 1)"
            )
            // Override the random color with a predictable one for preview.
            let _ = { member.avatarColor = color }()
            MemberAvatarView(member: member, size: 44)
        }
    }
    .padding()
}
