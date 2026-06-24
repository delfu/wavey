/// The verdict from verifying live audio against an expected target.
public enum MatchResult: Hashable, Sendable {
    /// The player is playing the expected note/chord.
    case match
    /// The player is playing something, but not the expected note/chord.
    case wrong
    /// Nothing is being played (below the detection/gate threshold).
    case silence
}
