// ContentView.swift
// Écran principal de l'app Watch LexDay.

import SwiftUI

// MARK: - Couleurs LexDay (miroir du widget iOS)

extension Color {
    static let lexGreen = Color(red: 107/255, green: 152/255, blue: 141/255)
    static let lexGreenDark = Color(red: 80/255, green: 115/255, blue: 106/255)
    static let lexCream = Color(red: 250/255, green: 245/255, blue: 235/255)
}

struct ContentView: View {
    @EnvironmentObject private var session: WatchSessionManager

    private var state: WatchReadingState { session.state }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                header
                if state.isReading {
                    progressBar
                }
                controls
                stats
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
        }
    }

    // MARK: - En-tête : couverture + titre + auteur

    private var header: some View {
        HStack(alignment: .top, spacing: 8) {
            cover
            VStack(alignment: .leading, spacing: 2) {
                Text(state.hasBook ? state.bookTitle : "Aucune lecture")
                    .font(.system(size: 14, weight: .semibold, design: .serif))
                    .foregroundColor(.lexGreenDark)
                    .lineLimit(2)
                if !state.bookAuthor.isEmpty {
                    Text(state.bookAuthor)
                        .font(.system(size: 11, design: .serif))
                        .foregroundColor(.lexGreen)
                        .lineLimit(1)
                }
                statusBadge
            }
            Spacer(minLength: 0)
        }
    }

    private var cover: some View {
        Group {
            if let data = state.coverData, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Color.lexGreen.opacity(0.18)
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.lexGreen.opacity(0.7))
                }
            }
        }
        .frame(width: 42, height: 63)
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    @ViewBuilder
    private var statusBadge: some View {
        if state.isReading {
            HStack(spacing: 4) {
                Circle()
                    .fill(state.isPaused ? Color.orange : Color.green)
                    .frame(width: 6, height: 6)
                Text(state.isPaused ? "En pause" : "Lecture")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.lexGreen)
            }
            .padding(.top, 2)
        }
    }

    // MARK: - Barre de progression du livre

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.lexGreen.opacity(0.2))
                Capsule()
                    .fill(Color.lexGreen)
                    .frame(width: max(0, geo.size.width * state.progressPercent))
            }
        }
        .frame(height: 4)
    }

    // MARK: - Boutons de contrôle

    @ViewBuilder
    private var controls: some View {
        if !state.isReading {
            actionButton(title: "Lancer la lecture",
                         systemImage: "play.fill",
                         tint: .lexGreen) {
                session.send(.start)
            }
            .disabled(!state.hasBook)
        } else {
            HStack(spacing: 8) {
                if state.isPaused {
                    actionButton(title: "Reprendre",
                                 systemImage: "play.fill",
                                 tint: .lexGreen) {
                        session.send(.resume)
                    }
                } else {
                    actionButton(title: "Pause",
                                 systemImage: "pause.fill",
                                 tint: .orange) {
                        session.send(.pause)
                    }
                }
                actionButton(title: "Arrêter",
                             systemImage: "stop.fill",
                             tint: .red) {
                    session.send(.stop)
                }
            }
        }
    }

    private func actionButton(title: String,
                              systemImage: String,
                              tint: Color,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .bold))
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .foregroundColor(.white)
        .background(tint)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .opacity(session.isSending ? 0.6 : 1.0)
    }

    // MARK: - Stats du jour

    private var stats: some View {
        HStack(spacing: 6) {
            statPill(icon: "clock.fill",
                     value: "\(state.todayMinutes)",
                     label: "min",
                     tint: .lexGreen)
            statPill(icon: "flame.fill",
                     value: "\(state.streak)",
                     label: "flow",
                     tint: .orange)
        }
    }

    private func statPill(icon: String, value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 1) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(tint)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .serif))
                .foregroundColor(.lexGreenDark)
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.lexGreen.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color.lexGreen.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    ContentView()
        .environmentObject(WatchSessionManager.shared)
}
