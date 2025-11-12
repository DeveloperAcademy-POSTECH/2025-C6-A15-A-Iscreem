//
//  KoreanSearchUtils.swift
//  learningTool
//
//  Created by 이혜빈 on 11/2/25.
//

import Foundation

// MARK: - Korean-aware fuzzy search (Hangul Jamo subsequence)
struct KoreanSearchUtils {
    
    /// Returns true if `text` matches `query` using Korean-aware fuzzy search
    static func matches(_ text: String, query: String) -> Bool {
        let t = text.lowercased()
        let q = query.lowercased()
        
        // 1) Plain substring (fast path)
        if t.contains(q) { return true }
        
        // 2) Jamo key subsequence match (handles cases like "개발" vs "갭")
        let tk = jamoKey(t)
        let qk = jamoKey(q)
        if tk.contains(qk) { return true }
        
        return isSubsequence(qk, in: tk)
    }
    
    /// Convert a string to a Hangul Jamo key: each syllable → L(ᄀ..ᄒ) + V(ᅡ..ᅵ) + [T(ᆨ..ᇂ)]
    /// Also maps compatibility Jamo (ㄱㅏㅂ etc.) to modern Jamo, removes spaces/punctuation.
    private static func jamoKey(_ s: String) -> String {
        let SBase: UInt32 = 0xAC00, SCount: UInt32 = 11172
        let LBase: UInt32 = 0x1100
        let VBase: UInt32 = 0x1161, VCount: UInt32 = 21
        let TBase: UInt32 = 0x11A7, TCount: UInt32 = 28
        
        // Compatibility Jamo → Modern Jamo (subset: initials & vowels)
        let compToModern: [UInt32: UInt32] = [
            // Initials (ㄱ..ㅎ)
            0x3131: 0x1100, // ㄱ → ᄀ
            0x3132: 0x1101, // ㄲ → ᄁ
            0x3134: 0x1102, // ㄴ → ᄂ
            0x3137: 0x1103, // ㄷ → ᄃ
            0x3138: 0x1104, // ㄸ → ᄄ
            0x3139: 0x1105, // ㄹ → ᄅ
            0x3141: 0x1106, // ㅁ → ᄆ
            0x3142: 0x1107, // ㅂ → ᄇ
            0x3143: 0x1108, // ㅃ → ᄈ
            0x3145: 0x1109, // ㅅ → ᄉ
            0x3146: 0x110A, // ㅆ → ᄊ
            0x3147: 0x110B, // ㅇ → ᄋ
            0x3148: 0x110C, // ㅈ → ᄌ
            0x3149: 0x110D, // ㅉ → ᄍ
            0x314A: 0x110E, // ㅊ → ᄎ
            0x314B: 0x110F, // ㅋ → ᄏ
            0x314C: 0x1110, // ㅌ → ᄐ
            0x314D: 0x1111, // ㅍ → ᄑ
            0x314E: 0x1112, // ㅎ → ᄒ
            // Vowels (ㅏ..ㅣ)
            0x314F: 0x1161, // ㅏ → ᅡ
            0x3150: 0x1162, // ㅐ → ᅢ
            0x3151: 0x1163, // ㅑ → ᅣ
            0x3152: 0x1164, // ㅒ → ᅤ
            0x3153: 0x1165, // ㅓ → ᅥ
            0x3154: 0x1166, // ㅔ → ᅦ
            0x3155: 0x1167, // ㅕ → ᅧ
            0x3156: 0x1168, // ㅖ → ᅨ
            0x3157: 0x1169, // ㅗ → ᅩ
            0x3158: 0x116A, // ㅘ → ᅪ
            0x3159: 0x116B, // ㅙ → ᅫ
            0x315A: 0x116C, // ㅚ → ᅬ
            0x315B: 0x116D, // ㅛ → ᅭ
            0x315C: 0x116E, // ㅜ → ᅮ
            0x315D: 0x116F, // ㅝ → ᅯ
            0x315E: 0x1170, // ㅞ → ᅰ
            0x315F: 0x1171, // ㅟ → ᅱ
            0x3160: 0x1172, // ㅠ → ᅲ
            0x3161: 0x1173, // ㅡ → ᅳ
            0x3162: 0x1174, // ㅢ → ᅴ
            0x3163: 0x1175  // ㅣ → ᅵ
        ]
        
        var out = String.UnicodeScalarView()
        let lower = s.lowercased()
        
        for scalar in lower.unicodeScalars {
            let v = scalar.value
            
            // Hangul syllables (가..힣)
            if v >= SBase && v <= SBase + SCount - 1 {
                let sIndex = v - SBase
                let lIndex = sIndex / (VCount * TCount)
                let vIndex = (sIndex % (VCount * TCount)) / TCount
                let tIndex = sIndex % TCount
                if let L = UnicodeScalar(LBase + lIndex) { out.append(L) }
                if let V = UnicodeScalar(VBase + vIndex) { out.append(V) }
                if tIndex > 0, let T = UnicodeScalar(TBase + tIndex) { out.append(T) }
                continue
            }
            
            // Compatibility jamo → modern jamo
            if let mapped = compToModern[v], let u = UnicodeScalar(mapped) {
                out.append(u)
                continue
            }
            
            // ASCII letters/digits: keep
            if ("0"..."9").contains(String(scalar)) || ("a"..."z").contains(String(scalar)) {
                out.append(scalar)
                continue
            }
            
            // Skip spaces/punctuations/others
        }
        
        return String(out)
    }
    
    /// Returns true if `small`'s scalars appear in order inside `big` (not necessarily contiguously).
    private static func isSubsequence(_ small: String, in big: String) -> Bool {
        if small.isEmpty { return true }
        var it = small.unicodeScalars.makeIterator()
        var need = it.next()
        for s in big.unicodeScalars {
            if s == need {
                need = it.next()
                if need == nil { return true }
            }
        }
        return false
    }
}
