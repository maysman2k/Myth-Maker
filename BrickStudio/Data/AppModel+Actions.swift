import Foundation
import CryptoKit

enum AuthError: LocalizedError {
    case invalidEmail
    case missingName
    case weakPassword
    case emailInUse
    case invalidCredentials
    case noAccountForEmail

    var errorDescription: String? {
        switch self {
        case .invalidEmail: return "That email address doesn't look right. Check it and try again."
        case .missingName: return "Add a display name so other builders know who you are."
        case .weakPassword: return "Choose a password with at least 8 characters."
        case .emailInUse: return "There's already an account with that email. Try signing in instead."
        case .invalidCredentials: return "Email or password didn't match. Try again."
        case .noAccountForEmail: return "We couldn't find an account with that email."
        }
    }
}

extension AppModel {
    // MARK: Toast

    func showToast(_ message: String, symbol: String = "checkmark.circle.fill") {
        toast = Toast(message: message, symbol: symbol)
    }

    /// Gate for member-only actions: shows the sign-in sheet for guests.
    @discardableResult
    func requireAccount() -> Bool {
        if isSignedIn { return true }
        isShowingAuth = true
        return false
    }

    // MARK: Auth

    static func hashPassword(_ password: String, email: String) -> String {
        let seasoned = "brickstudio:\(email.lowercased()):\(password)"
        let digest = SHA256.hash(data: Data(seasoned.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    func signUp(displayName: String, email: String, password: String) throws {
        let trimmedName = displayName.trimmingCharacters(in: .whitespaces)
        let normalisedEmail = email.trimmingCharacters(in: .whitespaces).lowercased()
        guard RequestValidator.isValidEmail(normalisedEmail) else { throw AuthError.invalidEmail }
        guard !trimmedName.isEmpty else { throw AuthError.missingName }
        guard password.count >= 8 else { throw AuthError.weakPassword }
        guard !accounts.contains(where: { $0.email == normalisedEmail }) else { throw AuthError.emailInUse }

        var account = UserAccount.new(
            displayName: trimmedName,
            email: normalisedEmail,
            passwordHash: Self.hashPassword(password, email: normalisedEmail)
        )
        account.lastActiveAt = Date()
        accounts.append(account)
        currentUserID = account.id
        notify(
            userID: account.id,
            kind: .general,
            title: "Welcome to Bricks in a Bag Studio",
            body: "Save what you love, join the conversation, and send us your build ideas."
        )
        isShowingAuth = false
        showToast("Welcome, \(trimmedName)")
        persist()
    }

    func signIn(email: String, password: String) throws {
        let normalisedEmail = email.trimmingCharacters(in: .whitespaces).lowercased()
        guard let index = accounts.firstIndex(where: { $0.email == normalisedEmail }) else {
            throw AuthError.invalidCredentials
        }
        guard accounts[index].passwordHash == Self.hashPassword(password, email: normalisedEmail) else {
            throw AuthError.invalidCredentials
        }
        accounts[index].lastActiveAt = Date()
        currentUserID = accounts[index].id
        isShowingAuth = false
        showToast("Signed in as \(accounts[index].displayName)")
        persist()
    }

    /// Demo stand-in for magic-link auth: signs straight in when the email
    /// matches an existing account. A real build sends an email link.
    func signInWithMagicLink(email: String) throws {
        let normalisedEmail = email.trimmingCharacters(in: .whitespaces).lowercased()
        guard let index = accounts.firstIndex(where: { $0.email == normalisedEmail }) else {
            throw AuthError.noAccountForEmail
        }
        accounts[index].lastActiveAt = Date()
        currentUserID = accounts[index].id
        isShowingAuth = false
        showToast("Signed in via magic link (demo)")
        persist()
    }

    func signOut() {
        currentUserID = nil
        selectedTab = .today
        showToast("Signed out", symbol: "hand.wave")
        persist()
    }

    func updateProfile(displayName: String, bio: String, favouriteClub: String, favouriteTopics: [String], publicProfileEnabled: Bool) {
        guard let index = accounts.firstIndex(where: { $0.id == currentUserID }) else { return }
        let trimmedName = displayName.trimmingCharacters(in: .whitespaces)
        if !trimmedName.isEmpty { accounts[index].displayName = trimmedName }
        accounts[index].bio = bio
        accounts[index].favouriteClub = favouriteClub
        accounts[index].favouriteTopics = favouriteTopics
        accounts[index].publicProfileEnabled = publicProfileEnabled
        showToast("Profile updated")
        persist()
    }

    func updateNotificationPreferences(_ preferences: NotificationPreferences) {
        guard let index = accounts.firstIndex(where: { $0.id == currentUserID }) else { return }
        accounts[index].notificationPreferences = preferences
        persist()
    }

    // MARK: Likes & bookmarks

    func toggleLike(_ type: ContentType, _ contentID: UUID) {
        guard requireAccount(), let currentUserID else { return }
        if let index = likes.firstIndex(where: { $0.userID == currentUserID && $0.contentType == type && $0.contentID == contentID }) {
            likes.remove(at: index)
            adjustLikeCount(type, contentID, by: -1)
        } else {
            likes.append(LikeRecord(id: UUID(), userID: currentUserID, contentType: type, contentID: contentID, createdAt: Date()))
            adjustLikeCount(type, contentID, by: 1)
            if type == .comment,
               let comment = comments.first(where: { $0.id == contentID }),
               comment.userID != currentUserID,
               account(id: comment.userID)?.notificationPreferences.commentReplies == true {
                notify(
                    userID: comment.userID,
                    kind: .commentLike,
                    title: "Someone liked your comment",
                    body: String(comment.body.prefix(80)),
                    targetType: comment.contentType,
                    targetID: comment.contentID
                )
            }
        }
        persist()
    }

    private func adjustLikeCount(_ type: ContentType, _ contentID: UUID, by delta: Int) {
        switch type {
        case .article:
            if let index = articles.firstIndex(where: { $0.id == contentID }) {
                articles[index].likeCount = max(0, articles[index].likeCount + delta)
            }
        case .review:
            if let index = reviews.firstIndex(where: { $0.id == contentID }) {
                reviews[index].likeCount = max(0, reviews[index].likeCount + delta)
            }
        case .lesson:
            if let index = lessons.firstIndex(where: { $0.id == contentID }) {
                lessons[index].likeCount = max(0, lessons[index].likeCount + delta)
            }
        case .comment:
            if let index = comments.firstIndex(where: { $0.id == contentID }) {
                comments[index].likeCount = max(0, comments[index].likeCount + delta)
            }
        default:
            break
        }
    }

    func toggleBookmark(_ type: ContentType, _ contentID: UUID) {
        guard requireAccount(), let currentUserID else { return }
        if let index = savedItems.firstIndex(where: { $0.userID == currentUserID && $0.contentType == type && $0.contentID == contentID }) {
            savedItems.remove(at: index)
            if type == .product, let productIndex = products.firstIndex(where: { $0.id == contentID }) {
                products[productIndex].saveCount = max(0, products[productIndex].saveCount - 1)
            }
            showToast("Removed from saved", symbol: "bookmark.slash")
        } else {
            savedItems.append(SavedItem(id: UUID(), userID: currentUserID, contentType: type, contentID: contentID, createdAt: Date()))
            if type == .product, let productIndex = products.firstIndex(where: { $0.id == contentID }) {
                products[productIndex].saveCount += 1
            }
            showToast("Saved", symbol: "bookmark.fill")
        }
        persist()
    }

    func incrementView(_ type: ContentType, _ contentID: UUID) {
        switch type {
        case .article:
            if let index = articles.firstIndex(where: { $0.id == contentID }) { articles[index].viewCount += 1 }
        case .review:
            if let index = reviews.firstIndex(where: { $0.id == contentID }) { reviews[index].viewCount += 1 }
        case .lesson:
            if let index = lessons.firstIndex(where: { $0.id == contentID }) { lessons[index].viewCount += 1 }
        case .product:
            if let index = products.firstIndex(where: { $0.id == contentID }) { products[index].viewCount += 1 }
        default:
            break
        }
    }

    // MARK: Comments

    @discardableResult
    func postComment(type: ContentType, contentID: UUID, body: String, parentCommentID: UUID? = nil) -> Bool {
        guard requireAccount(), let user = currentUser else { return false }
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        if let parentCommentID,
           let parent = comments.first(where: { $0.id == parentCommentID }),
           !CommentPolicy.canReply(to: parent, in: comments) {
            showToast("Replies go two levels deep at most.", symbol: "exclamationmark.bubble")
            return false
        }

        let status = CommentPolicy.initialStatus(for: trimmed, accountCreatedAt: user.createdAt)
        let comment = Comment(
            id: UUID(),
            contentType: type,
            contentID: contentID,
            parentCommentID: parentCommentID,
            userID: user.id,
            body: trimmed,
            status: status,
            likeCount: 0,
            reportCount: 0,
            createdAt: Date(),
            editedAt: nil
        )
        comments.append(comment)

        if let parentCommentID,
           let parent = comments.first(where: { $0.id == parentCommentID }),
           parent.userID != user.id,
           account(id: parent.userID)?.notificationPreferences.commentReplies == true {
            notify(
                userID: parent.userID,
                kind: .commentReply,
                title: "\(user.displayName) replied to your comment",
                body: String(trimmed.prefix(80)),
                targetType: type,
                targetID: contentID
            )
        }
        showToast(status == .pendingReview ? "Comment sent for review" : "Comment posted")
        persist()
        return true
    }

    func editComment(_ commentID: UUID, body: String) {
        guard let index = comments.firstIndex(where: { $0.id == commentID }),
              CommentPolicy.canEdit(comments[index], by: currentUserID) else { return }
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        comments[index].body = trimmed
        comments[index].editedAt = Date()
        showToast("Comment updated")
        persist()
    }

    func deleteComment(_ commentID: UUID) {
        guard let index = comments.firstIndex(where: { $0.id == commentID }),
              CommentPolicy.canDelete(comments[index], by: currentUser) else { return }
        comments[index].status = .deleted
        showToast("Comment deleted", symbol: "trash")
        persist()
    }

    func reportComment(_ commentID: UUID, reason: ReportReason, details: String) {
        guard requireAccount(), let currentUserID else { return }
        guard let index = comments.firstIndex(where: { $0.id == commentID }) else { return }
        guard !commentReports.contains(where: { $0.commentID == commentID && $0.reporterUserID == currentUserID }) else {
            showToast("You've already reported this comment.", symbol: "flag")
            return
        }
        commentReports.append(CommentReport(
            id: UUID(),
            commentID: commentID,
            reporterUserID: currentUserID,
            reason: reason,
            details: details,
            createdAt: Date()
        ))
        comments[index].reportCount += 1
        comments[index].status = CommentPolicy.statusAfterReports(
            currentStatus: comments[index].status,
            reportCount: comments[index].reportCount
        )
        showToast("Thanks — our moderators will take a look.", symbol: "flag.fill")
        persist()
    }

    // MARK: Review ratings

    func submitRating(reviewID: UUID, rating: Double, comment: String, ownsSet: Bool, builtSet: Bool) {
        guard requireAccount(), let currentUserID else { return }
        if let index = userRatings.firstIndex(where: { $0.reviewID == reviewID && $0.userID == currentUserID }) {
            userRatings[index].rating = rating
            userRatings[index].comment = comment
            userRatings[index].ownsSet = ownsSet
            userRatings[index].builtSet = builtSet
        } else {
            userRatings.append(ReviewUserRating(
                id: UUID(),
                reviewID: reviewID,
                userID: currentUserID,
                rating: rating,
                comment: comment,
                ownsSet: ownsSet,
                builtSet: builtSet,
                createdAt: Date()
            ))
        }
        showToast("Rating submitted — thanks!", symbol: "star.fill")
        persist()
    }

    // MARK: Mosaics

    func saveMosaic(_ project: MosaicProject) {
        if let index = mosaics.firstIndex(where: { $0.id == project.id }) {
            mosaics[index] = project
        } else {
            mosaics.append(project)
        }
        showToast("Mosaic saved to your designs")
        persist()
    }

    func deleteMosaic(_ projectID: UUID) {
        guard let index = mosaics.firstIndex(where: { $0.id == projectID }) else { return }
        ImageStore.delete(mosaics[index].originalImageFilename)
        ImageStore.delete(mosaics[index].previewImageFilename)
        mosaics.remove(at: index)
        showToast("Design deleted", symbol: "trash")
        persist()
    }

    func sendMosaicToBrickBar(_ projectID: UUID) {
        guard requireAccount(), let user = currentUser else { return }
        guard let index = mosaics.firstIndex(where: { $0.id == projectID }) else { return }
        mosaics[index].status = .sentToBrickBar
        mosaics[index].updatedAt = Date()
        let mosaic = mosaics[index]

        let request = BrickBarRequest(
            id: UUID(),
            userID: user.id,
            buildType: .mosaic,
            title: mosaic.title.isEmpty ? "Custom mosaic build" : mosaic.title,
            description: "Mosaic created in the Studio app. Style: \(mosaic.style.rawValue). Size: \(mosaic.size.rawValue) (\(mosaic.widthStuds)×\(mosaic.heightStuds) studs). Colour mode: \(mosaic.colourMode.rawValue). Estimated \(mosaic.estimatedBrickCount) bricks in \(mosaic.estimatedColourCount) colours.",
            referenceImageFilenames: [mosaic.previewImageFilename].filter { !$0.isEmpty },
            sizePreference: .notSure,
            budgetRange: .notSure,
            deadlineType: .noRush,
            deadlineDate: nil,
            contactEmail: user.email,
            contactPhone: "",
            status: .submitted,
            adminNotes: "",
            quotedPrice: nil,
            quoteStatus: .notQuoted,
            createdAt: Date(),
            updatedAt: Date()
        )
        brickBarRequests.append(request)
        notify(
            userID: user.id,
            kind: .brickBarUpdate,
            title: "Mosaic sent to The Brick Bar",
            body: "We've received your mosaic and will come back with next steps.",
            targetType: .brickBarRequest,
            targetID: request.id
        )
        showToast("Sent to The Brick Bar")
        persist()
    }

    // MARK: Brick Bar

    func submitBrickBarRequest(_ request: BrickBarRequest) {
        var submitted = request
        submitted.status = .submitted
        submitted.updatedAt = Date()
        brickBarRequests.append(submitted)
        notify(
            userID: submitted.userID,
            kind: .brickBarUpdate,
            title: "Request received",
            body: "We've received \"\(submitted.title)\" and will review it shortly.",
            targetType: .brickBarRequest,
            targetID: submitted.id
        )
        showToast("Request submitted — we'll be in touch")
        persist()
    }

    // MARK: Notifications

    func notify(userID: UUID, kind: NotificationKind, title: String, body: String, targetType: ContentType? = nil, targetID: UUID? = nil) {
        notifications.append(NotificationItem(
            id: UUID(),
            userID: userID,
            kind: kind,
            title: title,
            body: body,
            targetType: targetType,
            targetID: targetID,
            readAt: nil,
            createdAt: Date()
        ))
    }

    func markNotificationRead(_ notificationID: UUID) {
        guard let index = notifications.firstIndex(where: { $0.id == notificationID }) else { return }
        if notifications[index].readAt == nil {
            notifications[index].readAt = Date()
            persist()
        }
    }

    func markAllNotificationsRead() {
        for index in notifications.indices where notifications[index].userID == currentUserID && notifications[index].readAt == nil {
            notifications[index].readAt = Date()
        }
        persist()
    }

    // MARK: Lessons

    func toggleLessonCompleted(_ lessonID: UUID) {
        guard requireAccount(), let index = accounts.firstIndex(where: { $0.id == currentUserID }) else { return }
        if accounts[index].completedLessonIDs.contains(lessonID) {
            accounts[index].completedLessonIDs.remove(lessonID)
        } else {
            accounts[index].completedLessonIDs.insert(lessonID)
            showToast("Lesson marked as completed", symbol: "checkmark.seal.fill")
        }
        persist()
    }

    // MARK: Search history

    func recordSearch(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= SearchEngine.minimumQueryLength else { return }
        recentSearches.removeAll { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        recentSearches.insert(trimmed, at: 0)
        recentSearches = Array(recentSearches.prefix(8))
        persist()
    }

    // MARK: Admin actions

    /// Pulls new AI drafts from the scanner feed into the review queue.
    /// Approved/rejected drafts keep their status — only unseen IDs merge in.
    @MainActor
    func refreshAIDrafts(quietErrors: Bool = false) async {
        guard currentUser?.role.canEditContent == true else { return }
        do {
            let fetched = try await DraftFeedService.fetchLatest()
            let knownIDs = Set(aiDrafts.map(\.id))
            let fresh = fetched.filter { !knownIDs.contains($0.id) }
            guard !fresh.isEmpty else { return }
            aiDrafts.append(contentsOf: fresh)
            showToast("\(fresh.count) new AI draft\(fresh.count == 1 ? "" : "s") in the queue", symbol: "sparkles")
            persist()
        } catch {
            if !quietErrors {
                showToast("Couldn't reach the draft feed. Try again in a moment.", symbol: "wifi.exclamationmark")
            }
        }
    }

    /// Publishes an approved draft. `imageURLs` are the editor-approved
    /// images in display order — the first becomes the hero/banner and the
    /// full list renders as the article's photo gallery. Empty means the
    /// branded graphic.
    /// Force-runs the news scanner workflow on GitHub, then polls the feed
    /// until the fresh drafts arrive (a run takes a couple of minutes).
    @MainActor
    func runScannerNow() async {
        guard currentUser?.role.canEditContent == true, !isScannerRunning else { return }
        guard let token = KeychainStore.load(GitHubWorkflowService.tokenKeychainKey), !token.isEmpty else { return }
        isScannerRunning = true
        defer { isScannerRunning = false }
        do {
            try await GitHubWorkflowService.runNewsScanner(token: token)
            showToast("Scanner running — fresh drafts in a few minutes", symbol: "bolt.fill")
            let countBefore = aiDrafts.count
            // A run takes ~2-4 minutes; poll the feed until new drafts land.
            for delay in [90.0, 45, 45, 45, 45, 45] {
                try? await Task.sleep(for: .seconds(delay))
                await refreshAIDrafts(quietErrors: true)
                if aiDrafts.count > countBefore { return }
            }
            showToast("No new drafts yet — pull to refresh in a minute", symbol: "clock")
        } catch {
            showToast(error.localizedDescription, symbol: "exclamationmark.triangle")
        }
    }

    func approveAIDraft(_ draftID: UUID, imageURLs: [String] = []) {
        guard currentUser?.role.canEditContent == true,
              let index = aiDrafts.firstIndex(where: { $0.id == draftID }) else { return }
        let draft = aiDrafts[index]
        let article = Article(
            id: UUID(),
            title: draft.title,
            slug: TextUtilities.slugify(draft.title),
            summary: draft.summary,
            bodyMarkdown: draft.bodyMarkdown,
            category: draft.category,
            tags: draft.tags,
            authorName: "Bricks in a Bag Team",
            sources: draft.sourceLinks,
            isRumour: draft.isRumour,
            aiAssisted: true,
            commentsEnabled: true,
            status: .published,
            likeCount: 0,
            viewCount: 0,
            readTimeMinutes: TextUtilities.readTimeMinutes(for: draft.bodyMarkdown),
            publishedAt: Date(),
            createdAt: Date(),
            updatedAt: Date(),
            heroImageURL: imageURLs.first,
            galleryImageURLs: imageURLs.isEmpty ? nil : imageURLs
        )
        articles.append(article)
        aiDrafts[index].status = .approved
        showToast("Draft approved and published")
        persist()
    }

    func rejectAIDraft(_ draftID: UUID) {
        guard currentUser?.role.canEditContent == true,
              let index = aiDrafts.firstIndex(where: { $0.id == draftID }) else { return }
        aiDrafts[index].status = .rejected
        showToast("Draft rejected", symbol: "xmark.circle.fill")
        persist()
    }

    func setCommentStatus(_ commentID: UUID, status: CommentStatus) {
        guard currentUser?.role.canModerate == true,
              let index = comments.firstIndex(where: { $0.id == commentID }) else { return }
        comments[index].status = status
        if status != .pendingReview {
            commentReports.removeAll { $0.commentID == commentID }
        }
        showToast("Comment marked \(status == .visible ? "visible" : status.rawValue.replacingOccurrences(of: "_", with: " "))")
        persist()
    }

    func updateBrickBarRequest(_ requestID: UUID, status: RequestStatus, quote: Double? = nil, note: String? = nil) {
        guard currentUser?.role.canModerate == true,
              let index = brickBarRequests.firstIndex(where: { $0.id == requestID }) else { return }
        brickBarRequests[index].status = status
        brickBarRequests[index].updatedAt = Date()
        if let note, !note.isEmpty {
            brickBarRequests[index].adminNotes = note
        }
        let request = brickBarRequests[index]
        if let quote {
            brickBarRequests[index].quotedPrice = quote
            brickBarRequests[index].quoteStatus = .quoteSent
            notify(
                userID: request.userID,
                kind: .quoteSent,
                title: "Quote ready for \(request.title)",
                body: "We've quoted \(quote.formatted(.currency(code: "GBP"))). Open your request to see the details.",
                targetType: .brickBarRequest,
                targetID: request.id
            )
        } else {
            notify(
                userID: request.userID,
                kind: .brickBarUpdate,
                title: "Update on \(request.title)",
                body: "Status changed to \(status.displayName).",
                targetType: .brickBarRequest,
                targetID: request.id
            )
        }
        showToast("Request updated")
        persist()
    }

    func setArticleStatus(_ articleID: UUID, status: PublishStatus) {
        guard currentUser?.role.canEditContent == true,
              let index = articles.firstIndex(where: { $0.id == articleID }) else { return }
        articles[index].status = status
        articles[index].updatedAt = Date()
        if status == .published && articles[index].publishedAt == nil {
            articles[index].publishedAt = Date()
        }
        showToast("Article \(status.displayName.lowercased())")
        persist()
    }

    func setProductStatus(_ productID: UUID, status: ProductStatus) {
        guard currentUser?.role.canEditContent == true,
              let index = products.firstIndex(where: { $0.id == productID }) else { return }
        products[index].status = status
        products[index].updatedAt = Date()
        showToast("Product \(status.displayName.lowercased())")
        persist()
    }
}
