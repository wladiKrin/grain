package io.github.wladikrin.grain.meter

import android.hardware.camera2.CameraMetadata
import kotlin.math.abs
import kotlin.math.floor
import kotlin.math.ln
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.roundToInt
import kotlin.math.roundToLong

/**
 * The manual-exposure engine's loop: with AE off, Grain sets exposure time and ISO itself and
 * keeps the metered region near [TARGET] linear luma. Every unclipped frame is a measurement
 * wherever it lands; it re-exposes only when the region leaves [BAND_LOW]..[BAND_HIGH] or is
 * clipped. Under mains flicker ([flickerHz]) times longer than one flicker period are whole
 * periods (see [antiband]). Pure; no Android objects.
 */
class ExposureLoop(limits: Limits, start: Settings, flickerHz: Int = 0) {
    data class Settings(val exposureNs: Long, val iso: Int) {
        /** Exposure × ISO, the quantity the region's luma is proportional to. */
        val product: Double get() = exposureNs.toDouble() * iso
    }

    /** [maxExposureNs] is the loop's own longest time: [MAX_EXPOSURE_NS] or the device's, if lower. */
    data class Limits(val minExposureNs: Long, val maxExposureNs: Long, val minIso: Int, val maxIso: Int) {
        val minProduct: Double get() = minExposureNs.toDouble() * minIso
        val maxProduct: Double get() = maxExposureNs.toDouble() * maxIso

        /**
         * These limits within a physical camera's sensor ranges (the lens a logical
         * multi-camera is using): the overlap, or these limits where there is none.
         */
        fun within(minExposureNs: Long, maxExposureNs: Long, minIso: Int, maxIso: Int): Limits {
            val t0 = max(this.minExposureNs, minExposureNs)
            val t1 = min(this.maxExposureNs, maxExposureNs)
            val i0 = max(this.minIso, minIso)
            val i1 = min(this.maxIso, maxIso)
            return if (t0 in 1..t1 && i0 in 1..i1) Limits(t0, t1, i0, i1) else this
        }

        companion object {
            fun of(minExposureNs: Long, deviceMaxExposureNs: Long, minIso: Int, maxIso: Int) =
                Limits(minExposureNs, max(minExposureNs, min(deviceMaxExposureNs, MAX_EXPOSURE_NS)), minIso, maxIso)
        }
    }

    enum class State { SETTLING, STEADY, CLIPPED }

    /** One frame's verdict: [request] is new settings to send, or null to keep the current ones. */
    data class Step(val request: Settings?, val state: State, val atMin: Boolean, val atMax: Boolean)

    /** The exposure limits of the camera in use; see [reconfigure]. */
    var limits: Limits = limits
        private set

    /** Mains frequency, 50 or 60 Hz; 0 for no antibanding. */
    var flickerHz: Int = flickerHz
        private set

    /** The settings last asked for. */
    var requested: Settings = split(start.product, limits, flickerHz)
        private set

    /** The frame values the last request was stepped from. */
    private var from: Settings = requested

    private var waited = 0

    /**
     * One metered frame, captured with [frame] (its own result values) at region luma [luma]
     * with a [clip] share of clipped pixels; called for every frame, not only the ones sent
     * to Dart. Until a frame [shows] the last request no new step is taken (the frame still
     * measures); after [SETTLE_FRAMES] frames the camera's own values are taken as what it
     * can do.
     */
    fun onFrame(frame: Settings, luma: Double, clip: Double): Step {
        val d = decide(frame, luma, clip, limits, flickerHz)
        if (!shows(frame, requested, from)) {
            if (waited < SETTLE_FRAMES) {
                waited++
                return d.copy(request = null, state = State.SETTLING)
            }
            requested = frame
        }
        waited = 0
        d.request?.let {
            from = frame
            requested = it
        }
        return d
    }

    /**
     * The camera in use changed its [limits] (a logical camera moved to another lens) or the
     * mains frequency [flickerHz] became known: the last request is split again for them, at
     * the same exposure × ISO. Returns that request to send, or null when nothing changes.
     */
    fun reconfigure(limits: Limits, flickerHz: Int): Settings? {
        if (limits == this.limits && flickerHz == this.flickerHz) return null
        this.limits = limits
        this.flickerHz = flickerHz
        val next = split(requested.product, limits, flickerHz)
        if (next == requested) return null
        from = requested
        requested = next
        waited = 0
        return next
    }

    companion object {
        const val TARGET = 0.18
        const val BAND_LOW = 0.05
        const val BAND_HIGH = 0.5

        /** A region this bright or dark is clipped: its luma no longer measures. */
        const val CLIP_HIGH = 0.95

        /** A region this bright is all but white: it may be many stops over. */
        const val CLIP_FULL = 0.99

        /**
         * The step for a [CLIP_FULL] region, so daylight from an indoor start takes two steps;
         * a region between [CLIP_HIGH] and [CLIP_FULL] steps from [MAX_STEP_EV] up to this by
         * its clipped share.
         */
        const val FULL_CLIP_STEP_EV = 6.0
        const val CLIP_LOW = 0.002

        /** Share of the region's pixels at the top code that counts as clipped. */
        const val CLIP_SHARE = 0.02
        const val MAX_STEP_EV = 3.0

        /** Steps smaller than this are not worth a new request. */
        const val MIN_STEP_EV = 0.1

        /** A step down for clipped highlights stops at this luma, so it never leaves the band. */
        const val CLIP_FLOOR = 2 * BAND_LOW

        /** Longest time at the lowest ISO, so the preview stays smooth: 1/30 s. */
        const val SMOOTH_EXPOSURE_NS = 33_333_333L

        /** Longest time at all: 1/4 s. */
        const val MAX_EXPOSURE_NS = 250_000_000L

        /**
         * Frames (every frame, not only the throttled stats ones) to wait for a request to show
         * in the results before stepping anyway: deeper than the pipelines seen so far.
         */
        const val SETTLE_FRAMES = 8

        /** A first guess before any frame: 1/60 s at ISO 200, about EV 7 at mid grey. */
        val DEFAULT_START = Settings(16_666_667L, 200)

        private fun log2(x: Double) = ln(x) / ln(2.0)

        /** Whether [a] and [b] are within [MIN_STEP_EV] / 2 in both time and ISO. */
        fun close(a: Settings, b: Settings): Boolean =
            abs(log2(a.exposureNs.toDouble() / b.exposureNs)) < MIN_STEP_EV / 2 &&
                abs(log2(a.iso.toDouble() / b.iso)) < MIN_STEP_EV / 2

        /**
         * Whether [frame] shows the request [want] stepped from [origin]: it is [close] to it, or
         * it moved most of the way (a camera that rounds ISO or time never lands exactly).
         */
        fun shows(frame: Settings, want: Settings, origin: Settings): Boolean =
            close(frame, want) || abs(log2(frame.product / want.product)) < abs(log2(frame.product / origin.product))

        /** The step, EV, toward [TARGET] for region [luma] with a [clip] share clipped; 0 inside the band. */
        fun stepEv(luma: Double, clip: Double): Double = when {
            luma >= CLIP_FULL -> -FULL_CLIP_STEP_EV
            luma >= CLIP_HIGH -> -(MAX_STEP_EV + (FULL_CLIP_STEP_EV - MAX_STEP_EV) * clip.coerceIn(0.0, 1.0))
            luma <= CLIP_LOW -> MAX_STEP_EV
            luma > BAND_HIGH || luma < BAND_LOW -> log2(TARGET / luma).coerceIn(-MAX_STEP_EV, MAX_STEP_EV)
            clip > CLIP_SHARE -> log2(CLIP_FLOOR / luma).coerceIn(-2.0, 0.0)
            else -> 0.0
        }

        /**
         * The next settings from [frame]'s own values: stepped per [stepEv], split by [split].
         * At the limits the request is null and [Step.atMin] / [Step.atMax] say which.
         */
        fun decide(frame: Settings, luma: Double, clip: Double, limits: Limits, flickerHz: Int = 0): Step {
            val p = frame.product
            val atMin = p <= limits.minProduct * 1.05
            val atMax = p >= limits.maxProduct * 0.95
            val clipped = luma >= CLIP_HIGH || luma <= CLIP_LOW || clip > CLIP_SHARE
            val step = if (luma.isFinite()) stepEv(luma, clip) else 0.0
            val state = when {
                clipped -> State.CLIPPED
                step == 0.0 -> State.STEADY
                else -> State.SETTLING
            }
            val next = split(p * 2.0.pow(step), limits, flickerHz)
            val moves = abs(step) >= MIN_STEP_EV && !close(next, frame)
            return Step(if (moves) next else null, if (moves || clipped) state else State.STEADY, atMin, atMax)
        }

        /**
         * Exposure × ISO [product] as settings: the lowest ISO up to 1/30 s, then ISO up to its
         * maximum, then longer times up to the loop's maximum. Clamped to [limits]; under
         * [flickerHz] mains, [antiband]ed.
         */
        fun split(product: Double, limits: Limits, flickerHz: Int = 0): Settings =
            antiband(plainSplit(product, limits), product, limits, flickerHz)

        private fun plainSplit(product: Double, limits: Limits): Settings {
            val smooth = SMOOTH_EXPOSURE_NS.coerceIn(limits.minExposureNs, limits.maxExposureNs)
            val t1 = product / limits.minIso
            if (t1 <= smooth) {
                return Settings(t1.toLong().coerceIn(limits.minExposureNs, smooth), limits.minIso)
            }
            val iso = product / smooth
            if (iso <= limits.maxIso) {
                return Settings(smooth, iso.roundToInt().coerceIn(limits.minIso, limits.maxIso))
            }
            val t = (product / limits.maxIso).toLong().coerceIn(smooth, limits.maxExposureNs)
            return Settings(t, limits.maxIso)
        }

        /** Light under [hz] mains flickers at twice that: 10 ms at 50 Hz, 8.33 ms at 60 Hz. */
        fun flickerPeriodNs(hz: Int): Double = if (hz > 0) 1e9 / (2.0 * hz) else 0.0

        /**
         * ISO may land this far outside its range (MIN_STEP_EV / 2) and be clamped back: the
         * product then moves by less than a step worth taking.
         */
        private val ISO_SLACK = 2.0.pow(MIN_STEP_EV / 2)

        /**
         * [s], for exposure × ISO [product], with a time longer than one flicker period of
         * [hz] mains moved to a whole number of periods, so every row of the rolling shutter
         * sees the same light: the nearer of the multiples below and above whose ISO (the
         * product over that time) fits [limits]. The ISO takes the difference, so the product
         * stays. Times of one period or less, and times no multiple fits, stay as they are.
         */
        fun antiband(s: Settings, product: Double, limits: Limits, hz: Int): Settings {
            val period = flickerPeriodNs(hz)
            if (period <= 0.0) return s
            val t = s.exposureNs.toDouble()
            val n = floor(t / period)
            if (n < 1 || (n == 1.0 && t - period < 1.0)) return s
            var best = s
            var bestDist = Double.MAX_VALUE
            for (k in listOf(n, n + 1)) {
                val tk = (k * period).roundToLong()
                if (tk < limits.minExposureNs || tk > limits.maxExposureNs) continue
                val iso = product / tk
                if (iso < limits.minIso / ISO_SLACK || iso > limits.maxIso * ISO_SLACK) continue
                val dist = abs(ln(tk / t))
                if (dist < bestDist) {
                    best = Settings(tk, iso.roundToInt().coerceIn(limits.minIso, limits.maxIso))
                    bestDist = dist
                }
            }
            return best
        }

        /** The metered region's (luma, clipped share) in [stats]: the spot's when [spot], else the crop's. */
        fun metered(stats: Stats, spot: Boolean): Pair<Double, Double> =
            if (spot) stats.spot to stats.spotClip else stats.crop to stats.cropClip

        /** The frame duration for [exposureNs]: at least 1/30 s and at least the exposure. */
        fun frameDuration(exposureNs: Long): Long = max(exposureNs, SMOOTH_EXPOSURE_NS)

        /**
         * Whether to drop the captures in flight for [next], stepped from [frame]: when its frames
         * are at most half as long, so the old long ones (several deep) do not hold it back.
         */
        fun flushes(frame: Settings, next: Settings): Boolean =
            2 * frameDuration(next.exposureNs) <= frameDuration(frame.exposureNs)

        /** Why the manual engine can or cannot run on a camera; null [reason] means it can. */
        fun unsupportedReason(capabilities: IntArray?, aeModes: IntArray?, hasRanges: Boolean): String? = when {
            capabilities?.contains(CameraMetadata.REQUEST_AVAILABLE_CAPABILITIES_MANUAL_SENSOR) != true ->
                "no MANUAL_SENSOR capability"
            aeModes?.contains(CameraMetadata.CONTROL_AE_MODE_OFF) != true -> "no CONTROL_AE_MODE_OFF"
            !hasRanges -> "no exposure or sensitivity range"
            else -> null
        }
    }
}
