/* Copyright 2018 The KrakenCL Authors. All Rights Reserved.
 
 Created by Volodymyr Pavliukevych
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import XCTest
@testable import LibPNG

final class LibPNGTests: XCTestCase {
    func testInitSolidColorImage() {
        XCTAssertNoThrow(try PNGImage(width: 800, height: 600, pixels: .init(repeating: 0x000000FF, count: 800*600)))
        XCTAssertNoThrow(try PNGImage(width: 800, height: 600, pixels: .init(repeating: 0x7F7F7FFF, count: 800*600)))
        XCTAssertNoThrow(try PNGImage(width: 800, height: 600, pixels: .init(repeating: 0xFFFFFFFF, count: 800*600)))
    }
    
    func testReadWrite() {
        let path = "/tmp/randimage.png"
        
        let imageData = (0 ..< 64*64).map { _ in
            PNGImage.RGBA.random()
        }
        let image = try? PNGImage(width: 64, height: 64, pixels: imageData)
        XCTAssertNotNil(image)
        XCTAssertNoThrow(try image!.write(to: path))
        
        let read = try? PNGImage(contentsOf: path)
        XCTAssertNotNil(read)
        XCTAssertEqual(imageData, read!.pixels)
    }
    
    func testReadWriteURL() {
        let url = URL(string: "file:///tmp/randimage_url.png")!
        
        let imageData = (0 ..< 64*64).map { _ in
            PNGImage.RGBA.random()
        }
        let image = try? PNGImage(width: 64, height: 64, pixels: imageData)
        XCTAssertNotNil(image)
        XCTAssertNoThrow(try image!.write(to: url))
        
        let read = try? PNGImage(contentsOf: url)
        XCTAssertNotNil(read)
        XCTAssertEqual(imageData, read!.pixels)
    }
    
    func testRemoteRead() {
        let url = "https://www.google.com/images/branding/googlelogo/2x/googlelogo_light_color_272x92dp.png"
        XCTAssertThrowsError(try PNGImage(contentsOf: url))
    }
    
    func testRemoteReadFromURL() {
        let url = URL(string: "https://www.google.com/images/branding/googlelogo/2x/googlelogo_light_color_272x92dp.png")!
        XCTAssertNoThrow(try PNGImage(contentsOf: url))
    }
    
    static var allTests = [
        ("testInitSolidColorImage", testInitSolidColorImage),
        ("testReadWrite", testReadWrite),
        ("testReadWriteURL", testReadWriteURL),
        ("testRemoteRead", testRemoteRead),
        ("testRemoteReadFromURL", testRemoteReadFromURL),
    ]
}


