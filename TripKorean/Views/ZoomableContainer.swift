import SwiftUI
import UIKit

/// 基于 UIScrollView 的缩放容器：原生捏合缩放/平移/双击放大，
/// 与外层 SwiftUI ScrollView 的滚动手势自动协调，互不干扰。
struct ZoomableContainer<Content: View>: UIViewRepresentable {
    /// 内容在 1x 时的尺寸（通常是图片 aspect-fit 后的尺寸）
    let contentSize: CGSize
    /// 变化时重置缩放（如换图、切换翻译方向）
    let resetToken: String
    @ViewBuilder var content: Content

    func makeUIView(context: Context) -> UIScrollView {
        let scroll = UIScrollView()
        scroll.minimumZoomScale = 1
        scroll.maximumZoomScale = 5
        scroll.delegate = context.coordinator
        scroll.showsVerticalScrollIndicator = false
        scroll.showsHorizontalScrollIndicator = false
        scroll.alwaysBounceVertical = false
        scroll.alwaysBounceHorizontal = false
        scroll.bouncesZoom = true
        scroll.clipsToBounds = true
        scroll.contentInsetAdjustmentBehavior = .never
        scroll.backgroundColor = .clear

        let hostView = context.coordinator.host.view!
        hostView.backgroundColor = .clear
        scroll.addSubview(hostView)

        let doubleTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDoubleTap(_:))
        )
        doubleTap.numberOfTapsRequired = 2
        scroll.addGestureRecognizer(doubleTap)

        return scroll
    }

    func updateUIView(_ scroll: UIScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.host.rootView = AnyView(content)

        if coordinator.contentSize != contentSize || coordinator.resetToken != resetToken {
            coordinator.contentSize = contentSize
            coordinator.resetToken = resetToken
            scroll.zoomScale = 1
            coordinator.host.view.frame = CGRect(origin: .zero, size: contentSize)
            scroll.contentSize = contentSize
        }
        coordinator.centerContent(scroll)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        let host = UIHostingController(rootView: AnyView(EmptyView()))
        var contentSize: CGSize = .zero
        var resetToken = ""

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            host.view
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerContent(scrollView)
        }

        /// 内容小于视口时居中显示
        func centerContent(_ scrollView: UIScrollView) {
            let insetX = max((scrollView.bounds.width - scrollView.contentSize.width) / 2, 0)
            let insetY = max((scrollView.bounds.height - scrollView.contentSize.height) / 2, 0)
            scrollView.contentInset = UIEdgeInsets(top: insetY, left: insetX, bottom: insetY, right: insetX)
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scroll = gesture.view as? UIScrollView else { return }
            if scroll.zoomScale > 1.01 {
                scroll.setZoomScale(1, animated: true)
            } else {
                let point = gesture.location(in: host.view)
                let width = scroll.bounds.width / 2.5
                let height = scroll.bounds.height / 2.5
                scroll.zoom(
                    to: CGRect(x: point.x - width / 2, y: point.y - height / 2, width: width, height: height),
                    animated: true
                )
            }
        }
    }
}
