func joinPhraseGenerator(chars: Int = 8) -> String{
	let possibleChars: Set<Character> = {
		var set = Set<Character>()
		for i in 0...9{
			set.insert(Character(i.description))
		}
		
		//Based on https://stackoverflow.com/a/63760652/5257653
		let aScalars = "a".unicodeScalars
		let aCode = Int(aScalars[aScalars.startIndex].value)
		
		for i in 0..<26{
			set.insert(Character(Unicode.Scalar(aCode + i) ?? aScalars[aScalars.startIndex]))
		}
		
		return set
	}()
	
	
	return String((1...chars).map{ _ in possibleChars.randomElement()!})
}
