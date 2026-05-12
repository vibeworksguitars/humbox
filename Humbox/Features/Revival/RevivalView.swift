import SwiftUI

struct RevivalView: View {
    @EnvironmentObject private var audio: AudioService

    // Weekly revival candidates — in production, scored by recency + buried-gem algorithm
    private var revivalMemos: [(memo: Memo, reason: String)] {
        let candidates = audio.memos.filter { !$0.isDeveloped }
        return [
            candidates.indices.contains(1) ? (candidates[1], "Never replayed · 8 months old") : nil,
            candidates.indices.contains(2) ? (candidates[2], "Similar to your current project") : nil,
            candidates.indices.contains(3) ? (candidates[3], "You loved this one · \(candidates[3].playCount) plays") : nil,
        ].compactMap { $0 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(revivalMemos.count) ideas worth a second listen")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text("Your weekly graveyard rescue")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    // Revival cards
                    ForEach(revivalMemos, id: \.memo.id) { item in
                        RevivalCard(memo: item.memo, reason: item.reason)
                    }

                    if revivalMemos.isEmpty {
                        ContentUnavailableView(
                            "Graveyard is empty",
                            systemImage: "checkmark.circle",
                            description: Text("All your ideas have been developed. Record more!")
                        )
                        .padding(.top, 60)
                    }
                }
                .padding(.bottom)
            }
            .navigationTitle("Revive")
        }
    }
}

// MARK: - Revival Card

private struct RevivalCard: View {
    let memo: Memo
    let reason: String
    @EnvironmentObject private var audio: AudioService
    @State private var selectedMemo: Memo? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Reason pill
            Text(reason)
                .font(.caption)
                .foregroundStyle(Color.blue)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            Text(memo.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(2)

            Text(memo.metaSummary)
                .font(.caption)
                .foregroundStyle(.tertiary)

            HStack(spacing: 10) {
                Button {
                    audio.play(memo: memo)
                } label: {
                    Label("Listen", systemImage: "play.fill")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.white)

                Button {
                    selectedMemo = memo
                } label: {
                    Text("Develop")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.black)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.15), lineWidth: 0.5))
        .padding(.horizontal)
        .navigationDestination(item: $selectedMemo) { memo in
            MemoDetailView(memo: memo)
        }
    }
}

#Preview {
    RevivalView()
        .environmentObject(AudioService())
}
