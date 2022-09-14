@_implementationOnly import CPNG

public struct PNGImage {
    public struct RGBA: Hashable, RawRepresentable, ExpressibleByIntegerLiteral {
        public var redBits: UInt8 = .min
        public var greenBits: UInt8 = .min
        public var blueBits: UInt8 = .min
        public var alphaBits: UInt8 = .max
        
        @usableFromInline func denormalize(_ v: Double) -> UInt8 {
            return UInt8(Double(UInt8.max) * v)
        }
        @usableFromInline func normalize(_ v: UInt8) -> Double {
            return Double(v) / Double(UInt8.max)
        }
        
        @inlinable public var red: Double {
            get { normalize(redBits) }
            set { redBits = denormalize(newValue) }
        }
        @inlinable public var green: Double {
            get { normalize(greenBits) }
            set { greenBits = denormalize(newValue) }
        }
        @inlinable public var blue: Double {
            get { normalize(blueBits) }
            set { blueBits = denormalize(newValue) }
        }
        @inlinable public var alpha: Double {
            get { normalize(alphaBits) }
            set { alphaBits = denormalize(newValue) }
        }
        
        @inlinable public var rawValue: UInt32 {
            unsafeBitCast(self, to: UInt32.self)
        }
        @inlinable public init(rawValue: UInt32) {
            self = unsafeBitCast(rawValue, to: Self.self)
        }
        @inlinable public init(integerLiteral value: UInt32) {
            self.init(rawValue: value)
        }
        
        @inlinable public init() {
            self = 0x000000FF
        }
        
        @inlinable public init(redBits: UInt8, greenBits: UInt8, blueBits: UInt8, alphaBits: UInt8 = .max) {
            self.redBits = redBits
            self.greenBits = greenBits
            self.blueBits = blueBits
            self.alphaBits = alphaBits
        }
        @inlinable public init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
            self.redBits = denormalize(red)
            self.greenBits = denormalize(green)
            self.blueBits = denormalize(blue)
            self.alphaBits = denormalize(alpha)
        }
        @inlinable public init(gray: Double, alpha: Double = 1.0) {
            self.init(red: gray, green: gray, blue: gray, alpha: alpha)
        }
        
        @inlinable public static func random(using generator: inout some RandomNumberGenerator) -> RGBA {
            return .init(rawValue: .random(in: .min ... .max, using: &generator))
        }
        @inlinable public static func random() -> RGBA {
            var generator = SystemRandomNumberGenerator()
            return .random(using: &generator)
        }
    }
    
    public enum ColorType: UInt8, RawRepresentable, CaseIterable {
        case gray = 0
        case rgb = 2
        case palette = 3
        case grayAlpha = 4
        case rgba = 6
        
        public var componentCount: Int {
            switch self {
            case .gray:
                return 1
            case .grayAlpha:
                return 2
            case .rgb:
                return 3
            case .rgba:
                return 4
            case .palette:
                return 1
            }
        }
    }
    
    public let width: Int
    public let height: Int
    public internal(set) var pixels: [RGBA]
    
    @_transparent
    func assertValidSize() throws {
        guard pixels.count == width * height else {
            throw PNGError.incorrectDataSize
        }
    }
    
    public subscript(x: Int, y: Int) -> RGBA {
        _read { yield pixels[y * width + x] }
        _modify { yield &pixels[y * width + x] }
    }
    
    public init(width: Int, height: Int, pixels: [RGBA]) throws {
        self.width = width
        self.height = height
        self.pixels = pixels
        try assertValidSize()
    }
    
    @_transparent
    init(setIO: (png_structp?, png_infop?, () throws -> Void) throws -> Void, finalize: ((png_structp?, png_infop?, () throws -> Void) throws -> Void)? = nil) throws {
        /* adapted from https://gist.github.com/niw/5963798 */
        var error: PNGError?
        
        let catchError: png_error_ptr = { png, description in
            png_get_error_ptr(png).withMemoryRebound(to: PNGError?.self, capacity: 1) { pointer in
                pointer.pointee = .readError(description: description.map(String.init(cString:)))
            }
        }
        let catchWarn: png_error_ptr = { png, description in
            print("[PNG] \(String(cString: description!))")
        }
        
        @_transparent
        func assertNoError() throws {
            if let error {
                throw error
            }
        }
        
        var png = png_create_read_struct(PNG_LIBPNG_VER_STRING, &error, catchError, catchWarn)
        guard png != nil else {
            throw PNGError.unableToOpenFile
        }
        
        var info = png_create_info_struct(png)
        guard info != nil else { throw error! }
        defer { png_destroy_read_struct(&png, &info, nil) }
        try setIO(png, info, assertNoError)
        
        png_read_info(png, info)
        try assertNoError()
        
        self.width = Int(png_get_image_width(png, info))
        self.height = Int(png_get_image_height(png, info))
        
        let colorType = ColorType(rawValue: png_get_color_type(png, info))!
        let bitDepth = Int(png_get_bit_depth(png, info))
        
        if bitDepth == 16 { png_set_strip_16(png) }
        if colorType == .palette { png_set_palette_to_rgb(png) }
        if colorType == .gray && bitDepth < 8 { png_set_expand_gray_1_2_4_to_8(png) }
        
        if png_get_valid(png, info, PNG_INFO_tRNS) != 0 { png_set_tRNS_to_alpha(png) }
        
        switch colorType {
        case .rgb, .gray, .palette:
            png_set_filler(png, 0xFF, PNG_FILLER_AFTER)
        default:
            break
        }
        
        if colorType == .gray || colorType == .grayAlpha {
            png_set_gray_to_rgb(png)
        }
        
        png_read_update_info(png, info)
        try assertNoError()
        
        let rows = UnsafeMutablePointer<UnsafeMutablePointer<png_byte>?>.allocate(capacity: height)
        let rowbytes = png_get_rowbytes(png, info)
        for y in 0 ..< height {
            rows[y] = png_bytep.allocate(capacity: rowbytes)
        }
        
        png_read_image(png, rows)
        try assertNoError()
        
        self.pixels = UnsafeMutableBufferPointer(start: rows, count: height).flatMap { row in
            UnsafeMutableBufferPointer(start: row, count: rowbytes).withMemoryRebound(to: RGBA.self, Array.init)
        }
        
        try finalize?(png, info, assertNoError)
    }
    
    public init(contentsOf path: some StringProtocol) throws {
        let path = String(path)
        guard let fp = fopen(path, "rb") else {
            throw PNGError.unableToOpenFile
        }
        try self.init { png, info, assertNoError in
            png_init_io(png, fp)
        } finalize: { _, _, _ in
            fclose(fp)
        }
    }
    
    func write(setIO: (png_structp?, png_infop?, () throws -> Void) throws -> Void, finalize: ((png_structp?, png_infop?, () throws -> Void) throws -> Void)? = nil) throws {
        /* adapted from https://gist.github.com/niw/5963798 */
        var error: PNGError?
        
        let catchError: png_error_ptr = { png, description in
            png_get_error_ptr(png).withMemoryRebound(to: PNGError?.self, capacity: 1) { pointer in
                pointer.pointee = .readError(description: description.map(String.init(cString:)))
            }
        }
        let catchWarn: png_error_ptr = { png, description in
            print("[PNG] \(String(cString: description!))")
        }
        
        @_transparent
        func assertNoError() throws {
            if let error {
                throw error
            }
        }
        
        var png = png_create_write_struct(PNG_LIBPNG_VER_STRING, &error, catchError, catchWarn)
        guard png != nil else {
            throw PNGError.unableToOpenFile
        }
        
        var info = png_create_info_struct(png)
        guard info != nil else { throw error! }
        defer { png_destroy_write_struct(&png, &info) }
        try setIO(png, info, assertNoError)
        
        png_set_IHDR(png,
                     info,
                     .init(width),
                     .init(height),
                     8,
                     .init(ColorType.rgba.rawValue),
                     PNG_INTERLACE_NONE,
                     PNG_COMPRESSION_TYPE_DEFAULT,
                     PNG_FILTER_TYPE_DEFAULT)
        
        png_write_info(png, info)
        
        let rows = UnsafeMutableBufferPointer<UnsafeMutablePointer<png_byte>?>.allocate(capacity: height)
        
        for y in 0 ..< height {
            let i = y * width
            let row = UnsafeMutableBufferPointer<RGBA>.allocate(capacity: width)
            _ = row.initialize(from: pixels[i ..< i+width])
            row.withMemoryRebound(to: png_byte.self) { row in
                rows[y] = row.baseAddress
            }
        }
        
        png_write_image(png, rows.baseAddress)
        png_write_end(png, info)
        
        try finalize?(png, info, assertNoError)
    }
    
    public func write(to path: some StringProtocol) throws {
        let path = String(path)
        guard let fp = fopen(path, "wb") else {
            throw PNGError.unableToOpenFile
        }
        try self.write { png, info, assertNoError in
            png_init_io(png, fp)
        } finalize: { _, _, _ in
            fclose(fp)
        }
    }
}

#if canImport(Foundation)
import Foundation

extension PNGImage {
    public init(data: Data) throws {
        var reader = data.makeIterator()
        
        try self.init { png, info, assertNoError in
            png_set_read_fn(png, &reader) { png, bytes, byteCount in
                png_get_io_ptr(png).withMemoryRebound(to: Data.Iterator.self, capacity: 1) { pointer in
                    for i in 0 ..< byteCount {
                        bytes?[i] = pointer.pointee.next() ?? .zero
                    }
                }
            }
        } finalize: { png, info, assertNoError in
            png_set_read_fn(png, nil, nil)
        }
    }
}

extension PNGImage {
    public init(contentsOf url: URL) throws {
        let data = try Data(contentsOf: url)
        try self.init(data: data)
    }
}

extension PNGImage {
    public func write(to data: inout Data) throws {
        data.reserveCapacity(pixels.count * MemoryLayout<RGBA>.size)
        
        try self.write { png, info, assertNoError in
            png_set_write_fn(png, &data) { png, bytes, byteCount in
                png_get_io_ptr(png).withMemoryRebound(to: Data.self, capacity: 1) { pointer in
                    pointer.pointee.append(bytes!, count: byteCount)
                }
            } _: { _ in }
        } finalize: { png, info, assertNoError in
            png_set_write_fn(png, nil, nil, nil)
        }
    }
}

extension PNGImage {
    public func write(to url: URL) throws {
        var data = Data()
        try self.write(to: &data)
        try data.write(to: url)
    }
}
#endif
