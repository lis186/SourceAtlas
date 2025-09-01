import Foundation
import Combine

protocol ViewModelProtocol {
    var title: String { get }
    func loadData()
}

class MainViewModel: ObservableObject, ViewModelProtocol {
    @Published var title: String = "Main"
    @Published var items: [String] = []
    
    private let repository: DataRepository
    
    init(repository: DataRepository) {
        self.repository = repository
    }
    
    func loadData() {
        items = repository.fetchItems()
    }
    
    private func processItems(_ items: [String]) -> [String] {
        return items.sorted()
    }
}

struct DataRepository {
    func fetchItems() -> [String] {
        return ["Item1", "Item2", "Item3"]
    }
}