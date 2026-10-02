import SwiftUI

/// What the editor asks of the screen that presents it (`DiaryEditorScreen`).
struct DiaryEditorActions {
    var close: () -> Void
    var save: () -> Void
    var pickPhotos: () -> Void
}

/// Writing (mockup 04), editing and reading (mockup 03) a diary.
struct DiaryEditorView: View {
    @Bindable var viewModel: DiaryEditorViewModel
    let actions: DiaryEditorActions

    @State private var sheet: EditorSheet?
    @State private var viewerStart: PhotoViewerRequest?
    /// How many questions were passed with "another question".
    @State private var promptSkip = 0
    @FocusState private var focus: Field?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private enum Field {
        case title
        case content
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isEditable {
                    composer
                } else {
                    DiaryReaderContent(viewModel: viewModel, openPhoto: { viewerStart = PhotoViewerRequest(id: $0) })
                }
            }
            .background(DiaryTheme.Colors.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
        }
        .tint(DiaryTheme.Colors.brand)
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .date:
                DiaryDateSheet(date: viewModel.draft.date, onDone: { viewModel.selectDate($0) })
            case .emotion:
                DiaryConditionSheet(title: "오늘의 기분은 어땠나요?", conditions: DiaryConditions.emotions,
                                    selection: $viewModel.draft.emotion) { condition in
                    Image(condition.value).resizable().scaledToFit()
                }
            case .weather:
                DiaryConditionSheet(title: "오늘의 날씨", conditions: DiaryConditions.weathers,
                                    selection: $viewModel.draft.weather) { condition in
                    DiaryWeatherIcon(name: condition.value, size: 30)
                }
            }
        }
        .fullScreenCover(item: $viewerStart) { start in
            DiaryPhotoViewer(photos: viewModel.photos, start: start.id)
        }
        .alert("작성을 그만할까요?", isPresented: $viewModel.showsDiscardConfirmation) {
            Button("계속 작성", role: .cancel) {}
            Button("나가기", role: .destructive) {
                viewModel.discardDraft()
                actions.close()
            }
        } message: {
            Text("저장하지 않은 내용은 사라져요.")
        }
        .alert("사진의 위치를 넣을까요?", isPresented: photoPlaceQuestionShown, presenting: viewModel.photoPlaceQuestion) { _ in
            Button("넣지 않기", role: .cancel) { viewModel.answerPhotoPlace(addPlace: false) }
            Button("넣기") { viewModel.answerPhotoPlace(addPlace: true) }
        } message: { question in
            Text("사진을 찍은 곳: \(question.placeName)")
        }
        .onAppear {
            if viewModel.mode == .compose { focus = .title }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button {
                if viewModel.hasChanges {
                    viewModel.showsDiscardConfirmation = true
                } else {
                    actions.close()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(DiaryTheme.Colors.text)
            }
            .accessibilityLabel("닫기")
        }
        ToolbarItem(placement: .principal) {
            Text(title)
                .font(DiaryTheme.Fonts.section)
                .foregroundStyle(DiaryTheme.Colors.text)
        }
        ToolbarItem(placement: .confirmationAction) {
            if viewModel.isEditable {
                Button("저장", action: actions.save)
                    .font(.body.weight(.bold))
                    .disabled(viewModel.isSaving)
            } else {
                Button {
                    viewModel.beginEditing()
                    focus = .content
                } label: {
                    Image(systemName: "pencil")
                        .font(.body.weight(.semibold))
                }
                .accessibilityLabel("수정")
            }
        }
    }

    private var title: String {
        switch viewModel.mode {
        case .compose: return "일기 쓰기"
        case .edit: return "일기 수정"
        case .read: return ""
        }
    }

    // MARK: - Composer

    private var composer: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DiaryTheme.Spacing.medium) {
                DiaryDateCard(date: viewModel.draft.date, isToday: viewModel.isToday) { sheet = .date }
                conditionChips
                titleField
                if viewModel.mode == .compose { promptLine }
                contentField
                if viewModel.isLoadingPhotos || !viewModel.photos.isEmpty {
                    DiaryPhotoStrip(photos: viewModel.photos, loadingCount: viewModel.loadingPhotoCount, isEditable: true,
                                    onOpen: { viewerStart = PhotoViewerRequest(id: $0) }, onRemove: viewModel.removePhoto, onAdd: actions.pickPhotos)
                }
                if let placeName = viewModel.placeName {
                    DiaryPlaceLine(name: placeName, onRemove: viewModel.removePlace)
                }
            }
            .padding(.horizontal, DiaryTheme.Spacing.screen)
            .padding(.vertical, DiaryTheme.Spacing.small)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
    }

    private var conditionChips: some View {
        // In large text the live weather moves under the chips instead of squeezing beside them.
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DiaryTheme.Spacing.small))
            : AnyLayout(HStackLayout(spacing: DiaryTheme.Spacing.small))
        return layout {
            HStack(spacing: DiaryTheme.Spacing.small) {
                DiaryConditionChip(placeholder: "기분", symbol: "face.smiling",
                                   label: DiaryConditions.emotionLabel(viewModel.draft.emotion),
                                   hasValue: !viewModel.draft.emotion.isEmpty) {
                    Image(viewModel.draft.emotion).resizable().scaledToFit()
                } action: { sheet = .emotion }
                DiaryConditionChip(placeholder: "날씨", symbol: "cloud.sun",
                                   label: DiaryConditions.weatherLabel(viewModel.draft.weather),
                                   hasValue: !viewModel.draft.weather.isEmpty) {
                    DiaryWeatherIcon(name: viewModel.draft.weather, size: 20)
                } action: { sheet = .weather }
            }
            if !dynamicTypeSize.isAccessibilitySize {
                Spacer(minLength: DiaryTheme.Spacing.small)
            }
            // The live weather sits at the end of the same row, so the title comes right below.
            if viewModel.mode == .compose {
                DiaryWeatherNote(state: viewModel.weather, attribution: viewModel.attribution)
            }
        }
    }

    private var titleField: some View {
        TextField("제목을 입력해주세요", text: $viewModel.draft.title)
            .font(.title3.weight(.bold))
            .foregroundStyle(DiaryTheme.Colors.text)
            .focused($focus, equals: .title)
            .submitLabel(.next)
            .onSubmit { focus = .content }
            .padding(.horizontal, DiaryTheme.Spacing.screen)
            .frame(minHeight: 52)
            .background(DiaryTheme.Colors.surface, in: RoundedRectangle(cornerRadius: DiaryTheme.Radius.card))
    }

    /// A question to start writing from, for a new diary. It is only shown, never stored.
    private var promptLine: some View {
        let prompt = DiaryPrompts.prompt(on: viewModel.draft.date, calendar: .current, skip: promptSkip)
        return HStack(alignment: .center, spacing: DiaryTheme.Spacing.small) {
            Image(systemName: "lightbulb")
                .foregroundStyle(DiaryTheme.Colors.brand)
                .accessibilityHidden(true)
            Text(prompt)
                .font(DiaryTheme.Fonts.caption)
                .foregroundStyle(DiaryTheme.Colors.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel("오늘의 질문: \(prompt)")
            Button { promptSkip += 1 } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(DiaryTheme.Colors.brand)
                    .frame(width: DiaryTheme.Size.touchTarget, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("다른 질문 보기")
        }
        .padding(.leading, DiaryTheme.Spacing.small)
    }

    private var contentField: some View {
        TextField("오늘은 어떤 하루였나요?\n지금의 생각과 감정을 자유롭게 적어보세요.", text: $viewModel.draft.content, axis: .vertical)
            .font(DiaryTheme.Fonts.body)
            .lineSpacing(6)
            .foregroundStyle(DiaryTheme.Colors.text)
            .focused($focus, equals: .content)
            .lineLimit(10...)
            .padding(DiaryTheme.Spacing.screen)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(DiaryTheme.Colors.surface, in: RoundedRectangle(cornerRadius: DiaryTheme.Radius.card))
            .contentShape(Rectangle())
            .onTapGesture { focus = .content }
    }

    private var bottomBar: some View {
        HStack(spacing: 0) {
            barButton(symbol: "photo.on.rectangle", label: "사진 \(viewModel.photos.count)/\(DiaryPhotoPicking.limit)",
                      action: actions.pickPhotos)
            Divider().frame(height: 20)
            barButton(symbol: "face.smiling", label: "기분") { sheet = .emotion }
            Divider().frame(height: 20)
            barButton(symbol: "cloud.sun", label: "날씨") { sheet = .weather }
        }
        .padding(.vertical, 6)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
        // Three buttons share the width, so their labels stop growing at the largest standard size.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private func barButton(symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbol).font(.title3)
                Text(label).font(.subheadline)
            }
            .foregroundStyle(DiaryTheme.Colors.brand)
            .frame(maxWidth: .infinity, minHeight: DiaryTheme.Size.touchTarget)
        }
    }

    private var photoPlaceQuestionShown: Binding<Bool> {
        Binding(get: { viewModel.photoPlaceQuestion != nil },
                set: { shown in if !shown, viewModel.photoPlaceQuestion != nil { viewModel.answerPhotoPlace(addPlace: false) } })
    }
}

struct PhotoViewerRequest: Identifiable {
    let id: EditorPhoto.ID
}

enum EditorSheet: Identifiable {
    case date
    case emotion
    case weather

    var id: Self { self }
}

enum DiaryEditorFormat {
    private static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = format
        return formatter
    }

    /// "2026. 09. 30 (수)"
    static let cardDate = formatter("yyyy. MM. dd (E)")
    /// "2026. 09. 30 수요일"
    static let readerDate = formatter("yyyy. MM. dd EEEE")
    /// "2026년 9월 28일 (월) 18:42"
    static let dateTime = formatter("yyyy년 M월 d일 (E) HH:mm")
}

// MARK: - Date card

/// The date as a card that says it can be changed, instead of a bare title with an arrow.
struct DiaryDateCard: View {
    let date: Date
    let isToday: Bool
    let action: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // In large text the "change date" button goes under the date, so the date stays on one line.
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DiaryTheme.Spacing.medium))
            : AnyLayout(HStackLayout(spacing: DiaryTheme.Spacing.medium))
        return Button(action: action) {
            layout {
                dateLabel
                if !dynamicTypeSize.isAccessibilitySize {
                    Spacer(minLength: 0)
                }
                changeLabel
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DiaryTheme.Spacing.medium)
            .background(DiaryTheme.Colors.surface, in: RoundedRectangle(cornerRadius: DiaryTheme.Radius.card))
            .overlay {
                RoundedRectangle(cornerRadius: DiaryTheme.Radius.card)
                    .strokeBorder(DiaryTheme.Colors.brand.opacity(0.25), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: DiaryTheme.Radius.card))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("날짜, \(DiaryEditorFormat.cardDate.string(from: date))")
        .accessibilityHint("눌러서 날짜를 바꿉니다")
    }

    private var dateLabel: some View {
        HStack(spacing: DiaryTheme.Spacing.medium) {
            Image(systemName: "calendar")
                .font(.title3.weight(.semibold))
                .foregroundStyle(DiaryTheme.Colors.brand)
                .frame(width: 40, height: 40)
                .background(DiaryTheme.Colors.brand.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(isToday ? "오늘의 일기" : "지난 날의 일기")
                    .font(DiaryTheme.Fonts.caption)
                    .foregroundStyle(DiaryTheme.Colors.secondaryText)
                Text(DiaryEditorFormat.cardDate.string(from: date))
                    .font(.headline)
                    .foregroundStyle(DiaryTheme.Colors.text)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }

    private var changeLabel: some View {
        HStack(spacing: 4) {
            Text("날짜 변경")
            Image(systemName: "chevron.down").font(.caption.weight(.bold))
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(DiaryTheme.Colors.brand)
        .padding(.horizontal, DiaryTheme.Spacing.medium)
        .padding(.vertical, 7)
        .background(DiaryTheme.Colors.brand.opacity(0.12), in: Capsule())
    }
}

// MARK: - Conditions

struct DiaryConditionChip<Icon: View>: View {
    let placeholder: String
    let symbol: String
    let label: String?
    let hasValue: Bool
    @ViewBuilder let icon: () -> Icon
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if hasValue {
                    icon().frame(width: 20, height: 20)
                    Text(label ?? placeholder)
                } else {
                    Image(systemName: "plus")
                        .font(.caption.weight(.bold))
                    Text(placeholder)
                }
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(hasValue ? DiaryTheme.Colors.text : DiaryTheme.Colors.brand)
            .padding(.horizontal, DiaryTheme.Spacing.medium)
            .frame(minHeight: 36)
            .background(hasValue ? DiaryTheme.Colors.surface : DiaryTheme.Colors.brand.opacity(0.08), in: Capsule())
            .overlay {
                Capsule().strokeBorder(DiaryTheme.Colors.brand.opacity(hasValue ? 0.25 : 0.4),
                                       style: StrokeStyle(lineWidth: 1, dash: hasValue ? [] : [4, 3]))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(hasValue ? "\(placeholder), \(label ?? "")" : "\(placeholder) 추가")
    }
}

/// Current weather for a diary written today, with Apple Weather's attribution below it as WeatherKit requires.
/// Small and right-aligned, to sit at the end of the mood and weather row.
struct DiaryWeatherNote: View {
    let state: DiaryEditorViewModel.WeatherState
    let attribution: WeatherAttribution?
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if let text {
            VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing, spacing: 2) {
                Text(text)
                    .foregroundStyle(DiaryTheme.Colors.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .accessibilityLabel(accessibilityText)
                if case .loaded = state, let attribution {
                    Link(destination: attribution.legalPage) {
                        HStack(spacing: 4) {
                            AsyncImage(url: colorScheme == .dark ? attribution.darkMark : attribution.lightMark) { image in
                                image.resizable().scaledToFit()
                            } placeholder: {
                                Text("Apple 날씨")
                            }
                            .frame(height: 11)
                            Text("법적 고지").underline().lineLimit(1)
                        }
                        .foregroundStyle(DiaryTheme.Colors.secondaryText)
                    }
                    .accessibilityLabel("Apple 날씨 데이터 출처와 법적 고지")
                }
            }
            .font(DiaryTheme.Fonts.caption)
            .layoutPriority(-1)
        }
    }

    /// Nothing for a diary of another day: current weather does not describe it.
    private var text: String? {
        switch state {
        case .notToday: return nil
        case .loading: return "날씨 불러오는 중…"
        case .loaded(let description, let celsius): return "\(description) \(Int(celsius.rounded()))℃"
        case .failed(.noLocation): return "위치를 알 수 없어요"
        case .failed(.network): return "인터넷 연결 없음"
        case .failed: return "날씨 정보 없음"
        }
    }

    private var accessibilityText: String {
        switch state {
        case .loaded(let description, let celsius): return "지금 날씨, \(description) \(Int(celsius.rounded()))도"
        case .failed(.noLocation): return "위치를 알 수 없어 날씨를 불러오지 못했어요"
        case .failed(.network): return "인터넷 연결이 없어 날씨를 불러오지 못했어요"
        case .failed: return "날씨를 불러오지 못했어요"
        default: return text ?? ""
        }
    }
}

// MARK: - Reader

/// Reading a stored diary (mockup 03).
struct DiaryReaderContent: View {
    let viewModel: DiaryEditorViewModel
    let openPhoto: (EditorPhoto.ID) -> Void

    var body: some View {
        let draft = viewModel.draft
        ScrollView {
            VStack(alignment: .leading, spacing: DiaryTheme.Spacing.screen) {
                Text(DiaryEditorFormat.readerDate.string(from: draft.date))
                    .font(.subheadline)
                    .foregroundStyle(DiaryTheme.Colors.secondaryText)
                    .monospacedDigit()
                if !draft.emotion.isEmpty || !draft.weather.isEmpty {
                    HStack(spacing: DiaryTheme.Spacing.screen) {
                        if !draft.emotion.isEmpty {
                            condition(label: DiaryConditions.emotionLabel(draft.emotion)) {
                                Image(draft.emotion).resizable().scaledToFit()
                            }
                        }
                        if !draft.weather.isEmpty {
                            condition(label: DiaryConditions.weatherLabel(draft.weather)) {
                                DiaryWeatherIcon(name: draft.weather, size: 22)
                            }
                        }
                    }
                }
                Text(draft.title)
                    .font(.system(.title, design: .default).weight(.heavy))
                    .foregroundStyle(DiaryTheme.Colors.brand)
                    .fixedSize(horizontal: false, vertical: true)
                if viewModel.isLoadingPhotos || !viewModel.photos.isEmpty {
                    DiaryPhotoCarousel(photos: viewModel.photos, isLoading: viewModel.isLoadingPhotos, onOpen: openPhoto)
                }
                if !draft.content.isEmpty {
                    Text(draft.content)
                        .font(DiaryTheme.Fonts.body)
                        .lineSpacing(7)
                        .foregroundStyle(DiaryTheme.Colors.text)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let placeName = viewModel.placeName {
                    DiaryPlaceLine(name: placeName, onRemove: nil)
                }
            }
            .padding(.horizontal, DiaryTheme.Spacing.section)
            .padding(.vertical, DiaryTheme.Spacing.small)
        }
    }

    private func condition<Icon: View>(label: String?, @ViewBuilder icon: () -> Icon) -> some View {
        HStack(spacing: 6) {
            icon().frame(width: 22, height: 22)
            if let label {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(DiaryTheme.Colors.text)
            }
        }
    }
}

/// The photos' place as one short line, instead of a map.
struct DiaryPlaceLine: View {
    let name: String
    /// Nil on the read screen.
    let onRemove: (() -> Void)?

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "mappin.and.ellipse")
                .foregroundStyle(DiaryTheme.Colors.brand)
            Text(name)
                .foregroundStyle(DiaryTheme.Colors.secondaryText)
                .lineLimit(1)
            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(DiaryTheme.Colors.secondaryText.opacity(0.6))
                        .frame(width: DiaryTheme.Size.touchTarget, height: 28)
                }
                .accessibilityLabel("위치 빼기")
            }
        }
        .font(.subheadline)
    }
}
