import SwiftUI

struct ExportSheet: View {
    let memo: Memo
    @Environment(\.dismiss) private var dismiss

    @State private var selectedFormat: ExportFormat = .wav
    @State private var isExporting = false
    @State private var exportError: String?
    @State private var shareItems: [Any]?

    enum ExportFormat: CaseIterable {
        case wav
        case midi  // stubbed until pitch-timestamp capture is wired up

        var title: String {
            switch self {
            case .wav:  return "Audio (WAV)"
            case .midi: return "MIDI"
            }
        }
        var subtitle: String {
            switch self {
            case .wav:  return ExportService.filename(for: .placeholder, ext: "wav")
            case .midi: return "Melody capture coming in a future update"
            }
        }
        var icon: String {
            switch self {
            case .wav:  return "waveform"
            case .midi: return "pianokeys"
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                Text("Choose format")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.top, 20)
                    .padding(.bottom, 12)

                ForEach(ExportFormat.allCases, id: \.self) { format in
                    let available = format == .wav  // MIDI not yet available
                    Button {
                        if available { selectedFormat = format }
                    } label: {
                        HStack(spacing: 14) {
                            // Selection indicator
                            ZStack {
                                Circle()
                                    .stroke(available ? Color.primary : Color.secondary.opacity(0.3), lineWidth: 1.5)
                                    .frame(width: 20, height: 20)
                                if selectedFormat == format && available {
                                    Circle()
                                        .fill(Color.primary)
                                        .frame(width: 12, height: 12)
                                }
                            }

                            Image(systemName: format.icon)
                                .frame(width: 20)
                                .foregroundStyle(available ? .primary : .tertiary)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(format.title)
                                    .font(.subheadline)
                                    .foregroundStyle(available ? .primary : .tertiary)
                                Text(format == .wav
                                     ? ExportService.filename(for: memo, ext: "wav")
                                     : format.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            if !available {
                                Text("Soon")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.secondary.opacity(0.15))
                                    .clipShape(Capsule())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Divider().padding(.leading)
                }

                if let errorMessage = exportError {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                        .padding(.top, 8)
                }

                Spacer()

                // Share button
                Button {
                    Task { await export() }
                } label: {
                    HStack {
                        if isExporting {
                            ProgressView()
                                .tint(.black)
                                .padding(.trailing, 4)
                        }
                        Text(isExporting ? "Preparing…" : "Share →")
                            .fontWeight(.medium)
                            .foregroundStyle(.black)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .disabled(isExporting)
                .padding()
            }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .sheet(isPresented: Binding(
            get: { shareItems != nil },
            set: { if !$0 { shareItems = nil } }
        )) {
            if let items = shareItems {
                ActivitySheet(items: items) {
                    // Clean up temp file after sharing
                    if let url = items.first as? URL {
                        try? FileManager.default.removeItem(at: url)
                    }
                    shareItems = nil
                    dismiss()
                }
                .ignoresSafeArea()
            }
        }
    }

    private func export() async {
        exportError = nil
        isExporting = true
        defer { isExporting = false }

        do {
            let url = try await Task.detached(priority: .userInitiated) {
                try ExportService.exportWAV(memo: memo)
            }.value
            shareItems = [url]
        } catch {
            exportError = error.localizedDescription
        }
    }
}

// MARK: - UIActivityViewController bridge

struct ActivitySheet: UIViewControllerRepresentable {
    let items: [Any]
    var onComplete: (() -> Void)?

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        vc.completionWithItemsHandler = { _, _, _, _ in onComplete?() }
        return vc
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Placeholder for filename preview

private extension Memo {
    static let placeholder = Memo(
        fileURL: URL(fileURLWithPath: "/tmp/x.caf"),
        duration: 30,
        title: "",
        key: "Dm",
        bpm: 92,
        contentType: .guitar
    )
}
