import Foundation
import VoteKit
struct PlazaUI: UITableManager{
	var title: String = "Plaza"
	var errorString: String? = nil
	
	var buttons: [UIButton] = [.reload]
	
	var tableHeaders: [String] = ["Name", "Type", "Open", "Voted"]
	
	var rows: [VoteListElement] = []
	var hideIfEmpty: Bool = true
	
	var name: String
	var groupName: String
	
    var allowsVoteDeletion: Bool
    
	var showChat: Bool
	
	static var template: String = "plaza"
	
	
	internal init(errorString: String? = nil, constituent: Constituent, group: Group) async {
		self.errorString = errorString
		self.name = constituent.name ?? constituent.identifier
		self.groupName = group.name

		self.showChat = await group.constituentCanChat(constituent)
		self.allowsVoteDeletion = await group.settings.constituentsCanSelfResetVotes
	
		func setup<V: SupportedVoteType>(_ vote: V) async{
			let hasVoted: Bool = await vote.hasConstituentVoted(constituent)
			guard let status = await group.statusFor(vote) else {
				return
			}
			
			await rows.append(VoteListElement(voteID: vote.id, name: vote.name, isOpen: status == .open, hasVoted: hasVoted, voteType: V.typeName))
		}
		
		
		
		let (alt, yn, simmaj) = await group.allVotes()
		
		for vote in alt {
			await setup(vote)
		}
		
		for vote in yn {
			await setup(vote)
		}
		
		for vote in simmaj {
			await setup(vote)
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


