import Foundation

public struct AnimationCurves {
    /// Calculate the animation factor at a given time point
    public static func progress(
        at time: Double,
        start: Double,
        duration: Double,
        style: AnimationStyle,
        damping: Double = 0.75,
        response: Double = 0.8
    ) -> Double {
        if time < start {
            return 0.0
        }
        
        let elapsed = time - start
        let safeDuration = max(duration, 0.05)
        let tNormalized = min(elapsed / safeDuration, 1.0)
        
        switch style {
        case .spring:
            // Analytical solution of Apple's spring physics
            let zeta = max(0.1, min(damping, 0.999))
            let omegaN = (2.0 * .pi) / max(response, 0.1)
            let omegaD = omegaN * sqrt(1.0 - zeta * zeta)
            let decay = exp(-zeta * omegaN * elapsed)
            let oscillation = cos(omegaD * elapsed) + (zeta / sqrt(1.0 - zeta * zeta)) * sin(omegaD * elapsed)
            let result = 1.0 - decay * oscillation
            if elapsed >= safeDuration * 1.5 { return 1.0 }
            if elapsed >= safeDuration * 1.15 {
                let blend = min(1.0, (elapsed - safeDuration * 1.15) / (safeDuration * 0.35))
                let smoothBlend = blend * blend * (3.0 - 2.0 * blend)
                return max(0.0, result * (1.0 - smoothBlend) + 1.0 * smoothBlend)
            }
            return max(0.0, result)
            
        case .burstRush:
            // High energy rush-out with snappy overshoot and recovery
            let t = elapsed * 2.8 / safeDuration
            if t >= 3.0 { return 1.0 }
            let overshoot = 1.0 - exp(-3.2 * t) * cos(5.0 * t)
            if t >= 2.2 {
                let blend = min(1.0, (t - 2.2) / 0.8)
                let smoothBlend = blend * blend * (3.0 - 2.0 * blend)
                return max(0.0, overshoot * (1.0 - smoothBlend) + 1.0 * smoothBlend)
            }
            return max(0.0, overshoot)
            
        case .easeOut:
            // Cubic Ease Out
            let p = 1.0 - pow(1.0 - tNormalized, 3)
            return max(0.0, min(p, 1.0))
            
        case .bounce:
            // Bouncy entrance
            let t = tNormalized
            if t < 0.3636 {
                return 7.5625 * t * t
            } else if t < 0.7272 {
                let t2 = t - 0.5454
                return 7.5625 * t2 * t2 + 0.75
            } else if t < 0.9090 {
                let t3 = t - 0.8181
                return 7.5625 * t3 * t3 + 0.9375
            } else {
                let t4 = t - 0.9545
                return 7.5625 * t4 * t4 + 0.984375
            }
        }
    }
    
    /// Monotonic progress for number counter animation (0.0 -> 1.0).
    /// Strictly non-decreasing so numbers never dip, oscillate downward, or glitch.
    public static func numberCounterProgress(
        at time: Double,
        start: Double,
        duration: Double
    ) -> Double {
        if time <= start { return 0.0 }
        let elapsed = time - start
        // Numbers count up and settle right as the bar reaches full scale
        let counterDuration = max(duration * 0.85, 0.1)
        if elapsed >= counterDuration { return 1.0 }
        let t = elapsed / counterDuration
        // Smooth ease-out cubic curve (slows down gracefully into the final number)
        let ease = 1.0 - pow(1.0 - t, 3)
        return min(max(ease, 0.0), 1.0)
    }
}
