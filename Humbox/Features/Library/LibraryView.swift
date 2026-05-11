import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var audio: AudioService
    @State private var searchText = ""
    @State private var selectedKey: String? = nil
    @State private var selectedType: Memo.ContentType? = nil
    @State private var selectedMemo: Memo? = nil

    private var filteredMemos: [Memo] {
        audio.memos.filter { memo in
            let matchesSearch = searchText.isEmpty ||
                memo.title.localizedCaseInsensitiveContains(searchText) ||
                (memo.transcript?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                memo.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }

            let matchesKey = selectedKey == nil || memo.key == selectedKey
            let matchesType = selectedType == nil || memo.contentType == selectedType

            return matchesSearch && matchesKey && matchesType
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(
                            label: selectedKey.map { "Key: \($0)" } ?? "Key",
                            isActive: selectedKey != nil
                        ) { selectedKey = selectedKey == nil ? "Dm" : nil }

                        FilterChip(
                            label: selectedType.map { $0.label.capitalized } ?? "Type",
                            isActive: selectedType != nil
                        ) { selectedType = selectedType == nil ? .guitar : nil }

                        FilterChip(label: "BPM", isActive: false) {}
                        FilterChip(label: "Tag", isActive: false) {}
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }

                // Count
                HStack {
                    Text("\(filteredMemos.count) ideas · sorted by recent")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 4)

                Divider()

                // Memo list
                List(filteredMemos) { memo in
                    Button {
                        selectedMemo = memo
                    } label: {
                        MemoRow(memo: memo)
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                }
                .listStyle(.plain)
            }
            .navigationTitle("Library")
            .searchable(text: $searchText, prompt: "Search ideas, lyrics, vibes…")
            .navigationDestination(item: $selectedMemo) { memo in
                MemoDetailView(memo: memo)
            }
        }
    }
}

// MARK: - Memo Row

struct MemoRow: View {
    let memo: Memo

    var body: some View {
        HStack(spacing: 12) {
            StaticWaveform()
                .frame(width: 36, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(memo.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text(memo.metaSummary)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
    }
}

// MARK: - Static Waveform (placeholder)

struct StaticWaveform: View {
    private let heights: [CGFloat] = [0.3, 0.6, 0.9, 0.4, 0.7, 0.5, 0.8]

    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .center, spacing: 1.5) {
                ForEach(Array(heights.enumerated()), id: \.offset) { _, h in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.secondary.opacity(0.5))
                        .frame(width: max(1, geo.size.width / CGFloat(heights.count) - 1.5),
                               height: geo.size.height * h)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isActive ? Color.primary : Color.clear)
                .foregroundStyle(isActive ? Color(UIColor.systemBackground) : .secondary)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.secondary.opacity(0.3), lineWidth: 0.5))
        }
    }
}

#Preview {
    LibraryView()
        .environmentObject(AudioService())
}
