import CoreFoundation

enum Spacing {
    // Base spacing
    static let xs: CGFloat  = 4
    static let s: CGFloat   = 8
    static let m: CGFloat   = 12
    static let l: CGFloat   = 16
    static let xl: CGFloat  = 24
    static let xxl: CGFloat = 32

    // Corner radius
    static let radiusCard: CGFloat   = 12
    static let radiusButton: CGFloat = 12
    static let radiusPill: CGFloat   = 50

    // Borders
    static let borderWidth: CGFloat          = 1
    static let selectionBorderWidth: CGFloat = 2

    // Mood face sizes
    static let moodFaceSize: CGFloat        = 52
    static let moodFaceWrapperSize: CGFloat = 56
    static let moodFaceSmallSize: CGFloat   = 32
    static let moodFaceMediumSize: CGFloat  = 48
    static let moodFaceLargeSize: CGFloat   = 96

    // Components
    static let noteInputMinHeight: CGFloat = 80

    // Onboarding
    static let loginIconSize: CGFloat   = 160
    static let loginIconRadius: CGFloat = 36
}

enum FontSize {
    static let xs: CGFloat = 12
    static let s: CGFloat  = 14
    static let m: CGFloat  = 16
    static let l: CGFloat  = 22
    static let xl: CGFloat = 24
}
