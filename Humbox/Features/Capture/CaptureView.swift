import SwiftUI

struct CaptureView: View {
    @EnvironmentObject private var audio: AudioService
    @State private var showPermissionAlert = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                // Prompt
                VStack(spacing: 4) {
                    Text(audio.isRecording ? "Recording…" : "Ready when you are")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if !audio.isRecording {
                        Text("Tap to capture · long-press for buffer")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                // Big red button
                RecordButton(
                    isRecording: audio.isRecording,
                    levels: audio.currentLevels
                ) {
                    Task { await handleTap() }
                }

                Spacer()

                // Buffer toggle
                BufferToggle(enabled: $audio.bufferEnabled)
                    .padding(.bottom, 8)

                // Last captured
                if let last = audio.memos.first {
                    Text("Last captured · \"\(last.title)\"")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .padding(.horizontal)
                        .padding(.bottom, 12)
                }
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                // Pulse rings when recording
                if isRecording {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(Color.red.opacity(0.15 - Double(i) * 0.04), lineWidth: 2)
                            .frame(width: 140 + CGFloat(i + 1) * 28)
                    }
                }

                Circle()
                    .fill(isRecording ? Color.red.opacity(0.85) : Color.red)
                    .frame(width: 140, height: 140)
                    .shadow(color: .red.opacity(0.3), radius: isRecording ? 20 : 8)

                if isRecording {
                    // Live waveform
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
    }
}

// MARK: - Buffer Toggle

private struct BufferToggle: View {
    @Binding var enabled: Bool

    var body: some View {
        Button {
            enabled.toggle()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.subheadline)
                Text("30s buffer \(enabled ? "on" : "off")")
                    .font(.subheadline)
                Toggle("", isOn: $enabled)
                    .labelsHidden()
                    .tint(.blue)
                    .scaleEffect(0.8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: Capsule())
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
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
}
