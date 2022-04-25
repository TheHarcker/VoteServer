import Vapor
import VoteKit
import AltVoteKit
func voteCreationRoutes(_ app: Application, groupsManager: GroupsManager) {
    /// Shows admins a page which'' let them create the kind of vote supplied in the "type" parameter
    app.get("createvote", ":type", use: createVote)
	app.post("createvote", ":type", use: createVote)
	func createVote(req: Request) async throws -> Response{
		guard
			let sessionID = req.session.authenticated(AdminSession.self),
			let group = await groupsManager.groupForSession(sessionID)
		else {
			throw Redirect(.create)
		}
		guard let parameter = req.parameters.get("type"), let type = VoteTypes.StringStub(rawValue: parameter) else {
			throw Redirect(.admin)
		}
		
		if req.method == .POST{
			switch type {
			case .alternative:
				return try await treat(req: req, AlternativeVote.self, group: group)
			case .yesNo:
				return try await treat(req: req, yesNoVote.self, group: group)
			case .simpleMajority:
				return try await treat(req: req, SimpleMajority.self, group: group)
			}
		} else {
			switch type {
			case .alternative:
				return try await showUI(for: req, AlternativeVote.self)
			case .yesNo:
				return try await showUI(for: req, yesNoVote.self)
			case .simpleMajority:
				return try await showUI(for: req, SimpleMajority.self)
			}
		}
	}
}

/// Attempts to create a vote for a given request
fileprivate func treat<V: SupportedVoteType>(req: Request, _ type: V.Type, group: Group) async throws -> Response{
    var voteHTTPData: VoteCreationReceivedData<V>? = nil

    do {

        voteHTTPData = try req.content.decode(VoteCreationReceivedData<V>.self)

        // Since it voteHTTPData was just set it'll in this scope be treated as not being an optional
        let voteHTTPData = voteHTTPData!

        async let constituents = group.verifiedConstituents.union(await group.unverifiedConstituents)

        // Validates the data and generates a Vote object

        let title = try voteHTTPData.getTitle()
        let partValidators = voteHTTPData.getPartValidators()
        let genValidators = voteHTTPData.getGenValidators()
        let options = try voteHTTPData.getOptions()

        // Initialises the vote for the given type
        switch V.enumCase{
        case .alternative:
            let tieBreakers: [TieBreaker] = [.dropAll, .removeRandom, .keepRandom]
            
            let vote = AlternativeVote(name: title, options: options, constituents: await constituents, tieBreakingRules: tieBreakers, genericValidators: genValidators as! [GenericValidator<AlternativeVote.voteType>], particularValidators: partValidators as! [AlternativeVote.particularValidator])
            await group.addVoteToGroup(vote: vote)
        case .yesNo:
            let vote = yesNoVote(name: title, options: options, constituents: await constituents, genericValidators: genValidators as! [GenericValidator<yesNoVote.yesNoVoteType>], particularValidators: partValidators as! [yesNoVote.particularValidator])
            await group.addVoteToGroup(vote: vote)
        case .simpleMajority:
            let vote = SimpleMajority(name: title, options: options, constituents: await constituents, genericValidators: genValidators as! [GenericValidator<SimpleMajority.SimpleMajorityVote>], particularValidators: partValidators as! [SimpleMajority.particularValidator])
            await group.addVoteToGroup(vote: vote)
        }

        return req.redirect(to: .admin)

    } catch {
        return try await showUI(for: req, errorString: error.asString(), persistentData: voteHTTPData)
    }
}



fileprivate func showUI<V: SupportedVoteType>(for req: Request, _ type: V.Type = V.self, errorString: String? = nil, persistentData: VoteCreationReceivedData<V>? = nil) async throws -> Response{
    
    //Finds available validators
    let gen = GenericValidator<V.voteType>
        .allValidators
        .map{ genVal in
            ValidatorData<V>(genericValidator: genVal, isEnabled: false)
        }
    let part = V.particularValidator
        .allValidators
        .map{ partVal in
            ValidatorData<V>(particularValidator: partVal, isEnabled: false)
        }
    
    return try await VoteCreatorUI(errorString: errorString, validatorsGeneric: gen, validatorsParticular: part, persistentData).encodeResponse(for: req)
}



struct ValidatorData<V: SupportedVoteType>: Codable{
    var id: String
    var name: String
    var isEnabled: Bool
    var stack: ValidatorStacks
    
    init(particularValidator: V.particularValidator, isEnabled: Bool = false){
        self.name = particularValidator.name
        self.id = particularValidator.id
        self.isEnabled = isEnabled
        self.stack = .particularValidators
    }
    
    init(genericValidator: GenericValidator<V.voteType>, isEnabled: Bool = false){
        self.name = genericValidator.name
        self.id = genericValidator.id
        self.isEnabled = isEnabled
        self.stack = .genericValidators
    }
    
    
    enum ValidatorStacks: String, Codable{
        case genericValidators
        case particularValidators
    }
}
