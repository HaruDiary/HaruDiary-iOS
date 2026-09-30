import MapKit
import SwiftUI

/// The editor's photos, numbered in the order they were picked, with delete and add.
struct DiaryPhotoStrip: View {
    let photos: [EditorPhoto]
    let isLoading: Bool
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
                if isLoading {
                    ProgressView()
                        .frame(width: size, height: size)
                        .background(DiaryTheme.Colors.surface, in: RoundedRectangle(cornerRadius: 12))
                } else if isEditable, photos.count < DiaryPhotoPicking.limit {
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
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .aspectRatio(4 / 3, contentMode: .fit)
                    .background(DiaryTheme.Colors.surface)
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
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: DiaryTheme.Radius.card))
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

// MARK: - Place

/// Where the diary was written, or where its photos were taken. Opens Apple Maps or Google Maps, as before.
struct DiaryPlaceCard: View {
    let coordinates: [DiaryCoordinate]
    let placeName: String?
    let isPhotoPlace: Bool
    let openMaps: (DiaryCoordinate, DiaryMapApp) -> Void
    @State private var asksForMapApp = false

    var body: some View {
        Button { asksForMapApp = true } label: {
            VStack(spacing: 0) {
                Map(initialPosition: .automatic, interactionModes: []) {
                    ForEach(Array(coordinates.enumerated()), id: \.offset) { _, coordinate in
                        Marker("", coordinate: CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude))
                            .tint(DiaryTheme.Colors.brand)
                    }
                }
                .frame(height: 130)
                .allowsHitTesting(false)
                HStack(spacing: DiaryTheme.Spacing.small) {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundStyle(DiaryTheme.Colors.brand)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(placeName ?? "위치")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(DiaryTheme.Colors.text)
                            .lineLimit(1)
                        Text(isPhotoPlace ? "사진을 찍은 곳" : "일기를 쓴 곳")
                            .font(DiaryTheme.Fonts.caption)
                            .foregroundStyle(DiaryTheme.Colors.secondaryText)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.right.square")
                        .foregroundStyle(DiaryTheme.Colors.secondaryText)
                }
                .padding(DiaryTheme.Spacing.medium)
            }
            .background(DiaryTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: DiaryTheme.Radius.card))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(placeName ?? "위치"), 지도에서 열기")
        .confirmationDialog(placeName ?? "위치", isPresented: $asksForMapApp, titleVisibility: .visible) {
            if let first = coordinates.first {
                Button("Apple 지도에서 열기") { openMaps(first, .apple) }
                Button("Google 지도에서 열기") { openMaps(first, .google) }
            }
            Button("취소", role: .cancel) {}
        }
    }
}
