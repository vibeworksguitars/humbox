import SwiftUI

struct SplashView: View {
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 20) {
                Image("HumboxLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 240)

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
