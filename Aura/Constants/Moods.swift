import SwiftUI

struct MoodFace {
    let id: Int
    let key: String
    let label: String
    let sub: String
    let color: Color
    let imageName: String // asset catalog name, resolves light/dark automatically
}

let MOODS: [MoodFace] = [
    MoodFace(id: 1,  key: "angry",       label: "Angry",       sub: "frustrated, mad",      color: Color(hex: "#C0392B"), imageName: "mood_angry"),
    MoodFace(id: 2,  key: "exhausted",   label: "Exhausted",   sub: "drained, no fuel",     color: Color(hex: "#7F77DD"), imageName: "mood_exhausted"),
    MoodFace(id: 3,  key: "tired",       label: "Tired",       sub: "sleepy, worn out",     color: Color(hex: "#9B8EC4"), imageName: "mood_tired"),
    MoodFace(id: 4,  key: "overwhelmed", label: "Overwhelmed", sub: "too much, stressed",   color: Color(hex: "#9B2B4A"), imageName: "mood_overwhelmed"),
    MoodFace(id: 5,  key: "anxious",     label: "Anxious",     sub: "worried, on edge",     color: Color(hex: "#D85A30"), imageName: "mood_anxious"),
    MoodFace(id: 6,  key: "sad",         label: "Sad",         sub: "down, low",            color: Color(hex: "#378ADD"), imageName: "mood_sad"),
    MoodFace(id: 7,  key: "meh",         label: "Meh",         sub: "flat, indifferent",    color: Color(hex: "#888780"), imageName: "mood_meh"),
    MoodFace(id: 8,  key: "calm",        label: "Calm",        sub: "peaceful, at ease",    color: Color(hex: "#1D9E75"), imageName: "mood_calm"),
    MoodFace(id: 9,  key: "good",        label: "Good",        sub: "content, doing well",  color: Color(hex: "#639922"), imageName: "mood_good"),
    MoodFace(id: 10, key: "energised",   label: "Energised",   sub: "motivated, driven",    color: Color(hex: "#F07D20"), imageName: "mood_energised"),
    MoodFace(id: 11, key: "happy",       label: "Happy",       sub: "joyful, warm",         color: Color(hex: "#EF9F27"), imageName: "mood_happy"),
    MoodFace(id: 12, key: "excited",     label: "Excited",     sub: "thrilled, buzzing",    color: Color(hex: "#E91E8C"), imageName: "mood_excited"),
    MoodFace(id: 13, key: "loved",       label: "Loved",       sub: "grateful, warm inside",color: Color(hex: "#E87AAE"), imageName: "mood_loved"),
]

func getMoodFace(id: Int) -> MoodFace {
    MOODS.first { $0.id == id }!
}

let MOOD_NEGATIVE: [MoodFace] = MOODS.filter { $0.id >= 1 && $0.id <= 6 }
let MOOD_NEUTRAL:  [MoodFace] = MOODS.filter { $0.id == 7 }
let MOOD_POSITIVE: [MoodFace] = MOODS.filter { $0.id >= 8 && $0.id <= 13 }
let POSITIVE_MOOD_IDS: Set<Int> = Set(MOOD_POSITIVE.map { $0.id })

// Ordered from most negative → most positive for the log slider
let MOOD_SLIDER_ORDER: [MoodFace] = [1, 4, 5, 6, 2, 3, 7, 8, 9, 10, 11, 12, 13]
    .map { id in MOODS.first { $0.id == id }! }

// Sentiment index: 0 = most negative, 12 = most positive
let MOOD_SENTIMENT: [Int: Int] = Dictionary(
    uniqueKeysWithValues: MOOD_SLIDER_ORDER.enumerated().map { ($1.id, $0) }
)

// Valence score for trend chart: –2 to +2
let MOOD_VALENCE: [Int: Float] = [
    1: -2.0,   // angry
    2: -0.5,   // exhausted
    3: -0.5,   // tired
    4: -1.5,   // overwhelmed
    5: -1.0,   // anxious
    6: -1.0,   // sad
    7:  0.0,   // meh
    8:  1.0,   // calm
    9:  1.0,   // good
    10:  1.5,  // energised
    11:  2.0,  // happy
    12:  2.0,  // excited
    13:  2.0,  // loved
]

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
