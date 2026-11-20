/// Opaque sRGB roles derived from the reported shell, never from the device name.
struct FinishPalette: Equatable, Sendable {
    let background, surface, surfaceHigh, outline: UInt32
    let primary, onPrimary, text, secondary, error: UInt32
    let header, headerEdge, onHeader, headerSecondary: UInt32

    init(finish: HeadphoneFinish?, dark: Bool, increasedContrast: Bool = false) {
        let seed = finish?.shell ?? 0x818CA2
        let mix = Self.mix
        if dark {
            background = mix(0x141617, seed, 8)
            surface = mix(0x252729, seed, 13)
            surfaceHigh = mix(0x323537, seed, 14)
            outline = mix(increasedContrast ? 0xB6BABD : 0x838A92, seed, 11)
            primary = mix(0xF3F5FF, seed, 22)
            onPrimary = 0x14191F
            text = 0xF6F7F8
            secondary = mix(increasedContrast ? 0xF1F3F4 : 0xD3D6DB, seed, 8)
            error = 0xFFB8B0
        } else {
            background = mix(0xF6F7F8, seed, 5)
            surface = mix(0xFFFFFF, seed, 3)
            surfaceHigh = mix(0xF1F3F6, seed, 10)
            outline = mix(increasedContrast ? 0x4B5359 : 0x69737D, seed, 11)
            primary = mix(0x192031, seed, 32)
            onPrimary = 0xFFFFFF
            text = 0x172026
            secondary = mix(increasedContrast ? 0x283039 : 0x424A53, seed, 8)
            error = 0x932923
        }
        // A consistently lit studio surface keeps black and blue shells legible in dark mode.
        header = mix(dark ? 0xF0F1EF : 0xFBFBFA, seed, 17)
        headerEdge = mix(dark ? 0xDEE2E6 : 0xE9EEF1, seed, 27)
        onHeader = 0x171E23
        headerSecondary = mix(increasedContrast ? 0x222930 : 0x343F49, seed, 10)
    }

    private static func mix(_ base: UInt32, _ seed: UInt32, _ percent: UInt32) -> UInt32 {
        func component(_ shift: UInt32) -> UInt32 {
            let a = (base >> shift) & 255, b = (seed >> shift) & 255
            return ((a * (100 - percent) + b * percent + 50) / 100) << shift
        }
        return component(16) | component(8) | component(0)
    }
}
