import Foundation

/// Builds the first-launch dataset. All sample content lives here (§40.6 —
/// no hardcoded sample data outside seed files).
enum SeedFactory {
    static let demoPassword = "bricks123"

    static func makeSnapshot(now: Date = Date()) -> AppSnapshot {
        var snapshot = AppSnapshot()

        // MARK: Accounts
        func account(_ name: String, _ email: String, role: UserRole, bio: String = "", daysOld: Double = 200) -> UserAccount {
            var user = UserAccount.new(
                displayName: name,
                email: email,
                passwordHash: AppModel.hashPassword(demoPassword, email: email),
                role: role
            )
            user.bio = bio
            user.createdAt = now.addingTimeInterval(-daysOld * 86_400)
            return user
        }

        let admin = account("Pete", "admin@bricksinabag.com", role: .admin, bio: "Founder of Bricks in a Bag. Stadium builds are my thing.", daysOld: 700)
        let editor = account("Sasha", "editor@bricksinabag.com", role: .editor, bio: "Writes and reviews everything before it goes live.", daysOld: 400)
        let moderator = account("Ravi", "moderator@bricksinabag.com", role: .moderator, daysOld: 350)
        let member1 = account("Jess B", "jess@example.com", role: .user, bio: "Modular street almost complete. Send parts.", daysOld: 120)
        let member2 = account("TerraceTom", "tom@example.com", role: .user, bio: "If it has floodlights, I'll build it.", daysOld: 90)
        let member3 = account("MosaicMags", "mags@example.com", role: .user, daysOld: 45)
        snapshot.accounts = [admin, editor, moderator, member1, member2, member3]

        // MARK: Articles
        func article(
            _ title: String, summary: String, body: String, category: ArticleCategory,
            tags: [String], sources: [(String, String)], daysAgo: Double,
            isRumour: Bool = false, aiAssisted: Bool = false, likes: Int = 0, views: Int = 0
        ) -> Article {
            let published = now.addingTimeInterval(-daysAgo * 86_400)
            return Article(
                id: UUID(),
                title: title,
                slug: TextUtilities.slugify(title),
                summary: summary,
                bodyMarkdown: body,
                category: category,
                tags: tags,
                authorName: aiAssisted ? "Bricks in a Bag Team" : "Sasha",
                sources: sources.map { ArticleSource(id: UUID(), name: $0.0, url: $0.1) },
                isRumour: isRumour,
                aiAssisted: aiAssisted,
                commentsEnabled: true,
                status: .published,
                likeCount: likes,
                viewCount: views,
                readTimeMinutes: TextUtilities.readTimeMinutes(for: body),
                publishedAt: published,
                createdAt: published,
                updatedAt: published
            )
        }

        let articleStadium = article(
            "Behind the build: how our latest stadium model came together",
            summary: "From pitch measurements to floodlight brackets — a look inside the design process for our newest commissioned stadium build.",
            body: """
            Every stadium build starts the same way: photographs, ground plans and a long conversation about what makes the place feel like home.

            ## What happened

            Our latest commission is a mid-size league ground with a distinctive main stand roofline. We spent the first week just on the roof trusses, testing three different techniques before settling on an angled-plate approach that keeps the profile slim without sacrificing strength.

            ## Why it matters

            The techniques from this build — especially the modular stand sections — will carry into future commissions and make custom stadium requests faster to quote and build.

            ## What to watch next

            The finished model heads to its new home this month. Photos will follow in the shop section once the client has unwrapped it.
            """,
            category: .stadiumBuilds,
            tags: ["football-stadiums", "moc", "behind-the-build"],
            sources: [("Bricks in a Bag workshop notes", "https://bricksinabag.com")],
            daysAgo: 0.4, likes: 24, views: 310
        )

        let articleRumour = article(
            "New modular building rumours point to a busy year for collectors",
            summary: "A fresh round of rumours suggests modular building fans may have a strong release year ahead, though nothing has been officially confirmed.",
            body: """
            A fresh round of rumours is circulating about next year's modular building line-up.

            ## What happened

            Several usually-reliable community sources are pointing to a larger-than-usual modular release, with talk of a corner building and a companion accessory pack. None of this has been officially confirmed.

            ## Why it matters

            Modulars are among the most collected display lines, and a corner unit would be the first in several years. If the rumours hold, collectors may want to plan shelf space — and budgets — early.

            ## What to watch next

            Official reveal windows typically land a few months before release. Until then, treat every detail here as unconfirmed.
            """,
            category: .rumours,
            tags: ["modular-buildings", "rumour", "collectors"],
            sources: [("Community forum thread", "https://example.com/forum/modular-rumours"), ("Fan site roundup", "https://example.com/roundup")],
            daysAgo: 1.2, isRumour: true, aiAssisted: true, likes: 41, views: 620
        )

        let articleRetiring = article(
            "Retiring soon: display sets to watch before they disappear",
            summary: "Several popular display sets are marked for retirement this year. Here's what that usually means for availability and pricing.",
            body: """
            Retirement lists have been updated, and a handful of display-focused sets now show as retiring this year.

            ## What happened

            Retailer listings have moved several large display sets to end-of-line status. Historically that means stock runs down over a few months, with occasional final discounts before prices climb on the secondary market.

            ## Why it matters

            If a set has been sitting on your wishlist, retirement windows are the time to decide. Waiting past the end of production usually means paying collector prices.

            ## What to watch next

            We'll flag genuine last-chance deals in the Deals category as they appear — not every "retiring soon" banner is urgent.
            """,
            category: .retiringSoon,
            tags: ["retiring-sets", "collectors", "deal"],
            sources: [("Retailer availability pages", "https://example.com/availability")],
            daysAgo: 2.5, aiAssisted: true, likes: 18, views: 402
        )

        let articleReveal = article(
            "Official reveal: new architecture skyline set announced",
            summary: "An official announcement confirms a new skyline set joining the architecture range, with a focus on European landmarks.",
            body: """
            An official announcement has confirmed a new skyline set for the architecture range.

            ## What happened

            The set was revealed through official channels this week, featuring a run of European landmarks in the familiar skyline format. Piece count and pricing were confirmed in the announcement.

            ## Why it matters

            Skyline sets are a favourite gateway into display building — compact, affordable and shelf-friendly. This one also introduces a couple of interesting new part usages that mosaic and micro-scale builders will want to study.

            ## What to watch next

            Release is expected in the coming months. We'll publish a full review when we've built it.
            """,
            category: .officialReveals,
            tags: ["official", "new-release", "architecture"],
            sources: [("Official press announcement", "https://example.com/press/skyline")],
            daysAgo: 4, likes: 33, views: 540
        )

        let articleMosaic = article(
            "Mosaic month: what makes a photo work as a brick mosaic",
            summary: "Not every photo makes a great mosaic. Here's what we've learned about contrast, crops and colour after building dozens of them.",
            body: """
            We build a lot of mosaics, and the difference between a good one and a great one is almost always the source photo.

            ## What happened

            This month we're sharing what we've learned. The short version: strong contrast beats high resolution, tight crops beat wide scenes, and faces need more studs than you think.

            ## Why it matters

            If you're planning to try the Mosaic Maker in this app, five minutes choosing the right photo will do more for the result than any setting. Portraits with plain backgrounds are the sweet spot.

            ## What to watch next

            A new Studio Lesson on mosaic colour mapping is in the works — bookmark this article and we'll link it here.
            """,
            category: .brickCulture,
            tags: ["mosaics", "moc", "tips"],
            sources: [("Bricks in a Bag workshop notes", "https://bricksinabag.com")],
            daysAgo: 6, likes: 27, views: 388
        )

        let articleDeals = article(
            "Deal watch: sets genuinely worth grabbing this week",
            summary: "A short, honest list of current discounts that are actually good — and one that looks better than it is.",
            body: """
            Deal banners are everywhere; genuinely good prices are not. Here's this week's filtered list.

            ## What happened

            Three display-scale sets have dropped to their lowest tracked prices, and one heavily promoted "50% off" set is simply back at its normal street price after a quiet RRP bump.

            ## Why it matters

            Price history matters more than percentage badges. If you're building a collection on a budget, the three real deals this week are solid buys; the fourth can wait.

            ## Sources

            Prices checked against public price-tracking data at time of writing.
            """,
            category: .deals,
            tags: ["deal", "collectors"],
            sources: [("Price tracking data", "https://example.com/prices")],
            daysAgo: 8, aiAssisted: true, likes: 12, views: 295
        )

        let articleUpdate = article(
            "Bricks in a Bag update: The Brick Bar is open in the app",
            summary: "Custom build requests now run through the app — guided steps, reference photos and progress tracking in your profile.",
            body: """
            The Brick Bar — our custom build request service — is now built into this app.

            ## What happened

            Instead of emailing us photos and hoping for the best, you can now send a structured request: build type, reference images, size, budget range and deadline. You'll see status updates and quotes in your profile.

            ## Why it matters

            Clearer requests mean faster, more accurate quotes. It also means your idea, our notes and the quote all live in one place.

            ## What to watch next

            In-app messaging on requests is planned for a future update. For now we'll reach out on the email you provide.
            """,
            category: .bricksInABagUpdates,
            tags: ["bricks-in-a-bag", "brick-bar"],
            sources: [("Bricks in a Bag", "https://bricksinabag.com")],
            daysAgo: 10, likes: 45, views: 812
        )

        let articleCompatible = article(
            "Compatible brands corner: what to know before your first non-LEGO kit",
            summary: "Thinking about trying a compatible brick brand? A quick, balanced primer on quality, instructions and what \"compatible\" really means.",
            body: """
            Compatible brick-building brands have improved enormously, but the experience still differs from what set builders may expect.

            ## What happened

            We've now reviewed kits from several compatible brands, and the patterns are consistent: part quality is usually good, instructions vary wildly, and clutch power differs subtly between manufacturers.

            ## Why it matters

            Going in with the right expectations makes the difference between a pleasant surprise and a frustrating evening. Check our reviews section for brand-by-brand notes before you buy.

            ## What to watch next

            Two more compatible-brand kit reviews are in progress and will land in the Reviews section soon.
            """,
            category: .compatibleBrands,
            tags: ["compatible-brands", "reviews"],
            sources: [("Bricks in a Bag reviews", "https://bricksinabag.com")],
            daysAgo: 13, likes: 15, views: 267
        )

        snapshot.articles = [articleStadium, articleRumour, articleRetiring, articleReveal, articleMosaic, articleDeals, articleUpdate, articleCompatible]

        // MARK: Reviews
        func review(
            _ setName: String, brand: String, setNumber: String?, pieces: Int?, price: Double?,
            year: Int, category: ReviewCategory, verdict: ReviewVerdict, overall: Double,
            breakdown: RatingBreakdown, summary: String, pros: [String], cons: [String],
            body: String, difficulty: String, availability: String, daysAgo: Double, likes: Int = 0
        ) -> Review {
            let published = now.addingTimeInterval(-daysAgo * 86_400)
            let title = "\(setName) review"
            return Review(
                id: UUID(),
                title: title,
                slug: TextUtilities.slugify(title),
                brand: brand,
                setName: setName,
                setNumber: setNumber,
                pieceCount: pieces,
                ageRange: "18+",
                releaseYear: year,
                retailPrice: price,
                currency: "GBP",
                availability: availability,
                category: category,
                summary: summary,
                verdict: verdict,
                pros: pros,
                cons: cons,
                bodyMarkdown: body,
                ratingOverall: overall,
                breakdown: breakdown,
                buildDifficulty: difficulty,
                status: .published,
                commentsEnabled: true,
                likeCount: likes,
                viewCount: Int.random(in: 150...600),
                publishedAt: published,
                createdAt: published,
                updatedAt: published
            )
        }

        let reviewModular = review(
            "Grand Corner Emporium", brand: "LEGO®", setNumber: "10312", pieces: 2510, price: 194.99,
            year: 2025, category: .modularBuildings, verdict: .recommended, overall: 4.5,
            breakdown: RatingBreakdown(buildExperience: 4.5, displayValue: 5, partsSelection: 4.5, accuracyDetail: 4.5, valueForMoney: 4, funFactor: 4.5),
            summary: "A strong display model with a satisfying build and a few minor compromises.",
            pros: ["Superb street presence on display", "Clever interior details on every floor", "Great parts selection for MOC builders"],
            cons: ["Repetitive window sub-builds", "Interior of the top floor feels sparse"],
            body: """
            ## Build experience

            The build flows well across three evenings, with the ground floor providing the most interesting techniques. Window assembly gets repetitive in the middle section, but never enough to stall momentum.

            ## Display value

            This is where the set earns its money. The corner footprint anchors a modular street beautifully and the roofline detail reads well from every angle.

            ## Value for money

            At just under £200 for 2,500 pieces it sits comfortably in the expected range for the line. Watch for seasonal promotions if you're patient.

            ## Who it is for

            Modular collectors, obviously — but also anyone starting a street: corner buildings are the hardest slot to fill and this is a good one.
            """,
            difficulty: "Intermediate", availability: "Available", daysAgo: 1.5, likes: 22
        )

        let reviewStadium = review(
            "Grand Arena Stadium Kit", brand: "CaDA", setNumber: "C66888", pieces: 3650, price: 289.99,
            year: 2024, category: .stadiumSets, verdict: .oneForFans, overall: 4.0,
            breakdown: RatingBreakdown(buildExperience: 4, displayValue: 4.5, partsSelection: 4, accuracyDetail: 4, valueForMoney: 3.5, funFactor: 4),
            summary: "A big, impressive stadium build from a compatible brand — with instructions that demand patience.",
            pros: ["Genuinely impressive scale on display", "Stand sections use smart repeatable modules", "Good part quality throughout"],
            cons: ["Instruction booklet colour contrast is poor", "A few tight connections need firm pressure", "Premium price for the brand"],
            body: """
            ## Build experience

            The stand modules are the heart of this build — once you've done one, you'll do the remaining seven on autopilot. The instructions are the weak point: dark parts on dark backgrounds slow you down.

            ## Display value

            Excellent. At nearly 70cm long it dominates a shelf, and the pitch detailing is better than we expected at this scale.

            ## Value for money

            It's priced like a premium set. You're paying for scale, and you get it — but check our stadium-build lessons before committing; a custom build may suit some fans better.

            ## Who it is for

            Football fans who want maximum stadium on a set-kit budget, and don't mind a compatible brand's quirks.
            """,
            difficulty: "Advanced", availability: "Available", daysAgo: 5, likes: 17
        )

        let reviewMosaicSet = review(
            "Portrait Mosaic Frame Set", brand: "LEGO®", setNumber: "31207", pieces: 4002, price: 99.99,
            year: 2023, category: .mosaics, verdict: .greatPartsPack, overall: 4.0,
            breakdown: RatingBreakdown(buildExperience: 3.5, displayValue: 4, partsSelection: 5, accuracyDetail: 4, valueForMoney: 4.5, funFactor: 3.5),
            summary: "Meditative rather than exciting to build, but unbeatable as a parts source for mosaic makers.",
            pros: ["Huge quantity of 1×1 tiles and plates", "Multiple official designs in one box", "Excellent per-piece value"],
            cons: ["Building by grid is slow and repetitive", "Frame design is basic"],
            body: """
            ## Build experience

            Building a mosaic from a grid chart is either meditative or maddening depending on your temperament. Podcasts help.

            ## Value for money

            Around 2.5p per piece with a heavy skew towards exactly the tiles custom mosaic builders need. Even ignoring the official designs, it's worth it as a parts pack.

            ## Who it is for

            Anyone planning their own mosaic projects — including designs made with this app's Mosaic Maker.
            """,
            difficulty: "Beginner", availability: "Retiring soon", daysAgo: 9, likes: 13
        )

        let reviewSpeed = review(
            "Classic Rally Legends Pack", brand: "LEGO®", setNumber: "76920", pieces: 668, price: 44.99,
            year: 2025, category: .vehicles, verdict: .betterOnSale, overall: 3.5,
            breakdown: RatingBreakdown(buildExperience: 4, displayValue: 3.5, partsSelection: 3.5, accuracyDetail: 4, valueForMoney: 2.5, funFactor: 4),
            summary: "Two sharp little cars with genuinely clever techniques, priced a touch ambitiously.",
            pros: ["Excellent shaping at this scale", "Quick, fun weekend build", "Displays well in a pair"],
            cons: ["Price per piece is steep", "Stickers where prints would shine"],
            body: """
            ## Build experience

            Both cars pack real techniques into a small footprint — the front-end shaping on the second car is the highlight of the set.

            ## Value for money

            This is the sticking point. At RRP it's hard to recommend; at the 25–30% discounts these packs regularly see, it becomes an easy yes.

            ## Who it is for

            Car fans and desk-display builders. Wait for the sale.
            """,
            difficulty: "Beginner", availability: "Available", daysAgo: 12, likes: 9
        )

        let reviewBlueBrixx = review(
            "Old Town Fire Station", brand: "BlueBrixx", setNumber: "104216", pieces: 2180, price: 119.99,
            year: 2024, category: .compatibleSets, verdict: .goodDisplayPiece, overall: 4.0,
            breakdown: RatingBreakdown(buildExperience: 3.5, displayValue: 4.5, partsSelection: 4, accuracyDetail: 4, valueForMoney: 4.5, funFactor: 3.5),
            summary: "A handsome, great-value display building that shows how far compatible brands have come — bring patience for the instructions.",
            pros: ["Lovely facade detailing", "Strong value per piece", "Sits comfortably next to modular buildings"],
            cons: ["Digital-only instructions", "Some very small pieces in large quantities", "No interior to speak of"],
            body: """
            ## Build experience

            Part quality surprised us — clutch is consistent and colours match well. The digital instructions work fine on a tablet but you'll miss a printed booklet.

            ## Display value

            The facade is the star. Lined up in a modular street it holds its own, which is the highest compliment for a compatible-brand building.

            ## Who it is for

            Street builders who want to expand affordably and don't need interiors.
            """,
            difficulty: "Intermediate", availability: "Available", daysAgo: 16, likes: 11
        )

        snapshot.reviews = [reviewModular, reviewStadium, reviewMosaicSet, reviewSpeed, reviewBlueBrixx]

        // MARK: Products
        func product(
            _ name: String, category: ProductCategory, short: String, description: String,
            price: Double?, fromPrice: Double?, availability: String, pieces: Int?,
            dimensions: String, leadTime: String, tags: [String], status: ProductStatus = .active, daysAgo: Double
        ) -> Product {
            let created = now.addingTimeInterval(-daysAgo * 86_400)
            return Product(
                id: UUID(),
                name: name,
                slug: TextUtilities.slugify(name),
                shortDescription: short,
                description: description,
                category: category,
                price: price,
                fromPrice: fromPrice,
                currency: "GBP",
                status: status,
                availability: availability,
                externalShopURL: "https://bricksinabag.com/shop/\(TextUtilities.slugify(name))",
                pieceCountEstimate: pieces,
                dimensions: dimensions,
                leadTime: leadTime,
                deliveryInfo: "Tracked UK delivery included. International by arrangement.",
                tags: tags,
                viewCount: Int.random(in: 80...500),
                saveCount: Int.random(in: 3...40),
                createdAt: created,
                updatedAt: created
            )
        }

        snapshot.products = [
            product(
                "Custom Football Stadium Build", category: .footballStadiums,
                short: "Your club's ground, built to display scale.",
                description: "Every stadium is designed from scratch around your club's ground — stands, roof lines, pitch detail and the touches that make it unmistakably yours. We work from photographs and plans, share the design before building, and hand-finish every model. Tell us the ground and we'll take it from there.",
                price: nil, fromPrice: 250, availability: "Made to order", pieces: nil,
                dimensions: "Sized to your ground — typically 40–80cm", leadTime: "Discussed after enquiry",
                tags: ["stadium", "custom", "football"], daysAgo: 30
            ),
            product(
                "Classic British Ground — Display Edition", category: .stadiumBuilds,
                short: "A ready-designed classic ground, built to order.",
                description: "Our house-designed take on the classic British football ground: four distinct stands, floodlight pylons and terracing detail. Built to order in your choice of primary colours so it can wear your club's identity without licensing baggage.",
                price: 395, fromPrice: nil, availability: "Made to order", pieces: 2800,
                dimensions: "58 × 46 × 18 cm", leadTime: "4–6 weeks",
                tags: ["stadium", "display", "football"], daysAgo: 45
            ),
            product(
                "Photo Mosaic — Framed", category: .mosaics,
                short: "Your photo, rebuilt stud by stud and framed.",
                description: "Send us a photo — a portrait, a pet, a badge — and we'll turn it into a hand-built brick mosaic, mounted and framed, ready to hang. Start with the Mosaic Maker in this app to preview how your photo translates.",
                price: nil, fromPrice: 120, availability: "Made to order", pieces: nil,
                dimensions: "From 26 × 26 cm (32×32 studs)", leadTime: "2–3 weeks",
                tags: ["mosaic", "gift", "portrait"], daysAgo: 40
            ),
            product(
                "Stadium Keyring — Terrace Series", category: .accessories,
                short: "A pocket-size stand section, built by hand.",
                description: "A tiny hand-built terrace section on a sturdy keyring — the smallest stadium build we make. A favourite stocking-filler and matchday gift.",
                price: 12.50, fromPrice: nil, availability: "In stock", pieces: 45,
                dimensions: "4 × 3 × 3 cm", leadTime: "Ships in 2–3 days",
                tags: ["gift", "accessory", "football"], daysAgo: 60
            ),
            product(
                "Landmark Commission — Your Building in Bricks", category: .displayBuilds,
                short: "Homes, shopfronts and landmarks, built to order.",
                description: "From family homes to local landmarks, we design and build display models of real buildings. Popular for anniversaries, retirements and business displays. Send photos through The Brick Bar and we'll scope the build with you.",
                price: nil, fromPrice: 180, availability: "Made to order", pieces: nil,
                dimensions: "Typically 25–50cm footprint", leadTime: "Discussed after enquiry",
                tags: ["landmark", "custom", "gift"], daysAgo: 55
            ),
            product(
                "Limited Run — Floodlit Friday Night", category: .limitedRuns,
                short: "A floodlit terrace scene. Twenty made, then gone.",
                description: "Our first limited run: a floodlit terrace corner scene with working LED floodlight, numbered baseplate and certificate. Twenty pieces only.",
                price: 89, fromPrice: nil, availability: "Sold out", pieces: 640,
                dimensions: "22 × 18 × 20 cm", leadTime: "—",
                tags: ["limited", "display", "football"], status: .soldOut, daysAgo: 90
            ),
            product(
                "Mini Mosaic Kit — Build Your Own Badge", category: .gifts,
                short: "A DIY mosaic kit with everything in the bag.",
                description: "A self-build mosaic kit: baseplate, sorted tiles, grid chart and a stand. Choose from our ready-made badge-style designs at checkout. A great first mosaic project.",
                price: 34.99, fromPrice: nil, availability: "In stock", pieces: 1024,
                dimensions: "26 × 26 cm finished", leadTime: "Ships in 2–3 days",
                tags: ["mosaic", "gift", "kit"], daysAgo: 25
            ),
            product(
                "New Release — Cup Final Day Diorama", category: .newReleases,
                short: "Wembley-inspired arch scene with two team buses.",
                description: "Our newest ready-designed build: an arch-inspired national stadium scene with two customisable team buses and a fan walkway. Colours chosen at order time.",
                price: 149, fromPrice: nil, availability: "Made to order", pieces: 1450,
                dimensions: "45 × 30 × 24 cm", leadTime: "3–4 weeks",
                tags: ["stadium", "new", "display"], daysAgo: 5
            )
        ]

        // MARK: Lessons
        func lesson(
            _ title: String, summary: String, body: String, difficulty: LessonDifficulty,
            category: LessonCategory, tags: [String], daysAgo: Double
        ) -> Lesson {
            let published = now.addingTimeInterval(-daysAgo * 86_400)
            return Lesson(
                id: UUID(),
                title: title,
                slug: TextUtilities.slugify(title),
                summary: summary,
                bodyMarkdown: body,
                difficulty: difficulty,
                category: category,
                tags: tags,
                readTimeMinutes: TextUtilities.readTimeMinutes(for: body),
                commentsEnabled: true,
                status: .published,
                likeCount: Int.random(in: 5...30),
                viewCount: Int.random(in: 100...400),
                publishedAt: published,
                createdAt: published,
                updatedAt: published
            )
        }

        snapshot.lessons = [
            lesson(
                "How to scale a football stadium into a display model",
                summary: "The maths and the shortcuts: turning a 100-metre pitch into a shelf-friendly model without losing what makes the ground recognisable.",
                body: """
                Scaling a stadium is about choosing what to keep, not shrinking everything equally.

                ## Step 1 — Fix the pitch first

                Everything hangs off the pitch. At display scale we usually build the pitch at around 40×26 studs, which sets the whole model's footprint.

                ## Step 2 — Identify the signature

                Every ground has one feature people recognise instantly — a cantilever roof, a corner tower, a famous stand. Give that feature a disproportionate share of your detail budget.

                ## Step 3 — Simplify the stands

                Real stands have thousands of seats; models suggest them. Alternating 1×2 plates in two tones reads as seating from normal viewing distance.

                ## Tips

                - Photograph the real ground from the angle your model will be displayed at.
                - Build one stand section as a test module before committing to the footprint.
                - Floodlights sell the silhouette — don't skip them.
                """,
                difficulty: .intermediate, category: .stadiumDesign, tags: ["stadium", "scale", "football"], daysAgo: 3
            ),
            lesson(
                "Mosaic colour mapping: why your photo looks wrong in bricks",
                summary: "Brick palettes are tiny compared to a photo's colours. Learn how mapping works and how to pick photos that survive the translation.",
                body: """
                A photo has millions of colours; a practical mosaic palette has ten to sixteen. Every mosaic is a negotiation.

                ## Step 1 — Understand nearest-colour mapping

                Each region of your photo is averaged, then snapped to the closest available brick colour. Subtle gradients collapse — which is why skies band and skin tones flatten.

                ## Step 2 — Choose contrast over colour

                A high-contrast black-and-white portrait almost always beats a colourful but flat photo. If the photo works in greyscale, it'll work in bricks.

                ## Step 3 — Crop tight

                Studs are expensive pixels. Spend them on the face, not the background.

                ## Tips

                - Try the black-and-white mode first; it's the most forgiving.
                - Avoid photos where the subject wears colours close to the background.
                - The Mosaic Maker in this app shows the estimated colour count — fewer colours usually means a cleaner read.
                """,
                difficulty: .beginner, category: .mosaicDesign, tags: ["mosaic", "colour", "photos"], daysAgo: 7
            ),
            lesson(
                "Display tips: lighting and dust-proofing your builds",
                summary: "Your build deserves better than a dusty shelf. Practical, affordable ways to light and protect display models.",
                body: """
                A finished model is only half the job — display is the other half.

                ## Step 1 — Get it off the highest shelf

                Eye level or slightly below is where detail lives. High shelves reduce every build to a silhouette.

                ## Step 2 — Light from the front-top

                A small LED spot angled from above and slightly in front avoids the flat look of ambient light. Warm white flatters tan and red builds; cool white suits greys and blues.

                ## Step 3 — Consider a case for keepers

                Acrylic cases have become affordable. For sentimental builds — wedding mosaics, commissioned stadiums — they're worth every penny; dusting bare studs is nobody's hobby.

                ## Tips

                - Rotate displayed builds seasonally to keep shelves interesting.
                - Keep builds out of direct sunlight; some colours fade noticeably.
                """,
                difficulty: .beginner, category: .displayTips, tags: ["display", "lighting"], daysAgo: 12
            ),
            lesson(
                "Brick techniques: five connections every builder should know",
                summary: "SNOT, offsets, hinges and friends — the five techniques that unlock most custom building, each explained in a few minutes.",
                body: """
                Most impressive custom builds boil down to a handful of techniques used confidently.

                ## Step 1 — Studs Not On Top (SNOT)

                Brackets and headlight bricks let studs point sideways, unlocking smooth walls and detailed facades. Start with a 1×1 headlight brick and a tile.

                ## Step 2 — The half-plate offset

                Jumper plates shift elements half a stud, breaking the grid. Essential for centred details and natural-looking windows.

                ## Step 3 — Hinges for angles

                Real buildings aren't all right angles. Hinge plates and clips let walls meet at the angles your reference photos actually show.

                ## Step 4 — Texture with tiles

                Mixing tiles and plates on a wall surface creates brickwork texture that reads beautifully at display distance.

                ## Step 5 — The sideways sandwich

                Building a section flat on the table, then mounting it vertically, is how most detailed signage and mosaic-style facades are made.

                ## Tips

                - Buy a small parts assortment of brackets and jumpers before your first MOC — you'll use them constantly.
                """,
                difficulty: .intermediate, category: .brickTechniques, tags: ["techniques", "moc", "snot"], daysAgo: 18
            ),
            lesson(
                "Behind the build: quoting a custom commission",
                summary: "What actually happens after you press submit in The Brick Bar — how we scope, price and schedule a custom build.",
                body: """
                Ever wondered what happens to your Brick Bar request? Here's the honest walkthrough.

                ## Step 1 — The feasibility pass

                We read every request and ask one question first: can this be great in bricks? Some ideas need a size change or a different angle to work; we'll suggest it.

                ## Step 2 — Parts and design estimate

                We rough out the design digitally, count the major part groups and check colour availability — rare colours can move a quote significantly.

                ## Step 3 — The quote

                You'll get a price range and timeline in the app. No obligation; quotes stay open for 30 days.

                ## Tips

                - More reference photos means a faster, tighter quote.
                - Telling us your budget range honestly saves a round-trip — we design to it.
                """,
                difficulty: .beginner, category: .behindTheBuild, tags: ["brick-bar", "commission"], daysAgo: 22
            )
        ]

        // MARK: AI drafts (admin queue)
        snapshot.aiDrafts = [
            AIDraft(
                id: UUID(),
                title: "Rumour roundup: three sets fans think are coming next spring",
                summary: "Community chatter points to three possible spring releases. None are confirmed — here's the sensible read on each.",
                bodyMarkdown: """
                Community sources are discussing three possible spring releases.

                ## What happened

                Separate forum threads describe a mid-size castle set, a new botanical piece and a fan-voted ideas set entering production. Evidence quality varies from plausible to wishful.

                ## Why it matters

                Spring release windows shape collector budgets. If even two of the three land, it's a crowded quarter.

                ## What to watch next

                Official channels typically confirm spring sets in the new year. Treat all three as rumours until then.
                """,
                category: .rumours,
                tags: ["rumour", "new-release"],
                sourceLinks: [ArticleSource(id: UUID(), name: "Forum thread A", url: "https://example.com/thread-a"), ArticleSource(id: UUID(), name: "Forum thread B", url: "https://example.com/thread-b")],
                isRumour: true,
                relevanceScore: 74,
                riskNotes: "All three claims are unconfirmed. Rumour labelling required. No usable images — use category graphic.",
                status: .needsReview,
                foundAt: now.addingTimeInterval(-0.3 * 86_400)
            ),
            AIDraft(
                id: UUID(),
                title: "Official announcement: brick recycling pilot expands to the UK",
                summary: "An official sustainability pilot for used bricks is expanding to UK customers, according to a press release.",
                bodyMarkdown: """
                An official press release confirms the used-brick recycling pilot is expanding to the UK.

                ## What happened

                The programme, previously limited to other markets, will accept donated bricks by post for cleaning and redistribution to community projects.

                ## Why it matters

                Many collectors sit on kilos of unsorted bricks. A donation route with official backing is a genuinely useful option — and community projects get parts.

                ## What to watch next

                Sign-up details are expected on the official site within weeks.
                """,
                category: .officialReveals,
                tags: ["official", "sustainability"],
                sourceLinks: [ArticleSource(id: UUID(), name: "Official press release", url: "https://example.com/press/recycling")],
                isRumour: false,
                relevanceScore: 86,
                riskNotes: "Press-sourced; low risk. Verify UK dates before publishing.",
                status: .needsReview,
                foundAt: now.addingTimeInterval(-0.8 * 86_400)
            ),
            AIDraft(
                id: UUID(),
                title: "Viral video: builder recreates entire league in micro-scale",
                summary: "A builder's micro-scale recreation of all 20 top-flight grounds is doing the rounds. Fun, but thin on detail.",
                bodyMarkdown: """
                A video of all twenty top-flight grounds in micro-scale has gone viral this week.

                ## What happened

                The builder spent a reported eight months on the project, with each ground at roughly credit-card footprint.

                ## Why it matters

                Micro-scale stadium building is exactly our readers' corner of the hobby — and a good excuse to link our stadium scaling lesson.
                """,
                category: .brickCulture,
                tags: ["moc", "football-stadiums", "community"],
                sourceLinks: [ArticleSource(id: UUID(), name: "Social video", url: "https://example.com/video")],
                isRumour: false,
                relevanceScore: 55,
                riskNotes: "Video embed rights unclear — do not use stills. Low news value; consider skipping.",
                status: .needsReview,
                foundAt: now.addingTimeInterval(-1.4 * 86_400)
            )
        ]

        // MARK: Comments
        func comment(_ user: UserAccount, on type: ContentType, _ contentID: UUID, _ body: String, hoursAgo: Double, parent: UUID? = nil, likes: Int = 0) -> Comment {
            Comment(
                id: UUID(),
                contentType: type,
                contentID: contentID,
                parentCommentID: parent,
                userID: user.id,
                body: body,
                status: .visible,
                likeCount: likes,
                reportCount: 0,
                createdAt: now.addingTimeInterval(-hoursAgo * 3600),
                editedAt: nil
            )
        }

        let c1 = comment(member2, on: .article, articleStadium.id, "That roofline is spot on. Any chance of a lower-league series? Some of us support teams with one decent stand and a lot of hope.", hoursAgo: 7, likes: 6)
        let c2 = comment(admin, on: .article, articleStadium.id, "Never say never — smaller grounds actually make brilliant models. Send it through The Brick Bar and we'll take a look.", hoursAgo: 5, parent: c1.id, likes: 4)
        let c3 = comment(member1, on: .article, articleRumour.id, "Corner modular would be an instant buy. My street has had a gap for two years.", hoursAgo: 20, likes: 8)
        let c4 = comment(member3, on: .article, articleRumour.id, "Rumours like this are why my wishlist never shrinks.", hoursAgo: 16, likes: 3)
        let c5 = comment(member1, on: .review, reviewModular.id, "Built this over Christmas — agree on the windows, but the finished corner is worth it.", hoursAgo: 30, likes: 5)
        let c6 = comment(member2, on: .review, reviewStadium.id, "The instruction contrast issue is real. Tablet at full brightness helped.", hoursAgo: 50, likes: 2)
        let c7 = comment(member3, on: .article, articleMosaic.id, "Tried a family photo first and learned the contrast lesson the hard way. Pet portrait worked much better.", hoursAgo: 60, likes: 4)
        let c8 = comment(moderator, on: .review, reviewBlueBrixx.id, "Good to see compatible brands covered honestly rather than dismissed.", hoursAgo: 80, likes: 7)
        snapshot.comments = [c1, c2, c3, c4, c5, c6, c7, c8]

        // MARK: Community layer — challenge, posts, reactions, poll, scores

        let lastWeekChallenge = BuildChallenge(
            id: UUID(),
            title: "Micro Motors",
            prompt: "Build any vehicle in 30 pieces or fewer.",
            status: .finished,
            startsAt: now.addingTimeInterval(-14 * 86_400),
            votingAt: now.addingTimeInterval(-9 * 86_400),
            endsAt: now.addingTimeInterval(-7 * 86_400),
            winnerPostID: nil,
            createdAt: now.addingTimeInterval(-14 * 86_400)
        )
        let thisWeekChallenge = BuildChallenge(
            id: UUID(),
            title: "Terrace Heroes",
            prompt: "Build a matchday moment — a stand, a scarf, a pie stall, anything terrace — in under 100 pieces.",
            status: .open,
            startsAt: now.addingTimeInterval(-1 * 86_400),
            votingAt: now.addingTimeInterval(4 * 86_400),
            endsAt: now.addingTimeInterval(6 * 86_400),
            winnerPostID: nil,
            createdAt: now.addingTimeInterval(-1 * 86_400)
        )

        func post(_ user: UserAccount, _ caption: String, hoursAgo: Double, challengeID: UUID? = nil, threadID: UUID? = nil, threadDay: Int? = nil, title: String = "") -> CommunityPost {
            CommunityPost(
                id: UUID(),
                userID: user.id,
                caption: caption,
                imageReferences: [],
                challengeID: challengeID,
                threadID: threadID,
                threadDay: threadDay,
                status: .visible,
                reportCount: 0,
                createdAt: now.addingTimeInterval(-hoursAgo * 3600),
                updatedAt: now.addingTimeInterval(-hoursAgo * 3600),
                title: title
            )
        }

        let wipThread = UUID()
        let post1 = post(member2, "Day 1 of the Elland Road build. Pitch down, 3,000 studs to go. Send tea.", hoursAgo: 30, threadID: wipThread, threadDay: 1, title: "Elland Road build diary")
        let post2 = post(member2, "Day 3: East Stand roof finally stopped fighting back. Cantilevers are no joke at this scale.", hoursAgo: 6, threadID: wipThread, threadDay: 3, title: "Elland Road build diary")
        let post3 = post(member1, "Finished the corner café from last month's modular kick. First MOC I'm actually proud of!", hoursAgo: 12, title: "Corner café, done!")
        let entry1 = post(member3, "My pie stall entry — complete with a 1x1 tile pie that took longer than the stall.", hoursAgo: 8, challengeID: thisWeekChallenge.id, title: "The Pie Stand")
        let entry2 = post(member1, "Terrace scarf in brick form. 43 pieces of pure nostalgia.", hoursAgo: 4, challengeID: thisWeekChallenge.id, title: "Brick scarf")
        let winnerPost = post(member3, "Micro milk float — 28 pieces, one very small delivery round.", hoursAgo: 200, challengeID: lastWeekChallenge.id, title: "Micro milk float")

        var eventPost = post(member2, "Yorkshire's biggest brick show is back — MOC displays, traders and a build zone for the kids. BIAB will have a stand, come say hello!", hoursAgo: 20, title: "Yorkshire Brick Show 2026")
        eventPost.kind = .event
        eventPost.eventDate = now.addingTimeInterval(12 * 86_400)
        eventPost.eventLocation = "Leeds Town Hall"

        var ideasPost = post(member1, "My working pier arcade is live on LEGO® Ideas — penny pusher, grabber and all. Every vote counts, back it if you fancy seeing it on shelves!", hoursAgo: 10, title: "Seaside Pier Arcade — back it on Ideas!")
        ideasPost.kind = .ideas
        ideasPost.ideasEndDate = now.addingTimeInterval(45 * 86_400)
        ideasPost.backerCount = 2847

        var finishedChallenge = lastWeekChallenge
        finishedChallenge.winnerPostID = winnerPost.id
        snapshot.challenges = [finishedChallenge, thisWeekChallenge]
        snapshot.communityPosts = [post1, post2, post3, entry1, entry2, winnerPost, eventPost, ideasPost]

        func react(_ user: UserAccount, _ target: CommunityPost, _ reaction: BrickReaction, hoursAgo: Double) -> ReactionRecord {
            ReactionRecord(id: UUID(), userID: user.id, postID: target.id, reaction: reaction, createdAt: now.addingTimeInterval(-hoursAgo * 3600))
        }
        snapshot.reactions = [
            react(member1, post1, .niceBuild, hoursAgo: 28),
            react(member3, post1, .how, hoursAgo: 26),
            react(member2, post3, .niceBuild, hoursAgo: 11),
            react(member3, post3, .instructionsPlease, hoursAgo: 10),
            react(admin, post3, .niceBuild, hoursAgo: 9),
            react(member1, entry1, .niceBuild, hoursAgo: 7),
            react(member2, entry1, .wantThis, hoursAgo: 5),
            react(member2, winnerPost, .niceBuild, hoursAgo: 190)
        ]

        snapshot.follows = [
            Follow(id: UUID(), followerID: member1.id, followedID: member2.id, createdAt: now.addingTimeInterval(-20 * 86_400)),
            Follow(id: UUID(), followerID: member3.id, followedID: member2.id, createdAt: now.addingTimeInterval(-10 * 86_400)),
            Follow(id: UUID(), followerID: member2.id, followedID: member3.id, createdAt: now.addingTimeInterval(-9 * 86_400))
        ]

        let stadiumPoll = Poll(
            id: UUID(),
            question: "Which stadium should Bricks in a Bag build next?",
            options: [
                PollOption(id: UUID(), label: "Anfield"),
                PollOption(id: UUID(), label: "St James' Park"),
                PollOption(id: UUID(), label: "Villa Park"),
                PollOption(id: UUID(), label: "Celtic Park")
            ],
            status: .open,
            createdAt: now.addingTimeInterval(-2 * 86_400)
        )
        snapshot.polls = [stadiumPoll]
        snapshot.pollVotes = [
            PollVote(id: UUID(), pollID: stadiumPoll.id, optionID: stadiumPoll.options[1].id, userID: member2.id, createdAt: now.addingTimeInterval(-86_400)),
            PollVote(id: UUID(), pollID: stadiumPoll.id, optionID: stadiumPoll.options[0].id, userID: member1.id, createdAt: now.addingTimeInterval(-80_000)),
            PollVote(id: UUID(), pollID: stadiumPoll.id, optionID: stadiumPoll.options[1].id, userID: member3.id, createdAt: now.addingTimeInterval(-40_000))
        ]

        let weekKey = GameScoreEntry.currentWeekKey(for: now)
        snapshot.gameScores = [
            GameScoreEntry(id: UUID(), userID: member2.id, displayName: member2.displayName, game: .brickStack, score: 34, weekKey: weekKey, updatedAt: now.addingTimeInterval(-3600)),
            GameScoreEntry(id: UUID(), userID: member1.id, displayName: member1.displayName, game: .brickStack, score: 27, weekKey: weekKey, updatedAt: now.addingTimeInterval(-7200)),
            GameScoreEntry(id: UUID(), userID: member3.id, displayName: member3.displayName, game: .studMatch, score: 18, weekKey: weekKey, updatedAt: now.addingTimeInterval(-5400))
        ]

        return snapshot
    }
}
