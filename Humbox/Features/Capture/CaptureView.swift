import SwiftUI

struct CaptureView: View {
    @EnvironmentObject private var audio: AudioService
    @EnvironmentObject private var store: StoreService
    @State private var showPermissionAlert = false
    @State private var showPaywall = false

    private var atCap: Bool {
        !store.isPro && audio.memos.count >= StoreService.freeRecordingCap
    }

    private var remainingFree: Int {
        max(0, StoreService.freeRecordingCap - audio.memos.count)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                // Prompt
                VStack(spacing: 4) {
                    Text(audio.isRecording ? "Recording…" : (atCap ? "Free limit reached" : "Ready when you are"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if !audio.isRecording {
                        if atCap {
                            Text("Upgrade to keep capturing")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        } else {
                            Text("Tap to start · tap again to stop")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                Spacer()

                // Big red button — dims and shows lock when at cap
                RecordButton(
                    isRecording: audio.isRecording,
                    levels: audio.currentLevels,
                    locked: atCap
                ) {
                    if atCap {
                        showPaywall = true
                    } else {
                        Task { await handleTap() }
                    }
                }

                Spacer()

                // Footer: last captured or free-tier counter
                Group {
                    if atCap {
                        Button("Upgrade to Pro →") { showPaywall = true }
                            .font(.caption)
                            .fontWeight(.medium)
                    } else if !store.isPro && remainingFree <= 3 {
                        Text("\(remainingFree) free idea\(remainingFree == 1 ? "" : "s") remaining")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if let last = audio.memos.first {
                        Text("Last captured · \"\(last.title)\"")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .padding(.horizontal)
                    }
                }
                .padding(.bottom, 12)
            }
            .navigationTitle("Humbox")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Microphone Access", isPresented: $showPermissionAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Humbox needs microphone access to capture your ideas. Enable it in Settings.")
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    private func handleTap() async {
        if audio.isRecording {
            audio.stopRecording()
        } else {
            let granted = await audio.requestMicrophonePermission()
            if granted {
                await audio.startRecording()
            } else {
                showPermissionAlert = true
            }
        }
    }
}

// MARK: - Record Button

private struct RecordButton: View {
    let isRecording: Bool
    let levels: [Float]
    let locked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isRecording {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(Brand.crimson.opacity(0.15 - Double(i) * 0.04), lineWidth: 2)
                            .frame(width: 140 + CGFloat(i + 1) * 28)
                    }
                }

                Circle()
                    .fill(locked ? Color.secondary.opacity(0.25) : (isRecording ? Brand.crimson.opacity(0.85) : Brand.crimson))
                    .frame(width: 140, height: 140)
                    .shadow(color: locked ? .clear : Brand.crimson.opacity(0.4), radius: isRecording ? 20 : 8)

                if locked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                } else if isRecording {
                    WaveformBars(levels: levels, color: .white)
                        .frame(width: 80, height: 40)
                } else {
                    VStack(spacing: 4) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.white)
                        Text("REC")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isRecording)
        .animation(.easeInOut(duration: 0.2), value: locked)
    }
}

// MARK: - Waveform Bars

struct WaveformBars: View {
    let levels: [Float]
    var color: Color = .secondary

    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .center, spacing: 2) {
                ForEach(Array(levels.enumerated()), id: \.offset) { _, level in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(color)
                        .frame(width: max(1, (geo.size.width / CGFloat(levels.count)) - 2),
                               height: max(3, geo.size.height * CGFloat(level)))
                        .animation(.easeInOut(duration: 0.05), value: level)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}

#Preview {
    CaptureView()
        .environmentObject(AudioService())
        .environmentObject(StoreService())
}
