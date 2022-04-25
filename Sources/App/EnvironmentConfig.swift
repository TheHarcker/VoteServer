import Vapor
struct Config{
	let maxNameLength: UInt
	let joinPhraseLength: UInt
	let maxChatLength: UInt
	let chatQueryLimit: UInt
	let chatRateLimiting: (seconds: Double, messages: UInt)
	let defaultValueForUnverifiedConstituents: Bool
	let enableChat: Bool
	let adminProfilePicture: String
	
	private(set) static var config: Config!
	
	static func setGlobalConfig() {
		self.config = getEnvironmentConfig()
	}
	
	static func setDefaultConfig(){
		self.config = getDefaultConfig()
	}
	
	private static func getEnvironmentConfig() -> Config{
		let defaultConfig = getDefaultConfig()
		let maxNameLength: UInt = Environment.key("maxNameLength", defaultValue: defaultConfig.maxNameLength)
		let joinPhraseLength: UInt = Environment.key("joinPhraseLength", defaultValue: defaultConfig.joinPhraseLength)
		let maxChatLength: UInt = Environment.key("maxChatLength", defaultValue: defaultConfig.maxChatLength)
		let chatQueryLimit: UInt = Environment.key("chatQueryLimit", defaultValue: defaultConfig.chatQueryLimit)
		let chatRateLimiting: (seconds: Double, messages: UInt) = (seconds: Environment.key("chatRateLimitingSeconds", defaultValue: defaultConfig.chatRateLimiting.seconds), messages: Environment.key("chatRateLimitingMessages", defaultValue: defaultConfig.chatRateLimiting.messages))
		let defaultValueForUnverifiedConstituents: Bool = Environment.key("defaultValueForUnverifiedConstituents", defaultValue: defaultConfig.defaultValueForUnverifiedConstituents)
		let enableChat: Bool = Environment.key("enableChat", defaultValue: defaultConfig.enableChat)
		let adminProfilePicture: String = Environment.key("adminProfilePicture", defaultValue: defaultConfig.adminProfilePicture)
		
		return Config(maxNameLength: maxNameLength, joinPhraseLength: joinPhraseLength, maxChatLength: maxChatLength, chatQueryLimit: chatQueryLimit, chatRateLimiting: chatRateLimiting, defaultValueForUnverifiedConstituents: defaultValueForUnverifiedConstituents, enableChat: enableChat, adminProfilePicture: adminProfilePicture)
	}
	
	private static func getDefaultConfig() -> Config{
		Config(maxNameLength: 100, joinPhraseLength: 6, maxChatLength: 1000, chatQueryLimit: 100, chatRateLimiting: (seconds: 10.0, messages: 10), defaultValueForUnverifiedConstituents: false, enableChat: true, adminProfilePicture: "/img/icon.png")
	}
}

extension Config{
	static var maxNameLength: UInt {Self.config.maxNameLength}
	static var joinPhraseLength: UInt {Self.config.joinPhraseLength}
	static var maxChatLength: UInt {Self.config.maxChatLength}
	static var chatQueryLimit: UInt {Self.config.chatQueryLimit}
	static var chatRateLimiting: (seconds: Double, messages: UInt) {Self.config.chatRateLimiting}
	static var defaultValueForUnverifiedConstituents: Bool {Self.config.defaultValueForUnverifiedConstituents}
	static var enableChat: Bool {Self.config.enableChat}
	static var adminProfilePicture: String {Self.config.adminProfilePicture}

}

extension Environment{
	fileprivate static func key(_ key: String, defaultValue: UInt) -> UInt{
		guard let v: String = Self.get(key) else {
			return defaultValue
		}
		
		guard let i = UInt(v) else {
			fatalError("Could not read Environmental variable \"\(key)\", expected unsigned integer (UInt64 on most systems)")
		}
		return i
	}
	
	fileprivate static func key(_ key: String, defaultValue: Double) -> Double{
		guard let v: String = Self.get(key) else {
			return defaultValue
		}
		
		guard let i = Double(v) else {
			fatalError("Could not read Environmental variable \"\(key)\", expected floating point value (Double)")
		}
		return i
	}
	
	fileprivate static func key(_ key: String, defaultValue: Bool) -> Bool{
		guard let v: String = Self.get(key) else {
			return defaultValue
		}
		
		guard let i = Bool(v) else {
			fatalError("Could not read Environmental variable \"\(key)\", expected boolean value (true/false)")
		}
		return i
	}
	
	fileprivate static func key(_ key: String, defaultValue: String) -> String{
		guard let v: String = Self.get(key) else {
			return defaultValue
		}
		
		guard !v.isEmpty else {
			fatalError("Could not read Environmental variable \"\(key)\", expected a non empty string value")
		}
		return v
	}
}
