/// Standard six-string guitar tuning.
public enum StandardTuning {
    /// Open strings from low (6th, E2) to high (1st, E4): E2 A2 D3 G3 B3 E4.
    public static let openStrings: [Note] = [
        Note(.e, 2),
        Note(.a, 2),
        Note(.d, 3),
        Note(.g, 3),
        Note(.b, 3),
        Note(.e, 4),
    ]
}
