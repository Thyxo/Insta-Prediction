// Minimal zip-læser (kun "stored" og "deflate"), så skrift-zip'en kan vælges direkte fra Filer.
// Bruger zip'ens centrale katalog (virker også når lokale headers har data descriptor, bit 3).
import Compression
import Foundation

enum ZipReader {
    struct Entry {
        let name: String
        let method: UInt16
        let compressedSize: Int
        let size: Int
        let localOffset: Int
    }

    static func entries(_ d: Data) -> [Entry] {
        let b = [UInt8](d)
        func u16(_ o: Int) -> Int { o + 1 < b.count ? Int(b[o]) | Int(b[o + 1]) << 8 : 0 }
        func u32(_ o: Int) -> Int { o + 3 < b.count ? u16(o) | u16(o + 2) << 16 : 0 }
        // End of central directory: signatur 0x06054b50 i de sidste ~64 KB
        var eocd = -1
        var i = b.count - 22
        while i >= max(0, b.count - 65_557) {
            if u32(i) == 0x0605_4b50 { eocd = i; break }
            i -= 1
        }
        guard eocd >= 0 else { return [] }
        let count = u16(eocd + 10)
        var p = u32(eocd + 16)
        var out: [Entry] = []
        for _ in 0..<count {
            guard u32(p) == 0x0201_4b50 else { break }
            let method = UInt16(u16(p + 10))
            let csize = u32(p + 20), size = u32(p + 24)
            let nlen = u16(p + 28), xlen = u16(p + 30), clen = u16(p + 32)
            let off = u32(p + 42)
            let name = String(decoding: b[(p + 46)..<min(b.count, p + 46 + nlen)], as: UTF8.self)
            out.append(Entry(name: name, method: method, compressedSize: csize, size: size, localOffset: off))
            p += 46 + nlen + xlen + clen
        }
        return out
    }

    static func extract(_ d: Data, _ e: Entry) -> Data? {
        let b = [UInt8](d)
        let o = e.localOffset
        guard o + 30 <= b.count, b[o] == 0x50, b[o + 1] == 0x4b, b[o + 2] == 3, b[o + 3] == 4 else { return nil }
        let nlen = Int(b[o + 26]) | Int(b[o + 27]) << 8
        let xlen = Int(b[o + 28]) | Int(b[o + 29]) << 8
        let start = o + 30 + nlen + xlen
        guard start + e.compressedSize <= b.count else { return nil }
        let comp = Array(b[start..<(start + e.compressedSize)])
        switch e.method {
        case 0:
            return Data(comp)
        case 8:
            var dst = [UInt8](repeating: 0, count: max(1, e.size))
            let n = comp.withUnsafeBufferPointer { src in
                compression_decode_buffer(&dst, dst.count, src.baseAddress!, comp.count, nil, COMPRESSION_ZLIB)
            }
            return n == e.size ? Data(dst) : nil
        default:
            return nil
        }
    }
}
