import Foundation

enum LessonDifficulty: String, Codable, CaseIterable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
}

enum LessonCategory: String, Codable, CaseIterable, Identifiable {
    case stadiumDesign = "Stadium Design"
    case mosaicDesign = "Mosaic Design"
    case colourMatching = "Colour Matching"
    case scaleProportion = "Scale and Proportion"
    case brickTechniques = "Brick Techniques"
    case displayTips = "Display Tips"
    case behindTheBuild = "Behind the Build"
    case studioTips = "Stud.io Tips"
    case beginnerGuides = "Beginner Guides"
    case advancedGuides = "Advanced Guides"

    var id: String { rawValue }
}

struct Lesson: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var slug: String
    var summary: String
    var bodyMarkdown: String
    var difficulty: LessonDifficulty
    var category: LessonCategory
    var tags: [String]
    var readTimeMinutes: Int
    var commentsEnabled: Bool
    var status: PublishStatus
    var likeCount: Int
    var viewCount: Int
    var publishedAt: Date?
    var createdAt: Date
    var updatedAt: Date
}
