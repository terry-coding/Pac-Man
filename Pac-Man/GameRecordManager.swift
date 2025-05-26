import Foundation

class GameRecordManager {
    static let shared = GameRecordManager()
    private let recordsKey = "pacman_game_records"
    
    private init() {}
    
    func saveRecord(_ record: GameRecord) {
        var records = getAllRecords()
        records.append(record)
        records.sort { $0.timeSpent < $1.timeSpent } // 按完成時間排序
        
        if let encodedData = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(encodedData, forKey: recordsKey)
        }
    }
    
    func getAllRecords() -> [GameRecord] {
        guard let data = UserDefaults.standard.data(forKey: recordsKey),
              let records = try? JSONDecoder().decode([GameRecord].self, from: data) else {
            return []
        }
        return records
    }
    
    func clearAllRecords() {
        UserDefaults.standard.removeObject(forKey: recordsKey)
    }
}