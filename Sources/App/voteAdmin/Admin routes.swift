import Vapor
import VoteKit
import Foundation
import FluentKit

func adminRoutes(_ app: Application, groupsManager: GroupsManager) {
	let admin = app.grouped("admin")
	let voteadmin = app.grouped("voteadmin")
	let login = app.grouped("login")

	
	admin.get { req async throws -> Response in
		//List of votes
		guard
			let sessionID = req.session.authenticated(AdminSession.self),
			let group = await groupsManager.groupForSession(sessionID)
		else {
			return req.redirect(to: .create)
		}
		
		return try await AdminUIController(for: group).encodeResponse(for: req)
	}
    
	voteadmin.get{ req async throws -> Response in
        return req.redirect(to: .admin)
    }
    
	// Changes the open/closed status of the vote passed as ":voteID"
	voteadmin.get(":voteID", ":command", use: setStatus)
	
	func setStatus(req: Request) async -> Response{
		if let voteIDStr = req.parameters.get("voteID"),
		   let commandStr = req.parameters.get("command"),
		   let command = VoteStatus(rawValue: commandStr),
		   let sessionID = req.session.authenticated(AdminSession.self),
		   let group = await groupsManager.groupForSession(sessionID),
		   let vote = await group.voteForID(voteIDStr)
		{
            await group.setStatusFor(await vote.id(), to: command)
		}
		return req.redirect(to: .admin)
	}
	
	// Shows an overview for a specific vote, with information such as who has voted and who has not
	voteadmin.get(":voteID") { req async throws -> Response in
		guard let voteIDStr = req.parameters.get("voteID") else {
			return req.redirect(to: .admin)
		}
		
		guard
			let sessionID = req.session.authenticated(AdminSession.self),
			let group = await groupsManager.groupForSession(sessionID),
			let vote = await group.voteForID(voteIDStr)
		else {
			return req.redirect(to: .admin)
		}
		
        return try await VoteAdminUIController(vote: vote, group: group).encodeResponse(for: req)
            
	}
	
	voteadmin.post(":voteID") { req async throws -> Response in
		guard
            let voteIDStr = req.parameters.get("voteID"),
            let voteID = UUID(voteIDStr)
        else {
			return req.redirect(to: .admin)
		}
		
		guard
			let adminID = req.session.authenticated(AdminSession.self),
			let group = await groupsManager.groupForSession(adminID),
			let vote = await group.voteForID(voteID)
		else {
			return req.redirect(to: .admin)
		}
		
        // Checks requests if they ask for deletion
        if let deleteID = (try? req.content.decode([String:String].self))?["voteToDelete"], voteIDStr == deleteID, await group.statusFor(voteID) == .closed {
            await group.removeVoteFromGroup(vote: vote)
            return req.redirect(to: .admin)
        }
        
        // Checks if any status change is requested
		if let status = (try? req.content.decode([String:VoteStatus].self))?["statusChange"] {
            await group.setStatusFor(await vote.id(), to: status)
            
            let pageController = await VoteAdminUIController(vote: vote, group: group)
            return try await pageController.encodeResponse(for: req)
        } else {
            let pageController = await VoteAdminUIController(vote: vote, group: group)
            return try await pageController.encodeResponse(for: req)
        }
    
       
     
	}
	
	// Shows a list of constituents and related settings
	admin.get("constituents") {req async throws -> Response in
		guard
			let sessionID = req.session.authenticated(AdminSession.self),
			let group = await groupsManager.groupForSession(sessionID)
		else {
			return req.redirect(to: .admin)
		}
		
		return try await ConstituentsListUI(group: group).encodeResponse(for: req)
	}
	
	admin.post("constituents") {req async throws -> Response in
		guard
			let sessionID = req.session.authenticated(AdminSession.self),
			let group = await groupsManager.groupForSession(sessionID)
		else {
			return req.redirect(to: .constituents)
		}
		
		if let status = try? req.content.decode(ChangeVerificationRequirementsData.self).getStatus(){
            await group.setSettings(allowsUnverifiedConstituents: status)
		}
        
		return try await ConstituentsListUI(group: group).encodeResponse(for: req)
	
		struct ChangeVerificationRequirementsData: Codable{
			private var setVerifiedRequirement: String
			func getStatus()->Bool?{
				if setVerifiedRequirement == "true"{
					return true
				} else if setVerifiedRequirement == "false"{
					return false
				} else {
					return nil
				}
			}
		}
	}
	
	admin.get("constituents", "downloadcsv") {req async throws -> Response in
		guard
			let sessionID = req.session.authenticated(AdminSession.self),
			let group = await groupsManager.groupForSession(sessionID)
		else {
			return req.redirect(to: .constituents)
		}
		
        let csv = await group.allPossibleConstituents().toCSV(config: group.settings.csvConfiguration)
		return try await downloadResponse(for: req, content: csv, filename: "constituents.csv")

	}

	
	admin.post("resetaccess", ":userID"){req async throws -> Response in
		if let userIdentifierbase64 = req.parameters.get("userID")?.trimmingCharacters(in: .whitespacesAndNewlines),
           let userIdentifier = String(urlsafeBase64: userIdentifierbase64),
		   let sessionID = req.session.authenticated(AdminSession.self),
		   let group = await groupsManager.groupForSession(sessionID),
		   let constituent = await group.constituent(for: userIdentifier)
		{
			await group.resetConstituent(constituent)
		}
		
		return req.redirect(to: .constituents)

	}
	
	voteadmin.post("reset", ":voteID", ":userID") { req async -> Response in
		// Retrieves the vote id from the uri
		guard let voteIDStr = req.parameters.get("voteID") else {
			return req.redirect(to: .admin)
		}
        
		// The single cast vote that should be deleted
		if let userIdentifierbase64 = req.parameters.get("userID")?.trimmingCharacters(in: .whitespacesAndNewlines),
           let constituentID = String(urlsafeBase64: userIdentifierbase64),
		   let adminID = req.session.authenticated(AdminSession.self),
		   let group = await groupsManager.groupForSession(adminID),
		   let vote = await group.voteForID(voteIDStr)
		{
            await group.singleVoteReset(vote: vote, constituentID: constituentID)
		}
		
		return req.redirect(to: .voteadmin(voteIDStr))
	}
	
    login.get{ req async -> LoginUI in
        let showRedirectToPlaza = await groupsManager.groupAndVoterForReq(req: req) != nil

        return LoginUI(showRedirectToPlaza: showRedirectToPlaza)
	}
	
	login.post {req async -> Response in
		var joinPhrase: JoinPhrase?
		do{
			guard
				let loginData = try? req.content.decode([String: String].self),
				let pw = loginData["password"],
				let jf = loginData["joinPhrase"]
			else {
				throw "Invalid request"
			}
			joinPhrase = jf
			
			
			// Saves the group
			guard let session = await groupsManager.login(request: req, joinphrase: jf, password: pw) else{
				throw "No match for password and join code"
			}
			
			//Registers the session with the client
			req.session.authenticate(session)
			return req.redirect(to: .admin)
			
		} catch {
            let showRedirectToPlaza = await groupsManager.groupAndVoterForReq(req: req) != nil

			return (try? await LoginUI(prefilledJF: joinPhrase ?? "", errorString: error.asString(), showRedirectToPlaza: showRedirectToPlaza).encodeResponse(for: req)) ?? req.redirect(to: .login)
		}
	}
    
    // The admin settings page
    admin.get("settings"){ req async throws -> Response in
        guard
            let sessionID = req.session.authenticated(AdminSession.self),
            let group = await groupsManager.groupForSession(sessionID)
        else {
            return req.redirect(to: .create)
        }
        
        return try await SettingsUI(for: group).encodeResponse(for: req)
        
    }
    
    // Requests for changing the settings of a group
    admin.post("settings"){ req async throws -> Response in
        guard
            let sessionID = req.session.authenticated(AdminSession.self),
            let group = await groupsManager.groupForSession(sessionID)
        else {
            return req.redirect(to: .create)
        }
        
        if let newSettings = try? req.content.decode(SetSettings.self){
            await newSettings.saveSettings(to: group)
        }
        
        
        return try await SettingsUI(for: group).encodeResponse(for: req)

        
    }
	
	admin.get("chats") { req async -> Response in
		guard
			let sessionID = req.session.authenticated(AdminSession.self),
			let group = await groupsManager.groupForSession(sessionID)
		else {
			return req.redirect(to: .create)
		}
		guard await group.settings.chatState != .disabled else {
			return req.redirect(to: .admin)
		}
		return try! await AdminChatPage().render(for: req)
	}
	
	admin.get("chats", "downloadcsv", use: downloadChats)
	
	func downloadChats(req: Request) async throws -> Response{
		guard
			let sessionID = req.session.authenticated(AdminSession.self),
			let group = await groupsManager.groupForSession(sessionID)
				
		else {
			return Response(status: .unauthorized)
		}
		
		guard let allChats = try? await Chats
			.query(on: req.db)
			.filter(\.$groupID == group.id)
			.all() else {
			return Response(status: .internalServerError)
		}
		
		let header = "Sender,Message,Timestamp,Systems message\n"
		let content = allChats.map { chat -> String in
			[chat.sender, chat.message, "\(chat.timestamp)", "\(chat.systemsMessage ? 1 : 0)"].joined(separator: ",")
		}.joined(separator: "\n")
		
		let csv = header + content
		return try await downloadResponse(for: req, content: csv, filename: "chathistory-\(group.joinPhrase).csv")
	}
}

fileprivate struct SettingsUI: UITableManager{
    var title: String = "Settings"
    var errorString: String? = nil
    static var template: String = "settings"
    var buttons: [UIButton] = [.backToAdmin]
    
    var rows: [Setting]
    var tableHeaders: [String] = []
    
    
    init(for group: Group) async {
		let current = await group.settings
        self.rows = [
            Setting("auv", "Allow unverified constituents", type: .bool(current: current.allowsUnverifiedConstituents), disclaimer: current.allowsUnverifiedConstituents ? "Changing this setting will kick unverified constituents" : nil),
            Setting("selfReset", "Constituents can reset their votes", type: .bool(current: current.constituentsCanSelfResetVotes)),
            Setting("CSVConfiguration", "CSV Export mode", type: .list(options: Array(current.csvKeys.keys), current: current.csvConfiguration.name)),
			Setting("showTags", "Show tags", type: .bool(current: current.showTags)),
			Setting("chat", "Allow livechat", type: .list(options: GroupSettings.ChatState.allCases.map(\.rawValue), current: current.chatState.rawValue)),
            ]
    }
    
    struct Setting: Codable{
        init(_ key: String, _ name: String, type: SettingsType, disclaimer: String? = nil){
            self.key = key
            self.name = name
            self.type = type
            self.disclaimer = disclaimer
        }
        
        var key: String
        var name: String
        var type: SettingsType
        var disclaimer: String?
        
        enum SettingsType: Codable{
            case bool(current: Bool)
            case list(options: [String], current: String)
        }
    }
}


struct SetSettings: Codable{
    var auv: String?
    var selfReset: String?
    var CSVConfiguration: String?
	var showTags: String?
	var chat: GroupSettings.ChatState?
	
    func saveSettings(to group: Group) async{
        let rAUV = convertBool(auv)
        let rSelfReset = convertBool(selfReset)
		let rShowTags = convertBool(showTags)

		
        let rConfig: CSVConfiguration?
        if let key = CSVConfiguration{
            rConfig = await group.settings.csvKeys[key]
        } else {
            rConfig = nil
        }
        
		await group.setSettings(allowsUnverifiedConstituents: rAUV, constituentsCanSelfResetVotes: rSelfReset, csvConfiguration: rConfig, showTags: rShowTags, chatState: chat)
    }
    // Due to limitations of HTTP/HTML the state of checkboxes is only sent when they're on
    private func convertBool(_ value: String?) -> Bool{
        switch value{
        case "on":
            return true
        default:
            return false
        }
    }
}
