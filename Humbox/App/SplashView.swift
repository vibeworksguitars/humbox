import SwiftUI

struct SplashView: View {
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 16) {
                // Wordmark — "h" and "b" in crimson, rest in gray
                HStack(spacing: 0) {
                    Text("h")
                        .foregroundStyle(Brand.crimson)
                    Text("um")
                        .foregroundStyle(Brand.gray)
                    Text("b")
                        .foregroundStyle(Brand.crimson)
                    Text("ox")
                        .foregroundStyle(Brand.gray)
                }
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .kerning(-1)

                Text("capture your ideas")
                    .font(.subheadline)
                    .foregroundStyle(Brand.gray)
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
