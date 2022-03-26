protocol UITableManager: UIManager{
    associatedtype rowType: Codable
    var rows: [rowType] {get}
    var tableHeaders: [String] {get}
	
	var hideIfEmpty: Bool {get}

}

extension UITableManager{
	var hideIfEmpty: Bool {false}
}
