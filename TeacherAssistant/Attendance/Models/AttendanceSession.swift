import Foundation
import SwiftData

@Model
class AttendanceSession {
    var date: Date
    var records: [AttendanceRecord]
    
    init(date: Date, records: [AttendanceRecord] = []) {
        self.date = date
        self.records = records
    }
}
