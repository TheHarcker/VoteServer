import Foundation
import AltVoteKit
import VoteKit
import Logging

actor Group{
	typealias VoteID = UUID
	
	internal init(adminSessionID: SessionID, name: String, constituents: Set<Constituent>, joinPhrase: JoinPhrase, allowsUnverifiedConstituents: Bool) {
		self.adminSessionID = adminSessionID
		self.name = name
		self.verifiedConstituents = constituents
		self.joinPhrase = joinPhrase
		self.allowsUnverifiedConstituents = allowsUnverifiedConstituents
		
		self.logger = Logger(label: "Group \"\(name)\":\"\(joinPhrase)\"")
	}
	
	/// The name of the group as shown in the UI
	let name: String
	/// The joinPhrase used for constituents to join  the group
	let joinPhrase: JoinPhrase
	/// The ID of  the group
	let id: UUID = UUID()
	
	/// Admin session ID
	let adminSessionID: SessionID
	/// The open/closedness status of a vote
	private var statusForVote = [VoteID: VoteStatus]()
	
    /// The different kinds of votes, stored by their id
	private var AltVotesByID = [VoteID: AlternativeVote]()
	private var SimMajVotesByID = [VoteID: SimpleMajority]()
	private var YNVotesByID = [VoteID: yesNoVote]()
	
	private(set) var verifiedConstituents: Set<Constituent>
	private(set) var unverifiedConstituents: Set<Constituent> = []
	
    /// If this group allows unverified constituents to join
	var allowsUnverifiedConstituents: Bool
	
    
	var joinedConstituentsByID = [ConstituentIdentifier: Constituent]()
	
	/// A dictionary of unverified constituents who has been removed one way or another
	var previouslyJoinedUnverifiedConstituents = Set<ConstituentIdentifier>()
	
    /// The session id associated with each constituent
	var constituentsSessionID: [UUID: Constituent] = [:]
	
	private let logger: Logger
}


//MARK: Get constituents and their status
extension Group{
	
    //Retrieves verified constituents by their identifier
	func verifiedConstituent(for identifier: ConstituentIdentifier) -> Constituent?{
		verifiedConstituents.first(where: {$0.identifier == identifier})
	}
    //Retrieves unverified constituents by their identifier
	func unverifiedConstituent(for identifier: ConstituentIdentifier) -> Constituent?{
		unverifiedConstituents.first(where: {$0.identifier == identifier})
	}
	
    //Retrieves constituents by their identifier, not regarding whether they're verified
	func constituent(for identifier: ConstituentIdentifier) -> Constituent?{
		if let v = verifiedConstituent(for: identifier){
			return v
		} else {
			return unverifiedConstituent(for: identifier)
		}
	}
	
	// Returns a set of all constituents who has ever been in this group
	func allPossibleConstituents() -> Set<Constituent>{
		verifiedConstituents
			.union(unverifiedConstituents)
		//Converts the previously joined into "real" constituents
			.union(previouslyJoinedUnverifiedConstituents.map{Constituent(identifier: $0)})
	}
	
	func constituentIsVerified(_ const: Constituent) -> Bool{
		verifiedConstituents.contains(const)
	}
	
	func constituentHasJoined(_ identifier: ConstituentIdentifier) -> Bool{
		joinedConstituentsByID.values.contains(where: {$0.identifier == identifier})
	}
}

//MARK: Reset/disallow constituents
extension Group{
	func resetConstituent(_ constituent: Constituent) async{
		if unverifiedConstituents.contains(constituent){
			self.unverifiedConstituents.remove(constituent)
			self.previouslyJoinedUnverifiedConstituents.insert(constituent.identifier)

			
			for v in AltVotesByID.values{
				await v.removeConstituent(constituent)
			}
			for v in YNVotesByID.values{
				await v.removeConstituent(constituent)
			}
			for v in SimMajVotesByID.values{
				await v.removeConstituent(constituent)
			}
			
		}
		
		self.joinedConstituentsByID[constituent.identifier] = nil
		
		// Removes all sessionIDs referencing the one being deleted
		constituentsSessionID = constituentsSessionID.filter{ _, const in
			return constituent.identifier != const.identifier
		}
		
		logger.info("Constituent \"\(constituent.identifier)\" was reset")
	}
	
    /// Changes whether unverified constituents are allowed in this group.
    ///  Handles rule changes and removes unverified constituents from all votes they haven't cast a vote in
    /// - Parameter state: if false every constituent that isn't on the verified list will be removed else allowsUnverifiedConstituents will be set to true
	func setAllowsUnverifiedConstituents(_ state: Bool) async{
		guard state != self.allowsUnverifiedConstituents else {return}
		if !state{
			/// Adds all unverified constituens to previouslyJoinedUnverifiedConstituents
			previouslyJoinedUnverifiedConstituents.formUnion(unverifiedConstituents.map(\.identifier))
			
			//Removes all unverified constituents who hasn't cast a vote
			func procedure<V: SupportedVoteType>(_ vote: V) async{
				await vote
					.setConstituents(vote.constituents
									 // Removes all unverified
										.subtracting(unverifiedConstituents)
									 // Adds everyone who has already voted, including unverified
										.union(vote.votes.map(\.constituent)))
			}
			
			
			for v in AltVotesByID.values{
				await procedure(v)
			}
			for v in YNVotesByID.values{
				await procedure(v)
			}
			for v in SimMajVotesByID.values{
				await procedure(v)
			}
			
			// Removes all sessionIDs referencing the one being deleted
			let unverifiedIdentifiers = unverifiedConstituents.map(\.identifier)
			constituentsSessionID = constituentsSessionID.filter{ _, const in
				return unverifiedIdentifiers.contains(const.identifier)
			}
			
			unverifiedConstituents = []
			joinedConstituentsByID = joinedConstituentsByID.filter{(_, value) in
				verifiedConstituents.contains(value)
			}
		}
		self.allowsUnverifiedConstituents = state
		
		logger.info("Access for unverified was set to: \(state)")
	}
}

//MARK: Join
extension Group{
    
    /// Adds a constituent to the group
    /// - Parameters:
    ///   - const: The constituent to add
    ///   - sessionId: The session from which a client signed in
    /// - Returns: True if the constituent could be added
	func joinConstituent(_ const: Constituent, for sessionId: SessionID) async -> Bool {
		guard joinedConstituentsByID[const.identifier] == nil else {
			return false
		}
		
		if !verifiedConstituents.contains(const){
			if unverifiedConstituents.contains(const){
				assertionFailure()
				logger.warning("\"\(const.name ?? const.identifier)\" is stored in unverifiedConstituents eventhough it's not joined")
                return false
			}
			
			guard allowsUnverifiedConstituents else {
				assertionFailure("joinConstituent was called with an unverified constituent")
				logger.warning("joinConstituent was called with an unverified constituent")
				return false
			}
			
			unverifiedConstituents.insert(const)
			previouslyJoinedUnverifiedConstituents.remove(const.identifier)
			
			
			for v in AltVotesByID.values{
				await v.addConstituents(const)
			}
			for v in YNVotesByID.values{
				await v.addConstituents(const)
			}
			for v in SimMajVotesByID.values{
				await v.addConstituents(const)
			}
			
		}
		defer{
			logger.info("Constituent \(const.identifier) joined the group")
		}
		
		constituentsSessionID[sessionId] = const
		
		joinedConstituentsByID[const.identifier] = const
		return true
	}
	
}

//MARK: Handle votes (elections)
extension Group {
    /// Finds a vote by its id
    func voteForID(_ id: VoteID) -> VoteTypes?{
        if let v = AltVotesByID[id]{
            return VoteTypes(vote: v)
        } else if let v = YNVotesByID[id]{
            return VoteTypes(vote: v)
        } else if let v = SimMajVotesByID[id]{
            return VoteTypes(vote: v)
        } else {
            return nil
        }
    }
	
    /// Finds a vote by a string representation of its id
    func voteForID(_ id: String) -> VoteTypes?{
        guard let voteID = VoteID(id) else {
            return nil
        }
        return voteForID(voteID)
    }
    
    
	/// Returns three arrays, all containing all instances for each kind of vote
	func allVotes() -> ([AlternativeVote],[yesNoVote],[SimpleMajority]){
		return (Array(AltVotesByID.values), Array(YNVotesByID.values), Array(SimMajVotesByID.values))
	}

    /// Gets the status for the id of a vote
    func statusFor(_ id: VoteID) async -> VoteStatus?{
        return statusForVote[id]
    }
    
	/// Gets the status of a vote
	func statusFor<V: SupportedVoteType>(_ vote: V) async -> VoteStatus?{
        statusForVote[await vote.id]
	}




	func setStatusFor<V: SupportedVoteType>(_ vote: V, to value: VoteStatus) async{
        setStatusFor(await vote.id, to: value)
	}
    func setStatusFor(_ vote: VoteID, to value: VoteStatus){
        statusForVote[vote] = value
    }
	
	/// Adds new votes to the group
	func addVoteToGroup<V: SupportedVoteType>(vote: V) async{
		let voteID = await vote.id
		
		switch V.enumCase{
        case .alternative:
			AltVotesByID[voteID] = vote as? AlternativeVote
        case .yesNo:
			YNVotesByID[voteID] = vote as? yesNoVote
        case .simpleMajority:
			SimMajVotesByID[voteID] = vote as? SimpleMajority
		}
		
		statusForVote[voteID] = .closed
        
        let vName = await vote.name
        logger.info("Vote of kind \"\(V.typeName)\" named \"\(vName)\" was added to the group")
	}
	
	/// The session used for "proving" membership of a group
	var groupSession: GroupSession{
		return .init(sessionID: self.id)
	}
}


enum VoteStatus: String, Codable{
	case open
	case closed
}
