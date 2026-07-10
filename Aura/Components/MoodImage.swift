import SwiftUI

struct MoodImage: View {
    let face: MoodFace
    var size: CGFloat = Spacing.moodFaceSize

    var body: some View {
        Image(face.imageName)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }
}
