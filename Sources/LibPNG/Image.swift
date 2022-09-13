@_implementationOnly import CPNG

public struct PNGImage {
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
    
    public internal(set) var width: Int
    public internal(set) var height: Int
    public internal(set) var colorType: ColorType
    public internal(set) var bitDepth: Int
    public internal(set) var pixelData: [UInt8]
    
    @_transparent
    var rowByteCount: Int {
        width * colorType.componentCount * bitDepth / 8
    }
    
    @_transparent
    func assertValidSize() throws {
        guard pixelData.count == height * rowByteCount else {
            throw PNGError.incorrectDataSize
        }
    }
    
    public subscript(x: Int, y: Int) -> UInt8 {
        _read { yield pixelData[y * rowByteCount + x] }
        _modify { yield &pixelData[y * rowByteCount + x] }
    }
    
    public init(width: Int, height: Int, colorType: ColorType, bitDepth: Int, pixelData: [UInt8]) throws {
        self.width = width
        self.height = height
        self.colorType = colorType
        self.bitDepth = bitDepth
        self.pixelData = pixelData
        try assertValidSize()
    }
    
    public init<T: BinaryFloatingPoint>(width: Int, height: Int, colorType: ColorType, pixelData: [T]) throws {
        try self.init(width: width, height: height, colorType: colorType, bitDepth: 8, pixelData: pixelData.map { sample in
            UInt8(sample * T(UInt8.max))
        })
    }
    
    @_transparent
    init(path: String, setIO: (png_structp?, png_infop?, () throws -> Void) throws -> Void, finalize: ((png_structp?, png_infop?, () throws -> Void) throws -> Void)? = nil) throws {
        /* adapted from https://gist.github.com/niw/5963798 */
        typealias ErrorPair = (path: String, error: PNGError?)
        var error: ErrorPair = (path, nil)
        
        let catchError: png_error_ptr = { png, description in
            png_get_error_ptr(png).withMemoryRebound(to: ErrorPair.self, capacity: 1) { pointer in
                pointer.pointee.error = .readError(path: pointer.pointee.path, description: description.map(String.init(cString:)))
            }
        }
        let catchWarn: png_error_ptr = { png, description in
            print("[PNG] \(String(cString: description!))")
        }
        
        @_transparent
        func assertNoError() throws {
            if let error = error.error {
                throw error
            }
        }
        
        var png = png_create_read_struct(PNG_LIBPNG_VER_STRING, &error, catchError, catchWarn)
        guard png != nil else {
            throw PNGError.unableToOpenFile(error.path)
        }
        
        var info = png_create_info_struct(png)
        guard info != nil else { throw error.error! }
        defer { png_destroy_read_struct(&png, &info, nil) }
        try setIO(png, info, assertNoError)
        
        png_read_info(png, info)
        try assertNoError()
        
        self.width = Int(png_get_image_width(png, info))
        self.height = Int(png_get_image_height(png, info))
        self.colorType = ColorType(rawValue: png_get_color_type(png, info))!
        self.bitDepth = Int(png_get_bit_depth(png, info))
        
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
        
        self.pixelData = UnsafeMutableBufferPointer(start: rows, count: height).flatMap { row in
            Array(UnsafeMutableBufferPointer(start: row, count: rowbytes))
        }
        
        try finalize?(png, info, assertNoError)
    }
    
    public init(contentsOf path: some StringProtocol) throws {
        let path = String(path)
        guard let fp = fopen(path, "rb") else {
            throw PNGError.unableToOpenFile(String(path))
        }
        try self.init(path: path) { png, info, assertNoError in
            png_init_io(png, fp)
        } finalize: { _, _, _ in
            fclose(fp)
        }
    }
    
    @_transparent
    func write(path: String, setIO: (png_structp?, png_infop?, () throws -> Void) throws -> Void, finalize: ((png_structp?, png_infop?, () throws -> Void) throws -> Void)? = nil) throws {
        /* adapted from https://gist.github.com/niw/5963798 */
        typealias ErrorPair = (path: String, error: PNGError?)
        var error: ErrorPair = (path, nil)
        
        let catchError: png_error_ptr = { png, description in
            png_get_error_ptr(png).withMemoryRebound(to: ErrorPair.self, capacity: 1) { pointer in
                pointer.pointee.error = .readError(path: pointer.pointee.path, description: description.map(String.init(cString:)))
            }
        }
        let catchWarn: png_error_ptr = { png, description in
            print("[PNG] \(String(cString: description!))")
        }
        
        @_transparent
        func assertNoError() throws {
            if let error = error.error {
                throw error
            }
        }
        
        var png = png_create_write_struct(PNG_LIBPNG_VER_STRING, &error, catchError, catchWarn)
        guard png != nil else {
            throw PNGError.unableToOpenFile(error.path)
        }
        
        var info = png_create_info_struct(png)
        guard info != nil else { throw error.error! }
        defer { png_destroy_write_struct(&png, &info) }
        try setIO(png, info, assertNoError)
        
        png_set_IHDR(png,
                     info,
                     .init(width),
                     .init(height),
                     .init(bitDepth),
                     .init(colorType.rawValue),
                     PNG_INTERLACE_NONE,
                     PNG_COMPRESSION_TYPE_DEFAULT,
                     PNG_FILTER_TYPE_DEFAULT)
        
        png_write_info(png, info)
        
        let rows = UnsafeMutableBufferPointer<UnsafeMutablePointer<png_byte>?>.allocate(capacity: height)
        
        let rowByteCount = self.rowByteCount
        for y in 0 ..< height {
            let i = y * rowByteCount
            let row = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: rowByteCount)
            _ = row.initialize(from: pixelData[i ..< i+rowByteCount])
            rows[y] = row.baseAddress
        }
        
        png_write_image(png, rows.baseAddress)
        png_write_end(png, info)
        
        try finalize?(png, info, assertNoError)
    }
    
    public func write(to path: String) throws {
        guard let fp = fopen(path, "wb") else {
            throw PNGError.unableToOpenFile(path)
        }
        try self.write(path: path) { png, info, assertNoError in
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
        
        try self.init(path: "Data") { png, info, assertNoError in
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
        data.reserveCapacity(pixelData.count)
        
        try self.write(path: "Data") { png, info, assertNoError in
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
