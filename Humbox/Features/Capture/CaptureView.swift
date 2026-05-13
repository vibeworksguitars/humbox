import SwiftUI

struct CaptureView: View {
    @EnvironmentObject private var audio: AudioService
    @EnvironmentObject private var store: StoreService
    @StateObject private var click = ClickTrackService()
    @State private var showPermissionAlert = false
    @State private var showPaywall = false
    @State private var showClickSettings = false
    @State private var clickEnabled = false
    @State private var clickBPM = 120
    @State private var clickTimeSig: ClickTrackService.TimeSignature = .fourFour

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

                // Click track control
                if !atCap {
                    ClickTrackControl(
                        enabled: $clickEnabled,
                        bpm: $clickBPM,
                        timeSig: $clickTimeSig,
                        isRecording: audio.isRecording,
                        currentBeat: click.currentBeat,
                        beatsPerBar: clickTimeSig.beatsPerBar
                    )
                    .padding(.bottom, 8)
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Image("HumboxLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 44)
                }
            }
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
            click.stop()
        } else {
            let granted = await audio.requestMicrophonePermission()
            if granted {
                if clickEnabled {
                    click.start(bpm: clickBPM, timeSignature: clickTimeSig)
                }
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

// MARK: - Click Track Control

private struct ClickTrackControl: View {
    @Binding var enabled: Bool
    @Binding var bpm: Int
    @Binding var timeSig: ClickTrackService.TimeSignature
    let isRecording: Bool
    let currentBeat: Int
    let beatsPerBar: Int

    @State private var showPicker = false

    var body: some View {
        VStack(spacing: 8) {
            // Beat indicator dots (only visible while recording with click)
            if isRecording && enabled {
                HStack(spacing: 8) {
                    ForEach(0..<beatsPerBar, id: \.self) { i in
                        Circle()
                            .fill(i == currentBeat ? Brand.crimson : Color.secondary.opacity(0.3))
                            .frame(width: i == 0 ? 10 : 7, height: i == 0 ? 10 : 7)
                            .animation(.easeInOut(duration: 0.05), value: currentBeat)
                    }
                }
            }

            // Toggle pill
            Button { withAnimation { showPicker = enabled ? false : true; enabled.toggle() } } label: {
                HStack(spacing: 8) {
                    Image(systemName: "metronome")
                        .font(.subheadline)
                    Text(enabled ? "\(bpm) BPM · \(timeSig.rawValue)" : "Click track off")
                        .font(.subheadline)
                    Toggle("", isOn: $enabled)
                        .labelsHidden()
                        .tint(Brand.crimson)
                        .scaleEffect(0.8)
                        .allowsHitTesting(false)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: Capsule())
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(isRecording)

            // BPM + time sig picker
            if showPicker && !isRecording {
                VStack(spacing: 10) {
                    // Time signature picker
                    HStack(spacing: 8) {
                        ForEach(ClickTrackService.TimeSignature.allCases, id: \.self) { sig in
                            Button(sig.rawValue) { timeSig = sig }
                                .font(.subheadline)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(timeSig == sig ? Brand.crimson : Color(.secondarySystemBackground))
                                .foregroundStyle(timeSig == sig ? Color.white : Color.secondary)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }

                    // BPM stepper
                    HStack(spacing: 16) {
                        Button { bpm = max(40, bpm - 1) } label: {
                            Image(systemName: "minus.circle")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                        Button { bpm = max(40, bpm - 5) } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                        Text("\(bpm) BPM")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(width: 80)
                        Button { bpm = min(240, bpm + 5) } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                        Button { bpm = min(240, bpm + 1) } label: {
                            Image(systemName: "plus.circle")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .onChange(of: enabled) { _, on in
            if !on { showPicker = false }
        }
    }
}

#Preview {
    CaptureView()
        .environmentObject(AudioService())
        .environmentObject(StoreService())
}
