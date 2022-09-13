# LibPNG

Swift API for libpng

## Usage

Install libpng and pkg-conf

On macOS using `brew`:
```bash
$ brew install pkgconfig libpng
```

On Linux, using `apt`:
```bash
$ sudo apt install pkgconfig libpng
```

### Reading

```swift
let image = try PNGImage(contentsOf: ".../image.png")
// or
let url = URL(string: "https://example.com/image.png")!
let image = try PNGImage(contentsOf: url)
// or
let data: Data = ...
let image = try PNGImage(data: data)
```

### Writing

```swift
let pixelData: [UInt8] = [...]
let image: PNGImage = try PNGImage(width: 64, height: 64, colorType: .rgba, bitDepth: 8, pixelData: pixelData)

try image.write(to: ".../image.png")
// or
let url = URL(string: "file://.../image.png")!
try image.write(to: url)
// or
var data = Data()
try image.write(to: &data)
```
