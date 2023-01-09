import VoteKit
struct VoteCreatorUI<V: VoteProtocol>: UIManager{
	var title: String
	var errorString: String? = nil
	var generalInformation: HeaderInformation! = nil
	static var template: String {"createvote"}
	
    let validatorsGeneric: [ValidatorData<V>]
    let validatorsParticular: [ValidatorData<V>]
	let nameOfVote: String?
	let options: String?
	
    var buttons: [UIButton] = []
    
	init(errorString: String? = nil, validatorsGeneric: [ValidatorData<V>], validatorsParticular: [ValidatorData<V>], _ persistentData: VoteCreationReceivedData<V>? = nil) {
		self.title = "Create \(V.shortName)"
        self.errorString = errorString
        self.nameOfVote = persistentData?.nameOfVote
        self.options = persistentData?.options.trimmingCharacters(in: .whitespacesAndNewlines)
		
        
		
		// Sets the validator as enabled if they appear in persistentData
		if let enabledValidatorIDs = persistentData?.getAllEnabledIDs(), !enabledValidatorIDs.isEmpty{
			self.validatorsGeneric = validatorsGeneric.map{val in
				var val = val
				val.isEnabled = enabledValidatorIDs.contains(val.id)
				return val
			}
            
            self.validatorsParticular = validatorsParticular.map{val in
                var val = val
                val.isEnabled = enabledValidatorIDs.contains(val.id)
                return val
            }
		} else {
			self.validatorsGeneric = validatorsGeneric
            self.validatorsParticular = validatorsParticular
		}
	}
	
}

