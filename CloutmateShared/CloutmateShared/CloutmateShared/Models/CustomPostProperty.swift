//
//  CustomPostProperty.swift
//  CloutmateShared
//
//  Created by Mike Letts on 10/23/25.
//

import Foundation
import SwiftData

public enum PropertyType: String, Codable {
    case text
    case number
    case select
    case multiselect
    case date
    case checkbox
}

@Model
public final class CustomPostProperty {
    public var id: UUID = UUID()
    public var name: String
    public var typeRaw: String = PropertyType.text.rawValue
    public var options: [String] = []
    public var icon: String?
    public var color: String?
    public var createdAt: Date = Date()
    public var sortOrder: Int = 0
    
    public var type: PropertyType {
        get { PropertyType(rawValue: typeRaw) ?? .text }
        set { typeRaw = newValue.rawValue }
    }
    
    public init(
        name: String,
        type: PropertyType = .text,
        options: [String] = [],
        icon: String? = nil,
        color: String? = nil,
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.name = name
        self.typeRaw = type.rawValue
        self.options = options
        self.icon = icon
        self.color = color
        self.sortOrder = sortOrder
        self.createdAt = Date()
    }
}

public enum ViewType: String, Codable {
    case table
    case kanban
    case gallery
    case timeline
}

@Model
public final class PostView {
    public var id: UUID = UUID()
    public var name: String
    public var viewTypeRaw: String = ViewType.table.rawValue
    public var filters: [String: String] = [:]
    public var sortBy: String?
    public var groupBy: String?
    public var visibleProperties: [String] = []
    public var isDefault: Bool = false
    public var createdAt: Date = Date()
    
    public var viewType: ViewType {
        get { ViewType(rawValue: viewTypeRaw) ?? .table }
        set { viewTypeRaw = newValue.rawValue }
    }
    
    public init(
        name: String,
        viewType: ViewType = .table,
        filters: [String: String] = [:],
        sortBy: String? = nil,
        groupBy: String? = nil,
        visibleProperties: [String] = [],
        isDefault: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.viewTypeRaw = viewType.rawValue
        self.filters = filters
        self.sortBy = sortBy
        self.groupBy = groupBy
        self.visibleProperties = visibleProperties
        self.isDefault = isDefault
        self.createdAt = Date()
    }
}

