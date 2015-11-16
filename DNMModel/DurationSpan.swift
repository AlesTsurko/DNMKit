//
//  DurationSpan.swift
//  denm_model
//
//  Created by James Bean on 8/28/15.
//  Copyright © 2015 James Bean. All rights reserved.
//

import Foundation

/**
Span between two Durations
*/
public struct DurationSpan: CustomStringConvertible {
    
    public var description: String { get { return getDescription() } }
    
    public var startDuration: Duration = DurationZero
    public var stopDuration: Duration = DurationZero
    public var duration: Duration = DurationZero
    
    public init() { }
    
    /**
    Create a DurationSpan with two Durations, which do not have to be in order.
    
    - parameter duration:      One Duration
    - parameter otherDuration: Another Duration
    
    - returns: DurationSpan
    */
    public init(duration: Duration, andAnotherDuration otherDuration: Duration) {
        let durations: [Duration] = [duration, otherDuration].sort(<)
        self.startDuration = durations.first!
        self.stopDuration = durations.last!
        self.duration = stopDuration - startDuration
    }
    
    /**
    Create a DurationSpan with two Durations (the first being before the second)
    
    - parameter startDuration: Duration to start the DurationSpan
    - parameter stopDuration:  Duration to stop the DurationSpan
    
    - returns: DurationSpan
    */
    public init(startDuration: Duration, stopDuration: Duration) {
        self.startDuration = startDuration
        self.stopDuration = stopDuration
        self.duration = stopDuration - startDuration
    }
    
    /**
    Create a DurationSpan with the total Duration and a start Duration
    
    - parameter duration:      Total Duration of DurationSpan
    - parameter startDuration: Duration to start the DurationSpan
    
    - returns: DurationSpan
    */
    public init(duration: Duration, startDuration: Duration) {
        self.duration = duration
        self.startDuration = startDuration
        self.stopDuration = duration + startDuration
    }
    
    /**
    Get the DurationSpanRelationship between this DurationSpan and another DurationSpan.
    The possible relationships are: .None, .Adjacent, and .Overlapping.
    
    - parameter durationSpan: DurationSpan to compare with this DurationSpan
    
    - returns: DurationSpanRelationship (.None, .Adjacent, .Overlapping)
    */
    public func relationShipWithDurationSpan(durationSpan: DurationSpan) -> DurationSpanRelationship {
        if startDuration < durationSpan.startDuration {
            if stopDuration < durationSpan.startDuration { return .None }
            else if stopDuration > durationSpan.startDuration { return .Overlapping }
            else { return .Adjacent }
            }
            else if durationSpan.startDuration < startDuration {
                if durationSpan.stopDuration < startDuration { return .None }
            else if durationSpan.stopDuration > startDuration { return .Overlapping }
            else { return .Adjacent }
        }
        else { return .Overlapping }
    }
    
    private func getDescription() -> String {
        return "start: \(startDuration); stop: \(stopDuration); total: \(duration)"
    }
}

// MAKE EXTENSION
public func makeDurationSpanWithDurationNodes(durationNodes: [DurationNode]) -> DurationSpan {
    if durationNodes.count == 0 { return DurationSpan() }
    else {
        let nds = durationNodes
        let startDuration = nds.sort({
            $0.durationSpan.startDuration < $1.durationSpan.startDuration
        }).first!.durationSpan.startDuration
        let stopDuration = nds.sort({
            $0.durationSpan.stopDuration > $1.durationSpan.stopDuration
        }).first!.durationSpan.stopDuration
        return DurationSpan(startDuration: startDuration, stopDuration: stopDuration)
    }
}


public enum DurationSpanRelationship {
    case None, Adjacent, Overlapping
}

extension Duration {
    public func isInDurationSpan(durationSpan: DurationSpan) -> Bool {
        return self >= durationSpan.startDuration && self <= durationSpan.stopDuration
    }
}