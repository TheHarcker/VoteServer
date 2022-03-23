import Vapor
import Fluent
import VoteKit

fileprivate struct SocketWrapper{
	var socket: WebSocket
	var constituent: ConstituentIdentifier
	var isVerified: Bool
}

actor ChatSocketController{
	var sockets: [ConstituentIdentifier: SocketWrapper] = [:]
	var adminSocket: WebSocket? = nil
	
	let db: Database
	let logger: Logger
	
	weak var group: Group?
	
	public init(db: Database) {
		self.db = db
		self.logger = Logger(label: "Chat socket controller")
	}
	
	private func remove(constituent: ConstituentIdentifier) async{
		sockets.removeValue(forKey: constituent)
	}
	
	func connect(_ ws: WebSocket, constituent: Constituent) async {
		guard let group = group else {return}
		let isVerified = await group.constituentIsVerified(constituent)
		let wrapper = SocketWrapper(socket: ws, constituent: constituent.identifier, isVerified: isVerified)
				
		if let oldSocket = sockets.updateValue(wrapper, forKey: constituent.identifier){
			try? await oldSocket.socket.close()
		}
		
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
		
	
	}
	
	func send(message: ServerChatProtocol, to sockets: [WebSocket]){
		do {
			
			logger.info("Sending: \(message)")
			
			let encoder = JSONEncoder()
			let data = try encoder.encode(message)
			
			sockets.forEach {
				$0.send(raw: data, opcode: .binary)
			}
			
		} catch {
			logger.report(error: error)
		}
	}
	
	
	func onData(_ ws: WebSocket, constituent: Constituent, _ data: Data) async {
		guard let group = group else {
			//Removes and closes all sockets
			let sockets = self.sockets.values.map(\.socket)
			self.sockets = [:]
			sockets.forEach { socket in
				Task{
					socket.close()
				}
			}
			return
		}
		
		//MARK: Decoding
		let decoder = JSONDecoder()
		guard let request = try? decoder.decode(ClientChatProtocol.self, from: data) else {
			sendER(error: .invalidRequest, to: ws)
			return
		}
		let groupID = group.id
		do {
			switch request{
			case .query:
				let chats = try await Chats
					.query(on: db)
					.filter(\.$groupID == groupID)
					.sort(\.$timestamp)
					.limit(chatQueryLimit)
					.all()

				await self.send(message: .newMessages(chats.chatFormat(group: group)), to: ws)
			case .send(let newMsg):
				let msg = try checkMessage(msg: newMsg)
				
				let chat = Chats(groupID: groupID, sender: constituent.identifier, message: msg)
				try await chat.save(on: db)
				
				Task{
					let formatted = await chat.chatFormat(senderName: constituent.name ?? constituent.identifier)
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
			logger.error("Error while kicking \(constituent) in \(group?.joinPhrase ?? "?") from their chatsocket")
		}
	}
	
	func kickAll(onlyUnverified: Bool = false, includeAdmins: Bool = false){
		assert(!(onlyUnverified && includeAdmins))
		
		var toClose = self.sockets.values.filter{!onlyUnverified || !$0.isVerified}.map(\.socket)
		
		if includeAdmins && adminSocket != nil{
			toClose.append(adminSocket!)
		}
		
		Task{
			for socket in toClose{
				do{
					try await socket.close()
				} catch{
					logger.error("Error while kicking all \(onlyUnverified ? "unverified" : "") in \(group?.joinPhrase ?? "?") from their chatsocket")
				}
				
			}
		}
		
	}
	
	func sendToAll(msg: ServerChatProtocol) async{
		let allSockets: [WebSocket] = sockets.values.map(\.socket)
		self.send(message: msg, to: allSockets)
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
