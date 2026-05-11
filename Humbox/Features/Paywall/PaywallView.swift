import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject private var store: StoreService
    @Environment(\.dismiss) private var dismiss
    @State private var isPurchasing = false
    @State private var isRestoring = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {

                    // Header
                    VStack(spacing: 10) {
                        Image(systemName: "waveform.badge.plus")
                            .font(.system(size: 52))
                            .foregroundStyle(.primary)
                        Text("Humbox Pro")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("You've captured \(StoreService.freeRecordingCap) ideas.\nUpgrade to keep going.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)

                    // Feature list
                    VStack(alignment: .leading, spacing: 14) {
                        FeatureRow(icon: "infinity",          text: "Unlimited recordings")
                        FeatureRow(icon: "tuningfork",        text: "Key & BPM detection")
                        FeatureRow(icon: "clock.arrow.circlepath", text: "30-second capture buffer")
                        FeatureRow(icon: "arrow.clockwise",   text: "Weekly revival feed")
                        FeatureRow(icon: "pianokeys",         text: "Melody-to-MIDI export")
                    }
                    .padding(.horizontal)

                    // Plan picker
                    if store.products.isEmpty {
                        ProgressView()
                            .padding()
                    } else {
                        VStack(spacing: 10) {
                            if let yearly = store.yearly {
                                PlanButton(
                                    product: yearly,
                                    badge: "Best value",
                                    isPurchasing: isPurchasing
                                ) { await buy(yearly) }
                            }
                            if let monthly = store.monthly {
                                PlanButton(
                                    product: monthly,
                                    badge: nil,
                                    isPurchasing: isPurchasing
                                ) { await buy(monthly) }
                            }
                        }
                        .padding(.horizontal)
                    }

                    if let error = store.purchaseError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // Restore
                    Button {
                        Task {
                            isRestoring = true
                            await store.restorePurchases()
                            isRestoring = false
                            if store.isPro { dismiss() }
                        }
                    } label: {
                        if isRestoring {
                            ProgressView()
                        } else {
                            Text("Restore purchases")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text("Subscriptions auto-renew unless cancelled.\nCancel any time in App Store settings.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.bottom)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") { dismiss() }
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func buy(_ product: Product) async {
        isPurchasing = true
        await store.purchase(product)
        isPurchasing = false
        if store.isPro { dismiss() }
    }
}

// MARK: - Feature Row

private struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(.primary)
            Text(text)
                .font(.subheadline)
            Spacer()
            Image(systemName: "checkmark")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Plan Button

private struct PlanButton: View {
    let product: Product
    let badge: String?
    let isPurchasing: Bool
    let action: () async -> Void

    var body: some View {
        Button {
            Task { await action() }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(product.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        if let badge {
                            Text(badge)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.primary)
                                .foregroundStyle(Color(UIColor.systemBackground))
                                .clipShape(Capsule())
                        }
                    }
                    Text(product.displayPrice + (product.id.hasSuffix("yearly") ? " / year" : " / month"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isPurchasing {
                    ProgressView()
                } else {
                    Text("Subscribe")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.2), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .disabled(isPurchasing)
    }
}

#Preview {
    PaywallView()
        .environmentObject(StoreService())
}
