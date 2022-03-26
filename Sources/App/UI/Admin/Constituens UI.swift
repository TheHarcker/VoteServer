import VoteKit
struct ConstituentsListUI: UITableManager{
	var title: String = "Constituents"
	var errorString: String? = nil
	var hideIfEmpty: Bool = true
	
	var buttons: [UIButton] = [.backToAdmin,
							   .reload,
							   .init(uri: "/admin/constituents/downloadcsv/", text: "Download constituents as CSV", color: .blue, downloadable: true)
	]
	
	var tableHeaders: [String]
	var rows: [ConstituentData] = []

	var allowsUnverified: Bool
	
	static var template: String = "constituents list"
	
	var showsTags: Bool
	var tagStats: [String]? = nil
	
	init(group: Group) async{
		let verified = await group.verifiedConstituents
		let unverified = await group.unverifiedConstituents
		
		
        self.allowsUnverified = await group.settings.allowsUnverifiedConstituents
		
		assert(verified.isDisjoint(with: unverified))
		
		self.showsTags = await group.settings.showTags
		if self.showsTags {
			self.tableHeaders = ["User id", "Name", "Tag", "Is verified", ""]
			if !verified.isEmpty || !unverified.isEmpty{
				let joined = await Set(group.joinedConstituentsByID.keys)
				self.tagStats = generateStats(verified: verified, unverified: unverified, joined: joined)
			}
		} else {
			self.tableHeaders = ["User id", "Name", "Is verified", ""]
		}
		
		
		for const in verified{
			rows.append(await ConstituentData(constituent: const, group: group, isVerified: true))
			
		}
		
		for const in unverified {
			rows.append(await ConstituentData(constituent: const, group: group, isVerified: false))
		}
		
		rows.sort{$0.userID < $1.userID}
	}
	/// Calculates statistics for all tags
	private func generateStats(verified: Set<Constituent>, unverified: Set<Constituent>, joined: Set<ConstituentIdentifier>) -> [String]{
		var tagStats = [String]()
		func genStat(tag: String, constituentIdentifiers conID: Array<ConstituentIdentifier>, numTot: Int) {
			let num = joined.intersection(conID).count

			let pct = Double(num)/Double(numTot) * 100.0
			let pctStr = String(format:"%.2f", pct)
			let str = " \(tag): \(num)/\(numTot), \(pctStr)%"
			tagStats.append(str)
		}
		
		
		let allTags = Set(verified.map(\.tag))
		
		for tag in allTags {
			let constForTag = verified.filter{$0.tag == tag}.map(\.identifier)
			let numTot = constForTag.count

			genStat(tag: tag ?? "--No tag", constituentIdentifiers: constForTag, numTot: numTot)
		}
		
		genStat(tag: "--Total", constituentIdentifiers: verified.union(unverified).map(\.identifier), numTot: verified.count + unverified.count)
		
		if !verified.isEmpty{
			genStat(tag: "--Verified", constituentIdentifiers: verified.map(\.identifier), numTot: verified.count)
		}
		if !unverified.isEmpty {
			genStat(tag: "--Unverified", constituentIdentifiers: unverified.map(\.identifier), numTot: unverified.count)
		}
		
		return tagStats.sorted { str1, str2 in
			if str1.hasPrefix("--"){
				return str2.hasPrefix("--") && str1 < str2
			} else {
				return str2.hasPrefix("--") || str1 < str2
			}
		}
	}
	
	
	struct ConstituentData: Codable{
		internal init(constituent: Constituent, group: Group, isVerified: Bool) async{
			self.userID = constituent.identifier
			self.name = constituent.name ?? ""
            self.userID64 = constituent.identifier.asURLSafeBase64() ?? ""
			self.isVerified = isVerified
			self.hasJoined = await group.constituentHasJoined(constituent.identifier)
			self.tag = constituent.tag ?? ""
		}
		
		var tag: String
		var userID: String
        var userID64: String
		var name: String
		var isVerified: Bool
		var hasJoined: Bool
	}
}
