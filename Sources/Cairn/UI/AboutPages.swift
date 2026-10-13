import SwiftUI

/// The four plain-text pages at the end of Settings: About, Privacy policy,
/// Legal, and Credits and licenses. Text is data here, so changing a sentence
/// never touches layout. Paragraphs and list items take Markdown links.
enum DocPart {
    case heading(String)
    case text(String)
    case list([String])
}

enum AboutDocs {
    static let updated = "Last updated 13 October 2026."
    static let repo = "https://github.com/adam-dev-haven/cairn"

    // MARK: About

    static let about: [DocPart] = [
        .heading("What Cairn is"),
        .text("Cairn is a training log for one plan: fourteen weeks of bouldering at the gym and calisthenics at home on resistance bands, ending in a test week. You log climbs and sets. The app turns them into a mountain you climb, moves the week around when you miss days, and keeps your loads honest."),
        .text("It began as my own log for the Wall & Bar block, 28 September to 31 December 2026, and it is still built around that block. I made it for myself first. If it is useful to you, good."),
        .heading("Who made it"),
        .text("I'm Adam Cronstedt, in Sweden. Cairn is written in Swift, one codebase for the Mac and the iPhone. I build with an AI coding assistant, and the optional Coach uses Claude, an AI model from Anthropic."),
        .heading("What it doesn't do"),
        .list([
            "There are no accounts, no ads and no analytics.",
            "It doesn't send your training data to me. A few optional features send it elsewhere, and the privacy policy names each one.",
            "It isn't a doctor, a physiotherapist or a personal trainer. Read the Legal page before you train.",
        ]),
        .heading("Source and contact"),
        .text("The source code is public under the MIT license: [github.com/adam-dev-haven/cairn](\(repo)). Questions and bug reports go in the issues there. Leave your own health details out of anything you post."),
    ]

    // MARK: Privacy policy

    static let privacy: [DocPart] = [
        .text("Short version: Cairn keeps your training data on your own devices. I don't receive it, I can't see it, and there is no account. This page says what is stored, the few cases where it goes somewhere, and what you can do about it."),
        .heading("Who is responsible"),
        .text("I'm Adam Cronstedt, in Sweden. Your data stays on your devices and never reaches me, so I don't hold or control it. Where data does leave a device, it goes to a service you set up and signed in to yourself, and that service's own privacy policy applies to it."),
        .heading("What Cairn stores"),
        .list([
            "Your plan and settings.",
            "Sessions, sets, reps, loads and notes.",
            "Climbs: grades, attempts, falls, flashes and notes.",
            "What you choose to enter in check-ins: pain and energy scores, sick days, body weight, waist, steps, protein and free-text notes. Pain scores, weight and notes are health data.",
            "Bouldering and walking sessions imported from a folder you choose on the Mac, if you set that up.",
            "Coach check-ins and the reports they produce.",
            "Daily backups of the above.",
        ]),
        .text("Cairn doesn't collect your name, email address, location, contacts, photos, device identifiers or advertising identifier, and it doesn't ask for permission to read any of them. The only permission it asks for is local network access on the iPhone, for syncing with your Mac."),
        .heading("Where it is stored"),
        .text("On the Mac, in the folder ~/Library/Application Support/Cairn. On the iPhone, in the app's own storage. The files are plain text and Cairn doesn't encrypt them. Your Mac's disk encryption (FileVault) and your iPhone's passcode are what protect them, so turn both on. If your Mac or iPhone backs up app data to Time Machine, iCloud or a computer, that copy sits under Apple's terms and your settings, not under Cairn."),
        .heading("When data leaves a device"),
        .text("Nothing leaves your devices unless you use one of these two things."),
        .list([
            "Sync between your iPhone and your Mac. The Mac listener is off until you switch it on in Settings → Sync. It runs over your local Wi-Fi and uses a six-digit pairing code. The connection is not encrypted, so anyone who can watch traffic on that network could read it. Use it on a network you trust and switch it off on public Wi-Fi.",
            "The Coach check-in, on the Mac. When you start one, Cairn runs the Claude command-line program that you installed and signed in to, and gives it a summary of your recent log: sessions, grades, loads, pain and energy, steps, protein, weight and waist if you entered them, your targets, and the context text from Settings. It sends no name, email address or device identifier. Whatever you type in the context field is sent too. That summary goes to Anthropic, which handles it under [its privacy policy](https://www.anthropic.com/privacy) and the terms of your own plan. Cairn never starts a check-in on its own.",
        ]),
        .text("Importing goes the other way. If you pick a folder in Settings → Sync, Cairn reads the manifest.json in it and never writes to it. Cairn doesn't sign in to Garmin or any other service and sends nothing anywhere when it imports. Whatever put the file in that folder is covered by its own policy. With automatic import on, it runs when Cairn opens and about once an hour."),
        .text("There is no analytics, crash reporting, advertising or tracking in Cairn, and no cookies."),
        .heading("Your choices"),
        .list([
            "See your data: the files are readable JSON in the folders above.",
            "Take it with you: copy those files.",
            "Delete it: Settings → Reset clears logs inside the app. To remove everything, delete the Cairn folder in Application Support (backups included) and delete the app from your iPhone.",
            "Stop any transfer: switch off iPhone sync, don't run the Coach, and leave Sync off.",
        ]),
        .text("Because I hold none of your data, I can't look it up, correct it or delete it for you. You already have all of it. For data held by Anthropic or Apple, use the rights those companies give you. If you live in the EU or EEA you have rights of access, correction and erasure under the GDPR, and you can complain to the Swedish Authority for Privacy Protection, [IMY](https://www.imy.se)."),
        .heading("Children"),
        .text("Cairn is written for adults. It isn't aimed at children and I don't knowingly collect anything from anyone."),
        .heading("Changes"),
        .text("If this policy changes, the new text ships in an app update with a new date at the top."),
        .heading("Contact"),
        .text("Questions: the issues page at [github.com/adam-dev-haven/cairn](\(repo)). Don't post health details there. To report a security problem, use the Security tab of that repository and choose Report a vulnerability."),
    ]

    // MARK: Legal

    static let legal: [DocPart] = [
        .heading("Not medical advice"),
        .text("Cairn is not a substitute for a doctor, a physiotherapist or a qualified personal trainer or climbing coach, and using it creates no professional relationship with any of them. It logs training and applies simple rules to what you log. It doesn't examine you, diagnose anything or treat anything. The pain traffic light, the elbow notes, the exercise guides and the Coach's suggestions are general information, not advice for your body."),
        .text("Talk to a doctor before you start if you're injured, ill, pregnant, recovering from surgery, or have a heart, joint, blood pressure or other medical condition, or if you're not sure. See a clinician for pain that is sharp, keeps coming back, wakes you at night, or comes with numbness, tingling, swelling or a pop. Stop the exercise when it happens. In an emergency call 112 in Sweden, or your local emergency number."),
        .heading("You train at your own risk"),
        .text("Exercise, bouldering and calisthenics can cause injury, including serious injury. Climbing means falling from height. You decide what to do, how hard and how often, and you are responsible for judging whether an exercise is right for you on the day."),
        .list([
            "Check resistance bands for nicks, cracks and wear before every session. A band that snaps can hit your face or eyes. Don't use a damaged band.",
            "Close the door and put the anchor on the hinge side of it. Make sure the anchor point holds.",
            "Chairs, tables and sofas used for dips, rows, handstands and flags must be heavy, stable and unable to slide or tip. Test them first, or leave the exercise out.",
            "Warm up. Stop when your form breaks. Don't train through sharp pain.",
            "Follow your gym's rules, and get proper instruction before you climb or try a new skill.",
        ]),
        .heading("No guarantee of results"),
        .text("The plan, points, loads, band weights, grades, progressions and Coach suggestions come from simple rules and general sources, and they can be wrong for you. Band labels are the maker's ratings, not exact weights. An AI model writes the Coach's text and can make mistakes. Check anything that matters to your health with a qualified person."),
        .heading("The app is provided as is"),
        .text("Cairn is free. It comes without any warranty, express or implied, including any warranty of fitness for a particular purpose, accuracy or that it will run without errors or lose no data. Keep your own backup of anything you can't afford to lose."),
        .heading("Limit of liability"),
        .text("To the fullest extent the law allows, I am not liable for any injury, illness, death, loss or damage that comes from using Cairn or from relying on anything in it, whether it is the plan, a number, a guide, a photograph or a suggestion from the Coach. That covers direct and indirect loss. This applies whatever the legal ground of the claim."),
        .text("Nothing here limits liability that the law doesn't allow me to limit. That includes liability for intent or gross negligence, and any rights you have as a consumer under mandatory law where you live."),
        .heading("Other people's services"),
        .text("Cairn can work with Claude (Anthropic) and Apple's systems. They are separate services with their own terms. I'm not responsible for them, and Cairn is not affiliated with or endorsed by any of them."),
        .heading("License to the code"),
        .text("The source code is released under the MIT license. The text is on the Credits and licenses page. Photographs and other material come from other people and keep their own terms, listed there."),
        .heading("Governing law"),
        .text("Swedish law applies, without its conflict-of-laws rules. If you are a consumer, you keep the protection of the mandatory consumer rules of the country where you live. Disputes go to the courts of Sweden, unless mandatory law lets you bring a claim in your home courts."),
        .heading("Changes and contact"),
        .text("If these terms change, the new text ships in an app update with a new date. Questions go to the issues page at [github.com/adam-dev-haven/cairn](\(repo)). Keep health details out of public posts."),
    ]

    // MARK: Credits and licenses

    static let credits: [DocPart] = [
        .heading("Source code"),
        .text("Cairn's code is released under the MIT license."),
        .text("MIT License. Copyright (c) 2026 Adam Cronstedt. Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the Software), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software."),
        .text("THE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE."),
        .heading("Exercise photographs"),
        .list([
            "Most start and finish photographs come from [free-exercise-db](https://github.com/yuhonas/free-exercise-db), whose dataset credits Ollie Jennings. The project is released under the Unlicense (public domain).",
            "The L-sit photograph is by Tommy Gilligan, West Point Public Affairs, via [Wikimedia Commons](https://commons.wikimedia.org/wiki/File:West_Point_male_gymnast_L-sit.jpg). Public domain.",
            "The crow photograph is \"Bakasana\" by Trev M, via [Wikimedia Commons](https://commons.wikimedia.org/wiki/File:Bakasana.jpg), used under [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/). It is cropped to fit the screen.",
        ]),
        .heading("Typefaces and symbols"),
        .text("Cairn uses Apple's system fonts through SwiftUI. No font files are bundled. Icons are Apple's SF Symbols, used under Apple's license. They are part of the operating system and are not copied into the app."),
        .heading("Frameworks"),
        .text("Cairn is built with Apple's SwiftUI, Charts, Network and Foundation frameworks. It has no third-party code libraries."),
        .heading("Where the training content comes from"),
        .text("The cues, band guidance, progressions and pain rules were written with these in mind. Cairn is not affiliated with any of them, and none of them has reviewed this software."),
        .list([
            "Training for Climbing, on [tendon loading and recovery](https://trainingforclimbing.com/stronger-tendons-fingers-climbing/) and [climber's elbow](https://trainingforclimbing.com/treating-climbers-elbow-medial-epicondylitis/).",
            "Strength Climbing, on [elbow pain causes and prevention](https://strengthclimbing.com/elbow-pain-the-ultimate-guide-for-rock-climbers/).",
            "Lopes and others, 2019, on [elastic versus conventional resistance training](https://pubmed.ncbi.nlm.nih.gov/30815258/).",
            "Schoenfeld and others, 2017, on [low-load versus high-load training](https://journals.lww.com/nsca-jscr/fulltext/2017/12000/strength_and_hypertrophy_adaptations_between_low_.31.aspx).",
            "[Elastic band tension reference values](https://pmc.ncbi.nlm.nih.gov/articles/PMC4868225/) and a guide to [stacking resistance bands](https://bodymotionlab.com/blog/resistance-band-stacking-progressive-overload-guide).",
            "Two lists of calisthenics skills with progressions, from [Dieringe](https://dieringe.com/blog/calisthenics-skills) and [Gymnastics tips](https://www.gymnasetips.com/calisthenics-skills/).",
            "A [door-anchor band exercise reference](https://thefitnessphantom.com/resistance-band-door-exercises-with-pdf).",
            "The r/bodyweightfitness Recommended Routine, for the rule of moving up a step at three clean sets of eight.",
        ]),
        .heading("Trademarks"),
        .text("Claude and Anthropic are trademarks of Anthropic. Garmin is a trademark of Garmin Ltd. Apple, iPhone, Mac, SwiftUI and SF Symbols are trademarks of Apple Inc. Cairn is not affiliated with or endorsed by any of them."),
    ]
}

/// One page of those parts, in the settings card.
struct DocSection: View {
    var title: String
    var parts: [DocPart]
    var showsVersion = false

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String
        return build.map { "\(short) (\($0))" } ?? short
    }

    var body: some View {
        SettingsSection(title: title, detail: AboutDocs.updated) {
            VStack(alignment: .leading, spacing: 10) {
                if showsVersion {
                    Text("Cairn, version \(version)").font(Face.small).foregroundStyle(Ink.ink2)
                }
                ForEach(Array(parts.enumerated()), id: \.offset) { i, part in
                    switch part {
                    case .heading(let h):
                        Text(h).font(Face.heading).foregroundStyle(Ink.ink)
                            .padding(.top, i == 0 ? 0 : 8)
                    case .text(let t):
                        Text(.init(t)).font(Face.body).foregroundStyle(Ink.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    case .list(let items):
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Text("•").font(Face.body).foregroundStyle(Ink.ink2)
                                    Text(.init(item)).font(Face.body).foregroundStyle(Ink.ink)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
        }
    }
}
