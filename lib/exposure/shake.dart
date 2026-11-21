/// Whether a handheld exposure of [seconds] risks camera shake by the
/// 1/focal-length rule, with [eqFocal] the focal length on 135 film.
bool shakeRisk({required double seconds, required double eqFocal}) =>
    seconds > 1 / eqFocal;
