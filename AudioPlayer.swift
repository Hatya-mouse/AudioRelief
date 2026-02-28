//
//  AudioPlayer.swift
//  AudioRelief
//
//  Created by Kasatani Shuntaro on 2026/02/26.
//

import Foundation
import AVFoundation
import CoreAudio
import Synchronization

class AudioPlayer {
    let audioEngine: AVAudioEngine
    let audioFormat: AVAudioFormat
    let mixerNode: AVAudioMixerNode
    let outputNode: AVAudioOutputNode
    
    let dimension: SIMD2<Int>
    let heightMapPointer: UnsafePointer<Float>
    
    let sampleRate: Float = 44100.0
    let deltaTime: Float
    
    let frequencies: PointerPair<Float>
    
    var isStopping: Bool
    var playhead: Float
    
    init(dimension: SIMD2<Int>, pointer: UnsafePointer<Float>) {
        self.audioEngine = AVAudioEngine()
        self.audioFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: Double(self.sampleRate), channels: 1, interleaved: true)!
        self.mixerNode = self.audioEngine.mainMixerNode
        self.outputNode = self.audioEngine.outputNode
        
        self.dimension = dimension
        self.heightMapPointer = pointer
        
        self.deltaTime = 1.0 / self.sampleRate
        
        self.frequencies = PointerPair(.allocate(capacity: dimension.x), .allocate(capacity: dimension.x))
        
        self.isStopping = false
        self.playhead = 0
        
        self.updateFrequencies()
    }
    
    func play() {
        var time: Float = 0.0
        var phase: Float = 0.0
        var volume: Float = 0.0

        // Create a render block to generate sound
        let renderBlock: AVAudioSourceNodeRenderBlock = { [weak self] (_, _, frameCount, audioBufferList) -> OSStatus in
            guard let self = self else { return noErr }
            let listPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            
            for frame in 0..<Int(frameCount) {
                let frequency = self.interpolateFrequency(self.playhead)
                let sample = self.getSample(phase: phase) * volume
                
                if self.isStopping {
                    volume = volume * 0.99
                } else if volume < 0.5 {
                    volume = volume * 0.99 + 0.5 * 0.01
                }
                
                for buffer in listPointer {
                    let bufferPointer: UnsafeMutableBufferPointer<Float> = UnsafeMutableBufferPointer(buffer)
                    bufferPointer[frame] = sample
                }
                
                let deltaPhase = frequency / self.sampleRate
                phase = (phase + deltaPhase).truncatingRemainder(dividingBy: 1)
                self.playhead = (self.playhead + 0.00001).truncatingRemainder(dividingBy: 1)
                time += self.deltaTime
            }
            return noErr
        }
        
        // Create an AVAudioSourceNode for generating sound
        let sourceNode = AVAudioSourceNode(renderBlock: renderBlock)
        
        // Create the format
        let inputFormat = outputNode.inputFormat(forBus: 0)
        
        // Attach the node to the engine
        audioEngine.attach(sourceNode)
        audioEngine.connect(sourceNode, to: mixerNode, format: inputFormat)
        audioEngine.connect(mixerNode, to: outputNode, format: nil)
        
        try? audioEngine.start()
    }
    
    func updateFrequencies() {
        let writable = frequencies.getWritablePointer()
        for row in 0..<dimension.x {
            writable[row] = getFrequencyOf(row)
        }
        frequencies.swap()
    }
    
    @MainActor
    func pause() {
        self.isStopping = true
        Task {
            try? await Task.sleep(nanoseconds: 50_000_000)
            
            self.isStopping = false
            self.audioEngine.stop()
            
            self.audioEngine.disconnectNodeInput(self.audioEngine.mainMixerNode)
            self.audioEngine.disconnectNodeInput(self.audioEngine.outputNode)
        }
    }
    
    func getFrequencyOf(_ row: Int) -> Float {
        let start = getIndex(row, 0)
        let buffer = UnsafeBufferPointer(start: heightMapPointer.advanced(by: start), count: dimension.x)
        let average = buffer.reduce(0.0, +) / Float(dimension.x)
        return average * 1000
    }
    
    func getIndex(_ row: Int, _ col: Int) -> Int {
        return col + row * dimension.x
    }
    
    func interpolateFrequency(_ rowPhase: Float) -> Float {
        let freqs = frequencies.getReadablePointer()
        let rowFactor = rowPhase.truncatingRemainder(dividingBy: 1)
        let firstRowFrequency = freqs[Int(floor(rowPhase * Float(dimension.y - 1)))]
        let secondRowFrequency = freqs[Int(ceil(rowPhase * Float(dimension.y - 1)))]
        let interpolatedFrequency = firstRowFrequency.addingProduct(rowFactor, secondRowFrequency - firstRowFrequency)
        return interpolatedFrequency
    }
    
    func getSample(phase: Float) -> Float {
        let rowFactor = playhead.truncatingRemainder(dividingBy: 1)
        let phaseFactor = phase.truncatingRemainder(dividingBy: 1)

        let firstRowIndex = Int(floor(playhead * Float(dimension.y - 1)))
        let secondRowIndex = Int(ceil(playhead * Float(dimension.y - 1)))
        let firstPhaseIndex = Int(floor(phase * Float(dimension.x - 1)))
        let secondPhaseIndex = Int(ceil(phase * Float(dimension.x - 1)))

        let firstRowFirst = heightMapPointer[getIndex(firstRowIndex, firstPhaseIndex)]
        let firstRowSecond = heightMapPointer[getIndex(firstRowIndex, secondPhaseIndex)]
        let secondRowFirst = heightMapPointer[getIndex(secondRowIndex, firstPhaseIndex)]
        let secondRowSecond = heightMapPointer[getIndex(secondRowIndex, secondPhaseIndex)]

        let firstRow = firstRowFirst.addingProduct(phaseFactor, firstRowSecond - firstRowFirst)
        let secondRow = secondRowFirst.addingProduct(phaseFactor, secondRowSecond - secondRowFirst)

        return firstRowFirst.addingProduct(rowFactor, firstRow - secondRow)
    }
}
