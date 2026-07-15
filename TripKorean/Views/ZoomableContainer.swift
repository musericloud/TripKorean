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

    func makeUIView(context: Context) -> CenteringScrollView {
        let scroll = CenteringScrollView()
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
        scroll.centeredView = hostView

        let doubleTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDoubleTap(_:))
        )
        doubleTap.numberOfTapsRequired = 2
        scroll.addGestureRecognizer(doubleTap)

        return scroll
    }

    func updateUIView(_ scroll: CenteringScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.host.rootView = AnyView(content)

        if coordinator.contentSize != contentSize || coordinator.resetToken != resetToken {
            coordinator.contentSize = contentSize
            coordinator.resetToken = resetToken
            scroll.zoomScale = 1
            // 只改尺寸，原点交给 layoutSubviews 实时居中，避免先贴边再跳中的闪动
            coordinator.host.view.frame.size = contentSize
            scroll.contentSize = contentSize
            scroll.setNeedsLayout()
        }
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
            (scrollView as? CenteringScrollView)?.centerContent()
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

/// 在每次布局时把内容视图居中（Apple PhotoScroller 模式），
/// 保证首帧渲染前就已居中，不会出现先贴边再弹回的闪动。
final class CenteringScrollView: UIScrollView {
    weak var centeredView: UIView?

    override func layoutSubviews() {
        super.layoutSubviews()
        centerContent()
    }

    func centerContent() {
        guard let view = centeredView else { return }
        var frame = view.frame
        frame.origin.x = frame.width < bounds.width ? (bounds.width - frame.width) / 2 : 0
        frame.origin.y = frame.height < bounds.height ? (bounds.height - frame.height) / 2 : 0
        if view.frame.origin != frame.origin {
            view.frame = frame
        }
    }
}
