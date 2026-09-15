//
//  CalendarVC.swift
//  EveryDiary
//
//  Created by t2023-m0044 on 2/23/24.
//

import UIKit
import Observation

import SnapKit

class CalendarVC: UIViewController {
    
    private let viewModel: CalendarViewModel
    private var decoratedDays: Set<CalendarDay> = []
    private var diaries: [DiaryEntry] { viewModel.selectedEntries }

    init(viewModel: CalendarViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { return nil }
    
    private lazy var settingButton : UIBarButtonItem = {
        let settingButton = UIBarButtonItem(title: "세팅뷰 이동",image: UIImage(named: "setting"), target: self, action: #selector(tabSettingBTN))
        return settingButton
    }()
    
    private lazy var calendarLabel : UILabel = {
        let calendarLabel = UILabel()
        calendarLabel.text = "캘린더"
        calendarLabel.font = UIFont(name: "SFProDisplay-Bold", size: 25)
        calendarLabel.textColor = UIColor(named: "mainTheme")
        return calendarLabel
    }()
    
    private lazy var writeDiaryButton : UIButton = {
        var config = UIButton.Configuration.plain()
        let writeDiaryButton = UIButton(configuration: config)
        writeDiaryButton.layer.shadowRadius = 3
        writeDiaryButton.layer.borderColor = UIColor(named: "mainCell")?.cgColor
        writeDiaryButton.layer.shadowOpacity = 0.3
        writeDiaryButton.layer.shadowOffset = CGSize(width: 0, height: 0)
        writeDiaryButton.setImage(UIImage(named: "write"), for: .normal)
        writeDiaryButton.addTarget(self, action: #selector(tabWriteDiaryBTN), for: .touchUpInside)
        return writeDiaryButton
    }()
    
    private lazy var calendarView : UICalendarView = {
        var calendarView = UICalendarView()
        calendarView.wantsDateDecorations = true
        return calendarView
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(named: "mainBackground")
        addSubviewsCalendarVC()
        autoLayoutCalendarVC()
        configurateViews()
        loadDiaries() // 처음 View 로드 시, data load
        observeState()
    }
    
    @objc private func tabSettingBTN() {
        let settingVC = SettingVC()
        settingVC.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(settingVC, animated: true)
    }
    
    @objc private func tabWriteDiaryBTN() {
        let writeDiaryVC = WriteDiaryVC()
        writeDiaryVC.enterDiary(to: .writeNewDiary)
        writeDiaryVC.delegate = self
        writeDiaryVC.modalPresentationStyle = .automatic
        self.present(writeDiaryVC, animated: true)
    }
    
    private func setNavigationBar() {
        navigationItem.rightBarButtonItem = settingButton
        navigationController?.navigationBar.tintColor = UIColor(named: "mainTheme")
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "캘린더", style: .plain, target: nil, action: nil)
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: calendarLabel)
    }
    
    private func addSubviewsCalendarVC() {
        view.addSubview(writeDiaryButton)
        view.addSubview(calendarView)
        view.sendSubviewToBack(calendarView)
    }
    
    private func autoLayoutCalendarVC() {
        writeDiaryButton.snp.makeConstraints { make in
            make.trailing.equalTo(view.safeAreaLayoutGuide.snp.trailing).offset(-10)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-32)
        }
        calendarView.snp.makeConstraints { make in
            make.leading.equalTo(view.safeAreaLayoutGuide).inset(15)
            make.trailing.equalTo(view.safeAreaLayoutGuide).inset(15)
            make.top.equalTo(view.safeAreaLayoutGuide).offset(20)
        }
    }
    
    private func loadDiaries() {
        viewModel.start()
    }

    private func observeState() {
        let dates = viewModel.index.decorationDaysToReload(previous: decoratedDays)
        decoratedDays = viewModel.index.decoratedDays
        calendarView.reloadDecorations(forDateComponents: dates.map(\.dateComponents), animated: true)
        withObservationTracking {
            _ = viewModel.index
            _ = viewModel.state
        } onChange: { [weak self] in
            Task { @MainActor in self?.observeState() }
        }
    }
}

//MARK: - UICalendarView Custom & Decorations
extension CalendarVC {
    private func configurateViews() {
        customCalendar()
        setDateComponents()
        setNavigationBar()
        dateSelectCalendar()
    }
    
    private func customCalendar() {
        calendarView.tintColor = .mainTheme
        calendarView.backgroundColor = .mainCell
        calendarView.layer.shadowRadius = 3
        calendarView.layer.shadowColor = UIColor(named: "mainTheme")?.cgColor
        calendarView.layer.shadowOpacity = 0.1
        calendarView.layer.shadowOffset = CGSize(width: 0, height: 0)
        calendarView.calendar = viewModel.calendar
        calendarView.locale = Locale(identifier: "ko-KR")
        calendarView.timeZone = viewModel.calendar.timeZone
        calendarView.fontDesign = .rounded
        calendarView.layer.cornerRadius = 20
        calendarView.delegate = self
    }
    
    private func dateSelectCalendar() {
        let dataSelection = UICalendarSelectionSingleDate(delegate: self)
        calendarView.selectionBehavior = dataSelection
    }
    
    private func setDateComponents() {
        let fromDateComponents = DateComponents(
            calendar: calendarView.calendar,
            year: 2011,
            month: 1,
            day: 1
        )
        guard let fromDate = fromDateComponents.date else {
            fatalError("Invalid date components: \(fromDateComponents)")
        }
        let calendarViewDateRange = DateInterval(start: fromDate, end: .distantFuture)
        calendarView.availableDateRange = calendarViewDateRange
    }
}


//MARK: - 일기를 쓴 해당 날짜 filter 후, 데이터 처리방법 표시
extension CalendarVC: UICalendarViewDelegate, UICalendarSelectionSingleDateDelegate {
   
    func calendarView(_ calendarView: UICalendarView, decorationFor dateComponents: DateComponents) -> UICalendarView.Decoration? {
        guard let date = viewModel.calendar.date(from: dateComponents),
              calendarView.availableDateRange.contains(date) else {
            return nil
        }
        
        let hasDiary = viewModel.index.decoratedDays.contains(CalendarDay(date: date, calendar: viewModel.calendar))
        return hasDiary ? .default(color: .mainTheme, size: .medium) : nil
    }
    
    func dateSelection(_ selection: UICalendarSelectionSingleDate, didSelectDate dateComponents: DateComponents?) {
        guard let dateComponents = dateComponents,
              let date = viewModel.calendar.date(from: dateComponents) else {
            return
        }
        
        viewModel.select(date)
        if !viewModel.selectedEntries.isEmpty {
            let calendarListVC = CalendarListVC(viewModel: viewModel)
            calendarListVC.hidesBottomBarWhenPushed = true
            navigationController?.pushViewController(calendarListVC, animated: true)
        }
    }
}

//MARK: - 일기 데이터 수정 시, View Reload
extension CalendarVC: DiaryUpdateDelegate {
    func diaryDidUpdate() {
        loadDiaries()
    }
}
