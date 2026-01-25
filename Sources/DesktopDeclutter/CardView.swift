import SwiftUI

struct CardView: View {
    let file: DesktopFile
    let onKeep: () -> Void
    let onBin: () -> Void
    let onPreview: (() -> Void)?
    
    @State private var offset: CGSize = .zero
    @State private var color: Color = .clear
    
    init(file: DesktopFile, onKeep: @escaping () -> Void, onBin: @escaping () -> Void, onPreview: (() -> Void)? = nil) {
        self.file = file
        self.onKeep = onKeep
        self.onBin = onBin
        self.onPreview = onPreview
    }
    
    @State private var isPreviewHovered = false
    
    private var fileDateString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        if let date = try? FileManager.default.attributesOfItem(atPath: file.url.path)[.creationDate] as? Date {
            return formatter.localizedString(for: date, relativeTo: Date())
        }
        return "Recently"
    }
    
    var body: some View {
        ZStack {
            // Card background
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 8)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            
            VStack(spacing: 0) {
                // Preview area with padding
                ZStack {
                    Color(nsColor: .controlBackgroundColor)
                    
                    Group {
                        if let thumbnail = file.thumbnail {
                            Image(nsImage: thumbnail)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } else {
                            Image(nsImage: file.icon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 120, height: 120)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(20)
                }
                .frame(height: 320)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 20,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 20
                    )
                )
                
                // File info footer
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(file.name)
                            .font(.system(size: 15, weight: .semibold))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 6) {
                            Text(ByteCountFormatter.string(fromByteCount: file.fileSize, countStyle: .file))
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(.secondary)
                            
                            Text("•")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary.opacity(0.6))
                            
                            Text(fileDateString)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Preview button
                    if onPreview != nil {
                        Button(action: {
                            onPreview?()
                        }) {
                            Image(systemName: "eye.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(isPreviewHovered ? .white : .blue)
                                .frame(width: 36, height: 36)
                                .background {
                                    Circle()
                                        .fill(isPreviewHovered ? Color.blue : Color.blue.opacity(0.12))
                                }
                        }
                        .buttonStyle(.plain)
                        .help("Preview file (Space)")
                        .onHover { hovering in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isPreviewHovered = hovering
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background {
                    Color(nsColor: .controlBackgroundColor)
                        .opacity(0.6)
                }
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: 20,
                        bottomTrailingRadius: 20,
                        topTrailingRadius: 0
                    )
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            
            // Swipe overlays with improved visuals
            HStack {
                // KEEP (Left side of card, visible when swiping right)
                if offset.width > 0 {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.green.opacity(0.25),
                                        Color.green.opacity(0.15)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 64, weight: .semibold))
                                .foregroundColor(.green)
                                .opacity(min(Double(offset.width / 120), 1.0))
                            
                            Text("Keep")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.green)
                                .opacity(min(Double(offset.width / 120), 1.0))
                        }
                        .rotationEffect(.degrees(-min(Double(offset.width / 8), 12)))
                    }
                }
                
                // BIN (Right side of card, visible when swiping left)
                if offset.width < 0 {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.red.opacity(0.25),
                                        Color.red.opacity(0.15)
                                    ],
                                    startPoint: .trailing,
                                    endPoint: .leading
                                )
                            )
                        
                        VStack(spacing: 8) {
                            Image(systemName: "trash.circle.fill")
                                .font(.system(size: 64, weight: .semibold))
                                .foregroundColor(.red)
                                .opacity(min(Double(-offset.width / 120), 1.0))
                            
                            Text("Bin")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.red)
                                .opacity(min(Double(-offset.width / 120), 1.0))
                        }
                        .rotationEffect(.degrees(min(Double(-offset.width / 8), 12)))
                    }
                }
            }
            .allowsHitTesting(false)
        }
        .frame(width: 300, height: 400)
        .offset(x: offset.width, y: 0)
        .rotationEffect(.degrees(Double(offset.width / 25)))
        .scaleEffect(1.0 - abs(offset.width) / 1200)
        .gesture(
            DragGesture(minimumDistance: 10)
                .onChanged { gesture in
                    withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.7)) {
                        offset = gesture.translation
                    }
                }
                .onEnded { gesture in
                    let threshold: CGFloat = 120
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        if offset.width > threshold {
                            onKeep()
                        } else if offset.width < -threshold {
                            onBin()
                        } else {
                            offset = .zero
                        }
                    }
                }
        )
    }
}
