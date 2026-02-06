import SwiftUI

struct HistoryView: View {
    @ObservedObject var viewModel: DeclutterViewModel
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Session History")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    isPresented = false
                }
                .buttonStyle(.plain)
                .foregroundColor(.blue)
            }
            .padding()
            .background(VisualEffectView(material: .headerView, blendingMode: .behindWindow))
            
            Divider()
            
            if viewModel.actionHistory.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No actions taken yet")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.actionHistory.reversed()) { action in
                            HStack(spacing: 12) {
                                // Icon
                                Image(systemName: icon(for: action.type))
                                    .foregroundColor(color(for: action.type))
                                    .frame(width: 24)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(action.file.name)
                                        .font(.system(size: 13, weight: .medium))
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    
                                    Text(description(for: action))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                // Undo specific action?
                                // Only allow undoing the LAST action safely?
                                // Or any action? To undo any action, we need robust logic (which we added: undoDecision).
                                // But `undoDecision` removes from history.
                                // If we undo from middle, history order changes.
                                // For simplicity, let's allow undoing specific file decision.
                                
                                Button(action: {
                                    withAnimation {
                                        viewModel.undoDecision(for: action.file)
                                    }
                                }) {
                                    Image(systemName: "arrow.uturn.backward.circle")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                                .help("Undo this action")
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(HoverBackgroundView())
                            
                            Divider().padding(.leading, 48)
                        }
                    }
                    .padding(.vertical)
                }
            }
            
            // Footer
            if !viewModel.actionHistory.isEmpty {
                Divider()
                HStack {
                    Button(action: {
                        withAnimation {
                            viewModel.resetSession()
                        }
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Reset Session")
                        }
                        .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    Text("\(viewModel.actionHistory.count) actions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(VisualEffectView(material: .headerView, blendingMode: .behindWindow))
            }
        }
        .frame(width: 320, height: 450)
        .background(VisualEffectView(material: .popover, blendingMode: .behindWindow))
    }
    
    // Helpers
    func icon(for type: DeclutterViewModel.Action.ActionType) -> String {
        switch type {
        case .keep: return "checkmark.circle.fill"
        case .bin: return "trash.circle.fill"
        case .stack: return "square.stack.3d.up.fill"
        case .cloud: return "icloud.and.arrow.up.fill"
        }
    }
    
    func color(for type: DeclutterViewModel.Action.ActionType) -> Color {
        switch type {
        case .keep: return .green
        case .bin: return .red
        case .stack: return .blue
        case .cloud: return .blue
        }
    }
    
    func description(for action: DeclutterViewModel.Action) -> String {
        switch action.type {
        case .keep: return "Kept"
        case .bin: return "Moved to Bin" // or Trash
        case .stack: return "Stacked"
        case .cloud: return "Moved to Cloud"
        }
    }
}

// Simple hover background
struct HoverBackgroundView: View {
    @State private var isHovered = false
    var body: some View {
        Color(nsColor: isHovered ? .quaternaryLabelColor : .clear)
            .onHover { isHovered = $0 }
    }
}
