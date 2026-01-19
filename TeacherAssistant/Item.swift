//
//  Item.swift
//  TeacherAssistant
//
//  Created by Frederico Monaquezi Fernandes on 19/01/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
