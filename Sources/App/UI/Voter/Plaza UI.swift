import Foundation
import VoteKit
struct PlazaUI: UITableManager{
	var title: String = "Plaza"
	var errorString: String? = nil
	var generalInformation: HeaderInformation! = nil
	
	var buttons: [UIButton] = [.reload]
	
	var tableHeaders: [String] = ["Name", "Type", "Open", "Voted"]
	
	var rows: [VoteListElement] = []
	var hideIfEmpty: Bool = true
	
	var name: String
	var groupName: String
	
    var allowsVoteDeletion: Bool
    
	var showChat: Bool
	
	static var template: String = "plaza"
	
	
	internal init(errorString: String? = nil, linker: GroupConstLinker, dbGroup: DBGroup, group: Group, user: DBUser) async {
		self.errorString = errorString
		self.name = user.name
		self.groupName = dbGroup.name

		self.showChat = linker.constituentCanChat()
		self.allowsVoteDeletion = dbGroup.settings.constituentsCanSelfResetVotes
		let constituent = user.asConstituent()
		
		for vote in await group.allVotes() {
			let hasVoted: Bool = await vote.hasConstituentVoted(constituent)
			guard let status = await group.statusFor(vote) else {
				return
			}
			
			await rows.append(VoteListElement(voteID: vote.id, name: vote.name, isOpen: status == .open, hasVoted: hasVoted, voteType: vote.longName))
		}
		
		rows.sort(by: {$0.name < $1.name})
	}
	
	
	struct VoteListElement: Codable{
		init(voteID: UUID, name: String, isOpen: Bool, hasVoted: Bool, voteType: String) {
			self.voteID = voteID
			self.name = name
			self.isOpen = isOpen
			self.hasVoted = hasVoted
			self.showLink = isOpen && !hasVoted
			self.voteType = voteType
		}
		
		let voteID: UUID
		let name: String
		let isOpen: Bool
		let hasVoted: Bool
		let showLink: Bool
		let voteType: String
	}
}


