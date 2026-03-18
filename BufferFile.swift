//
//  BufferFile.swift
//  AudioRelief
//
//  Created by Kasatani Shuntaro on 2026/02/28.
//

import SwiftUI
import UniformTypeIdentifiers
@preconcurrency import Metal

struct BufferHeader {
    var width: UInt32
    var height: UInt32
    var byteLength: UInt64
}

struct BufferFile: FileDocument {
    static let readableContentTypes: [UTType] = [UTType.data]
    
    var data: Data
    
    init() {
        self.data = Data()
    }
    
    init(data: Data) {
        self.data = data
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw NSError(domain: "LoadError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No data found."])
        }
        self.data = data
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: data)
    }
    
    func loadData(device: MTLDevice) throws -> any MTLBuffer {
        // Get the header
        let headerSize = MemoryLayout<BufferHeader>.size
        let bufferSize = meshDimension.x * meshDimension.y * MemoryLayout<Float>.size
        let expectedSize = headerSize + bufferSize
        
        if data.count != expectedSize {
            throw NSError(domain: "LoadError", code: 1, userInfo: [NSLocalizedDescriptionKey: "File size is invalid."])
        }
        
        let header = data.withUnsafeBytes { pointer in
            pointer.load(as: BufferHeader.self)
        }
        // If the dimensions doesn't not match, throw an error
        if header.width != meshDimension.x || header.height != meshDimension.y {
            throw NSError(domain: "LoadError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Dimension does not match."])
        }
        
        // Take the buffer part
        let bufferData = data.subdata(in: headerSize..<data.count)
        guard let buffer = bufferData.withUnsafeBytes({ pointer in
            device.makeBuffer(
                bytes: pointer.baseAddress!,
                length: bufferData.count,
                options: .storageModeShared
            )
        }) else {
            throw NSError(domain: "LoadError", code: 1, userInfo: [NSLocalizedDescriptionKey: "makeBuffer failed."])
        }
        
        return buffer
    }
    
    static func prepareExportData(device: MTLDevice, buffer: any MTLBuffer) -> Data {
        // Create a header which stores some capacity informations
        var header = BufferHeader(
            width: UInt32(meshDimension.x),
            height: UInt32(meshDimension.y),
            byteLength: UInt64(buffer.length)
        )
        // Create a data
        var data = Data(bytes: &header, count: MemoryLayout<BufferHeader>.size)
        let bufferData = Data(bytes: buffer.contents(), count: buffer.length)
        data.append(bufferData)
        
        return data
    }
}
