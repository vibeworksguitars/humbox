import SwiftUI

struct SplashView: View {
    @State private var opacity: Double = 0

    private static let taglines = [
        "Better than \"New Recording 47\"",
        "The notebook your melodies deserve.",
        "For every riff you forgot you wrote.",
        "Your songwriting graveyard, resurrected.",
        "Hum now. Sort later. Never lose it.",
        "Bring your forgotten ideas back to life.",
        "Sound, contained.",
        "Capture the song before it's gone.",
        "From earworm to encore.",
    ]
    private let tagline = taglines.randomElement()!

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 20) {
                Image("HumboxLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 320)

                Text(tagline)
                    .font(.subheadline)
                    .foregroundStyle(Brand.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.easeIn(duration: 0.4)) { opacity = 1 }
        }
    }
}

#Preview {
    SplashView()
}
