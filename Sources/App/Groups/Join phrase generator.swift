/// Generates a join phrase with the characters [a-z,, 0-9]
/// - Parameter chars: The number of characters in the final string
/// - Returns: A join phrase with the characters [a-z, 0-9]
func joinPhraseGenerator(chars: UInt = joinPhraseLength) -> String{
	guard chars >= 1 else {
		assertionFailure("Join phrases can't be \(chars) long")
		return ""
	}
	return String((1...chars).map{ _ in possibleChars.randomElement()!})
}

fileprivate let possibleChars: Set<Character> = {
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
