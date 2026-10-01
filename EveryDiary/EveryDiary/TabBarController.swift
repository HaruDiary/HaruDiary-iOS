//
//  TapBarController.swift
//  EveryDiary
//
//  Created by t2023-m0044 on 2/21/24.
//

import SwiftUI
import UIKit

/// The three tabs, with a floating Instagram-style bar (`DiaryTabBar`) in place of the system tab bar.
/// The system bar stays hidden; this controller keeps selection, the bar's size and switching in step.
class TabBarController: UITabBarController, UINavigationControllerDelegate {
    let firstVC: UINavigationController
    let secondVC: UINavigationController
    let thirdVC: UINavigationController

    private let barState = DiaryTabBarState(tabs: [
        DiaryTab(id: 0, title: "나의 일기", image: "diary"),
        DiaryTab(id: 1, title: "여정", image: "building"),
        DiaryTab(id: 2, title: "캘린더", image: "calendar"),
    ])
    private var barHost: UIHostingController<DiaryTabBar>?
    private var collapse = TabBarCollapse()
    private var scrollObservation: NSKeyValueObservation?
    private weak var observedScrollView: UIScrollView?

    init(dependencies: AppDependencies) {
        let makeWriteDiary: MakeWriteDiary = { DiaryEditorModule.makeEditor(saver: dependencies.diarySaving) }
        let makeSettings = { dependencies.makeSettingsModule().makeViewController(makeWriteDiary: makeWriteDiary) }
        firstVC = UINavigationController(rootViewController: dependencies.makeDiaryListModule().makeViewController(makeWriteDiary: makeWriteDiary, makeSettings: makeSettings))
        secondVC = UINavigationController(rootViewController: dependencies.makeJourneyModule().makeViewController(makeWriteDiary: makeWriteDiary, makeSettings: makeSettings))
        thirdVC = UINavigationController(rootViewController: dependencies.makeCalendarModule().makeViewController(makeWriteDiary: makeWriteDiary, makeSettings: makeSettings))
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { return nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        viewControllers = [firstVC, secondVC, thirdVC]
        for (index, navigation) in [firstVC, secondVC, thirdVC].enumerated() {
            let tab = barState.tabs[index]
            navigation.tabBarItem = UITabBarItem(title: tab.title, image: UIImage(named: tab.image), tag: index + 1)
            navigation.delegate = self
            // The tab's first screen leaves room for the floating bar; pushed screens hide it.
            navigation.viewControllers.first?.additionalSafeAreaInsets.bottom = DiaryTabBar.expandedHeight + 8
        }
        hideSystemTabBar()
        installBar()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        hideSystemTabBar()
    }

    /// UIKit shows its own bar again after a screen that hides it is popped, so it is hidden every time.
    private func hideSystemTabBar() {
        if #available(iOS 18.0, *) {
            if !isTabBarHidden { setTabBarHidden(true, animated: false) }
        } else {
            tabBar.isHidden = true
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.isHidden = true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        observeScrolling()
    }

    private func installBar() {
        let host = UIHostingController(rootView: DiaryTabBar(
            state: barState,
            onSelect: { [weak self] in self?.select($0) },
            onExpand: { [weak self] in self?.expandBar() }
        ))
        host.view.backgroundColor = .clear
        host.sizingOptions = []
        addChild(host)
        view.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            // Only as wide as the bar itself, so touches beside it reach the screen behind.
            host.view.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            host.view.widthAnchor.constraint(equalToConstant: DiaryTabBar.width(tabs: barState.tabs.count, collapsed: false)),
            host.view.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: 2),
            host.view.heightAnchor.constraint(equalToConstant: DiaryTabBar.expandedHeight),
        ])
        host.didMove(toParent: self)
        barHost = host
    }

    // MARK: - Switching tabs

    /// Tapping the open tab again scrolls it back to the top, like Instagram.
    private func select(_ index: Int) {
        guard index != selectedIndex else {
            scrollToTop()
            return
        }
        crossFade(to: index)
        barState.selected = index
        expandBar()
        observeScrolling()
    }

    /// Netflix-style switch: the current tab fades away while the next one fades in, settling from slightly smaller.
    private func crossFade(to index: Int) {
        guard let current = selectedViewController?.view,
              let snapshot = current.snapshotView(afterScreenUpdates: false) else {
            selectedIndex = index
            return
        }
        snapshot.frame = current.frame
        view.insertSubview(snapshot, belowSubview: barHost?.view ?? view)
        selectedIndex = index
        guard let next = selectedViewController?.view else {
            snapshot.removeFromSuperview()
            return
        }
        let reduceMotion = UIAccessibility.isReduceMotionEnabled
        next.alpha = 0
        if !reduceMotion { next.transform = CGAffineTransform(scaleX: 0.97, y: 0.97) }
        UIView.animate(withDuration: reduceMotion ? 0.18 : 0.28, delay: 0, options: [.curveEaseOut, .allowUserInteraction]) {
            next.alpha = 1
            next.transform = .identity
            snapshot.alpha = 0
        } completion: { _ in
            next.alpha = 1
            next.transform = .identity
            snapshot.removeFromSuperview()
        }
    }

    private func scrollToTop() {
        guard let scrollView = observedScrollView else { return }
        let top = CGPoint(x: scrollView.contentOffset.x, y: -scrollView.adjustedContentInset.top)
        scrollView.setContentOffset(top, animated: true)
        expandBar()
    }

    // MARK: - Shrinking on scroll

    private func expandBar() {
        collapse.expand(at: observedScrollView.map(Self.distanceFromTop))
        barState.isCollapsed = false
    }

    private func observeScrolling() {
        scrollObservation = nil
        observedScrollView = nil
        attachToScrollView(retries: 3)
    }

    /// SwiftUI creates its scroll view a moment after the screen appears, so looking is retried briefly.
    private func attachToScrollView(retries: Int) {
        let screen = (selectedViewController as? UINavigationController)?.topViewController?.view
        guard let scrollView = screen.flatMap(Self.mainScrollView(in:)) else {
            if retries > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    guard let self, self.observedScrollView == nil else { return }
                    self.attachToScrollView(retries: retries - 1)
                }
            }
            return
        }
        observedScrollView = scrollView
        collapse.expand(at: Self.distanceFromTop(scrollView))
        scrollObservation = scrollView.observe(\.contentOffset, options: [.new]) { [weak self] scrollView, _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.collapse.scrolled(to: Self.distanceFromTop(scrollView))
                if self.barState.isCollapsed != self.collapse.isCollapsed {
                    self.barState.isCollapsed = self.collapse.isCollapsed
                }
            }
        }
    }

    private static func distanceFromTop(_ scrollView: UIScrollView) -> CGFloat {
        scrollView.contentOffset.y + scrollView.adjustedContentInset.top
    }

    /// The screen's main vertical scroll view: the largest one filling most of the screen (not a photo carousel).
    private static func mainScrollView(in root: UIView) -> UIScrollView? {
        var queue = [root]
        var best: UIScrollView?
        while !queue.isEmpty {
            let view = queue.removeFirst()
            if let scrollView = view as? UIScrollView, scrollView.isScrollEnabled, !scrollView.isPagingEnabled,
               scrollView.bounds.height >= root.bounds.height * 0.5,
               scrollView.bounds.height * scrollView.bounds.width > (best.map { $0.bounds.height * $0.bounds.width } ?? 0) {
                best = scrollView
            }
            queue.append(contentsOf: view.subviews)
        }
        return best
    }

    // MARK: - Pushed screens

    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController,
                              animated: Bool) {
        barState.isHidden = viewController !== navigationController.viewControllers.first
        hideSystemTabBar()
    }

    func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController,
                              animated: Bool) {
        // A cancelled back swipe ends on the pushed screen again.
        barState.isHidden = viewController !== navigationController.viewControllers.first
        hideSystemTabBar()
        if !barState.isHidden { observeScrolling() }
    }
}
