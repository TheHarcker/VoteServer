struct AdminUIController: UITableManager{
	var title: String
	var errorString: String? = nil
	var hideIfEmpty: Bool = true
	
	var buttons: [UIButton] = [
		.reload,
        .init(uri: .createvote(.alternative), text: "Create \"Alternative vote\"", color: .green),
        .init(uri: .createvote(.simpleMajority), text: "Create \"Simple majority vote\"", color: .green),
        .init(uri: .createvote(.yesNo), text: "Create \"Yes/no vote\"", color: .green),
        .init(uri: "/admin/settings/", text: "Settings", color: .blue),
		.init(uri: "/admin/constituents/", text: "Manage constituents", color: .blue),
	]
	
	var rows = [SimplifiedVoteData]()
	var tableHeaders = [String]()
	
	var groupJoinLink: String
	
	init(for group: Group) async{
		self.title = group.name
		groupJoinLink = group.joinPhrase
		tableHeaders = ["Name", "Vote type", "No. of votes cast", "Open/closed"]
		
		let (alt, yn, simMaj) = await group.allVotes()
		for vote in alt {
			await genRow(vote)
		}
		
		for vote in yn {
			await genRow(vote)
		}
		
		for vote in simMaj {
			await genRow(vote)
		}
		
		
		func genRow<V: SupportedVoteType>(_ vote: V) async{
			var status = await group.statusFor(vote)
			if status == nil{
				assertionFailure("Vote without status was found.")
                await group.setStatusFor(vote.id, to: .closed)
				status = .closed
			}
			
            await rows.append(SimplifiedVoteData(name: vote.name, voteType: V.typeName, isOpen: status == .open, totalVotesCast: await vote.votes.count, voteID: await vote.id.uuidString))
			
		}
		
		
		rows.sort{ $0.name < $1.name}
		
		if await group.settings.chatState != .disabled {
			self.buttons.append(UIButton(uri: "/admin/chats/", text: "Chats", color: .blue))
		}
	}
	
	static var template: String = "admin"
}

//TODO: Merge with similar type for plaza
struct SimplifiedVoteData: Codable{
	
	let name: String
    let voteType: String
	let isOpen: Bool
	let totalVotesCast: Int
	let voteID: String
}
