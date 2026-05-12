import SwiftUI

struct DevelopSheet: View {
    let memo: Memo
    let onDevelop: (String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var notes: String = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {

                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("Mark as developed")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text(""\(memo.title)"")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                // Notes box
                VStack(alignment: .leading, spacing: 8) {
                    Text("What did this become?")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("Optional — a song name, album, or any note to your future self.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.secondarySystemBackground))
                        if notes.isEmpty {
                            Text("e.g. "Turned into the chorus of Starless Night"")
                                .font(.subheadline)
                                .foregroundStyle(.quaternary)
                                .padding(12)
                        }
                        TextEditor(text: $notes)
                            .font(.subheadline)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .frame(minHeight: 100, maxHeight: 160)
                    }
                }

                Spacer()

                // Confirm button
                Button {
                    onDevelop(notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes)
                    dismiss()
                } label: {
                    Label("Mark as Developed", systemImage: "checkmark.circle.fill")
                        .fontWeight(.medium)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    DevelopSheet(memo: Memo.samples[0]) { _ in }
}
