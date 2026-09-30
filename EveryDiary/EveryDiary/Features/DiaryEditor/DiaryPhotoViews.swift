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
struct DiaryPhotoViewer: View {
    let photos: [EditorPhoto]
    @State private var page: EditorPhoto.ID?
    @Environment(\.dismiss) private var dismiss

    init(photos: [EditorPhoto], start: EditorPhoto.ID) {
        self.photos = photos
        _page = State(initialValue: start)
    }

    private var index: Int { photos.firstIndex { $0.id == page } ?? 0 }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            TabView(selection: $page) {
                ForEach(photos) { photo in
                    ZoomablePhoto(image: photo.image)
                        .tag(Optional(photo.id))
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea(edges: .bottom)
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
        }
        .overlay(alignment: .bottomLeading) {
            if photos.indices.contains(index), let date = photos[index].captureDate {
                Label(DiaryEditorFormat.dateTime.string(from: date), systemImage: "camera")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(DiaryTheme.Spacing.screen)
            }
        }
        .statusBarHidden()
    }
}

private struct ZoomablePhoto: View {
    let image: UIImage
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
            .accessibilityLabel("사진")
    }
}
