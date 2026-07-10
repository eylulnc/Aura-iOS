//
//  AuraWidgetBundle.swift
//  AuraWidget
//
//  Created by Eylul Naz Can on 6.07.2026.
//

import WidgetKit
import SwiftUI

@main
struct AuraWidgetBundle: WidgetBundle {
    var body: some Widget {
        AuraMoodWidget()
        AuraStreakWidget()
    }
}
