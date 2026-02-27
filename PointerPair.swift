//
//  PointerPair.swift
//  AudioRelief
//
//  Created by Kasatani Shuntaro on 2026/02/27.
//

import Foundation
import Synchronization

class PointerPair<T> {
    let pointerA: UnsafeMutablePointer<T>
    let pointerB: UnsafeMutablePointer<T>
    private let writablePointer: Atomic<Int>
    
    init(_ a: UnsafeMutablePointer<T>, _ b: UnsafeMutablePointer<T>) {
        writablePointer = Atomic(0)
        pointerA = a
        pointerB = b
    }
    
    private func getPointer(_ active: Int) -> UnsafeMutablePointer<T> {
        return active == 0 ? pointerA : pointerB
    }
    
    func getReadablePointer() -> UnsafeMutablePointer<T> {
        let writable = writablePointer.load(ordering: .acquiring)
        return getPointer(1 - writable)
    }
    
    func getWritablePointer() -> UnsafeMutablePointer<T> {
        let writable = writablePointer.load(ordering: .acquiring)
        return getPointer(writable)
    }
    
    func swap() {
        writablePointer.bitwiseXor(1, ordering: .releasing)
    }
}
