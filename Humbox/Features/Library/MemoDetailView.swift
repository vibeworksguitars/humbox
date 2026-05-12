import SwiftUI

struct MemoDetailView: View {
    let memo: Memo
    @EnvironmentObject private var audio: AudioService
    @State private var isPlaying = false
    @State private var playProgress: CGFloat = 0
    @State private var showExportSheet = false
    @State private var showDevelopSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // Title & date
                VStack(alignment: .leading, spacing: 4) {
                    Text(memo.title)
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text(memo.createdAt.formatted(.dateTime.month().day().hour().minute()) + " · auto-titled")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                // Waveform player
                WaveformPlayer(isPlaying: $isPlaying, progress: $playProgress) {
                    isPlaying.toggle()
                    if isPlaying { audio.play(memo: memo) }
                }

                // Badges
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        if let key = memo.key {
                            MetaBadge(text: key)
                        }
                        if let bpm = memo.bpm {
                            MetaBadge(text: "\(bpm) BPM")
                        }
                        MetaBadge(text: memo.contentType.label)
                        MetaBadge(text: memo.formattedDuration)
                    }
                }

                // Transcript / lyrics
                LyricsSection(transcript: memo.transcript)

                // Development notes
                if memo.isDeveloped {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                            Text("Developed")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            if let date = memo.developedAt {
                                Text("· \(date.formatted(.dateTime.month().day()))")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        if let notes = memo.developmentNotes {
                            Text(notes)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(Color.green)
                            .frame(width: 2)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // Project
                HStack {
                    Text("Project:")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                    Button("+ Add to a song") {}
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 24)

                // Actions
                HStack(spacing: 12) {
                    Button {
                        showDevelopSheet = true
                    } label: {
                        Label(memo.isDeveloped ? "Developed" : "Develop", systemImage: memo.isDeveloped ? "checkmark.circle.fill" : "checkmark.circle")
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(memo.isDeveloped ? .secondary : .black)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(memo.isDeveloped ? Color(.secondarySystemBackground) : .white)
                    .disabled(memo.isDeveloped)

                    Button {
                        showExportSheet = true
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                }
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showExportSheet) {
            ExportSheet(memo: memo)
        }
        .sheet(isPresented: $showDevelopSheet) {
            DevelopSheet(memo: memo) { notes in
                var updated = memo
                updated.isDeveloped = true
                updated.developedAt = Date()
                updated.developmentNotes = notes
                audio.update(memo: updated)
            }
        }
    }
}

// MARK: - Waveform Player

private struct WaveformPlayer: View {
    @Binding var isPlaying: Bool
    @Binding var progress: CGFloat
    let onToggle: () -> Void

    private let bars: [CGFloat] = [0.3, 0.55, 0.8, 0.7, 0.6, 0.45, 0.75, 0.35, 0.55, 0.4]

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
                    .foregroundStyle(.primary)
            }

            GeometryReader { geo in
                HStack(alignment: .center, spacing: 2) {
                    ForEach(Array(bars.enumerated()), id: \.offset) { i, h in
                        let played = CGFloat(i) / CGFloat(bars.count) < progress
                        RoundedRectangle(cornerRadius: 1)
                            .fill(played ? Color.primary : Color.secondary.opacity(0.3))
                            .frame(width: max(1, geo.size.width / CGFloat(bars.count) - 2),
                                   height: geo.size.height * h)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 40)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Lyrics Section

private struct LyricsSection: View {
    let transcript: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(transcript != nil ? "Lyrics" : "Lyrics (none detected)")
                .font(.subheadline)
                .fontWeight(.medium)
            if let transcript {
                Text(transcript)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Button("Add a lyric note?") {}
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.blue)
                .frame(width: 2)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Meta Badge

struct MetaBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(.secondarySystemBackground))
            .foregroundStyle(.secondary)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

#Preview {
    NavigationStack {
        MemoDetailView(memo: Memo.samples[0])
            .environmentObject(AudioService())
    }
}
