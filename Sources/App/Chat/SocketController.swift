import Vapor
import Fluent
import VoteKit

fileprivate struct SocketWrapper{
	var socket: WebSocket
	var constituent: ConstituentIdentifier
	var isVerified: Bool
}

actor ChatSocketController{
	private var sockets: [ConstituentIdentifier: SocketWrapper] = [:]
	private var adminSocket: WebSocket? = nil
	
	private let db: Database
	private var logger: Logger!
	
	private weak var group: Group?
	
	public init(db: Database) {
		self.db = db
	}
	
	func setup(group: Group) {
		self.group = group
		self.logger = Logger(label: "Chat socket controller: \(group.joinPhrase)")
	}
	
	private func remove(constituent: ConstituentIdentifier) async{
		sockets.removeValue(forKey: constituent)
	}
	
	func connect(_ ws: WebSocket, constituent: Constituent) async {
		guard let group = group else {return}
		
		ws.onBinary { [weak self] ws, buffer in
			guard let self = self, let data = buffer.getData(at: buffer.readerIndex, length: buffer.readableBytes) else { return }
			await self.onData(ws, constituent: constituent, data)
		}
		
		ws.onText { [weak self] ws, text in
			guard let self = self, let data = text.data(using: .utf8) else { return }
			await self.onData(ws, constituent: constituent, data)
		}
		ws.onClose.whenSuccess{
			Task{ [weak self] in
				await self?.remove(constituent: constituent.identifier)
			}
		}

		ws.pingInterval = .seconds(30)
		
		let isVerified = await group.constituentIsVerified(constituent)
		let wrapper = SocketWrapper(socket: ws, constituent: constituent.identifier, isVerified: isVerified)
				
		if let oldSocket = sockets.updateValue(wrapper, forKey: constituent.identifier){
			try? await oldSocket.socket.close()
		}
		
	}
	
	func connectAdmin(_ ws: WebSocket) async {
		if let oldSocket = adminSocket {
			try? await oldSocket.close()
		}
		
		ws.onBinary { [weak self] ws, buffer in
			guard let self = self, let data = buffer.getData(at: buffer.readerIndex, length: buffer.readableBytes) else { return }
			await self.onData(ws, isAdmin: true, data)
		}
		
		ws.onText { [weak self] ws, text in
			guard let self = self, let data = text.data(using: .utf8) else { return }
			await self.onData(ws, isAdmin: true, data)
		}
		ws.pingInterval = .seconds(30)
		adminSocket = ws
	}
	
	private func send(message: ServerChatProtocol, to sockets: [WebSocket]){
		do {
			let encoder = JSONEncoder()
			let data = try encoder.encode(message)
			
			sockets.forEach {
				$0.send(raw: data, opcode: .binary)
			}
			
		} catch {
			logger.report(error: error)
		}
	}
	
	
	private func onData(_ ws: WebSocket, constituent: Constituent? = nil, isAdmin: Bool = false, _ data: Data) async {
		assert((constituent != nil) != isAdmin, "onData needs a constituent or an admin")

		let decoder = JSONDecoder()
		guard let request = try? decoder.decode(ClientChatProtocol.self, from: data) else {
			if group == nil {
				self.kickAll(onlyUnverified: false, includeAdmins: true)
				return
			}
			
			sendER(error: .invalidRequest, to: ws)
			return
		}
		
		await handleRequest(request: request, socket: ws, constituent: constituent, isAdmin: isAdmin)
	}
	
	private func handleRequest(request: ClientChatProtocol, socket ws: WebSocket, constituent: Constituent?, isAdmin: Bool) async{
		assert((constituent != nil) != isAdmin)
		
		guard let group = group else {
			//Removes and closes all sockets if the group is no longer exsistent
			self.kickAll(onlyUnverified: false, includeAdmins: true)
			return
		}
		
		do {
			switch request{
			case .query:
				var qb = Chats
					.query(on: db)
					.filter(\.$groupID == group.id)
					.sort(\.$timestamp, .descending)
				if !isAdmin{
					qb = qb.limit(Int(Config.chatQueryLimit))
				}
				
				let chats = try await qb.all()
			
				
				await self.send(message: .newMessages(chats.chatFormat(group: group)), to: ws)
			case .send(let newMsg):
				let msg = try checkMessage(msg: newMsg)
				
				if !isAdmin{
					// Max n messages pr. m seconds pr. constituent
					let time = Date().advanced(by: -Config.chatRateLimiting.seconds)
					let count = try await Chats.query(on: db)
						.filter(\.$groupID == group.id)
						.filter(\.$sender == constituent!.identifier)
						.filter(\.$timestamp > time)
						.count()
					
					if count >= Config.chatRateLimiting.messages {
						sendER(error: .rateLimited, to: ws)
						return
					}
				}
				
				let chat = Chats(groupID: group.id, sender: isAdmin ? "Admin" : constituent!.identifier, message: msg, systemsMessage: isAdmin)
				try await chat.save(on: db)
				
				Task{
					let name: String
					let imageURL: String?

					if isAdmin{
						name = "Admin"
						imageURL = Config.adminProfilePicture
					} else {
						name = constituent!.getNameOrId()
						imageURL = await group.getGravatarURLForConst(constituent)
					}
					
					let formatted = await chat.chatFormat(senderName: name, imageURL: imageURL)
					await sendToAll(msg: .newMessage(formatted))
				}
			}
		} catch let error as ChatError{
			sendER(error: error, to: ws)
		}
		catch {
			logger.report(error: error)
		}
	}
	
	func close(constituent: ConstituentIdentifier) async{
		do{
			try await self.sockets[constituent]?.socket.close()
		} catch{
			logger.error("Error while kicking \(constituent) from their chatsocket")
		}
	}
	
	func kickAll(onlyUnverified: Bool = false, includeAdmins: Bool = false){
		assert(!(onlyUnverified && includeAdmins))
		
		var toClose = self.sockets.values.filter{!onlyUnverified || !$0.isVerified}.map(\.socket)
		
		if includeAdmins && adminSocket != nil{
			toClose.append(adminSocket!)
		}
		
		Task{ [toClose] in
			for socket in toClose{
				do{
					try await socket.close()
				} catch{
					logger.error("Error while kicking all \(onlyUnverified ? "unverified" : "") from their chatsocket")
				}
				
			}
		}
		
	}
	
	func sendToAll(msg: ServerChatProtocol, async: Bool = false, includeAdmin: Bool = true) async{
		
		if async{
			Task{ [weak self] in
				guard let self = self else {return}
				var allSockets: [WebSocket] = await self.sockets.values.map(\.socket)
				if includeAdmin && adminSocket != nil{
					allSockets.append(adminSocket!)
				}
				
				await self.send(message: msg, to: allSockets)
				
			}
		} else {
			
			var allSockets: [WebSocket] = sockets.values.map(\.socket)
			if includeAdmin && adminSocket != nil{
				allSockets.append(adminSocket!)
			}
			
			self.send(message: msg, to: allSockets)
		}
	}
	
	deinit{
		self.kickAll(onlyUnverified: false, includeAdmins: true)
	}
}



extension ChatSocketController{
	func send(message: ServerChatProtocol, to socket: WebSocket){
		send(message: message, to: [socket])
	}
	
	//Succes sending
	
//	func sendSM(message: serverMessages, to users: [UserID]){
//		send(message: .withSM(message) , to: users)
//	}
//
//	func sendSM(message: serverMessages, respondingTo reqID: ReqID? = nil, to user: UserID){
//		sendSM(message: message, to: [user])
//	}
//
//	func sendSM(message: serverMessages, to socket: [WebSocket]){
//		send(message: .withSM(message), to: socket)
//	}
//	func sendSM(message: serverMessages, respondingTo reqID: ReqID? = nil, to socket: WebSocket){
//		sendSM(message: message, to: [socket])
//	}
//
	//Error sending
	
//	func sendER(error: errorCodes, respondingTo reqID: ReqID? = nil, to user: UserID){
//		send(message: .withError(error, to: reqID), to: [user])
//	}
//
	func sendER(error: ChatError, to socket: WebSocket){
		send(message: .error(error), to: socket)
	}
	
}
