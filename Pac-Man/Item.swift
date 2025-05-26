//
//  Item.swift
//  Pac-Man
//
//  Created by 戴光晨 on 2025/4/23.
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
