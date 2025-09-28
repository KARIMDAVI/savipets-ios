import SwiftUI
import AVKit

struct PlayerLayerView: UIViewRepresentable {
    let videoName: String
    let fileType: String

    func makeUIView(context: Context) -> PlayerContainerView {
        let v = PlayerContainerView()
        v.backgroundColor = .clear

        let url = Bundle.main.url(forResource: videoName, withExtension: fileType)
            ?? Bundle.main.url(forResource: "SavSpalsh", withExtension: "mp4")
            ?? Bundle.main.url(forResource: "SavSplash", withExtension: "mp4")

        if let url {
            let player = AVPlayer(url: url)
            player.isMuted = true
            player.automaticallyWaitsToMinimizeStalling = false
            v.playerLayer.player = player
            v.playerLayer.videoGravity = .resizeAspectFill

            NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main) { _ in
                player.seek(to: .zero)
                player.play()
            }
            player.playImmediately(atRate: 1.0)
        }
        return v
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {}

    class PlayerContainerView: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
        override func layoutSubviews() {
            super.layoutSubviews()
            playerLayer.frame = bounds
        }
    }
}

struct SavSplash: View {
	@State private var showSplash = true
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            RootView()
                .opacity(showSplash ? 0 : 1)

            if showSplash {
                // Themed fallback under video to avoid any black frame
                SPDesignSystem.Colors.goldenGradient(colorScheme)
                    .ignoresSafeArea()
                PlayerLayerView(videoName: "SavSpalsh", fileType: "mp4")
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                withAnimation(.easeOut(duration: 0.35)) { showSplash = false }
            }
        }
    }
}


