//
//  Parser.swift
//  DNMConverter
//
//  Created by James Bean on 11/9/15.
//  Copyright © 2015 James Bean. All rights reserved.
//

import Foundation
import DNMUtility
import DNMModel

public class Parser {
    
    /** 
    Manner in which the current DurationNode is placed in time
    - Measure: place DurationNode at beginning of current Measure
    - Increment: place DurationNode immediately after last DurationNode
    - Decrement: place DurationNode at beginning of last DurationNode
    */
    private var durationNodeStackMode: DurationNodeStackMode = .Measure
    
    /// Stack of DurationNodes, used to embed DurationNodes into other ones
    //private var durationNodeContainerStack = Stack<DurationNode>()
    
    // use instead of above
    private var durationNodeContainerStack = Stack<DurationNode>()
    
    /// Current DurationNodeLeaf which shall be decorated with Components
    private var currentDurationNodeLeaf: DurationNode?
    
    /// Offset of start of current measure from the beginning of the piece
    private var currentMeasureDurationOffset: Duration = DurationZero
    
    /// Offset of current location from beginning of current measure
    private var accumDurationInMeasure: Duration = DurationZero
    
    /// Offset of current DurationNode from beginning of the piece
    private var currentDurationNodeOffset: Duration = DurationZero
    
    /// Offset of current location from the beginning of the piece
    private var accumTotalDuration: Duration = DurationZero
    
    /// Depth of current DurationNode (in the case of embedded tuplets)
    private var currentDurationNodeDepth: Int = 0
    
    private var currentPerformerID: String?
    private var currentInstrumentID: String?
    
    /**
    Collection of InstrumentIDsWithInstrumentType, organized by PerformerID.
    These values ensure Performer order and Instrument order, 
    while making it still possible to call for this information by key identifiers.
    */
    private var instrumentIDAndInstrumentTypesByPerformerID = OrderedDictionary<
        String, OrderedDictionary<String, InstrumentType>
    >()
    
    // MARK: DNMScoreModel values
    
    private var title: String = ""
    private var durationNodes: [DurationNode] = []
    private var measures: [Measure] = []
    private var tempoMarkings: [TempoMarking] = []
    private var rehearsalMarkings: [RehearsalMarking] = []
    
    public init() { }
    
    public func parseTokenContainer(tokenContainer: TokenContainer) -> DNMScoreModel {
        
        for token in tokenContainer.tokens {
    
            if let container = token as? TokenContainer {
                switch container.identifier {
                case "PerformerDeclaration":
                    do { try managePerformerDeclarationTokenContainer(container) }
                    catch ParserError.InvalidInstrumentType(let string) {
                        print("INVALID InstrumentType: \(string)")
                    } catch _ { print("...?") }
                    
                case "Pitch": managePitchTokenContainer(container)
                case "DynamicMarking": manageDynamicMarkingTokenContainer(container)
                case "Articulation": manageArticulationTokenContainer(container)
                case "SlurStart": manageSlurStartTokenContainer(container)
                case "SlurStop": manageSlurStopTokenContainer(container)
                    
                // shouldn't happen at top-level: only embedded
                //case "SpannerStart": manageSpannerStartTokenContainer(container)
                default: break
                }
            }
            else {
                switch token.identifier {
                case "DurationNodeStackMode": manageDurationNodeStackModeToken(token)
                case "Measure": manageMeasureToken()
                case "RootDuration": manageRootDurationToken(token)
                case "InternalNodeDuration": manageInternalDurationToken(token)
                case "LeafNodeDuration": manageLeafNodeDurationToken(token)
                case "PerformerID": managePerformerIDWithToken(token)
                case "InstrumentID": manageInstrumentIDWithToken(token)
                default: break
                }
            }
        }
        
        setDurationOfLastMeasure()
        finalizeDurationNodes()
        
        let scoreModel = makeScoreModel()
        
        // return something real
        return scoreModel
    }
    
    private func managePerformerIDWithToken(token: Token) {
        print("manage PID: \(token)")
        currentPerformerID = (token as? TokenString)?.value
        print("currentPID: \(currentPerformerID)")
    }
    
    private func manageInstrumentIDWithToken(token: Token) {
        print("manage IID: \(token)")
        currentInstrumentID = (token as? TokenString)?.value
        print("currentIID: \(currentInstrumentID)")
    }
    
    private func makeScoreModel() -> DNMScoreModel {
        var scoreModel = DNMScoreModel()
        scoreModel.title = title
        scoreModel.measures = measures
        scoreModel.durationNodes = durationNodes
        scoreModel.tempoMarkings = tempoMarkings
        scoreModel.rehearsalMarkings = rehearsalMarkings
        scoreModel.instrumentIDsAndInstrumentTypesByPerformerID = instrumentIDAndInstrumentTypesByPerformerID
        return scoreModel
    }
    
    private func managePerformerDeclarationTokenContainer(container: TokenContainer) throws {
        let performerID = container.openingValue
        
        // Create the ordered dictionary that will contain the order dictionary for this PID
        var instrumentIDsAndInstrumentTypesByPerformerID = OrderedDictionary<
            String, OrderedDictionary<String, InstrumentType>
        >()
        
        // Initialize the ordered dictionary for this PID
        instrumentIDsAndInstrumentTypesByPerformerID[performerID] = OrderedDictionary<
            String, InstrumentType
        >()
        
        // Same as above but short name
        var dictForPID = instrumentIDsAndInstrumentTypesByPerformerID[performerID]!
        
        // Keep adding pairs of InstrumentIDs and InstrumentTypes as they come
        var lastInstrumentID: String?
        for token in container.tokens {
            switch token.identifier {
            case "InstrumentID":
                let instrumentID = (token as! TokenString).value
                lastInstrumentID = instrumentID
            case "InstrumentType":
                let instrumentTypeString = (token as! TokenString).value
                guard let instrumentType = InstrumentType(rawValue: instrumentTypeString) else {
                    throw ParserError.InvalidInstrumentType(string: instrumentTypeString)
                }
                if let lastInstrumentID = lastInstrumentID {
                    dictForPID[lastInstrumentID] = instrumentType
                }
            default: break
            }
        }
        self.instrumentIDAndInstrumentTypesByPerformerID[performerID] = dictForPID
    }
    
    private func manageMeasureToken() {
        setDurationOfLastMeasure()
        let measure = Measure(offsetDuration: currentMeasureDurationOffset)
        measures.append(measure)
    }
    
    private func setDurationOfLastMeasure() {
        if measures.count == 0 { return }
        var lastMeasure = measures.removeLast()
        lastMeasure.duration = accumDurationInMeasure
        measures.append(lastMeasure)
        currentMeasureDurationOffset += lastMeasure.duration
    }
    
    private func manageDurationNodeStackModeToken(token: Token) {
        if let tokenString = token as? TokenString {
            if let stackMode = DurationNodeStackMode(rawValue: tokenString.value) {
                durationNodeStackMode = stackMode
            }
        }
        
        switch durationNodeStackMode {
        case .Measure: accumDurationInMeasure = DurationZero
        case .Increment: break
        case .Decrement: break // currently, not supported?
        }
    }
    
    private func manageRootDurationToken(token: Token) {
        if let tokenDuration = token as? TokenDuration {
            let rootDurationNode = DurationNode(duration: Duration(tokenDuration.value))
            setOffsetDurationForNewRootDurationNode(rootDurationNode)
            addRootDurationNode(rootDurationNode)
            accumTotalDuration += rootDurationNode.duration
            currentDurationNodeDepth = 0
        }
    }

    private func manageInternalDurationToken(token: Token) {
        if let tokenInt = token as? TokenInt, indentationLevel = tokenInt.indentationLevel {

            // Pop the necessary amount of DurationNodeContainers from the stack
            let depth = indentationLevel - 1
            if depth < currentDurationNodeDepth {
                let amount = currentDurationNodeDepth - depth
                durationNodeContainerStack.pop(amount: amount)
            }
            
            // Add new Internal DurationNode with Beats
            let beats = tokenInt.value
            if let lastDurationNode = durationNodeContainerStack.top {
                let lastDurationNodeContainer = lastDurationNode.addChildWithBeats(beats)
                durationNodeContainerStack.push(lastDurationNodeContainer)
                currentDurationNodeDepth = depth
            }
        }
    }
    
    private func manageLeafNodeDurationToken(token: Token) {
        if let tokenInt = token as? TokenInt, indentationLevel = tokenInt.indentationLevel {

            // Pop the necessary amount of DurationNodeContainers from the stack
            let depth = indentationLevel - 1
            if depth < currentDurationNodeDepth {
                let amount = currentDurationNodeDepth - depth
                durationNodeContainerStack.pop(amount: amount)
            }
            
            // Add new Leaf DurationNode
            let beats = tokenInt.value
            if let lastDurationNode = durationNodeContainerStack.top {
                let lastDurationNodeChild = lastDurationNode.addChildWithBeats(beats)
                currentDurationNodeLeaf = lastDurationNodeChild
                currentDurationNodeDepth = depth
            }
        }
    }
    
    private func manageSlurStartTokenContainer(container: TokenContainer) {
        // add slur start
    }
    
    private func manageSlurStopTokenContainer(container: TokenContainer) {
        // add slur stop
    }
    
    private func managePitchTokenContainer(container: TokenContainer) {
        print("manage pitches")
        var pitches: [Float] = []
        for token in container.tokens {
            if let spannerStart = token as? TokenContainer
                where spannerStart.identifier == "SpannerStart"
            {
                // manage glissando
            }
            else if let tokenFloat = token as? TokenFloat {
                pitches.append(tokenFloat.value)
            }
        }
        guard let pID = currentPerformerID, iID = currentInstrumentID else { return }
        let pitchComponent = ComponentPitch(pID: pID, iID: iID, pitches: pitches)
        print("pitchComponent: \(pitchComponent)")
        currentDurationNodeLeaf?.addComponent(pitchComponent)
    }
    
    private func manageDynamicMarkingTokenContainer(container: TokenContainer) {
        
    }
    
    private func manageArticulationTokenContainer(container: TokenContainer) {
        
    }
    
    private func manageSpannerStartTokenContainer(container: TokenContainer) {
        
    }
    

    
    private func setOffsetDurationForNewRootDurationNode(rootDurationNode: DurationNode) {
        let offsetDuration: Duration
        switch durationNodeStackMode {
        case .Measure:
            offsetDuration = currentMeasureDurationOffset
            accumTotalDuration = currentMeasureDurationOffset
            accumDurationInMeasure = rootDurationNode.duration
        case .Increment:
            offsetDuration = accumTotalDuration
        case .Decrement:
            if let lastDurationNode = durationNodeContainerStack.top {
                offsetDuration = lastDurationNode.offsetDuration
                accumTotalDuration = offsetDuration
                accumDurationInMeasure -= lastDurationNode.duration
            } else {
                offsetDuration = DurationZero
            }
        }
        rootDurationNode.offsetDuration = offsetDuration
    }
    
    private func addRootDurationNode(rootDurationNode: DurationNode) {
        durationNodes.append(rootDurationNode)
        durationNodeContainerStack = Stack(items: [rootDurationNode])
    }
    
    private func finalizeDurationNodes() {
        for durationNode in durationNodes {
            (durationNode.root as! DurationNode).matchDurationsOfTree()
            (durationNode.root as! DurationNode).scaleDurationsOfChildren()
            (durationNode.root as! DurationNode).setOffsetDurationOfChildren()
        }
    }
}

private enum DurationNodeStackMode: String {
    case Measure = "|"
    case Increment = "+"
    case Decrement = "-"
}

private enum ParserError: ErrorType {
    case InvalidInstrumentType(string: String)
    case UndeclaredPerformerID
    case UndeclaredInstrumentID
    
}