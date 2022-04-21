/// Generates a join phrase with the characters [a-z,, 0-9]
/// - Parameter chars: The number of characters in the final string
/// - Returns: A join phrase with the characters [a-z, 0-9]
func joinPhraseGenerator(chars: UInt = Config.joinPhraseLength) -> String{
	guard chars >= 1 else {
		assertionFailure("Join phrases can't be \(chars) long")
		return ""
	}
	return String((1...chars).map{ _ in possibleChars.randomElement()!})
}

fileprivate let possibleChars: Set<Character> = {
	//Based on https://stackoverflow.com/a/63760652/5257653
	let aScalars: String.UnicodeScalarView = "a".unicodeScalars
	let aCode = Int(aScalars[aScalars.startIndex].value)
	
	let numbers: [Character] = (0...9).map{i -> Character in
		return Character(i.description)
	}
	
	let chars: [Character] = (0..<26).map { i -> Character in
		return Character(Unicode.Scalar(aCode + i)!)
	}
	
	return Set(chars + numbers)
}()
