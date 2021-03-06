//
//  Parser.swift
//  DNMConverter
//
//  Created by James Bean on 11/9/15.
//  Copyright © 2015 James Bean. All rights reserved.
//

import Foundation

/// Create DNMScoreModel from a TokenContainer (produced by Tokenizer, tokenizing a DNM file)
public class Parser {

    /// Stack of DurationNodes, used to embed DurationNodes into other ones
    private var durationNodeContainerStack = Stack<DurationNode>()
    
    /**
    Manner in which the current DurationNode is placed in time
    - Measure: place DurationNode at beginning of current Measure
    - Increment: place DurationNode immediately after last DurationNode
    - Decrement: place DurationNode at beginning of last DurationNode
    */
    private var currentDurationNodeStackMode: DurationNodeStackMode = .Measure
    
    
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
    private var currentMetadataKey: String?
    
    /**
    Collection of InstrumentIDsWithInstrumentType, organized by PerformerID.
    These values ensure Performer order and Instrument order, 
    while making it still possible to call for this information by key identifiers.
    */
    private var instrumentIDAndInstrumentTypesByPerformerID = OrderedDictionary<
        String, OrderedDictionary<String, InstrumentType>
    >()
    
    // MARK: DNMScoreModel values
    
    private var metadata: [String: String] = [:]
    private var title: String = ""
    private var durationNodes: [DurationNode] = []
    private var measures: [Measure] = []
    private var tempoMarkings: [TempoMarking] = []
    private var rehearsalMarkings: [RehearsalMarking] = []
    
    /**
    Create a Parser

    - returns: Parser
    */
    public init() { }
    
    
    /**
    Parse a TokenContainer (produced by Tokenizer)

    - parameter tokenContainer: TokenContainer containing all Tokens of a musical work

    - returns: DNMScoreModel (musical model to be represented by DNMRenderer)
    */
    public func parseTokenContainer(tokenContainer: TokenContainer) -> DNMScoreModel {
        
        for token in tokenContainer.tokens {
    
            if let container = token as? TokenContainer {
                switch container.identifier {
                case "PerformerDeclaration":
                    do { try managePerformerDeclarationTokenContainer(container) }
                    catch let error { print(error) }
                    
                case "Rest": manageRestToken()
                case "Pitch": managePitchTokenContainer(container)
                case "DynamicMarking": manageDynamicMarkingTokenContainer(container)
                case "Articulation": manageArticulationTokenContainer(container)
                case "SlurStart": manageSlurStartToken()
                case "SlurStop": manageSlurStopToken()
                case "Measure": manageMeasureToken()
                case "ExtensionStart": manageExtensionStartToken()
                case "ExtensionStop": manageExtensionStopToken()
                case "DurationNodeStackModeMeasure": manageDurationNodeStackModeMeasure()
                case "DurationNodeStackModeIncrement": manageDurationNodeStackModeIncrement()
                case "DurationNodeStackModeDecrement": manageDurationNodeStackModeDecrement()
                default: break
                }
            }
            else {
                switch token.identifier {
                case "RootNodeDuration": manageRootDurationToken(token)
                case "InternalNodeDuration": manageInternalDurationToken(token)
                case "LeafNodeDuration": manageLeafNodeDurationToken(token)
                case "PerformerID": managePerformerIDWithToken(token)
                case "InstrumentID": manageInstrumentIDWithToken(token)
                case "MetadataKey": manageMetadataKeyToken(token)
                case "MetadataValue": manageMetadataValueToken(token)
                default: break
                }
            }
        }
        setDurationOfLastMeasure()
        finalizeDurationNodes()
        let scoreModel = makeScoreModel()
        return scoreModel
    }
    
    private func manageMetadataKeyToken(token: Token) {
        currentMetadataKey = (token as? TokenString)?.value
    }
    
    private func manageMetadataValueToken(token: Token) {
        if let key = currentMetadataKey {
            if let value = (token as? TokenString)?.value {
                metadata[key] = value
                currentMetadataKey = nil
            }
        }
    }
    
    private func manageRestToken() {
        guard let pID = currentPerformerID, iID = currentInstrumentID else { return }
        let component = ComponentRest(performerID: pID, instrumentID:  iID)
        addComponent(component)
    }
    
    private func manageDurationNodeStackModeMeasure() {
        currentDurationNodeStackMode = .Measure
        accumDurationInMeasure = DurationZero
    }
    
    private func manageDurationNodeStackModeIncrement() {
        currentDurationNodeStackMode = .Increment
    }
    
    private func manageDurationNodeStackModeDecrement() {
        
    }
    
    private func manageExtensionStartToken() {
        guard let pID = currentPerformerID, iID = currentInstrumentID else { return }
        let component = ComponentExtensionStart(performerID: pID, instrumentID: iID)
        addComponent(component)
    }
    
    private func manageExtensionStopToken() {
        guard let pID = currentPerformerID, iID = currentInstrumentID else { return }
        let component = ComponentExtensionStop(performerID: pID, instrumentID: iID)
        addComponent(component)
    }
    
    private func managePerformerIDWithToken(token: Token) {
        currentPerformerID = (token as? TokenString)?.value
    }
    
    private func manageInstrumentIDWithToken(token: Token) {
        currentInstrumentID = (token as? TokenString)?.value
    }
    
    private func makeScoreModel() -> DNMScoreModel {
        var scoreModel = DNMScoreModel()
        //scoreModel.title = title
        scoreModel.metadata = metadata
        scoreModel.measures = measures
        scoreModel.durationNodes = durationNodes
        scoreModel.tempoMarkings = tempoMarkings
        scoreModel.rehearsalMarkings = rehearsalMarkings
        scoreModel.instrumentIDsAndInstrumentTypesByPerformerID = instrumentIDAndInstrumentTypesByPerformerID
        return scoreModel
    }
    
    private func managePerformerDeclarationTokenContainer(container: TokenContainer) throws {

        var performerID: String {
            for token in container.tokens {
                switch token.identifier {
                case "PerformerID":
                    return (token as! TokenString).value
                default: break
                }
            }
            return ""
        }
        
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
        //measures.append(measure)
        addMeasure(measure)

        // set offset of the location from the start of the current measure to DurationZero
        accumDurationInMeasure = DurationZero
        
        // set default duration node stacking behavior
        currentDurationNodeStackMode = .Measure
    }
    
    private func addMeasure(var measure: Measure) {
        measure.number = measures.count + 1
        measures.append(measure)
    }
    
    private func setDurationOfLastMeasure() {
        if measures.count == 0 { return }
        
        // pop last measure to modify
        var lastMeasure = measures.removeLast()
        lastMeasure.duration = accumDurationInMeasure
        
        // push last measure back on stack
        measures.append(lastMeasure)
        
        // set location of next measure to be created
        currentMeasureDurationOffset += lastMeasure.duration
    }
    
    private func manageRootDurationToken(token: Token) {
        if let tokenDuration = token as? TokenDuration {
            let rootDurationNode = DurationNode(duration: Duration(tokenDuration.value))
            setOffsetDurationForNewRootDurationNode(rootDurationNode)
            addRootDurationNode(rootDurationNode)
            accumTotalDuration += rootDurationNode.duration
            accumDurationInMeasure += rootDurationNode.duration
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
    
    private func manageSlurStartToken() {
        guard let pID = currentPerformerID, iID = currentInstrumentID else { return }
        let component = ComponentSlurStart(performerID: pID, instrumentID: iID)
        addComponent(component)
    }
    
    private func manageSlurStopToken() {
        guard let pID = currentPerformerID, iID = currentInstrumentID else { return }
        let component = ComponentSlurStop(performerID: pID, instrumentID: iID)
        addComponent(component)
    }
    
    private func managePitchTokenContainer(container: TokenContainer) {
        var pitches: [Float] = []
        for token in container.tokens {
            if let spannerStart = token as? TokenContainer
                where spannerStart.identifier == "SpannerStart"
            {
                // TODO: manage glissando: add glissando component
            }
            else if let tokenFloat = token as? TokenFloat {
                pitches.append(tokenFloat.value)
            }
        }
        guard let pID = currentPerformerID, iID = currentInstrumentID else { return }
        let component = ComponentPitch(performerID: pID, instrumentID: iID, values: pitches)
        addComponent(component)
    }
    
    private func manageDynamicMarkingTokenContainer(container: TokenContainer) {
        guard let pID = currentPerformerID, iID = currentInstrumentID else { return }
        for token in container.tokens {
            switch token.identifier {
            case "Value":
                let value = (token as! TokenString).value
                addDynamicMarkingComponentWithValue(value, performerID: pID, instrumentID: iID)
            case "SpannerStart":
                let component = ComponentDynamicMarkingSpannerStart(
                    performerID: pID, instrumentID: iID)
                addComponent(component)
            case "SpannerStop":
                let component = ComponentDynamicMarkingSpannerStop(
                    performerID: pID, instrumentID: iID)
                addComponent(component)
            default: break
            }
        }
    }
    
    private func addDynamicMarkingComponentWithValue(value: String,
        performerID: String, instrumentID: String
    )
    {
        let component = ComponentDynamicMarking(
            performerID: performerID,
            instrumentID: instrumentID,
            value: value
        )
        addComponent(component)
    }
    
    private func manageArticulationTokenContainer(container: TokenContainer) {
        var markings: [String] = []
        for token in container.tokens {
            if let tokenString = token as? TokenString { markings.append(tokenString.value) }
        }
        guard let pID = currentPerformerID, iID = currentInstrumentID else { return }
        let component = ComponentArticulation(performerID: pID, instrumentID: iID, values: markings)
        addComponent(component)
    }
    
    /*
    private func manageSpannerStartTokenContainer(container: TokenContainer) {

    }
    */

    // this needs to be tested thoroughly
    private func setOffsetDurationForNewRootDurationNode(rootDurationNode: DurationNode) {
        let offsetDuration: Duration
        switch currentDurationNodeStackMode {
        case .Measure:
            offsetDuration = currentMeasureDurationOffset
            accumTotalDuration = currentMeasureDurationOffset
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
    
    private func addComponent(component: Component) {
        currentDurationNodeLeaf?.addComponent(component)
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