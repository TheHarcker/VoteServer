import VoteKit
import Vapor
import Logging
import FluentKit

typealias JoinPhrase = String

/// Represents a collection of groups
actor GroupsManager{
	/// Groups represented by the session ID of the admin(s)
	private var groupsBySession = [SessionID: Group]()
	/// Groups represented by theit join phrase
	private var groupsByPhrase = [JoinPhrase: Group]()
	/// Groups represented by their internal id
	private var groupsByUUID = [UUID: Group]()
	/// The last time a group was accessed, used for manual garbage collection
	private var lastAccessForGroup = [UUID: Date]()
	/// JoinPhrases already in use
    private var reservedPhrases = Set<JoinPhrase>()
	
	private let logger = Logger(label: "Groups")
}


//MARK: Store last access
extension GroupsManager{
	private func updateAccessTimeFor(_ id: UUID){
		lastAccessForGroup[id] = Date()
	}
	
	private func updateAccessTimeFor(_ group: Group){
		updateAccessTimeFor(group.id)
	}
    
    func getLastAccess(for group: Group) -> String?{
        lastAccessForGroup[group.id]?.description
    }
}

//MARK: Get and create groups
extension GroupsManager{
	func groupForSession(_ session: SessionID) -> Group?{
		if let group = groupsBySession[session]{
			updateAccessTimeFor(group)
			return group
		} else {
			return nil
		}
	}
	
	func groupForGroupID(_ id: UUID) -> Group?{
		if let group = groupsByUUID[id]{
			updateAccessTimeFor(group)
			return group
		} else {
			return nil
		}
	}
	
	func groupForJoinPhrase(_ jf: JoinPhrase) -> Group?{
		if let group = groupsByPhrase[jf]{
			updateAccessTimeFor(group)
			return group
		} else {
			return nil
		}
	}
	
	func createGroup(session: SessionID, db: Database, name: String, constituents: Set<Constituent>, pwdigest: String, allowsUnverified: Bool) async -> Bool{
        guard let jf = createJoinPhrase() else {
            logger.warning("Joinphrase could not be generated within reasonable time")
            return false
        }
		
		let socketController = ChatSocketController(db: db)
		let group = Group(adminSessionID: session, socketController: socketController, name: name, constituents: constituents, joinPhrase: jf, allowsUnverifiedConstituents: allowsUnverified, passwordDigest: pwdigest)
		await socketController.setup(group: group)
		
		groupsBySession[group.adminSessionID] = group
		groupsByPhrase[jf] = group
		groupsByUUID[group.id] = group
		updateAccessTimeFor(group)
		
		logger.info("Group \"\(name)\" was created, with the joinphrase \"\(jf)\"")
        return true
	}
	
    func deleteGroup(jf: JoinPhrase) async -> Bool{
        guard let group = groupsByPhrase[jf] else {
            return false
        }
		
		// Closes all webSockets in this group
		await group.socketController.kickAll(includeAdmins: true)
		
        groupsBySession = groupsBySession.filter{ d in
            d.value.id != group.id
        }
    
        groupsByPhrase[jf] = nil
        groupsByUUID[group.id] = nil
        lastAccessForGroup[group.id] = nil
        reservedPhrases.remove(jf)
        logger.info("Group named \"\(group.name)\" was deleted")
        
        return true
    }
    
    
	/// Attempts to login using a joinphrase and the corresponding password
	func login(request: Request, joinphrase: JoinPhrase, password: String) async -> AdminSession?{
        if let group = groupForJoinPhrase(joinphrase), (try? request.password.verify(password, created: await group.passwordDigest)) == true {
            let sessionID = group.adminSessionID
            logger.info("An admin logged in to a group with the joinphrase \"\(joinphrase)\"")
            return AdminSession(sessionID: sessionID)
        } else {
			return nil
		}
	}
    
    
    func listAllGroups() -> String{
        let groups = self.groupsByPhrase.values
        let values = groups.map{
            "\t-\"\($0.name)\":\"\($0.joinPhrase)\" was last accessed at: " + (lastAccessForGroup[$0.id]?.description ?? "Unknown")
        }
        return values.joined(separator: "\n")
    }
}

//MARK: Support for creating joinphrases
extension GroupsManager{
    func createJoinPhrase(attemptsLeft: Int = 10) -> JoinPhrase?{
        guard attemptsLeft > 0 else{
            return nil
        }
        
		let phrase = joinPhraseGenerator()
		
		// If a phrase can be inserted without overwriting another element then it must be unique
		if reservedPhrases.insert(phrase).inserted {
			return phrase
		} else {
			//Otherwise we'll try again
            return createJoinPhrase(attemptsLeft: attemptsLeft - 1)
		}
	}
}

//MARK: Convenience getters
extension GroupsManager{
	func groupAndVoterForReq(req: Request) async -> (Group, Constituent)?{
		guard
			let groupID = req.session.authenticated(GroupSession.self),
			let constID = req.session.authenticated(VoterSession.self),
			let group = self.groupForGroupID(groupID),
			let constituent = await group.constituentsSessionID[constID]
		else {return nil}
		
		return (group, constituent)
	}
    
    func groupAndVoterForAPI(req: Request) async -> (Group, Constituent)?{
        guard
            let groupID = req.session.authenticated(GroupSession.self),
            let constID = req.session.authenticated(APISession.self),
            let group = self.groupForGroupID(groupID),
            let constituent = await group.constituentsSessionID[constID]
        else {return nil}
        
        return (group, constituent)
    }
}
