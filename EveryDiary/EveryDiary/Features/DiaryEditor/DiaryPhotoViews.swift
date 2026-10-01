import SwiftUI

/// The editor's photos, numbered in the order they were picked, with delete and add.
struct DiaryPhotoStrip: View {
    let photos: [EditorPhoto]
    /// Photos still arriving, each shown as a placeholder where it will appear.
    let loadingCount: Int
    let isEditable: Bool
    let onOpen: (EditorPhoto.ID) -> Void
    let onRemove: (EditorPhoto.ID) -> Void
    let onAdd: () -> Void

    private let size: CGFloat = 96

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DiaryTheme.Spacing.small) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                    Button { onOpen(photo.id) } label: {
                        Image(uiImage: photo.image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: size, height: size)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                    .overlay(alignment: .topLeading) {
                        Text("\(index + 1)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(DiaryTheme.Colors.brand, in: Circle())
                            .overlay { Circle().strokeBorder(.white, lineWidth: 1.5) }
                            .padding(6)
                            .accessibilityHidden(true)
                    }
                    .overlay(alignment: .topTrailing) {
                        if isEditable {
                            Button { onRemove(photo.id) } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title3)
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, .black.opacity(0.6))
                                    .padding(4)
                            }
                            .accessibilityLabel("사진 \(index + 1) 삭제")
                        }
                    }
                    .accessibilityLabel("사진 \(index + 1)")
                }
                ForEach(0..<loadingCount, id: \.self) { _ in
                    PhotoSkeleton(cornerRadius: 12)
                        .frame(width: size, height: size)
                        .transition(.opacity)
                }
                if loadingCount == 0, isEditable, photos.count < DiaryPhotoPicking.limit {
                    Button(action: onAdd) {
                        VStack(spacing: 4) {
                            Image(systemName: "plus").font(.title3.weight(.semibold))
                            Text("\(photos.count)/\(DiaryPhotoPicking.limit)").font(.caption)
                        }
                        .foregroundStyle(DiaryTheme.Colors.brand)
                        .frame(width: size, height: size)
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(DiaryTheme.Colors.brand.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("사진 추가")
                }
            }
            .padding(.vertical, 2)
            .animation(PhotoSkeleton.fadeIn, value: photos.map(\.id))
            .animation(PhotoSkeleton.fadeIn, value: loadingCount)
        }
    }
}

/// The read screen's photos, one at a time.
struct DiaryPhotoCarousel: View {
    let photos: [EditorPhoto]
    let isLoading: Bool
    let onOpen: (EditorPhoto.ID) -> Void
    @State private var page: EditorPhoto.ID?

    var body: some View {
        ZStack {
            if isLoading {
                PhotoSkeleton(cornerRadius: 0)
                    .aspectRatio(4 / 3, contentMode: .fit)
                    .transition(.opacity)
            } else {
                TabView(selection: $page) {
                    ForEach(photos) { photo in
                        Button { onOpen(photo.id) } label: {
                            Color.clear
                                .overlay {
                                    Image(uiImage: photo.image).resizable().scaledToFill()
                                }
                                .clipped()
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .tag(Optional(photo.id))
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: photos.count > 1 ? .always : .never))
                .aspectRatio(4 / 3, contentMode: .fit)
                .transition(.opacity)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: DiaryTheme.Radius.card))
        .animation(PhotoSkeleton.fadeIn, value: isLoading)
    }
}

/// A photo at full size (mockup 10): swipe between photos, pinch or double-tap to zoom.
/// It closes with its button or by pulling the photo down, which shrinks it back over the diary.
struct DiaryPhotoViewer: View {
    let photos: [EditorPhoto]
    @State private var page: EditorPhoto.ID?
    /// How far the photo is pulled down; let go far enough and the viewer closes.
    @State private var pull: CGFloat = 0
    /// Decided when a drag starts: only a downward drag pulls, so swiping between photos is left alone.
    @State private var isPulling: Bool?
    /// A zoomed photo is moved around by its own gestures, not pulled away.
    @State private var zoomed: Set<EditorPhoto.ID> = []
    /// Let go far enough: the photo shrinks away where it is, instead of the whole screen sliding down.
    @State private var isClosing = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(photos: [EditorPhoto], start: EditorPhoto.ID) {
        self.photos = photos
        _page = State(initialValue: start)
    }

    private var index: Int { photos.firstIndex { $0.id == page } ?? 0 }

    var body: some View {
        let progress = min(pull / 320, 1)
        ZStack {
            // The diary shows through more and more as the photo is pulled away.
            Color.black.opacity(isClosing ? 0 : 1 - progress).ignoresSafeArea()
            TabView(selection: $page) {
                ForEach(photos) { photo in
                    ZoomablePhoto(image: photo.image) { isZoomed in
                        if isZoomed { zoomed.insert(photo.id) } else { zoomed.remove(photo.id) }
                    }
                    .tag(Optional(photo.id))
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea(edges: .bottom)
            .scaleEffect(reduceMotion ? 1 : isClosing ? 0.4 : 1 - progress * 0.4)
            .offset(y: pull)
            .opacity(isClosing ? 0 : 1)
        }
        .overlay(alignment: .top) {
            ZStack {
                Text("\(index + 1) / \(photos.count)")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .monospacedDigit()
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: DiaryTheme.Size.touchTarget, height: DiaryTheme.Size.touchTarget)
                    }
                    .accessibilityLabel("닫기")
                    Spacer()
                }
            }
            .padding(.horizontal, DiaryTheme.Spacing.small)
            .opacity(1 - min(progress * 4, 1))
        }
        .overlay(alignment: .bottomLeading) {
            if photos.indices.contains(index), let date = photos[index].captureDate {
                Label(DiaryEditorFormat.dateTime.string(from: date), systemImage: "camera")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(DiaryTheme.Spacing.screen)
                    .opacity(1 - min(progress * 4, 1))
            }
        }
        .presentationBackground(.clear)
        .simultaneousGesture(
            DragGesture(minimumDistance: 16)
                .onChanged { drag in
                    if isPulling == nil {
                        let isZoomed = page.map(zoomed.contains) ?? false
                        isPulling = !isZoomed && drag.translation.height > 0
                            && drag.translation.height > abs(drag.translation.width)
                    }
                    if isPulling == true { pull = max(0, drag.translation.height) }
                }
                .onEnded { drag in
                    defer { isPulling = nil }
                    guard isPulling == true else { return }
                    if drag.translation.height > 120 || drag.predictedEndTranslation.height > 420 {
                        closeShrinking()
                    } else {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) { pull = 0 }
                    }
                }
        )
        .accessibilityAction(.escape) { dismiss() }
        .statusBarHidden()
    }

    private func closeShrinking() {
        withAnimation(.easeOut(duration: 0.2)) { isClosing = true }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            // Nothing is left to see, so the screen goes without its own slide down.
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { dismiss() }
        }
    }
}

private struct ZoomablePhoto: View {
    let image: UIImage
    let onZoomChanged: (Bool) -> Void
    @State private var scale: CGFloat = 1
    @GestureState private var pinch: CGFloat = 1

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .scaleEffect(scale * pinch)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .gesture(
                MagnifyGesture()
                    .updating($pinch) { value, state, _ in state = value.magnification }
                    .onEnded { value in scale = min(max(scale * value.magnification, 1), 4) }
            )
            .onTapGesture(count: 2) {
                withAnimation(.spring(duration: 0.25)) { scale = scale > 1 ? 1 : 2.5 }
            }
            .onChange(of: scale) { _, scale in onZoomChanged(scale > 1) }
            .accessibilityLabel("사진")
    }
}
