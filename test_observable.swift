import Foundation
import Observation

@Observable
final class AppState {
    var ambientVolume: Float = 0.75 {
        didSet {
            let clamped = min(max(ambientVolume, 0.0), 1.5)
            ambientVolume = clamped
            print("Set to \(clamped)")
        }
    }
}

let state = AppState()
state.ambientVolume = 1.0
