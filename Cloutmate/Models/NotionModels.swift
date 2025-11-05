//
//  NotionModels.swift
//  Cloutmate
//
//  Notion API Response Models
//

import Foundation
import Combine

// MARK: - OAuth Token Response

struct NotionTokenResponse: Codable {
    let accessToken: String
    let tokenType: String
    let botId: String
    let workspaceId: String?
    let workspaceName: String?
    let workspaceIcon: String?
    let refreshToken: String?
    let owner: NotionOwner?
    let duplicatedTemplateId: String?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case botId = "bot_id"
        case workspaceId = "workspace_id"
        case workspaceName = "workspace_name"
        case workspaceIcon = "workspace_icon"
        case refreshToken = "refresh_token"
        case owner
        case duplicatedTemplateId = "duplicated_template_id"
    }
}


// MARK: - Error Response

struct NotionAPIErrorResponse: Codable {
    let object: String
    let status: Int
    let code: String
    let message: String
}

// MARK: - Database List Response

struct NotionDatabaseListResponse: Codable {
    let object: String
    let results: [NotionDatabase]
    let nextCursor: String?
    let hasMore: Bool?
    
    enum CodingKeys: String, CodingKey {
        case object
        case results
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
    }
}

// MARK: - Database Response

struct NotionDatabaseResponse: Codable {
    let object: String
    let id: String
    let createdTime: Date
    let lastEditedTime: Date
    let createdBy: NotionUser?
    let lastEditedBy: NotionUser?
    let title: [NotionRichText]
    let description: [NotionRichText]?
    let isInline: Bool?
    let properties: [String: NotionProperty]
    
    enum CodingKeys: String, CodingKey {
        case object
        case id
        case createdTime = "created_time"
        case lastEditedTime = "last_edited_time"
        case createdBy = "created_by"
        case lastEditedBy = "last_edited_by"
        case title
        case description
        case isInline = "is_inline"
        case properties
    }
}

// MARK: - Page/Entry

struct NotionPage: Codable {
    let object: String
    let id: String
    let createdTime: Date
    let lastEditedTime: Date
    let createdBy: NotionUser?
    let lastEditedBy: NotionUser?
    let archived: Bool
    let properties: [String: NotionPropertyValue]
    let url: String
    let parent: NotionParent?
    
    enum CodingKeys: String, CodingKey {
        case object
        case id
        case createdTime = "created_time"
        case lastEditedTime = "last_edited_time"
        case createdBy = "created_by"
        case lastEditedBy = "last_edited_by"
        case archived
        case properties
        case url
        case parent
    }
}

struct NotionDatabase: Codable {
    let object: String
    let id: String
    let cover: NotionCover?
    let icon: NotionIcon?
    let createdTime: Date?
    let createdBy: NotionUser?
    let lastEditedBy: NotionUser?
    let lastEditedTime: Date?
    let title: [NotionRichText]?
    let description: [NotionRichText]?
    let isInline: Bool?
    let properties: [String: NotionProperty]?
    let parent: NotionParent?
    let url: String?
    let publicURL: String?
    let archived: Bool?
    let inTrash: Bool?
    
    enum CodingKeys: String, CodingKey {
        case object
        case id
        case cover
        case icon
        case createdTime = "created_time"
        case createdBy = "created_by"
        case lastEditedBy = "last_edited_by"
        case lastEditedTime = "last_edited_time"
        case title
        case description
        case isInline = "is_inline"
        case properties
        case parent
        case url
        case publicURL = "public_url"
        case archived
        case inTrash = "in_trash"
    }
}

// MARK: - Property Types

enum NotionPropertyType: String, Codable {
    case title
    case richText = "rich_text"
    case number
    case select
    case multiSelect = "multi_select"
    case date
    case people
    case files
    case checkBox = "checkbox"
    case url
    case email
    case phoneNumber = "phone_number"
    case formula
    case relation
    case rollup
    case createdTime = "created_time"
    case createdBy = "created_by"
    case lastEditedTime = "last_edited_time"
    case lastEditedBy = "last_edited_by"
}

enum NotionPropertyValue: Codable {
    case title([NotionRichText])
    case richText([NotionRichText])
    case number(Double?)
    case select(NotionSelectOption?)
    case multiSelect([NotionSelectOption])
    case date(NotionDateValue?)
    case people([NotionUser])
    case files([NotionFile])
    case checkbox(Bool)
    case url(String?)
    case email(String?)
    case phoneNumber(String?)
    case formula(NotionFormulaValue)
    case relation(NotionRelation)
    case rollup(NotionRollupValue)
    case createdTime(Date)
    case createdBy(NotionUser)
    case lastEditedTime(Date)
    case lastEditedBy(NotionUser)
    
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "title":
            self = .title(try NotionRichTextValue(from: decoder).title)
        case "rich_text":
            self = .richText(try NotionRichTextValue(from: decoder).richText)
        case "number":
            self = .number(try NotionNumberValue(from: decoder).number)
        case "select":
            self = .select(try NotionSelectValue(from: decoder).select)
        case "multi_select":
            self = .multiSelect(try NotionMultiSelectValue(from: decoder).multiSelect)
        case "date":
            self = .date(try NotionDatePropertyValue(from: decoder).date)
        case "people":
            self = .people(try NotionPeopleValue(from: decoder).people)
        case "files":
            self = .files(try NotionFilesValue(from: decoder).files)
        case "checkbox":
            self = .checkbox(try NotionCheckboxValue(from: decoder).checkbox)
        case "url":
            self = .url(try NotionUrlValue(from: decoder).url)
        case "email":
            self = .email(try NotionEmailValue(from: decoder).email)
        case "phone_number":
            self = .phoneNumber(try NotionPhoneValue(from: decoder).phoneNumber)
        case "formula":
            self = .formula(try NotionFormulaPropertyValue(from: decoder).formula)
        case "relation":
            self = .relation(try NotionRelationPropertyValue(from: decoder).relation)
        case "rollup":
            self = .rollup(try NotionRollupPropertyValue(from: decoder).rollup)
        case "created_time":
            self = .createdTime(try NotionCreatedTimeValue(from: decoder).createdTime)
        case "created_by":
            self = .createdBy(try NotionCreatedByValue(from: decoder).createdBy)
        case "last_edited_time":
            self = .lastEditedTime(try NotionLastEditedTimeValue(from: decoder).lastEditedTime)
        case "last_edited_by":
            self = .lastEditedBy(try NotionLastEditedByValue(from: decoder).lastEditedBy)
        default:
            throw DecodingError.typeMismatch(NotionPropertyValue.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unknown property type: \(type)"))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        // Implementation would be complex, not needed for now
    }
}

// Property structure - simple struct that just ignores unknown fields
struct NotionProperty: Codable {
    let id: String
    let type: String
    let name: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case name
    }
}


struct NotionPropertyTitle: Codable {
    // Empty - just a marker
}

struct NotionPropertyRichText: Codable {
    // Empty - just a marker
}

struct NotionPropertySelect: Codable {
    let options: [NotionPropertySelectOption]
}

struct NotionPropertyMultiSelect: Codable {
    let options: [NotionPropertySelectOption]
}

struct NotionPropertyStatus: Codable {
    let options: [NotionPropertyStatusOption]
    let groups: [NotionPropertyStatusGroup]
}

struct NotionPropertyStatusOption: Codable {
    let id: String
    let name: String
    let color: String?
    let description: String?
}

struct NotionPropertyStatusGroup: Codable {
    let id: String
    let name: String
    let color: String?
    let optionIds: [String]
    
    enum CodingKeys: String, CodingKey {
        case id, name, color
        case optionIds = "option_ids"
    }
}

struct NotionPropertyDate: Codable {
    // Empty - just a marker
}

struct NotionPropertyButton: Codable {
    // Empty - just a marker
}

struct NotionPropertyPeople: Codable {
    // Empty - just a marker
}

struct NotionPropertyCheckbox: Codable {
    // Empty - just a marker
}

struct NotionPropertyNumber: Codable {
    let format: String?
}

struct NotionPropertyURL: Codable {
    // Empty - just a marker
}

struct NotionPropertyEmail: Codable {
    // Empty - just a marker
}

struct NotionPropertyPhone: Codable {
    // Empty - just a marker
}

struct NotionPropertyFiles: Codable {
    // Empty - just a marker
}

struct NotionPropertyCreatedTime: Codable {
    let format: String?
}

struct NotionPropertyCreatedBy: Codable {
    // Empty - just a marker
}

struct NotionPropertyLastEditedTime: Codable {
    let format: String?
}

struct NotionPropertyLastEditedBy: Codable {
    // Empty - just a marker
}

struct NotionPropertyRollup: Codable {
    let rollupPropertyName: String
    let relationPropertyName: String
    let rollupPropertyId: String
    let relationPropertyId: String
    let function: String
    
    enum CodingKeys: String, CodingKey {
        case rollupPropertyName
        case relationPropertyName
        case rollupPropertyId
        case relationPropertyId
        case function
    }
}

struct NotionPropertySelectOption: Codable {
    let id: String
    let name: String
    let color: String?
    let description: String?
}

struct NotionPropertyFormula: Codable {
    let expression: String
}

struct NotionPropertyRelation: Codable {
    let databaseId: String
    let dataSourceId: String?
    let type: String
    let dualProperty: NotionDualProperty?
    let singleProperty: NotionSingleProperty?
    
    enum CodingKeys: String, CodingKey {
        case databaseId = "database_id"
        case dataSourceId = "data_source_id"
        case type
        case dualProperty = "dual_property"
        case singleProperty = "single_property"
    }
}

struct NotionDualProperty: Codable {
    let syncedPropertyName: String?
    let syncedPropertyId: String?
    
    enum CodingKeys: String, CodingKey {
        case syncedPropertyName = "synced_property_name"
        case syncedPropertyId = "synced_property_id"
    }
}

struct NotionSingleProperty: Codable {
    // Empty - just a marker
}

// MARK: - Helper Structures for Property Values

private struct NotionRichTextValue: Codable {
    let title: [NotionRichText]
    let richText: [NotionRichText]
}

private struct NotionNumberValue: Codable {
    let number: Double?
}

private struct NotionSelectValue: Codable {
    let select: NotionSelectOption?
}

private struct NotionMultiSelectValue: Codable {
    let multiSelect: [NotionSelectOption]
}

private struct NotionDatePropertyValue: Codable {
    let date: NotionDateValue?
}

private struct NotionPeopleValue: Codable {
    let people: [NotionUser]
}

private struct NotionFilesValue: Codable {
    let files: [NotionFile]
}

private struct NotionCheckboxValue: Codable {
    let checkbox: Bool
}

private struct NotionUrlValue: Codable {
    let url: String?
}

private struct NotionEmailValue: Codable {
    let email: String?
}

private struct NotionPhoneValue: Codable {
    let phoneNumber: String?
}

private struct NotionFormulaPropertyValue: Codable {
    let formula: NotionFormulaValue
}

private struct NotionRelationPropertyValue: Codable {
    let relation: NotionRelation
}

private struct NotionRollupPropertyValue: Codable {
    let rollup: NotionRollupValue
}

private struct NotionCreatedTimeValue: Codable {
    let createdTime: Date
}

private struct NotionCreatedByValue: Codable {
    let createdBy: NotionUser
}

private struct NotionLastEditedTimeValue: Codable {
    let lastEditedTime: Date
}

private struct NotionLastEditedByValue: Codable {
    let lastEditedBy: NotionUser
}

// MARK: - Shared Structures

struct NotionRichText: Codable {
    let type: String
    let plainText: String?
    let text: NotionTextContent?
    let annotations: NotionAnnotations?
    let href: String?
    let content: String?
    
    enum CodingKeys: String, CodingKey {
        case type
        case plainText = "plain_text"
        case text
        case annotations
        case href
        case content
    }
}

struct NotionTextContent: Codable {
    let content: String
    let link: NotionLink?
}

struct NotionLink: Codable {
    let type: String
    let url: String
}

struct NotionAnnotations: Codable {
    let bold: Bool?
    let italic: Bool?
    let strikethrough: Bool?
    let underline: Bool?
    let code: Bool?
    let color: String?
}

struct NotionSelectOption: Codable {
    let id: String
    let name: String
    let color: String?
}

struct NotionDateValue: Codable {
    let start: Date
    let end: Date?
    let timeZone: String?
    
    enum CodingKeys: String, CodingKey {
        case start
        case end
        case timeZone = "time_zone"
    }
}

struct NotionUser: Codable {
    let object: String
    let id: String
    let name: String?
    let avatarUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case object
        case id
        case name
        case avatarUrl = "avatar_url"
    }
}

struct NotionFile: Codable {
    let name: String
    let type: String
    let file: NotionFileInfo?
    
    struct NotionFileInfo: Codable {
        let url: String
        let expiryTime: String?
        
        enum CodingKeys: String, CodingKey {
            case url
            case expiryTime = "expiry_time"
        }
    }
}

struct NotionFormulaValue: Codable {
    let type: String
    let value: AnyCodable
}

struct NotionRelation: Codable {
    let id: String
}

struct NotionRollupValue: Codable {
    let type: String
    let value: AnyCodable
}

struct NotionParent: Codable {
    let type: String
    let databaseId: String?
    let pageId: String?
    let workspace: Bool?
    
    enum CodingKeys: String, CodingKey {
        case type
        case databaseId = "database_id"
        case pageId = "page_id"
        case workspace
    }
}

struct NotionCover: Codable {
    let type: String
    let external: NotionExternalFile?
    
    enum CodingKeys: String, CodingKey {
        case type
        case external
    }
}

struct NotionIcon: Codable {
    let type: String
    let emoji: String?
    let external: NotionExternalFile?
    let file: NotionExternalFile?
    
    enum CodingKeys: String, CodingKey {
        case type
        case emoji
        case external
        case file
    }
}

struct NotionExternalFile: Codable {
    let url: String
}

// MARK: - Owner
struct NotionOwner: Codable {
    let type: String
    let user: NotionUserWrapper?
    
    enum CodingKeys: String, CodingKey {
        case type
        case user
    }
}

struct NotionUserWrapper: Codable {
    let object: String
    let id: String
    let name: String?
    let avatarUrl: String?
    let type: String
    let person: NotionPerson?
    
    enum CodingKeys: String, CodingKey {
        case object
        case id
        case name
        case avatarUrl = "avatar_url"
        case type
        case person
    }
}

struct NotionPerson: Codable {
    let email: String
}

// MARK: - Page List Response

struct NotionPageListResponse: Codable {
    let object: String
    let results: [NotionPage]
    let nextCursor: String?
    let hasMore: Bool
    
    enum CodingKeys: String, CodingKey {
        case object
        case results
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
    }
}

// MARK: - Any Codable

struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict
        } else {
            throw DecodingError.typeMismatch(AnyCodable.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unable to decode AnyCodable"))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        if let bool = value as? Bool {
            try container.encode(bool)
        } else if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let string = value as? String {
            try container.encode(string)
        } else {
            // For complex types, we'd need more sophisticated encoding
            try container.encodeNil()
        }
    }
}

