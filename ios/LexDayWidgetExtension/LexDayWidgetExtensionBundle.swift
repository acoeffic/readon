import WidgetKit
import SwiftUI

@main
struct LexDayWidgetExtensionBundle: WidgetBundle {
    @WidgetBundleBuilder
    var body: some Widget {
        LexDayWidget()
        if #available(iOS 16.1, *) {
            ReadingLiveActivity()
        }
    }
}
