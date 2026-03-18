//
//  BufferPair.swift
//  AudioRelief
//
//  Created by Kasatani Shuntaro on 2026/02/28.
//

import SwiftUI
import Metal

class MTLBufferPair {
    let pointer: PointerPair<Float>
    var bufferA: any MTLBuffer
    var bufferB: any MTLBuffer
    
    init(_ a: any MTLBuffer, _ b: any MTLBuffer, capacity: Int) {
        let pointerA = a.contents().bindMemory(to: Float.self, capacity: capacity)
        let pointerB = b.contents().bindMemory(to: Float.self, capacity: capacity)
        self.pointer = PointerPair(pointerA, pointerB)
        self.bufferA = a
        self.bufferB = b
    }
    
    private func getBuffer(_ active: Int) -> any MTLBuffer {
        return active == 0 ? bufferA : bufferB
    }
    
    func getReadableBuffer() -> any MTLBuffer {
        let writable = pointer.writablePointer.load(ordering: .acquiring)
        return getBuffer(1 - writable)
    }
    
    func getWritableBuffer() -> any MTLBuffer {
        let writable = pointer.writablePointer.load(ordering: .acquiring)
        return getBuffer(writable)
    }
    
    func replaceBuffer(_ buffer: any MTLBuffer, capacity: Int) {
        let writable = pointer.writablePointer.load(ordering: .acquiring)
        if writable == 0 {
            self.bufferA = buffer
            self.pointer.pointerA = buffer.contents().bindMemory(to: Float.self, capacity: capacity)
        } else {
            self.bufferB = buffer
            self.pointer.pointerB = buffer.contents().bindMemory(to: Float.self, capacity: capacity)
        }
    }
    
    /// Swaps the pointer and sync the buffer content.
    func swap() {
        pointer.swap()
        
        let readable = getReadableBuffer()
        let writable = getWritableBuffer()
        
        memcpy(writable.contents(), readable.contents(), readable.length)
    }
}
