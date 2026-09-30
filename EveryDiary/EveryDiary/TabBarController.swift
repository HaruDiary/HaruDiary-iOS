//
//  TapBarController.swift
//  EveryDiary
//
//  Created by t2023-m0044 on 2/21/24.
//

import UIKit

class TabBarController: UITabBarController, UITabBarControllerDelegate {
    let firstVC: UINavigationController
    let secondVC: UINavigationController
    let thirdVC: UINavigationController

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
        delegate = self
        setTabBar()
        customTabBar()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.isHidden = true
    }
    
    private func setTabBar() {
        self.viewControllers = [firstVC,secondVC,thirdVC]
        
        firstVC.tabBarItem = UITabBarItem(title: "나의 일기",image: UIImage(named: "diary"), tag: 1)
        secondVC.tabBarItem = UITabBarItem(title: "여정",image: UIImage(named: "building"), tag: 2)
        thirdVC.tabBarItem = UITabBarItem(title: "캘린더",image: UIImage(named: "calendar"), tag: 3)
    }
    
    private func customTabBar() {
        let tabBar: UITabBar = self.tabBar
        tabBar.tintColor = .mainTheme
        tabBar.unselectedItemTintColor = .subText
        if #available(iOS 26.0, *) {
            // The system glass bar: it shrinks while scrolling down and grows back when tapped or scrolled up.
            tabBarMinimizeBehavior = .onScrollDown
        } else {
            tabBar.backgroundColor = .mainCell
            tabBar.layer.borderColor = UIColor(named: "mainTheme")?.cgColor
            tabBar.layer.borderWidth = 0.2
        }
    }

    // MARK: - Sliding between tabs

    func tabBarController(_ tabBarController: UITabBarController,
                          animationControllerForTransitionFrom fromVC: UIViewController,
                          to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        guard let viewControllers, let from = viewControllers.firstIndex(of: fromVC),
              let to = viewControllers.firstIndex(of: toVC), from != to else { return nil }
        return TabSlideTransition(towardsRight: to > from)
    }
}

/// Switching tabs slides the next tab in from the side it sits on, like a page.
private final class TabSlideTransition: NSObject, UIViewControllerAnimatedTransitioning {
    private let towardsRight: Bool

    init(towardsRight: Bool) {
        self.towardsRight = towardsRight
    }

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        UIAccessibility.isReduceMotionEnabled ? 0.2 : 0.35
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let fromView = transitionContext.view(forKey: .from),
              let toView = transitionContext.view(forKey: .to),
              let toVC = transitionContext.viewController(forKey: .to) else {
            transitionContext.completeTransition(true)
            return
        }
        let container = transitionContext.containerView
        toView.frame = transitionContext.finalFrame(for: toVC)
        container.addSubview(toView)

        let duration = transitionDuration(using: transitionContext)
        guard !UIAccessibility.isReduceMotionEnabled else {
            // Reduce Motion: a short cross-fade instead of movement.
            toView.alpha = 0
            UIView.animate(withDuration: duration, animations: { toView.alpha = 1 }) { _ in
                toView.alpha = 1
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
            }
            return
        }
        let width = container.bounds.width
        let direction: CGFloat = towardsRight ? 1 : -1
        toView.transform = CGAffineTransform(translationX: direction * width, y: 0)
        UIView.animate(withDuration: duration, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0,
                       options: [.curveEaseOut, .allowUserInteraction]) {
            toView.transform = .identity
            fromView.transform = CGAffineTransform(translationX: -direction * width * 0.3, y: 0)
            fromView.alpha = 0.6
        } completion: { _ in
            fromView.transform = .identity
            fromView.alpha = 1
            toView.transform = .identity
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }
    }
}
