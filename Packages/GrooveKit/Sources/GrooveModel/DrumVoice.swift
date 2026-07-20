/// A playable articulation on the drum kit.
public enum DrumVoice: String, CaseIterable, Codable, Sendable, Hashable {
    case kick
    case snare
    case snareGhost
    case snareRim
    case hatClosed
    case hatOpen
    /// A "bark": struck open, immediately choked short by the foot. Distinct
    /// from `hatOpen`, which rings until the next hat closes it.
    case hatHalfOpen
    case hatPedal
    case tomHigh
    case tomMid
    case tomLow
    case ride
    case rideBell
    case crash

    /// Voices that choke each other when triggered (open hat is cut by a closed/pedal hat).
    public var chokeGroup: Int? {
        switch self {
        case .hatClosed, .hatOpen, .hatHalfOpen, .hatPedal: return 1
        default: return nil
        }
    }
}
