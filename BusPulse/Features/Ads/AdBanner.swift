import SwiftUI

// Ads are optional plumbing: everything below compiles to an empty view until
// the Google Mobile Ads SDK package is added to the project (File → Add
// Package Dependencies → https://github.com/googleads/swift-package-manager-google-mobile-ads),
// so the app builds and runs identically with or without it.

#if canImport(GoogleMobileAds)
import GoogleMobileAds

/// A single, anchored adaptive banner. Non-personalised (npa=1), so no App
/// Tracking Transparency dialog is ever shown. Sized by the SDK for the
/// current width; hides itself entirely until an ad actually loads, so
/// screens never show an empty grey hole.
struct AdBannerSlot: View {
    @State private var loadedHeight: CGFloat = 0

    var body: some View {
        if AppConfig.Ads.enabled {
            GeometryReader { proxy in
                AdBannerView(width: proxy.size.width, loadedHeight: $loadedHeight)
            }
            .frame(height: loadedHeight)
            .clipped()
            .accessibilityLabel("Advertisement")
        }
    }
}

private struct AdBannerView: UIViewRepresentable {
    let width: CGFloat
    @Binding var loadedHeight: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator(loadedHeight: $loadedHeight) }

    func makeUIView(context: Context) -> BannerView {
        let size = currentOrientationAnchoredAdaptiveBanner(width: max(width, 320))
        let banner = BannerView(adSize: size)
        banner.adUnitID = AppConfig.Ads.bannerUnitID
        banner.delegate = context.coordinator
        banner.rootViewController = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?.rootViewController

        let request = Request()
        let extras = Extras()
        extras.additionalParameters = ["npa": "1"] // non-personalised only
        request.register(extras)
        banner.load(request)
        return banner
    }

    func updateUIView(_ view: BannerView, context: Context) {}

    final class Coordinator: NSObject, BannerViewDelegate {
        @Binding var loadedHeight: CGFloat
        init(loadedHeight: Binding<CGFloat>) { _loadedHeight = loadedHeight }

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            loadedHeight = bannerView.adSize.size.height
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            loadedHeight = 0 // no fill — take no space rather than show a hole
        }
    }
}

enum AdSetup {
    /// Start the SDK once at launch (cheap; safe before any banner exists).
    static func start() {
        MobileAds.shared.start()
    }
}

#else

/// SDK not present — render nothing, everywhere.
struct AdBannerSlot: View {
    var body: some View { EmptyView() }
}

enum AdSetup {
    static func start() {}
}

#endif
