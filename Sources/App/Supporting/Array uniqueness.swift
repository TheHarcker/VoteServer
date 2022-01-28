extension Array where Element : Equatable {
	var nonUniques: [Self.Element] {
		var allUnique: [Self.Element] = []
		
		return self.compactMap{ element -> Self.Element? in
			if allUnique.contains(element){
				return element
			} else {
				allUnique.append(element)
				return nil
			}
		}
	}
	
	
}
