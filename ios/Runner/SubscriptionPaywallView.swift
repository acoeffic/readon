// SubscriptionPaywallView.swift
// Paywall natif Apple (SwiftUI + StoreKit 2) conforme aux directives App Store :
// titre, durée, prix avec unité, mention renouvellement auto, liens Terms/Privacy.
//
// Les entitlements restent synchronisés par RevenueCat en "observer mode" :
// le SDK RC détecte automatiquement les transactions StoreKit 2 et met à jour
// l'état de l'utilisateur côté Supabase via le webhook RevenueCat.

import SwiftUI
import StoreKit

@available(iOS 17.0, *)
struct SubscriptionPaywallView: View {
    let productIDs: [String]
    let onClose: () -> Void

    private let termsURL = URL(string: "https://www.lexday.fr/conditions-abonnement.html")!
    private let privacyURL = URL(string: "https://www.lexday.fr/privacy.html")!

    private let sageGreen = Color(red: 107/255, green: 152/255, blue: 141/255)
    private let cream = Color(red: 250/255, green: 243/255, blue: 232/255)

    var body: some View {
        NavigationStack {
            SubscriptionStoreView(productIDs: productIDs) {
                VStack(spacing: 14) {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(sageGreen)
                        .padding(20)
                        .background(sageGreen.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                    Text("Passez à")
                        .font(.system(size: 26, weight: .bold))

                    Text("LexDay Premium")
                        .font(.system(size: 26, weight: .bold, design: .serif))
                        .italic()
                        .foregroundStyle(sageGreen)

                    Text("Débloquez tout le potentiel de votre lecture")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    FeatureBullets()
                        .padding(.top, 8)
                }
                .padding(.top, 24)
                .padding(.bottom, 16)
                .containerBackground(cream, for: .subscriptionStoreFullHeight)
            }
            .backgroundStyle(cream)
            .subscriptionStoreButtonLabel(.multiline)
            .subscriptionStorePolicyDestination(url: privacyURL, for: .privacyPolicy)
            .subscriptionStorePolicyDestination(url: termsURL, for: .termsOfService)
            .storeButton(.visible, for: .restorePurchases)
            .storeButton(.visible, for: .policies)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.tertiary)
                    }
                    .accessibilityLabel("Fermer")
                }
            }
            .onInAppPurchaseCompletion { _, result in
                if case .success(.success) = result {
                    // Donne une poignée de ms à RevenueCat pour synchroniser
                    // l'entitlement avant de fermer le paywall.
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    await MainActor.run { onClose() }
                }
            }
        }
    }
}

@available(iOS 17.0, *)
private struct FeatureBullets: View {
    private let sageGreen = Color(red: 107/255, green: 152/255, blue: 141/255)

    private let items: [(String, String)] = [
        ("chart.bar.fill", "Statistiques avancées"),
        ("sparkles", "Muse — conseillère de lecture"),
        ("infinity", "Listes de lecture illimitées"),
        ("arrow.triangle.2.circlepath", "Sync Kindle automatique"),
        ("paintpalette.fill", "Thèmes personnalisés"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(items, id: \.1) { icon, label in
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .foregroundStyle(sageGreen)
                        .frame(width: 22)
                    Text(label)
                        .font(.system(size: 14, weight: .medium))
                }
            }
        }
        .padding(.horizontal, 32)
    }
}
