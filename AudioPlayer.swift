//
//  AudioPlayer.swift
//  AudioRelief
//
//  Created by Kasatani Shuntaro on 2026/02/26.
//

import Foundation
import AVFoundation
import CoreAudio

class AudioPlayer {
    let audioEngine: AVAudioEngine
    let audioFormat: AVAudioFormat
    
    let dimension: SIMD2<Int>
    let heightMap: UnsafeMutablePointer<Float>
    
    let sampleRate: Float = 44100.0
    let deltaTime: Float
    
    let harmonyDepth: Int = 5
    let voiceNumber: Int
    var harmony: [[(Float, Float)]] = []
    
    var isStopping: UnsafeMutablePointer<Bool>
    var playhead: UnsafeMutablePointer<Float>
    
    init(dimension: SIMD2<Int>, buffer: any MTLBuffer) {
        self.audioEngine = AVAudioEngine()
        self.audioFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: Double(self.sampleRate), channels: 1, interleaved: true)!
        self.dimension = dimension
        
        let capacity = dimension.x * dimension.y * MemoryLayout<Float>.size
        self.heightMap = buffer.contents().bindMemory(to: Float.self, capacity: capacity)
        self.deltaTime = 1.0 / self.sampleRate
        
        self.voiceNumber = harmonyDepth * 2 + 1
        
        self.isStopping = .allocate(capacity: 1)
        self.isStopping.pointee = false
        
        self.playhead = .allocate(capacity: 1)
        self.playhead.pointee = 0.0
        
        self.updateFrequencies()
    }
    
    func play() {
        let capacity = dimension.x * dimension.y
        let heightMap = Array(UnsafeBufferPointer(start: self.heightMap, count: capacity))
        
        let dimension = self.dimension
        let sampleRate = self.sampleRate
        let deltaTime = self.deltaTime
        
        let harmony = self.harmony
        let voiceNumber = self.voiceNumber
        
        let playhead = self.playhead
        let isStopping = self.isStopping
        
        var time: Float = 0.0
        var phases: [Float] = [Float](repeating: 0, count: voiceNumber)
        var masterVolume: Float = 0.0
    
        // Create a render block to generate sound
        let renderBlock: AVAudioSourceNodeRenderBlock = { (_, _, frameCount, audioBufferList) -> OSStatus in
            let listPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            
            for frame in 0..<Int(frameCount) {
//                let frequency = AudioPlayer.interpolateFrequency(playhead.pointee, harmony: harmony, dim: dimension)
                let currentHarmony = harmony[Int(floor(playhead.pointee))]
                var sample: Float = 0
                
                if isStopping.pointee {
                    masterVolume = masterVolume * 0.95
                } else if masterVolume < 1.0 {
                    masterVolume = masterVolume * 0.95 + 0.5 * 0.05
                }
                
                for voiceIndex in 0..<voiceNumber {
                    let (frequency, voiceVolume) = currentHarmony[voiceIndex]
                    let volume = masterVolume * voiceVolume
                    if phases[voiceIndex].isNaN {
                        print("NAN LMAO")
                    }
                    sample += AudioPlayer.getSample(heightMap: heightMap, playhead: playhead.pointee, phase: phases[voiceIndex], dim: dimension) * volume
                    
                    let deltaPhase = frequency / sampleRate
                    phases[voiceIndex] = (phases[voiceIndex] + deltaPhase).truncatingRemainder(dividingBy: 1)
                }
                
                sample /= Float(voiceNumber)
                for buffer in listPointer {
                    let bufferPointer: UnsafeMutableBufferPointer<Float> = UnsafeMutableBufferPointer(buffer)
                    bufferPointer[frame] = sample
                }
                
                playhead.pointee = (playhead.pointee + 0.00001).truncatingRemainder(dividingBy: 1)
                time += deltaTime
            }
            return noErr
        }
        // Create an AVAudioSourceNode for generating sound
        let sourceNode = AVAudioSourceNode(renderBlock: renderBlock)
        
        // Create the format
        let inputFormat = audioEngine.outputNode.inputFormat(forBus: 0)
        
        // Attach the node to the engine
        audioEngine.attach(sourceNode)
        audioEngine.connect(sourceNode, to: audioEngine.mainMixerNode, format: inputFormat)
        audioEngine.connect(audioEngine.mainMixerNode, to: audioEngine.outputNode, format: nil)
        
        try? audioEngine.start()
    }
    
    func updateFrequencies() {
        harmony.removeAll()
        for row in 0..<dimension.x {
            harmony.append(getHarmony(row))
        }
    }
    
    @MainActor
    func pause() {
        self.isStopping.pointee = true
        Task {
            try? await Task.sleep(nanoseconds: 50_000_000)
            
            self.isStopping.pointee = false
            self.audioEngine.stop()
            
            self.audioEngine.disconnectNodeInput(self.audioEngine.mainMixerNode)
            self.audioEngine.disconnectNodeInput(self.audioEngine.outputNode)
        }
    }
    
    func getHarmony(_ row: Int) -> [(Float, Float)] {
        let start = AudioPlayer.getIndex(row, 0, width: dimension.x)
        let buffer = UnsafeBufferPointer(start: self.heightMap.advanced(by: start), count: dimension.x)
        let baseFreq = (buffer.reduce(0.0, +) / Float(dimension.x)) * 1000
        
        let subHarmonics = (1...harmonyDepth).reversed().map { i in baseFreq * (1.0 / Float(i)) }
        let harmonics = (1...harmonyDepth).map { i in baseFreq * Float(i) }
        let allFreqs = subHarmonics + [1] + harmonics
        
        var harmony: [(Float, Float)] = []
        let indexPerHarmony = dimension.x / voiceNumber
        for index in 0..<voiceNumber {
            let currentHeight = buffer[index * indexPerHarmony]
            harmony.append((allFreqs[index], currentHeight))
        }
        
        return harmony
    }
    
    static func getIndex(_ row: Int, _ col: Int, width rowWidth: Int) -> Int {
        return col + row * rowWidth
    }
    
//    static func interpolateFrequency(_ rowPhase: Float, harmony: [[Float: Float]], dim dimension: SIMD2<Int>) -> Float {
//        let rowFactor = rowPhase.truncatingRemainder(dividingBy: 1)
//        let firstRowFrequency = harmony[Int(floor(rowPhase * Float(dimension.y - 1)))]
//        let secondRowFrequency = harmony[Int(ceil(rowPhase * Float(dimension.y - 1)))]
//        let interpolatedFrequency = firstRowFrequency.addingProduct(rowFactor, secondRowFrequency - firstRowFrequency)
//        return interpolatedFrequency
//    }
    
    static func getSample(heightMap: [Float], playhead: Float, phase: Float, dim dimension: SIMD2<Int>) -> Float {
        let rowFactor = playhead.truncatingRemainder(dividingBy: 1)
        let phaseFactor = phase.truncatingRemainder(dividingBy: 1)

        let firstRowIndex = Int(floor(playhead * Float(dimension.y - 1)))
        let secondRowIndex = Int(ceil(playhead * Float(dimension.y - 1)))
        let firstPhaseIndex = Int(floor(phase * Float(dimension.x - 1)))
        let secondPhaseIndex = Int(ceil(phase * Float(dimension.x - 1)))

        let firstRowFirst = heightMap[getIndex(firstRowIndex, firstPhaseIndex, width: dimension.x)]
        let firstRowSecond = heightMap[getIndex(firstRowIndex, secondPhaseIndex, width: dimension.x)]
        let secondRowFirst = heightMap[getIndex(secondRowIndex, firstPhaseIndex, width: dimension.x)]
        let secondRowSecond = heightMap[getIndex(secondRowIndex, secondPhaseIndex, width: dimension.x)]

        let firstRow = firstRowFirst.addingProduct(phaseFactor, firstRowSecond - firstRowFirst)
        let secondRow = secondRowFirst.addingProduct(phaseFactor, secondRowSecond - secondRowFirst)

        return firstRowFirst.addingProduct(rowFactor, firstRow - secondRow)
    }
}
