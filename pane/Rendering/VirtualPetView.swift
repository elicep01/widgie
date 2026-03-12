import SwiftUI
import SceneKit

// MARK: - Pet Personality System

/// Each character has a unique personality that affects dialogue, room, food, toys, and appearance.
struct PetPersonality {
    let name: String                  // e.g. "Fluffy"
    let species: String               // e.g. "cloud puff", "lil' dino"
    let trait: String                  // one-word trait for UI
    let bodyColor: NSColor            // primary body color
    let accentColor: NSColor          // secondary/accent
    let bellyColor: NSColor           // belly patch color

    // Dialogue
    let hatchGreeting: String         // first words after hatching
    let hatchButton: String           // button text to proceed
    let askNameLine: String           // "what's your name?"
    let greetingLine: (String) -> String  // greeting after learning owner name
    let greetingButton: String        // button to proceed
    let askPetNameLine: (String) -> String  // "what will you name me?"

    // Room
    let floorColor: NSColor
    let rugColor: NSColor
    let wallTint: NSColor
    let shelfItemColors: [NSColor]
    let roomAccent: String            // emoji for picture frame content
    let windowScene: WindowScene

    // Food
    let foods: [String]               // emoji food items

    // Toys
    let toyBallColor: NSColor
    let yarnColor: NSColor
    let cushionColor: NSColor
    let favoriteGame: String          // displayed in UI

    // Per-character idle thoughts — personality-driven dialogue
    let idleThoughts: [String]

    // Time-aware dialogue
    let morningGreetings: [String]      // 6am-10am
    let afternoonThoughts: [String]     // 12pm-3pm (post-lunch crash)
    let eveningThoughts: [String]       // 6pm-9pm
    let sleepyThoughts: [String]        // 10pm-6am
    let hungryThoughts: [String]        // when hunger < 40
    let happyThoughts: [String]         // when happiness > 80

    // Sleep mat
    let matColor: NSColor               // sleep mat / favorite spot color
    let matEmoji: String                // what's on the mat (printed pattern)
    let sleepStyle: String              // "curled up", "sprawled", "on back" etc

    enum WindowScene {
        case nightSky       // stars
        case sunset         // warm gradient
        case garden         // green with flowers
        case ocean          // blue waves
        case aurora         // northern lights
    }

    /// Returns a contextual thought based on current time and pet stats.
    func contextualThought(hunger: Double, happiness: Double) -> String {
        let hour = Calendar.current.component(.hour, from: Date())

        // Night — sleepy thoughts dominate
        if hour >= 22 || hour < 6 {
            return sleepyThoughts.randomElement()!
        }

        // Morning
        if hour >= 6 && hour < 10 {
            return morningGreetings.randomElement()!
        }

        // Post-lunch crash
        if hour >= 13 && hour < 15 {
            return afternoonThoughts.randomElement()!
        }

        // Evening wind-down
        if hour >= 18 && hour < 22 {
            return eveningThoughts.randomElement()!
        }

        // Stat-based overrides (30% chance)
        if hunger < 40 && Int.random(in: 0...2) == 0 {
            return hungryThoughts.randomElement()!
        }
        if happiness > 80 && Int.random(in: 0...2) == 0 {
            return happyThoughts.randomElement()!
        }

        // Default: personality idle thought
        return idleThoughts.randomElement()!
    }

    /// Whether the pet should be sleeping right now.
    static var isSleepTime: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= 23 || hour < 6
    }

    /// Whether it's meal time (breakfast 7-8, lunch 12-13, dinner 18-19).
    static var isMealTime: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return (hour == 7 || hour == 8) || (hour == 12 || hour == 13) || (hour == 18 || hour == 19)
    }

    /// Whether it's the afternoon energy crash (2-4pm).
    static var isAfternoonCrash: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= 14 && hour < 16
    }
}

extension UserDataStore.PetCharacter {
    var personality: PetPersonality {
        switch self {
        // Legacy characters redirect to VRM personalities
        case .fluffy, .pongoWhite: return Self.milk.personality
        case .pongoGreen: return Self.cuteSaurus.personality
        case .pongoPurple: return Self.coolEgg.personality
        case .pongoBlue: return Self.coolBunny.personality

        case .milk:
            return PetPersonality(
                name: "Milky",
                species: "milk carton",
                trait: "wholesome",
                bodyColor: NSColor(red: 0.95, green: 0.95, blue: 0.98, alpha: 1),
                accentColor: NSColor(red: 0.3, green: 0.6, blue: 0.9, alpha: 1),
                bellyColor: NSColor(red: 0.98, green: 0.98, blue: 1.0, alpha: 1),
                hatchGreeting: "moo~! 🥛✨\ni'm fresh out of the carton!\ncold and ready to\nmake your day better~",
                hatchButton: "you're adorable! 🥛",
                askNameLine: "hey hey! who's the\nlucky human i get\nto hang with? 🥛✨",
                greetingLine: { name in "nice to meet you \(name)~! 🥛💕\ni promise to always be\nfresh and wholesome!\ngot milk? you do now~" },
                greetingButton: "let's go, Milky! 🥛",
                askPetNameLine: { name in "\(name), what's my\nname gonna be?\nsomething refreshing~! 🧊✨" },
                floorColor: NSColor(red: 0.88, green: 0.92, blue: 0.96, alpha: 1),
                rugColor: NSColor(red: 0.7, green: 0.85, blue: 0.95, alpha: 0.2),
                wallTint: NSColor(red: 0.9, green: 0.95, blue: 1.0, alpha: 0.08),
                shelfItemColors: [.systemBlue, .white, .systemCyan, .systemTeal, .systemMint],
                roomAccent: "🥛",
                windowScene: .garden,
                foods: ["🍪", "🥣", "🧇", "🫐", "🍯", "🥜"],
                toyBallColor: NSColor.systemCyan,
                yarnColor: NSColor(red: 0.7, green: 0.85, blue: 0.95, alpha: 0.6),
                cushionColor: NSColor(red: 0.8, green: 0.9, blue: 0.95, alpha: 0.35),
                favoriteGame: "Fetch Ball",
                idleThoughts: [
                    "i'm 2% cute and 98% awesome~ 🥛",
                    "do you think i'd taste good with cookies? 🍪",
                    "my expiration date is... NEVER! i'm forever fresh~",
                    "calcium makes your bones strong! fun fact from me, a box 📦",
                    "*slosh slosh* that's me walking 🥛",
                    "i wonder what chocolate milk dreams about~",
                    "the fridge was nice but out here is nicer 🌞",
                    "shake me and i get bubbly! like my personality! ✨",
                    "got milk? because i AM milk 🥛",
                    "pour your heart out~ i'm a good listener 💙",
                    "being a carton means i'm always well-contained 📦",
                    "every day is a fresh start when you're refrigerated~ 🧊",
                ],
                morningGreetings: [
                    "good morning~! cereal time?? 🥣☀️",
                    "rise and pour! ...i mean shine! 🥛",
                    "morning is MY time to shine~ goes great with breakfast! 🍳",
                    "fresh morning, fresh milk~ let's gooo! ☀️✨",
                    "today's forecast: 100% chance of being adorable 🥛💕",
                    "cereal without me is just sad dry food~ 🥣",
                ],
                afternoonThoughts: [
                    "afternoon slump? have some milk~ oh wait i AM milk 😴🥛",
                    "getting a little warm out here... need fridge... 🥵",
                    "post-lunch me wants a nap in the dairy aisle~ 💤",
                    "the afternoon sun is pasteurizing me... 😴",
                    "cookie + milk nap combo? yes please~ 🍪💤",
                ],
                eveningThoughts: [
                    "warm milk before bed? that's basically a spa day for me 🥛✨",
                    "the sunset is the color of strawberry milk~ 🍓🌅",
                    "evening vibes: cozy and creamy 💕",
                    "time for warm milk and dreams~ 🥛🌙",
                    "the fridge light is my nightlight 🧊✨",
                ],
                sleepyThoughts: [
                    "zzz... *dreams of being chocolate milk*... 💤🍫",
                    "*quietly refrigerating* ...zzz... 🧊💤",
                    "zzz... expiration date... never... zzz 🥛💤",
                ],
                hungryThoughts: [
                    "i know i'm a drink but even drinks get hungry~! 🥛😤",
                    "pair me with some cookies please!! 🍪🥛",
                    "i need cookie fuel to keep being adorable~ 🥛",
                    "a hungry milk carton is a sad milk carton... 📦",
                    "feed me snacks and i'll keep you calcium-strong! 💪🥛",
                ],
                happyThoughts: [
                    "i'm SO full of joy! and also milk! 🥛💕✨",
                    "being happy is like being perfectly chilled~ 🧊💕",
                    "you + me = the best duo since cookies and milk! 🍪🥛",
                    "i could burst with happiness! ...please don't actually burst me 📦😅",
                    "life is DAIRY good right now~! 🥛✨",
                ],
                matColor: NSColor(red: 0.8, green: 0.9, blue: 0.95, alpha: 0.45),
                matEmoji: "🥛",
                sleepStyle: "on back"
            )

        case .coolEgg:
            return PetPersonality(
                name: "Eggy",
                species: "cool egg",
                trait: "sunny",
                bodyColor: NSColor(red: 0.98, green: 0.95, blue: 0.85, alpha: 1),
                accentColor: NSColor(red: 0.95, green: 0.8, blue: 0.4, alpha: 1),
                bellyColor: NSColor(red: 1.0, green: 0.98, blue: 0.92, alpha: 1),
                hatchGreeting: "YOOO i just hatched!! 🥚✨\nwait... i'm an egg\nthat hatched from an egg??\nmeta. 🤯",
                hatchButton: "that IS meta! 😂🥚",
                askNameLine: "ok ok so who are you?\nthe one who cracked\nme out of my shell? 🐣✨",
                greetingLine: { name in "ayy \(name)~! 🥚💛\nyou're egg-straordinary!\nget it? EGG-stra?\n...i'll see myself out 😎🍳" },
                greetingButton: "love the egg puns! 🍳",
                askPetNameLine: { name in "alright \(name), give me\nan egg-cellent name!\n...sorry. last one. maybe. 🥚😏" },
                floorColor: NSColor(red: 0.95, green: 0.92, blue: 0.82, alpha: 1),
                rugColor: NSColor(red: 0.95, green: 0.85, blue: 0.5, alpha: 0.2),
                wallTint: NSColor(red: 1.0, green: 0.95, blue: 0.85, alpha: 0.08),
                shelfItemColors: [.systemYellow, .systemOrange, .white, .systemBrown, .systemRed],
                roomAccent: "🍳",
                windowScene: .sunset,
                foods: ["🧈", "🥓", "🍞", "🧀", "🥑", "🌶️"],
                toyBallColor: NSColor.systemYellow,
                yarnColor: NSColor(red: 0.95, green: 0.85, blue: 0.5, alpha: 0.6),
                cushionColor: NSColor(red: 0.95, green: 0.9, blue: 0.7, alpha: 0.35),
                favoriteGame: "Laser Chase",
                idleThoughts: [
                    "which came first, the egg or the... other egg? 🤔",
                    "i'm egg-static just sitting here~ 🥚✨",
                    "don't put all your eggs in one basket. put ME there. 🧺",
                    "i'm a little cracked. in a good way. 😏",
                    "sunny side up is my default mood ☀️🍳",
                    "i'm not fragile! ...okay maybe a little 🥚",
                    "egg-cuse me, but i'm adorable 💛",
                    "hard-boiled on the outside, soft on the inside~",
                    "rolling around is my cardio 🥚💨",
                    "omelette you in on a secret: i'm awesome 😎",
                    "scrambled thoughts? that's just how i think~ 🧠",
                    "i crack myself up honestly 😂🥚",
                ],
                morningGreetings: [
                    "good morning! time to get egg-cited!! 🥚☀️",
                    "rise and CRACK! ...wait that sounds violent 😅",
                    "sunny side up and ready to roll~! 🍳",
                    "breakfast time? I'M breakfast! ...wait 😨",
                    "morning egg-ercises! *rolls around* 💪🥚",
                    "the early bird gets the worm but the early egg gets... pets? 🐣",
                ],
                afternoonThoughts: [
                    "afternoon... getting a bit poached in this heat... 😴🍳",
                    "post-lunch egg coma... it's real... 💤🥚",
                    "too warm... becoming a boiled egg... 🥵",
                    "nap? more like... egg-rest? ...yeah that one was bad 😴",
                    "the afternoon sun is frying me~ literally 🍳💤",
                ],
                eveningThoughts: [
                    "evening omelette vibes~ cozy 🥚🌅",
                    "today was egg-cellent! ...okay i'll stop 😏",
                    "sunset looks like a giant yolk~ 🌅🍳",
                    "winding down with some shell-f care~ 💛",
                    "evening is when eggs get philosophical 🥚✨",
                ],
                sleepyThoughts: [
                    "zzz... *rolls gently*... 💤🥚",
                    "*dreams of being a golden omelette*... zzz 🍳💤",
                    "zzz... egg-cellent... dreams... 🥚💤",
                ],
                hungryThoughts: [
                    "an egg wanting breakfast... the irony 🍳😤",
                    "feed me! i'm not on the menu, i'm a FRIEND! 🥚",
                    "hungry egg is a cranky egg! 😤🥚",
                    "my yolk is rumbling... that's my stomach right? 💛",
                    "i need fuel to keep being egg-mazing! 🥚✨",
                ],
                happyThoughts: [
                    "i'm OVER EASY with happiness rn~!! 🍳💛✨",
                    "egg-STATIC!! peak joy achieved!! 🥚💕",
                    "you crack me UP! in the BEST way! 😂💛",
                    "so happy i could... hatch! wait i already did 🐣✨",
                    "this is the golden yolk of my life~! 🥚☀️",
                ],
                matColor: NSColor(red: 0.95, green: 0.9, blue: 0.7, alpha: 0.45),
                matEmoji: "🍳",
                sleepStyle: "curled up"
            )

        case .coolBunny:
            return PetPersonality(
                name: "Bun Bun",
                species: "cool bunny",
                trait: "playful",
                bodyColor: NSColor(red: 0.92, green: 0.88, blue: 0.95, alpha: 1),
                accentColor: NSColor(red: 0.8, green: 0.7, blue: 0.9, alpha: 1),
                bellyColor: NSColor(red: 0.96, green: 0.92, blue: 0.98, alpha: 1),
                hatchGreeting: "boing boing~!! 🐰✨\ni'm here i'm here!\n*does a little hop*\nlet's be friends forever!!",
                hatchButton: "so bouncy!! 🐰💜",
                askNameLine: "ooh ooh! what's your name?\ni wanna remember it\nFOREVER! 🐰💕",
                greetingLine: { name in "\(name)~!! 🐰💜\nyay yay YAYY!\ni get a best friend!\n*happy ear wiggle*" },
                greetingButton: "boing boing! 🐰",
                askPetNameLine: { name in "\(name), name me!\nsomething bouncy and cute!\nlike me! 🐰✨" },
                floorColor: NSColor(red: 0.9, green: 0.85, blue: 0.92, alpha: 1),
                rugColor: NSColor(red: 0.82, green: 0.7, blue: 0.9, alpha: 0.2),
                wallTint: NSColor(red: 0.92, green: 0.88, blue: 0.95, alpha: 0.08),
                shelfItemColors: [.systemPurple, .systemPink, .magenta, .systemIndigo, .white],
                roomAccent: "🥕",
                windowScene: .garden,
                foods: ["🥕", "🥬", "🍎", "🫐", "🍓", "🌸"],
                toyBallColor: NSColor.systemPurple,
                yarnColor: NSColor(red: 0.82, green: 0.7, blue: 0.9, alpha: 0.6),
                cushionColor: NSColor(red: 0.85, green: 0.78, blue: 0.92, alpha: 0.35),
                favoriteGame: "Fetch Ball",
                idleThoughts: [
                    "*boing boing* just practicing my hops~! 🐰",
                    "my ears pick up EVERYTHING. yes, even that. 👂",
                    "carrots are a lifestyle, not just a food 🥕",
                    "i can hear you thinking! ...probably! 🐰✨",
                    "*wiggles nose* ...something smells like adventure!",
                    "bunnies are basically fluffy rockets 🚀🐰",
                    "hop hop hop~ la la la~ 🎵",
                    "my tail is so fluffy it has its own fan club 🐰💜",
                    "i wonder how high i can bounce... TO THE MOON?! 🌙",
                    "ears up, spirits up! that's my motto~",
                    "if cuteness was a sport, i'd be olympic gold 🥇🐰",
                    "*does a binky* pure joy expressed through HOPS 🐰✨",
                ],
                morningGreetings: [
                    "GOOD MORNING!! *boing boing boing*!! 🐰☀️",
                    "rise and HOP! best time of day! 🌅🐰",
                    "my ears are up! my energy is up! EVERYTHING IS UP! ☀️",
                    "morning carrots morning carrots MORNING CARROTS! 🥕",
                    "*zooms around the room* GOOD! MORNING! 🐰💨",
                    "the early bunny gets the... CARROT! 🥕☀️",
                ],
                afternoonThoughts: [
                    "even bunnies need a flop break... 😴🐰",
                    "*yawns* hop... hop... flop... 💤",
                    "afternoon nap = recharging my bounce batteries 🔋🐰",
                    "too... sleepy... to... boing... 😴",
                    "my ears are drooping... that means naptime 🐰💤",
                ],
                eveningThoughts: [
                    "evening hops hit different~ 🐰🌅",
                    "today i did SO many boings! personal best! 🏆",
                    "the stars are like tiny carrots in the sky... right? 🥕✨",
                    "winding down with gentle hops~ boing... boing... 🐰",
                    "cozy bunny hours activated~ 🐰💜",
                ],
                sleepyThoughts: [
                    "zzz... *ear twitches*... more carrots... 🥕💤",
                    "*dream-hopping on clouds*... boing... zzz ☁️🐰",
                    "zzz... the softest... burrow... 💤🐰",
                ],
                hungryThoughts: [
                    "CARROTS!! I NEED CARROTS!! 🥕🐰😤",
                    "a hungry bunny is a sad bunny! feed me! 🐰",
                    "my nose is twitching... that means HUNGRY 🐰",
                    "can't hop on an empty tummy~! 🥕",
                    "please... snacks... my ears are drooping from hunger 😭🐰",
                ],
                happyThoughts: [
                    "*BOING BOING BOING* SO HAPPY!! 🐰💜✨",
                    "my ears are VIBRATING with joy!! 🐰💕",
                    "BINKY TIME!! *does the happiest hop ever*!! 🐰🎉",
                    "you make my tail wiggle SO MUCH!! 💜🐰",
                    "happiest bunny in the WHOLE WORLD!! 🐰✨🌍",
                ],
                matColor: NSColor(red: 0.85, green: 0.78, blue: 0.92, alpha: 0.45),
                matEmoji: "🥕",
                sleepStyle: "curled up"
            )

        case .cuteSaurus:
            return PetPersonality(
                name: "Rex",
                species: "baby dino",
                trait: "curious",
                bodyColor: NSColor(red: 0.4, green: 0.78, blue: 0.65, alpha: 1),
                accentColor: NSColor(red: 0.3, green: 0.68, blue: 0.55, alpha: 1),
                bellyColor: NSColor(red: 0.65, green: 0.9, blue: 0.78, alpha: 1),
                hatchGreeting: "rawr~! 🦕✨\ni'm a real dinosaur!\nwell... a tiny one...\nbut i have BIG dreams!",
                hatchButton: "you're amazing, little dino! 🦕",
                askNameLine: "ooh a human!\ni've read about you!\nwhat's your name? 🦕📚",
                greetingLine: { name in "hi \(name)~! 🦕💚\ni'm gonna learn\nEVERYTHING about\nthe modern world!\nteach me things? 📖✨" },
                greetingButton: "of course, little Rex! 🦕",
                askPetNameLine: { name in "\(name), what would\nyou name a dinosaur?\nsomething prehistoric? 🦴✨" },
                floorColor: NSColor(red: 0.78, green: 0.88, blue: 0.82, alpha: 1),
                rugColor: NSColor(red: 0.4, green: 0.7, blue: 0.55, alpha: 0.2),
                wallTint: NSColor(red: 0.82, green: 0.92, blue: 0.85, alpha: 0.08),
                shelfItemColors: [.systemGreen, .systemTeal, .systemBrown, .systemOrange, .systemYellow],
                roomAccent: "🦴",
                windowScene: .garden,
                foods: ["🌿", "🥬", "🍃", "🥝", "🫛", "🌽"],
                toyBallColor: NSColor.systemTeal,
                yarnColor: NSColor(red: 0.4, green: 0.7, blue: 0.6, alpha: 0.6),
                cushionColor: NSColor(red: 0.5, green: 0.75, blue: 0.65, alpha: 0.35),
                favoriteGame: "Laser Chase",
                idleThoughts: [
                    "did you know T-Rex couldn't clap? sad... 🦖",
                    "i wonder if my ancestors would be proud of me~ 🦕",
                    "65 million years late but i'm HERE! 🌍",
                    "what's that thing? *sniffs curiously* 👃",
                    "i'm technically a living fossil. cool, right? 🦴✨",
                    "everything is new and FASCINATING! 🔍🦕",
                    "the meteor missed ME specifically 😎☄️",
                    "rawr means 'i love you' in dinosaur~ 🦕💚",
                    "i learned a new word today! ...i forgot it already 📖😅",
                    "my arms are small but my heart is ENORMOUS 💚",
                    "do you think birds remember us? they're our cousins! 🐦",
                    "i'm not extinct, i'm just fashionably late~ 🦕✨",
                ],
                morningGreetings: [
                    "good morning~! a new day to discover things! 🦕☀️",
                    "RAWR! ...that's good morning in dinosaur 🌅",
                    "the sun is like a big warm meteor! ...a FRIENDLY one! ☀️😅",
                    "morning exploration begins NOW! 🔍🦕",
                    "today i will learn at least 3 new things! 📚☀️",
                    "prehistoric morning routine: stretch, rawr, be curious! 🦕",
                ],
                afternoonThoughts: [
                    "even dinosaurs need rest after foraging... 😴🦕",
                    "afternoon nap... like my ancestors in the Jurassic sun... 💤☀️",
                    "my brain learned too many things... needs reboot... 📖😴",
                    "the warm afternoon... reminds me of... the Cretaceous... 🌿😴",
                    "power nap to power up my curiosity! 🔋🦕",
                ],
                eveningThoughts: [
                    "today i learned so many things~! 🦕✨",
                    "the evening sky looks like the Jurassic sunset... probably 🌅",
                    "time to organize my new discoveries! 📖🦕",
                    "stars! my ancestors saw these SAME stars! 🌟🦕",
                    "another successful day of not being extinct! 🎉",
                ],
                sleepyThoughts: [
                    "zzz... *dreams of the Jurassic*... 🌿💤🦕",
                    "*tiny dinosaur snores*... rrrrr... zzz 🦕💤",
                    "zzz... so many things... to learn... tomorrow... 📚💤",
                ],
                hungryThoughts: [
                    "need leaves! or whatever modern food is! 🌿🦕",
                    "a hungry dinosaur is a grumpy dinosaur! rawr! 😤🦕",
                    "my prehistoric stomach is RUMBLING! 🦕🌋",
                    "feed me and i'll teach you a dino fact! 📖🦕",
                    "even herbivores get hangry~! 🌿😤",
                ],
                happyThoughts: [
                    "RAWR RAWR RAWR!! that's HAPPY in dinosaur!! 🦕💚✨",
                    "i'm the happiest dino in 65 million years!! 🎉🦕",
                    "discovery of the day: HAPPINESS!! 📖💚",
                    "my tail is wagging! dinosaurs DO that! ...right? 🦕💕",
                    "being alive in the modern era is AMAZING!! 🌍🦕✨",
                ],
                matColor: NSColor(red: 0.5, green: 0.75, blue: 0.65, alpha: 0.45),
                matEmoji: "🦴",
                sleepStyle: "curled up"
            )
        }
    }
}

// MARK: - Virtual Pet Component

struct VirtualPetComponentView: View {
    let widgetID: UUID
    let component: ComponentConfig
    let theme: WidgetTheme

    @State private var pet: UserDataStore.PetStateData?
    @State private var isLoaded = false
    @State private var showHeart = false
    @State private var showFood = false
    @State private var showPlayMenu = false
    @State private var activeGame: PetGame? = nil
    @State private var feedTrigger = 0
    @State private var petModeActive = false

    // Hatching / intro flow
    enum IntroPhase: Equatable {
        case egg                // Tap to hatch
        case cracking           // Egg cracking animation
        case reveal             // Pet revealed with blush
        case askOwnerName       // "What's your name?"
        case greeting           // "Hi <name>! I'm your new pet~ 💕"
        case askPetName         // "What would you like to name me?"
        case done               // Normal widget
    }
    @State private var introPhase: IntroPhase = .egg
    @State private var eggTaps = 0
    @State private var ownerNameInput = ""
    @State private var petNameInput = ""

    enum PetGame: String, CaseIterable {
        case laser = "Laser Chase"
        case fetch = "Fetch Ball"
        case yarn = "Yarn Play"

        var icon: String {
            switch self {
            case .laser: return "light.max"
            case .fetch: return "circle.fill"
            case .yarn: return "circle.dotted"
            }
        }
    }

    private var componentKey: String {
        "\(widgetID.uuidString)#\(component.id ?? "pet")"
    }

    private func tc(_ token: String) -> Color {
        ThemeResolver.color(for: token, theme: theme)
    }

    /// Resolve the current pet's personality (falls back to fluffy).
    private var personality: PetPersonality {
        (pet?.character ?? .fluffy).personality
    }

    var body: some View {
        GeometryReader { geo in
            if isLoaded, let pet {
                if pet.hasHatched && pet.petName != nil {
                    // Normal pet view
                    normalPetView(pet: pet, geo: geo)
                } else {
                    // Hatching / intro flow
                    introFlowView(pet: pet, geo: geo)
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task { await loadOrCreate() }
    }

    // MARK: - Normal Pet View

    @ViewBuilder
    private func normalPetView(pet: UserDataStore.PetStateData, geo: GeometryProxy) -> some View {
        let petName = pet.petName ?? component.content ?? "Pixel"
        VStack(spacing: 0) {
            // Polaroid "photo" — the 3D scene
            ZStack(alignment: .topTrailing) {
                PetSceneView(
                    pet: pet,
                    theme: theme,
                    activeGame: activeGame,
                    feedTrigger: feedTrigger,
                    petModeActive: petModeActive,
                    onTap: { handleSceneTap() },
                    onPet: { positive in interact(positive ? .pet : .overPet) },
                    onPlay: { interact(.play) },
                    onPetModeEnd: { petModeActive = false }
                )

                // Floating particles
                if showHeart {
                    floatingParticle(text: "\u{2764}\u{FE0F}")
                }
                if showFood {
                    floatingParticle(text: "\u{1F356}")
                        .offset(x: -30)
                }

                // Pet mode instruction overlay
                if petModeActive {
                    VStack {
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "hand.point.up.left.fill")
                                .font(.system(size: 10))
                            Text("move mouse over pet to pet~")
                                .font(.system(size: 9, weight: .medium, design: .rounded))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.black.opacity(0.5)))
                        .padding(.bottom, 6)
                    }
                    .allowsHitTesting(false)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: geo.size.height * 0.55)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .animation(.easeInOut(duration: 0.2), value: petModeActive)

            // Polaroid bottom — name with heart
            HStack(spacing: 0) {
                Text("\u{2764}\u{FE0F}")
                    .font(.system(size: max(10, geo.size.width * 0.04)))
                Text(" \(petName) ")
                    .font(.system(size: max(11, min(geo.size.width * 0.055, 16)), weight: .bold, design: .rounded))
                    .foregroundStyle(tc("primary"))
                    .italic()
                Text("\u{2764}\u{FE0F}")
                    .font(.system(size: max(10, geo.size.width * 0.04)))
            }
            .lineLimit(1)
            .padding(.top, 5)
            .padding(.bottom, 2)

            if pet.isAlive {
                // Stats row — compact health/hunger/happiness
                HStack(spacing: max(6, geo.size.width * 0.025)) {
                    statCircle(icon: "heart.fill", value: pet.health, color: petHealthColor(pet.health), size: geo.size.width)
                    statCircle(icon: "leaf.fill", value: pet.hunger, color: .orange, size: geo.size.width)
                    statCircle(icon: "star.fill", value: pet.happiness, color: .pink, size: geo.size.width)
                }
                .padding(.bottom, 3)

                // Action buttons row
                HStack(spacing: max(4, geo.size.width * 0.02)) {
                    actionCircle(icon: "fork.knife", size: geo.size.width) {
                        interact(.feed)
                    }
                    petButton(size: geo.size.width)
                    actionCircle(
                        icon: activeGame != nil ? "stop.fill" : "gamecontroller.fill",
                        size: geo.size.width
                    ) {
                        if activeGame != nil {
                            activeGame = nil
                            showPlayMenu = false
                        } else {
                            showPlayMenu.toggle()
                        }
                    }
                }

                // Game selection menu
                if showPlayMenu && activeGame == nil {
                    HStack(spacing: geo.size.width * 0.02) {
                        ForEach(PetGame.allCases, id: \.rawValue) { game in
                            Button {
                                activeGame = game
                                showPlayMenu = false
                                interact(.play)
                            } label: {
                                VStack(spacing: 1) {
                                    Image(systemName: game.icon)
                                        .font(.system(size: max(9, geo.size.width * 0.038)))
                                    Text(game.rawValue)
                                        .font(.system(size: max(7, geo.size.width * 0.026), weight: .medium, design: .rounded))
                                }
                                .foregroundStyle(tc("accent"))
                                .padding(.horizontal, geo.size.width * 0.02)
                                .padding(.vertical, 3)
                                .background(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(tc("accent").opacity(0.12))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .padding(.top, 3)
                }
            } else {
                Text("R.I.P.")
                    .font(.system(size: max(11, geo.size.width * 0.05), weight: .heavy, design: .rounded))
                    .foregroundStyle(tc("muted"))
                    .padding(.top, 2)

                if let birth = parseISO(pet.birthDate),
                   let death = parseISO(pet.lastDecayAt) {
                    let days = max(0, Calendar.current.dateComponents([.day], from: birth, to: death).day ?? 0)
                    Text("Lived \(days) day\(days == 1 ? "" : "s")")
                        .font(.system(size: max(9, geo.size.width * 0.04), design: .rounded))
                        .foregroundStyle(tc("muted").opacity(0.6))
                }
            }

            Spacer(minLength: 2)
        }
        .padding(6)
    }

    // MARK: - Intro / Hatching Flow

    @ViewBuilder
    private func introFlowView(pet: UserDataStore.PetStateData, geo: GeometryProxy) -> some View {
        let sceneHeight = min(geo.size.height * 0.42, 240.0)

        VStack(spacing: 0) {
            switch introPhase {
            case .egg, .cracking:
                eggSceneSection(pet: pet, geo: geo)

            case .reveal:
                // Scene — capped height
                ZStack {
                    petSceneBlock(pet: pet)
                        .frame(height: sceneHeight)
                        .transition(.scale(scale: 0.3).combined(with: .opacity))

                    ForEach(0..<6, id: \.self) { i in
                        Text(["✨", "🌟", "💫", "⭐️", "✨", "🌟"][i])
                            .font(.system(size: CGFloat.random(in: 14...22)))
                            .offset(
                                x: CGFloat.random(in: -geo.size.width * 0.3...geo.size.width * 0.3),
                                y: CGFloat.random(in: -sceneHeight * 0.3...sceneHeight * 0.3)
                            )
                            .opacity(0.8)
                    }
                }
                .frame(height: sceneHeight)

                // Dialogue area — guaranteed visible
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 8) {
                        introBubble(text: personality.hatchGreeting, geo: geo)

                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                introPhase = .askOwnerName
                            }
                        } label: {
                            Text(personality.hatchButton)
                                .font(.system(size: max(10, geo.size.width * 0.042), weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(tc("accent")))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 8)
                }
                .frame(maxHeight: .infinity)

            case .askOwnerName:
                petSceneBlock(pet: pet)
                    .frame(height: sceneHeight)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 8) {
                        introBubble(text: personality.askNameLine, geo: geo)

                        HStack(spacing: 6) {
                            TextField("your name", text: $ownerNameInput)
                                .textFieldStyle(.plain)
                                .font(.system(size: max(11, geo.size.width * 0.045), weight: .medium, design: .rounded))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(tc("primary").opacity(0.08))
                                )
                                .frame(maxWidth: geo.size.width * 0.55)

                            Button {
                                guard !ownerNameInput.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                    introPhase = .greeting
                                }
                            } label: {
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(tc("accent"))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, geo.size.width * 0.08)
                    }
                    .padding(.vertical, 8)
                }
                .frame(maxHeight: .infinity)

            case .greeting:
                let name = ownerNameInput.trimmingCharacters(in: .whitespaces)
                petSceneBlock(pet: pet)
                    .frame(height: sceneHeight)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 8) {
                        introBubble(
                            text: personality.greetingLine(name),
                            geo: geo
                        )

                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                introPhase = .askPetName
                            }
                        } label: {
                            Text(personality.greetingButton)
                                .font(.system(size: max(10, geo.size.width * 0.042), weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(tc("accent")))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 8)
                }
                .frame(maxHeight: .infinity)

            case .askPetName:
                let name = ownerNameInput.trimmingCharacters(in: .whitespaces)
                petSceneBlock(pet: pet)
                    .frame(height: sceneHeight)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 8) {
                        introBubble(
                            text: personality.askPetNameLine(name),
                            geo: geo
                        )

                        HStack(spacing: 6) {
                            TextField("name me!", text: $petNameInput)
                                .textFieldStyle(.plain)
                                .font(.system(size: max(11, geo.size.width * 0.045), weight: .medium, design: .rounded))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(tc("primary").opacity(0.08))
                                )
                                .frame(maxWidth: geo.size.width * 0.55)

                            Button {
                                let trimmed = petNameInput.trimmingCharacters(in: .whitespaces)
                                guard !trimmed.isEmpty else { return }
                                finishIntro(petName: trimmed, ownerName: ownerNameInput.trimmingCharacters(in: .whitespaces))
                            } label: {
                                Image(systemName: "heart.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(tc("accent"))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, geo.size.width * 0.08)
                    }
                    .padding(.vertical, 8)
                }
                .frame(maxHeight: .infinity)

            case .done:
                normalPetView(pet: pet, geo: geo)
            }
        }
        .padding(introPhase == .done ? 0 : 8)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: introPhase)
    }

    /// Reusable pet scene block for intro flow — consistent size and clipping.
    @ViewBuilder
    private func petSceneBlock(pet: UserDataStore.PetStateData) -> some View {
        PetSceneView(
            pet: pet,
            theme: theme,
            activeGame: nil,
            feedTrigger: 0,
            petModeActive: false,
            onTap: {},
            onPet: { _ in },
            onPlay: {},
            onPetModeEnd: {}
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func eggSceneSection(pet: UserDataStore.PetStateData, geo: GeometryProxy) -> some View {
        let sceneHeight = min(geo.size.height * 0.5, 220.0)

        VStack(spacing: 0) {
            EggSceneView(
                theme: theme,
                tapCount: eggTaps,
                onTap: { handleEggTap() }
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .frame(maxWidth: .infinity)
            .frame(height: sceneHeight)

            Spacer(minLength: 8)

            // Progressive cute messages
            Text(eggMessage)
                .font(.system(size: max(11, geo.size.width * 0.044), weight: .semibold, design: .rounded))
                .foregroundStyle(tc("primary").opacity(0.8))
                .multilineTextAlignment(.center)
                .animation(.easeInOut(duration: 0.3), value: eggTaps)
                .padding(.horizontal, 12)

            Spacer(minLength: 6)

            if eggTaps == 0 {
                VStack(spacing: 4) {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: max(14, geo.size.width * 0.055)))
                        .foregroundStyle(tc("accent").opacity(0.4))
                    Text("tap gently~")
                        .font(.system(size: max(9, geo.size.width * 0.032), weight: .medium, design: .rounded))
                        .foregroundStyle(tc("muted"))
                }
            } else if eggTaps < 5 {
                // Progress dots
                HStack(spacing: 6) {
                    ForEach(0..<5, id: \.self) { i in
                        Circle()
                            .fill(i < eggTaps ? tc("accent") : tc("muted").opacity(0.2))
                            .frame(width: 8, height: 8)
                            .scaleEffect(i < eggTaps ? 1.2 : 1.0)
                            .animation(.spring(response: 0.3), value: eggTaps)
                    }
                }
            }

            Spacer(minLength: 4)
        }
    }

    /// Progressive egg messages that build anticipation.
    private var eggMessage: String {
        switch eggTaps {
        case 0: return "a mysterious egg appeared! ✨"
        case 1: return "oh! it wiggled a little! 👀"
        case 2: return "you can hear something inside~! 🥚💕"
        case 3: return "cracks are forming...! ✨"
        case 4: return "almost there...!! keep going~! 🥺"
        default: return "hatching...!! 🐣✨"
        }
    }

    private func handleEggTap() {
        eggTaps += 1
        if eggTaps >= 5 {
            introPhase = .cracking
            // Longer dramatic pause before reveal
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    if var p = pet {
                        p.hasHatched = true
                        pet = p
                        Task { await UserDataStore.shared.setPetState(p, for: componentKey) }
                    }
                    introPhase = .reveal
                }
            }
        }
    }

    private func finishIntro(petName: String, ownerName: String) {
        guard var p = pet else { return }
        p.petName = petName
        p.ownerName = ownerName
        p.hasHatched = true
        pet = p
        Task { await UserDataStore.shared.setPetState(p, for: componentKey) }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            introPhase = .done
        }
    }

    @ViewBuilder
    private func introBubble(text: String, geo: GeometryProxy) -> some View {
        Text(text)
            .font(.system(size: max(10, geo.size.width * 0.04), weight: .medium, design: .rounded))
            .foregroundStyle(tc("primary"))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tc("primary").opacity(0.07))
            )
            .padding(.horizontal, geo.size.width * 0.05)
    }

    // MARK: - Floating Particle

    @ViewBuilder
    private func floatingParticle(text: String) -> some View {
        Text(text)
            .font(.system(size: 22))
            .padding(6)
            .transition(.opacity.combined(with: .move(edge: .top)).combined(with: .scale))
    }

    // MARK: - Stat Bar

    @ViewBuilder
    // MARK: - Stat Circle

    private func statCircle(icon: String, value: Double, color: Color, size: CGFloat) -> some View {
        let dim = max(18, min(size * 0.085, 28))
        let pct = CGFloat(value / 100)
        return ZStack {
            // Background ring
            Circle()
                .stroke(color.opacity(0.15), lineWidth: 2.5)
            // Filled ring
            Circle()
                .trim(from: 0, to: pct)
                .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.4), value: value)
            // Icon
            Image(systemName: icon)
                .font(.system(size: dim * 0.38, weight: .semibold))
                .foregroundStyle(color.opacity(pct > 0.3 ? 0.8 : 0.4))
        }
        .frame(width: dim, height: dim)
        .help(String(format: "%.0f%%", value))
    }

    // MARK: - Action Circle Button

    @ViewBuilder
    private func petButton(size: CGFloat) -> some View {
        let dim = max(20, min(size * 0.09, 28))
        Button {
            petModeActive.toggle()
        } label: {
            Image(systemName: petModeActive ? "hand.raised.fill" : "hand.point.up.left.fill")
                .font(.system(size: dim * 0.4, weight: .medium))
                .foregroundStyle(petModeActive ? Color.white : tc("secondary"))
                .frame(width: dim, height: dim)
                .background(
                    Circle()
                        .fill(petModeActive ? tc("accent") : tc("accent").opacity(0.1))
                )
                .overlay(
                    // Pulsing ring when active
                    petModeActive ? Circle()
                        .stroke(tc("accent").opacity(0.4), lineWidth: 1.5)
                        .scaleEffect(1.3) : nil
                )
        }
        .buttonStyle(.plain)
        .help(petModeActive ? "Click pet to stop petting" : "Pet mode — hover over your pet to pet them!")
    }

    private func actionCircle(icon: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        let dim = max(20, min(size * 0.09, 28))
        return Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: dim * 0.4, weight: .medium))
                .foregroundStyle(tc("secondary"))
                .frame(width: dim, height: dim)
                .background(
                    Circle()
                        .fill(tc("accent").opacity(0.1))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Scene tap

    private func handleSceneTap() {
        guard let p = pet, p.isAlive else { return }
        interact(.pet)
    }

    // MARK: - Helpers

    private func petHealthColor(_ health: Double) -> Color {
        if health > 60 { return .green }
        if health > 30 { return .orange }
        return .red
    }

    // MARK: - Interactions

    private enum PetAction { case feed, pet, overPet, play }

    private func interact(_ action: PetAction) {
        guard var p = pet, p.isAlive else { return }
        let now = ISO8601DateFormatter().string(from: Date())

        switch action {
        case .feed:
            p.hunger = min(100, p.hunger + 25)
            p.health = min(100, p.health + 5)
            p.lastFedAt = now
            feedTrigger += 1  // triggers 3D feeding animation
        case .pet:
            p.happiness = min(100, p.happiness + 15)
            p.health = min(100, p.health + 2)
            withAnimation(.spring(response: 0.3)) { showHeart = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation { showHeart = false }
            }
        case .overPet:
            p.happiness = max(0, p.happiness - 20)
            p.health = max(0, p.health - 5)
        case .play:
            p.happiness = min(100, p.happiness + 20)
            p.hunger = max(0, p.hunger - 10)  // playing is tiring!
            p.health = min(100, p.health + 1)
            p.lastPlayedAt = now
        }

        pet = p
        Task { await UserDataStore.shared.setPetState(p, for: componentKey) }
    }

    // MARK: - Persistence & Decay

    private func loadOrCreate() async {
        if let existing = await UserDataStore.shared.petState(for: componentKey) {
            pet = existing
        } else {
            pet = await UserDataStore.shared.createPet(for: componentKey)
        }
        isLoaded = true
        await decayStats()
        startDecayTimer()
    }

    private func startDecayTimer() {
        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            Task { @MainActor in await decayStats() }
        }
    }

    private func decayStats() async {
        guard var p = pet, p.isAlive else { return }
        let now = Date()
        guard let lastDecay = parseISO(p.lastDecayAt) else { return }
        let elapsed = now.timeIntervalSince(lastDecay)
        guard elapsed >= 60 else { return }
        let minutes = elapsed / 60.0

        // Time-aware hunger: faster during meal times, slower at night
        let hungerRate: Double
        if PetPersonality.isSleepTime {
            hungerRate = 0.15  // slow at night — sleeping
        } else if PetPersonality.isMealTime {
            hungerRate = 0.6   // hungry at meal times
        } else {
            hungerRate = 0.35  // normal
        }
        p.hunger = max(0, p.hunger - minutes * hungerRate)

        // Happiness decays faster during afternoon crash
        let happinessRate = PetPersonality.isAfternoonCrash ? 0.25 : 0.15
        p.happiness = max(0, p.happiness - minutes * happinessRate)

        if p.hunger <= 0 {
            p.health = max(0, p.health - minutes * 0.5)
        } else if p.hunger < 20 {
            p.health = max(0, p.health - minutes * 0.1)
        }
        if p.hunger > 60 && p.health < 100 {
            p.health = min(100, p.health + minutes * 0.08)
        }
        if p.health <= 0 {
            p.isAlive = false
            p.health = 0
        }

        p.lastDecayAt = ISO8601DateFormatter().string(from: now)
        pet = p
        await UserDataStore.shared.setPetState(p, for: componentKey)
    }

    private func parseISO(_ string: String?) -> Date? {
        guard let string else { return nil }
        return ISO8601DateFormatter().date(from: string)
    }
}

// MARK: - SceneKit 3D Egg Scene

private struct EggSceneView: NSViewRepresentable {
    let theme: WidgetTheme
    let tapCount: Int
    let onTap: () -> Void

    func makeNSView(context: Context) -> SCNView {
        let scnView = SCNView()
        let scene = context.coordinator.buildEggScene(theme: theme)
        scnView.scene = scene
        scnView.backgroundColor = .clear
        scnView.antialiasingMode = .multisampling4X
        scnView.allowsCameraControl = false
        scnView.autoenablesDefaultLighting = false
        scnView.isJitteringEnabled = true

        let click = NSClickGestureRecognizer(target: context.coordinator, action: #selector(EggCoordinator.handleClick(_:)))
        scnView.addGestureRecognizer(click)

        return scnView
    }

    func updateNSView(_ scnView: SCNView, context: Context) {
        context.coordinator.updateCracks(tapCount: tapCount, in: scnView.scene)
    }

    func makeCoordinator() -> EggCoordinator {
        EggCoordinator(onTap: onTap)
    }

    class EggCoordinator: NSObject {
        let onTap: () -> Void
        private var eggNode: SCNNode?
        private var crackNodes: [SCNNode] = []
        private var glowNode: SCNNode?
        private var currentTapCount = 0

        init(onTap: @escaping () -> Void) {
            self.onTap = onTap
        }

        @objc func handleClick(_ gesture: NSClickGestureRecognizer) {
            // Wobble the egg on tap
            if let egg = eggNode {
                egg.removeAction(forKey: "wobble")
                let wobble = SCNAction.sequence([
                    SCNAction.rotateBy(x: 0, y: 0, z: 0.15, duration: 0.06),
                    SCNAction.rotateBy(x: 0, y: 0, z: -0.30, duration: 0.12),
                    SCNAction.rotateBy(x: 0, y: 0, z: 0.22, duration: 0.10),
                    SCNAction.rotateBy(x: 0, y: 0, z: -0.14, duration: 0.08),
                    SCNAction.rotateBy(x: 0, y: 0, z: 0.07, duration: 0.06),
                ])
                egg.runAction(wobble, forKey: "wobble")
            }
            onTap()
        }

        func buildEggScene(theme: WidgetTheme) -> SCNScene {
            let scene = SCNScene()
            let palette = ThemeResolver.palette(for: theme)
            let accent = NSColor(palette.accent)

            // Camera
            let cameraNode = SCNNode()
            cameraNode.camera = SCNCamera()
            cameraNode.camera?.fieldOfView = 40
            cameraNode.camera?.zNear = 0.1
            cameraNode.camera?.zFar = 50
            cameraNode.position = SCNVector3(0, 1.6, 4.0)
            cameraNode.look(at: SCNVector3(0, 0.6, 0))
            scene.rootNode.addChildNode(cameraNode)

            // Lighting — warm and cozy
            let keyLight = SCNNode()
            keyLight.light = SCNLight()
            keyLight.light?.type = .directional
            keyLight.light?.intensity = 700
            keyLight.light?.color = NSColor(white: 1.0, alpha: 1)
            keyLight.light?.castsShadow = true
            keyLight.light?.shadowMode = .deferred
            keyLight.light?.shadowSampleCount = 8
            keyLight.light?.shadowRadius = 4
            keyLight.light?.shadowColor = NSColor.black.withAlphaComponent(0.25)
            keyLight.eulerAngles = SCNVector3(-CGFloat.pi / 3, CGFloat.pi / 6, 0)
            scene.rootNode.addChildNode(keyLight)

            let fillLight = SCNNode()
            fillLight.light = SCNLight()
            fillLight.light?.type = .omni
            fillLight.light?.intensity = 200
            fillLight.light?.color = NSColor(red: 1.0, green: 0.92, blue: 0.8, alpha: 1)
            fillLight.position = SCNVector3(-2, 2.5, 3)
            scene.rootNode.addChildNode(fillLight)

            let ambient = SCNNode()
            ambient.light = SCNLight()
            ambient.light?.type = .ambient
            ambient.light?.intensity = 350
            ambient.light?.color = NSColor(red: 1.0, green: 0.97, blue: 0.93, alpha: 1)
            scene.rootNode.addChildNode(ambient)

            // Floor
            let floor = SCNFloor()
            floor.reflectivity = 0.1
            floor.reflectionFalloffEnd = 2.0
            let floorMat = SCNMaterial()
            floorMat.diffuse.contents = NSColor(red: 0.85, green: 0.75, blue: 0.62, alpha: 1.0)
            floorMat.roughness.contents = NSColor(white: 0.6, alpha: 1)
            floor.materials = [floorMat]
            scene.rootNode.addChildNode(SCNNode(geometry: floor))

            // Rug
            let rugGeo = SCNCylinder(radius: 1.2, height: 0.01)
            let rugMat = SCNMaterial()
            rugMat.diffuse.contents = accent.withAlphaComponent(0.18)
            rugGeo.materials = [rugMat]
            let rug = SCNNode(geometry: rugGeo)
            rug.position = SCNVector3(0, 0.005, 0.2)
            scene.rootNode.addChildNode(rug)

            // Back wall
            let wallGeo = SCNPlane(width: 6, height: 4)
            let wallMat = SCNMaterial()
            wallMat.diffuse.contents = accent.withAlphaComponent(0.06)
            wallMat.isDoubleSided = true
            wallGeo.materials = [wallMat]
            let wall = SCNNode(geometry: wallGeo)
            wall.position = SCNVector3(0, 2, -2.5)
            scene.rootNode.addChildNode(wall)

            // ── EGG ──
            let egg = buildEgg(accent: accent)
            egg.position = SCNVector3(0, 0.55, 0.2)
            scene.rootNode.addChildNode(egg)
            eggNode = egg

            // Subtle idle wobble
            let idleWobble = SCNAction.sequence([
                SCNAction.rotateBy(x: 0, y: 0, z: 0.02, duration: 1.5),
                SCNAction.rotateBy(x: 0, y: 0, z: -0.04, duration: 3.0),
                SCNAction.rotateBy(x: 0, y: 0, z: 0.02, duration: 1.5),
            ])
            idleWobble.timingMode = .easeInEaseOut
            egg.runAction(.repeatForever(idleWobble), forKey: "idle")

            // Glow node (hidden initially, grows with taps)
            let glowGeo = SCNSphere(radius: 0.7)
            let glowMat = SCNMaterial()
            glowMat.diffuse.contents = accent.withAlphaComponent(0.0)
            glowMat.emission.contents = accent.withAlphaComponent(0.0)
            glowMat.lightingModel = .constant
            glowMat.isDoubleSided = true
            glowGeo.materials = [glowMat]
            let glow = SCNNode(geometry: glowGeo)
            glow.position = SCNVector3(0, 0.55, 0.2)
            glow.opacity = 0
            scene.rootNode.addChildNode(glow)
            glowNode = glow

            return scene
        }

        private func buildEgg(accent: NSColor) -> SCNNode {
            let eggRoot = SCNNode()

            // Egg shape: sphere scaled taller, with a slight taper at top
            // Main egg body
            let eggGeo = SCNSphere(radius: 0.42)
            eggGeo.segmentCount = 48
            let eggMat = SCNMaterial()
            // Creamy white with subtle warm tint
            eggMat.diffuse.contents = NSColor(red: 0.97, green: 0.95, blue: 0.90, alpha: 1)
            eggMat.roughness.contents = NSColor(white: 0.35, alpha: 1)
            eggMat.metalness.contents = NSColor(white: 0.02, alpha: 1)
            // Subtle subsurface-like warmth
            eggMat.emission.contents = NSColor(red: 1.0, green: 0.95, blue: 0.88, alpha: 0.03)
            eggGeo.materials = [eggMat]

            let eggBody = SCNNode(geometry: eggGeo)
            eggBody.scale = SCNVector3(0.85, 1.15, 0.85) // taller oval
            eggRoot.addChildNode(eggBody)

            // Speckles — small subtle dots
            let speckleColors: [NSColor] = [
                accent.withAlphaComponent(0.2),
                accent.blended(withFraction: 0.5, of: .brown)?.withAlphaComponent(0.15) ?? accent.withAlphaComponent(0.15),
                NSColor(red: 0.7, green: 0.6, blue: 0.5, alpha: 0.15)
            ]
            for i in 0..<12 {
                let speckGeo = SCNSphere(radius: CGFloat.random(in: 0.012...0.028))
                speckGeo.segmentCount = 8
                let speckMat = SCNMaterial()
                speckMat.diffuse.contents = speckleColors[i % speckleColors.count]
                speckGeo.materials = [speckMat]
                let speck = SCNNode(geometry: speckGeo)

                // Distribute on egg surface using spherical coordinates
                let theta = CGFloat.random(in: 0.3...2.8)
                let phi = CGFloat.random(in: 0...(2 * .pi))
                let r: CGFloat = 0.42
                speck.position = SCNVector3(
                    r * 0.85 * sin(theta) * cos(phi),
                    r * 1.15 * cos(theta),
                    r * 0.85 * sin(theta) * sin(phi)
                )
                eggBody.addChildNode(speck)
            }

            // Nest — small ring of straw-colored torus at the base
            let nestGeo = SCNTorus(ringRadius: 0.38, pipeRadius: 0.06)
            let nestMat = SCNMaterial()
            nestMat.diffuse.contents = NSColor(red: 0.78, green: 0.65, blue: 0.40, alpha: 0.8)
            nestMat.roughness.contents = NSColor(white: 0.9, alpha: 1)
            nestGeo.materials = [nestMat]
            let nest = SCNNode(geometry: nestGeo)
            nest.position = SCNVector3(0, -0.42, 0)
            eggRoot.addChildNode(nest)

            // Extra straw bits around the nest
            for i in 0..<8 {
                let strawGeo = SCNCapsule(capRadius: 0.015, height: CGFloat.random(in: 0.12...0.22))
                let strawMat = SCNMaterial()
                strawMat.diffuse.contents = NSColor(
                    red: CGFloat.random(in: 0.7...0.85),
                    green: CGFloat.random(in: 0.58...0.68),
                    blue: CGFloat.random(in: 0.3...0.45),
                    alpha: 0.7
                )
                strawGeo.materials = [strawMat]
                let straw = SCNNode(geometry: strawGeo)
                let angle = CGFloat(i) * (.pi / 4) + CGFloat.random(in: -0.3...0.3)
                let dist: CGFloat = CGFloat.random(in: 0.3...0.45)
                straw.position = SCNVector3(
                    dist * cos(angle),
                    -0.42 + CGFloat.random(in: -0.02...0.04),
                    dist * sin(angle)
                )
                straw.eulerAngles = SCNVector3(
                    CGFloat.random(in: -0.5...0.5),
                    angle,
                    CGFloat.random(in: 0.2...1.0)
                )
                eggRoot.addChildNode(straw)
            }

            return eggRoot
        }

        func updateCracks(tapCount: Int, in scene: SCNScene?) {
            guard let scene, let egg = eggNode, tapCount > currentTapCount else { return }
            currentTapCount = tapCount

            // Wobble the egg on each tap — gets more intense
            let wobbleIntensity = CGFloat(tapCount) * 0.04
            egg.runAction(SCNAction.sequence([
                SCNAction.rotateBy(x: 0, y: 0, z: wobbleIntensity, duration: 0.06),
                SCNAction.rotateBy(x: 0, y: 0, z: -wobbleIntensity * 2, duration: 0.12),
                SCNAction.rotateBy(x: 0, y: 0, z: wobbleIntensity * 1.5, duration: 0.1),
                SCNAction.rotateBy(x: 0, y: 0, z: -wobbleIntensity * 0.5, duration: 0.08),
                SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.06)
            ]))

            // Progressive cracks with 5 taps
            if tapCount >= 1 && crackNodes.count < 1 {
                addCrackToEgg(egg: egg, seed: 1, intensity: 0.4)
            }
            if tapCount >= 2 && crackNodes.count < 2 {
                addCrackToEgg(egg: egg, seed: 2, intensity: 0.55)
            }
            if tapCount >= 3 && crackNodes.count < 3 {
                addCrackToEgg(egg: egg, seed: 3, intensity: 0.7)
                // Start glow
                if let glow = glowNode {
                    let accent = glow.geometry?.firstMaterial?.diffuse.contents as? NSColor ?? .white
                    glow.opacity = 0.2
                    glow.geometry?.firstMaterial?.emission.contents = (accent.withAlphaComponent(0.1) as NSColor)
                }
            }
            if tapCount >= 4 && crackNodes.count < 4 {
                addCrackToEgg(egg: egg, seed: 4, intensity: 0.85)
                // Brighter glow
                if let glow = glowNode {
                    let accent = glow.geometry?.firstMaterial?.diffuse.contents as? NSColor ?? .white
                    glow.opacity = 0.4
                    glow.geometry?.firstMaterial?.emission.contents = (accent.withAlphaComponent(0.2) as NSColor)
                }
                // Egg starts to bounce
                egg.runAction(SCNAction.sequence([
                    SCNAction.moveBy(x: 0, y: 0.08, z: 0, duration: 0.1),
                    SCNAction.moveBy(x: 0, y: -0.08, z: 0, duration: 0.1)
                ]))
            }
            if tapCount >= 5 {
                addCrackToEgg(egg: egg, seed: 5, intensity: 1.0)
                // Big burst + egg explodes
                performHatchAnimation(egg: egg, in: scene)
            }
        }

        private func addCrackToEgg(egg: SCNNode, seed: Int, intensity: CGFloat) {
            // Crack as a dark line etched into the surface
            // Use multiple thin boxes arranged in a zigzag on the egg surface
            let crackRoot = SCNNode()
            crackRoot.name = "crack_\(seed)"

            let crackMat = SCNMaterial()
            crackMat.diffuse.contents = NSColor(white: 0.2, alpha: Double(intensity))
            crackMat.lightingModel = .constant

            var rng = SeededRNG(seed: UInt64(seed * 31 + 7))
            let segments = 5 + seed
            var y: CGFloat = CGFloat.random(in: -0.1...0.15, using: &rng)
            var angle: CGFloat = CGFloat.random(in: 0...(2 * .pi), using: &rng)

            for _ in 0..<segments {
                let length: CGFloat = CGFloat.random(in: 0.06...0.12, using: &rng)
                let lineGeo = SCNBox(width: 0.008 * intensity, height: length, length: 0.005, chamferRadius: 0)
                lineGeo.materials = [crackMat]
                let line = SCNNode(geometry: lineGeo)

                let r: CGFloat = 0.43
                line.position = SCNVector3(
                    r * 0.85 * cos(angle),
                    y * 1.15,
                    r * 0.85 * sin(angle)
                )
                // Point outward from center
                line.look(at: SCNVector3(0, CGFloat(line.position.y), 0))
                line.eulerAngles.z += CGFloat.random(in: -0.4...0.4, using: &rng)

                crackRoot.addChildNode(line)

                // Branch occasionally
                if Int.random(in: 0...2, using: &rng) == 0 {
                    let branchGeo = SCNBox(width: 0.006 * intensity, height: CGFloat.random(in: 0.03...0.06, using: &rng), length: 0.005, chamferRadius: 0)
                    branchGeo.materials = [crackMat]
                    let branch = SCNNode(geometry: branchGeo)
                    branch.position = line.position
                    branch.eulerAngles = line.eulerAngles
                    branch.eulerAngles.z += CGFloat.random(in: 0.5...1.2, using: &rng) * (Bool.random(using: &rng) ? 1 : -1)
                    crackRoot.addChildNode(branch)
                }

                y += CGFloat.random(in: -0.08...0.08, using: &rng)
                angle += CGFloat.random(in: 0.15...0.4, using: &rng) * (Bool.random(using: &rng) ? 1 : -1)
            }

            // Pop in with scale
            crackRoot.scale = SCNVector3(0.01, 0.01, 0.01)
            crackRoot.runAction(.scale(to: 1.0, duration: 0.2))

            egg.addChildNode(crackRoot)
            crackNodes.append(crackRoot)
        }

        private func performHatchAnimation(egg: SCNNode, in scene: SCNScene) {
            // Intense wobble
            egg.removeAction(forKey: "idle")
            let shake = SCNAction.sequence([
                SCNAction.rotateBy(x: 0, y: 0, z: 0.12, duration: 0.05),
                SCNAction.rotateBy(x: 0, y: 0, z: -0.24, duration: 0.1),
                SCNAction.rotateBy(x: 0, y: 0, z: 0.20, duration: 0.08),
                SCNAction.rotateBy(x: 0, y: 0, z: -0.16, duration: 0.07),
                SCNAction.rotateBy(x: 0, y: 0, z: 0.08, duration: 0.05),
            ])
            egg.runAction(SCNAction.repeat(shake, count: 3), forKey: "hatchShake")

            // Glow intensifies
            if let glow = glowNode {
                glow.runAction(SCNAction.sequence([
                    SCNAction.fadeOpacity(to: 0.8, duration: 0.5),
                    SCNAction.scale(to: 2.0, duration: 0.5),
                    SCNAction.group([
                        SCNAction.fadeOut(duration: 0.3),
                        SCNAction.scale(to: 3.0, duration: 0.3)
                    ])
                ]))
            }

            // After shake, egg bursts apart
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                // Create shell fragments that fly outward
                let eggBody = egg.childNodes.first
                for i in 0..<8 {
                    let fragmentGeo = SCNBox(
                        width: CGFloat.random(in: 0.06...0.14),
                        height: CGFloat.random(in: 0.08...0.16),
                        length: 0.02,
                        chamferRadius: 0.01
                    )
                    let fragMat = SCNMaterial()
                    fragMat.diffuse.contents = NSColor(red: 0.97, green: 0.95, blue: 0.90, alpha: 1)
                    fragMat.roughness.contents = NSColor(white: 0.35, alpha: 1)
                    fragmentGeo.materials = [fragMat]

                    let frag = SCNNode(geometry: fragmentGeo)
                    frag.position = egg.position
                    scene.rootNode.addChildNode(frag)

                    let angle = CGFloat(i) * (.pi / 4)
                    let dx = cos(angle) * CGFloat.random(in: 0.8...1.5)
                    let dy = CGFloat.random(in: 0.6...1.5)
                    let dz = sin(angle) * CGFloat.random(in: 0.5...1.0)

                    frag.runAction(SCNAction.sequence([
                        SCNAction.group([
                            SCNAction.moveBy(x: dx, y: dy, z: dz, duration: 0.4),
                            SCNAction.rotateBy(
                                x: CGFloat.random(in: -3...3),
                                y: CGFloat.random(in: -3...3),
                                z: CGFloat.random(in: -3...3),
                                duration: 0.4
                            ),
                        ]),
                        SCNAction.group([
                            SCNAction.moveBy(x: 0, y: -2, z: 0, duration: 0.3),
                            SCNAction.fadeOut(duration: 0.3)
                        ]),
                        SCNAction.removeFromParentNode()
                    ]))
                }

                // Hide the original egg
                eggBody?.opacity = 0
                egg.childNodes.filter { $0.name?.hasPrefix("crack_") == true }.forEach { $0.opacity = 0 }

                // Sparkle particles at the egg position
                for i in 0..<12 {
                    let sparkGeo = SCNSphere(radius: CGFloat.random(in: 0.02...0.05))
                    sparkGeo.segmentCount = 8
                    let sparkMat = SCNMaterial()
                    sparkMat.diffuse.contents = NSColor.white
                    sparkMat.emission.contents = NSColor(red: 1, green: 0.95, blue: 0.7, alpha: 1)
                    sparkMat.lightingModel = .constant
                    sparkGeo.materials = [sparkMat]
                    let spark = SCNNode(geometry: sparkGeo)
                    spark.position = egg.position
                    scene.rootNode.addChildNode(spark)

                    let a = CGFloat.random(in: 0...(2 * .pi))
                    let r = CGFloat.random(in: 0.3...1.0)
                    spark.runAction(SCNAction.sequence([
                        SCNAction.group([
                            SCNAction.moveBy(x: r * cos(a), y: CGFloat.random(in: 0.3...1.2), z: r * sin(a), duration: 0.5),
                            SCNAction.fadeOut(duration: 0.5)
                        ]),
                        SCNAction.removeFromParentNode()
                    ]))
                }
            }
        }
    }
}

// MARK: - SceneKit 3D Pet Scene

private struct PetSceneView: NSViewRepresentable {
    let pet: UserDataStore.PetStateData
    let theme: WidgetTheme
    let activeGame: VirtualPetComponentView.PetGame?
    let feedTrigger: Int  // incremented to trigger feed animation
    let petModeActive: Bool  // true when user activates petting mode via button
    let onTap: () -> Void
    let onPet: (Bool) -> Void  // true = positive petting, false = over-tickled distress
    let onPlay: () -> Void
    let onPetModeEnd: () -> Void

    func makeNSView(context: Context) -> PetSCNView {
        let scnView = PetSCNView()
        scnView.coordinator = context.coordinator
        scnView.scene = context.coordinator.buildScene(pet: pet, theme: theme)
        scnView.backgroundColor = .clear
        scnView.antialiasingMode = .multisampling4X
        scnView.allowsCameraControl = false  // we handle mouse ourselves
        scnView.autoenablesDefaultLighting = false
        scnView.isJitteringEnabled = true

        let click = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleClick(_:)))
        scnView.addGestureRecognizer(click)

        // Tracking area for mouse movement (laser pointer + petting)
        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: context.coordinator,
            userInfo: nil
        )
        scnView.addTrackingArea(trackingArea)

        return scnView
    }

    func updateNSView(_ scnView: PetSCNView, context: Context) {
        context.coordinator.activeGame = activeGame
        context.coordinator.petModeActive = petModeActive
        context.coordinator.scnViewRef = scnView
        context.coordinator.currentHunger = pet.hunger
        context.coordinator.currentHappiness = pet.happiness
        context.coordinator.updateMood(pet: pet, in: scnView.scene)
        context.coordinator.handleFeedTrigger(feedTrigger, in: scnView.scene)
        context.coordinator.updateSleepState()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap, onPet: onPet, onPlay: onPlay, onPetModeEnd: onPetModeEnd)
    }

    // Custom SCNView subclass to forward mouse events to coordinator
    class PetSCNView: SCNView {
        weak var coordinator: Coordinator?

        override func mouseMoved(with event: NSEvent) {
            coordinator?.handleMouseMoved(in: self, event: event)
        }

        override func mouseDragged(with event: NSEvent) {
            coordinator?.handleMouseDragged(in: self, event: event)
        }

        override func mouseExited(with event: NSEvent) {
            coordinator?.handleMouseExited()
        }

        override var acceptsFirstResponder: Bool { true }
    }

    class Coordinator: NSObject {
        let onTap: () -> Void
        let onPet: (Bool) -> Void  // true = positive, false = distress
        let onPlay: () -> Void
        let onPetModeEnd: () -> Void
        var petModeActive = false
        var petCharacter: UserDataStore.PetCharacter = .fluffy
        weak var scnViewRef: SCNView?
        private var petBodyNode: SCNNode?   // the root node of the pet
        private var bodyMeshNode: SCNNode?  // the capsule body mesh
        private var headNode: SCNNode?
        private var leftEyeNode: SCNNode?
        private var rightEyeNode: SCNNode?
        private var leftPupilNode: SCNNode?
        private var rightPupilNode: SCNNode?
        private var mouthNode: SCNNode?
        private var leftCheekNode: SCNNode?
        private var rightCheekNode: SCNNode?

        // Zone-based petting state
        private enum PetZone { case cheeks, tummy, general }
        private var currentPetZone: PetZone = .general
        private var tummyTickleCount = 0
        private var tummyTickleLevel = 0  // 0=none, 1=giggle, 2=laugh, 3=hardLaugh, 4=crying
        private var isCryingFromTickle = false
        private var petOriginalPosition: SCNVector3?
        private var leftArmNode: SCNNode?
        private var rightArmNode: SCNNode?
        private var leftFootNode: SCNNode?
        private var rightFootNode: SCNNode?
        private var leftEarNode: SCNNode?
        private var rightEarNode: SCNNode?
        private var tailNode: SCNNode?

        // VRM skeleton bone references
        private var vrmBones: [String: SCNNode] = [:]
        private var vrmMorpherNode: SCNNode?
        private var vrmBlendShapeMap: [String: Int] = [:]

        private var hipsBone: SCNNode? { vrmBones["mixamorig:Hips"] }
        private var spineBone: SCNNode? { vrmBones["mixamorig:Spine"] }
        private var spine1Bone: SCNNode? { vrmBones["mixamorig:Spine1"] }
        private var spine2Bone: SCNNode? { vrmBones["mixamorig:Spine2"] }
        private var neckBone: SCNNode? { vrmBones["mixamorig:Neck"] }
        private var headBoneVRM: SCNNode? { vrmBones["mixamorig:Head"] }
        private var leftShoulderBone: SCNNode? { vrmBones["mixamorig:LeftShoulder"] }
        private var rightShoulderBone: SCNNode? { vrmBones["mixamorig:RightShoulder"] }
        private var leftUpperArmBone: SCNNode? { vrmBones["mixamorig:LeftArm"] }
        private var rightUpperArmBone: SCNNode? { vrmBones["mixamorig:RightArm"] }
        private var leftForeArmBone: SCNNode? { vrmBones["mixamorig:LeftForeArm"] }
        private var rightForeArmBone: SCNNode? { vrmBones["mixamorig:RightForeArm"] }
        private var leftHandBone: SCNNode? { vrmBones["mixamorig:LeftHand"] }
        private var rightHandBone: SCNNode? { vrmBones["mixamorig:RightHand"] }
        private var leftUpperLegBone: SCNNode? { vrmBones["mixamorig:LeftUpLeg"] }
        private var rightUpperLegBone: SCNNode? { vrmBones["mixamorig:RightUpLeg"] }
        private var leftLowerLegBone: SCNNode? { vrmBones["mixamorig:LeftLeg"] }
        private var rightLowerLegBone: SCNNode? { vrmBones["mixamorig:RightLeg"] }
        private var leftFootBone: SCNNode? { vrmBones["mixamorig:LeftFoot"] }
        private var rightFootBone: SCNNode? { vrmBones["mixamorig:RightFoot"] }

        private var laserDotNode: SCNNode?
        private var laserGlowNode: SCNNode?
        private var isChasing = false
        private var isPettingActive = false
        private var lastPetTime: Date = .distantPast
        private var lastPlayTime: Date = .distantPast
        private var petStrokeCount = 0
        private var sceneRef: SCNScene?
        // Room objects that can be toppled
        private var toyBallNode: SCNNode?
        private var yarnBallNode: SCNNode?
        private var bookStackNode: SCNNode?
        private var plantNode: SCNNode?
        private var cushionNode: SCNNode?
        private var toppledObjects: [SCNNode] = []  // objects currently knocked over
        var activeGame: VirtualPetComponentView.PetGame?
        private var lastFeedTrigger = 0
        var currentHunger: Double = 100
        var currentHappiness: Double = 100
        private var isSleeping = false
        private var sleepMatNode: SCNNode?
        private var zzzNode: SCNNode?

        init(onTap: @escaping () -> Void, onPet: @escaping (Bool) -> Void, onPlay: @escaping () -> Void, onPetModeEnd: @escaping () -> Void) {
            self.onTap = onTap
            self.onPet = onPet
            self.onPlay = onPlay
            self.onPetModeEnd = onPetModeEnd
        }

        @objc func handleClick(_ gesture: NSClickGestureRecognizer) {
            guard let scnView = gesture.view as? SCNView else {
                onTap()
                return
            }

            let location = gesture.location(in: scnView)
            let hitResults = scnView.hitTest(location, options: [.searchMode: SCNHitTestSearchMode.closest.rawValue])

            // Check if clicked on the pet
            let hitPet = hitResults.contains { result in
                var node: SCNNode? = result.node
                while let n = node {
                    if n === petBodyNode { return true }
                    node = n.parent
                }
                return false
            }

            if hitPet {
                // If in pet mode, clicking ends it
                if petModeActive {
                    endPetting()
                    petModeActive = false
                    NSCursor.arrow.set()
                    DispatchQueue.main.async { [weak self] in self?.onPetModeEnd() }
                    return
                }
                onTap()
                // Bounce + spin on click
                guard let body = petBodyNode else { return }
                let jump = SCNAction.sequence([
                    SCNAction.moveBy(x: 0, y: 0.4, z: 0, duration: 0.15),
                    SCNAction.group([
                        SCNAction.moveBy(x: 0, y: -0.4, z: 0, duration: 0.15),
                        SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 0.4)
                    ])
                ])
                jump.timingMode = .easeInEaseOut
                body.runAction(jump)
                wiggleEars()
                showHappyFace()

                // Spawn heart particle at hit point
                if let firstHit = hitResults.first {
                    spawnHeartParticle(at: firstHit.worldCoordinates)
                }
            } else if activeGame != nil {
                // Game is active — interact with floor based on game type
                let floorHits = hitResults.filter { result in
                    result.node.geometry is SCNFloor || result.node.name == "floor"
                }
                if let floorHit = floorHits.first {
                    switch activeGame {
                    case .laser:
                        moveLaserDot(to: floorHit.worldCoordinates)
                        chaseLaserDot(target: floorHit.worldCoordinates)
                    case .fetch:
                        // Throw the ball to that spot, pet fetches it
                        throwBall(to: floorHit.worldCoordinates)
                    case .yarn:
                        // Roll yarn there, pet chases
                        rollYarn(to: floorHit.worldCoordinates)
                    case .none:
                        break
                    }
                }
            }
        }

        // MARK: - Mouse Interaction

        func handleMouseMoved(in scnView: SCNView, event: NSEvent) {
            let location = scnView.convert(event.locationInWindow, from: nil)
            let hitResults = scnView.hitTest(location, options: [.searchMode: SCNHitTestSearchMode.closest.rawValue])

            // Laser dot only visible during laser game
            if activeGame == .laser {
                let floorHits = hitResults.filter { $0.node.geometry is SCNFloor || $0.node.name == "floor" }
                if let floorHit = floorHits.first {
                    moveLaserDot(to: floorHit.worldCoordinates)
                }
            }

            // Check if hovering over pet (for visual feedback)
            let overPet = hitResults.contains { result in
                var node: SCNNode? = result.node
                while let n = node {
                    if n === petBodyNode { return true }
                    node = n.parent
                }
                return false
            }

            // In pet mode, mouse movement over pet triggers petting (no drag needed)
            if petModeActive {
                if overPet {
                    NSCursor.openHand.set()
                    // Reuse the drag-based petting logic
                    handlePetModeMove(in: scnView, event: event, hitResults: hitResults)
                } else {
                    if isPettingActive {
                        endPetting()
                    }
                    NSCursor.openHand.set()  // keep hand cursor in pet mode
                }
                return
            }

            if overPet {
                headNode?.removeAction(forKey: "look")
                headNode?.runAction(SCNAction.rotateTo(x: 0.1, y: 0, z: 0, duration: 0.2), forKey: "lookAtMouse")
                leftPupilNode?.runAction(SCNAction.move(to: SCNVector3(0, 0.01, 0.065), duration: 0.1))
                rightPupilNode?.runAction(SCNAction.move(to: SCNVector3(0, 0.01, 0.065), duration: 0.1))
            } else {
                NSCursor.arrow.set()
            }
        }

        // Pet mode — mouse movement acts like dragging for petting
        private func handlePetModeMove(in scnView: SCNView, event: NSEvent, hitResults: [SCNHitTestResult]) {
            // Detect which zone was hit
            var hitZone: PetZone = .general

            for result in hitResults {
                var node: SCNNode? = result.node
                var isPetNode = false
                while let n = node {
                    if n === petBodyNode { isPetNode = true; break }
                    node = n.parent
                }
                guard isPetNode else { continue }

                var checkNode: SCNNode? = result.node
                while let n = checkNode {
                    if n === headNode { hitZone = .cheeks; break }
                    if n === bodyMeshNode { hitZone = .tummy; break }
                    checkNode = n.parent
                }
                break
            }

            petStrokeCount += 1

            // Track zone changes
            if !isPettingActive || currentPetZone != hitZone {
                if currentPetZone != hitZone && isPettingActive {
                    tummyTickleCount = 0
                    tummyTickleLevel = 0
                    isCryingFromTickle = false
                }
                currentPetZone = hitZone
            }

            if !isPettingActive {
                isPettingActive = true
                if petOriginalPosition == nil {
                    petOriginalPosition = petBodyNode?.position
                }
                let purr = SCNAction.sequence([
                    SCNAction.moveBy(x: 0.01, y: 0, z: 0, duration: 0.03),
                    SCNAction.moveBy(x: -0.02, y: 0, z: 0, duration: 0.06),
                    SCNAction.moveBy(x: 0.01, y: 0, z: 0, duration: 0.03)
                ])
                petBodyNode?.runAction(.repeatForever(purr), forKey: "purr")
            }

            switch hitZone {
            case .cheeks: handleCheekPetting()
            case .tummy: handleTummyTickle()
            case .general: handleGeneralPetting()
            }

            // Hearts (not when crying)
            if hitZone != .tummy || !isCryingFromTickle {
                if petStrokeCount % 8 == 0, let firstHit = hitResults.first {
                    spawnHeartParticle(at: firstHit.worldCoordinates)
                }
            }

            // Stat effects
            if petStrokeCount % 20 == 0 {
                let now = Date()
                if now.timeIntervalSince(lastPetTime) > 2.0 {
                    lastPetTime = now
                    onPet(!isCryingFromTickle)
                }
            }
        }

        func handleMouseDragged(in scnView: SCNView, event: NSEvent) {
            let location = scnView.convert(event.locationInWindow, from: nil)
            let hitResults = scnView.hitTest(location, options: [.searchMode: SCNHitTestSearchMode.closest.rawValue])

            // Detect which zone was hit
            var hitZone: PetZone? = nil
            var hitOnPet = false

            for result in hitResults {
                var node: SCNNode? = result.node
                while let n = node {
                    if n === petBodyNode {
                        hitOnPet = true
                        break
                    }
                    node = n.parent
                }
                guard hitOnPet else { continue }

                // Check if hit is on head (cheeks zone) or body (tummy zone)
                var checkNode: SCNNode? = result.node
                while let n = checkNode {
                    if n === headNode {
                        hitZone = .cheeks
                        break
                    }
                    if n === bodyMeshNode {
                        hitZone = .tummy
                        break
                    }
                    checkNode = n.parent
                }
                if hitZone == nil { hitZone = .general }
                break
            }

            if hitOnPet, let zone = hitZone {
                petStrokeCount += 1

                // Show hand cursor
                NSCursor.openHand.set()

                // Track zone changes
                if !isPettingActive || currentPetZone != zone {
                    if currentPetZone != zone && isPettingActive {
                        // Zone changed — reset tummy tickle escalation
                        tummyTickleCount = 0
                        tummyTickleLevel = 0
                        isCryingFromTickle = false
                    }
                    currentPetZone = zone
                }

                if !isPettingActive {
                    isPettingActive = true
                    if petOriginalPosition == nil {
                        petOriginalPosition = petBodyNode?.position
                    }
                    // Purr vibration for all zones
                    let purr = SCNAction.sequence([
                        SCNAction.moveBy(x: 0.01, y: 0, z: 0, duration: 0.03),
                        SCNAction.moveBy(x: -0.02, y: 0, z: 0, duration: 0.06),
                        SCNAction.moveBy(x: 0.01, y: 0, z: 0, duration: 0.03)
                    ])
                    petBodyNode?.runAction(.repeatForever(purr), forKey: "purr")
                }

                switch zone {
                case .cheeks:
                    handleCheekPetting()
                case .tummy:
                    handleTummyTickle()
                case .general:
                    handleGeneralPetting()
                }

                // Spawn heart particles for cheeks/general (not tummy when crying)
                if zone != .tummy || !isCryingFromTickle {
                    if petStrokeCount % 8 == 0, let firstHit = hitResults.first {
                        spawnHeartParticle(at: firstHit.worldCoordinates)
                    }
                }

                // Stat effects every ~20 strokes
                if petStrokeCount % 20 == 0 {
                    let now = Date()
                    if now.timeIntervalSince(lastPetTime) > 2.0 {
                        lastPetTime = now
                        onPet(!isCryingFromTickle)
                    }
                }
            } else {
                endPetting()
                NSCursor.arrow.set()
                // If dragging on floor during a game, interact
                if activeGame != nil {
                    let floorHits = hitResults.filter { $0.node.geometry is SCNFloor || $0.node.name == "floor" }
                    if let floorHit = floorHits.first {
                        if activeGame == .laser {
                            moveLaserDot(to: floorHit.worldCoordinates)
                            chaseLaserDot(target: floorHit.worldCoordinates)
                        }
                    }
                }
            }
        }

        // MARK: - Cheek Petting (smile, blush, hearts)
        private func handleCheekPetting() {
            // Lean into the touch
            bodyMeshNode?.runAction(SCNAction.rotateTo(x: 0.08, y: 0, z: 0, duration: 0.2), forKey: "petLean")

            // Happy squint eyes
            leftEyeNode?.runAction(SCNAction.run { n in n.scale = SCNVector3(1, 0.4, 1) }, forKey: "petSquint")
            rightEyeNode?.runAction(SCNAction.run { n in n.scale = SCNVector3(1, 0.4, 1) }, forKey: "petSquint")

            // Blush cheeks — pulse bigger and pinker
            if petStrokeCount % 6 == 0 {
                let blushPulse = SCNAction.sequence([
                    SCNAction.scale(to: 1.5, duration: 0.15),
                    SCNAction.scale(to: 1.2, duration: 0.2)
                ])
                leftCheekNode?.runAction(blushPulse, forKey: "blush")
                rightCheekNode?.runAction(blushPulse, forKey: "blush")

                // Make cheeks pinker
                let pinkMat = SCNMaterial()
                pinkMat.diffuse.contents = NSColor.systemPink.withAlphaComponent(0.6)
                pinkMat.emission.contents = NSColor.systemPink.withAlphaComponent(0.15)
                leftCheekNode?.geometry?.materials = [pinkMat]
                rightCheekNode?.geometry?.materials = [pinkMat]
            }

            // Wider smile — scale mouth wider
            mouthNode?.runAction(SCNAction.run { n in
                n.scale = SCNVector3(1.4, 0.7, 1)
            }, forKey: "smile")

            // Spawn extra hearts for cheek petting (more love!)
            if petStrokeCount % 5 == 0, let head = headNode {
                let worldPos = head.worldPosition
                spawnHeartParticle(at: SCNVector3(worldPos.x + CGFloat.random(in: -0.3...0.3), worldPos.y + 0.3, worldPos.z + 0.3))
            }
        }

        // MARK: - Tummy Tickle (escalating laughter → crying)
        private func handleTummyTickle() {
            tummyTickleCount += 1

            // Escalation thresholds
            let newLevel: Int
            if tummyTickleCount < 15 {
                newLevel = 1  // light giggle
            } else if tummyTickleCount < 40 {
                newLevel = 2  // laughing
            } else if tummyTickleCount < 70 {
                newLevel = 3  // hard laughing
            } else {
                newLevel = 4  // crying — too much!
            }

            if newLevel != tummyTickleLevel {
                tummyTickleLevel = newLevel
                applyTickleLevel(newLevel)
            }

            // Store original position on first tickle
            guard let body = petBodyNode else { return }
            if petOriginalPosition == nil {
                petOriginalPosition = body.position
            }
            let orig = petOriginalPosition!

            // Ongoing tickle animations per stroke — use absolute positions to prevent drift
            switch tummyTickleLevel {
            case 1:  // Light giggle — gentle body bounce
                if tummyTickleCount % 4 == 0 {
                    let bounce = SCNAction.sequence([
                        SCNAction.move(to: SCNVector3(orig.x, orig.y + 0.05, orig.z), duration: 0.06),
                        SCNAction.move(to: orig, duration: 0.06)
                    ])
                    body.runAction(bounce, forKey: "tickleBounce")
                }
            case 2:  // Laughing — bigger bounces + side wobble
                if tummyTickleCount % 3 == 0 {
                    let wobble = SCNAction.sequence([
                        SCNAction.move(to: SCNVector3(orig.x, orig.y + 0.1, orig.z), duration: 0.05),
                        SCNAction.rotateTo(x: 0, y: 0, z: 0.08, duration: 0.05),
                        SCNAction.move(to: orig, duration: 0.05),
                        SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.05)
                    ])
                    body.runAction(wobble, forKey: "tickleBounce")
                }
            case 3:  // Hard laughing — shaking violently
                if tummyTickleCount % 2 == 0 {
                    let shake = SCNAction.sequence([
                        SCNAction.move(to: SCNVector3(orig.x + 0.05, orig.y + 0.12, orig.z), duration: 0.04),
                        SCNAction.rotateTo(x: 0, y: 0, z: 0.12, duration: 0.04),
                        SCNAction.move(to: SCNVector3(orig.x - 0.05, orig.y, orig.z), duration: 0.04),
                        SCNAction.rotateTo(x: 0, y: 0, z: -0.12, duration: 0.04),
                        SCNAction.move(to: orig, duration: 0.04),
                        SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.04)
                    ])
                    body.runAction(shake, forKey: "tickleBounce")
                }
            case 4:  // Crying — spawn tears
                // Ensure pet is at original position while crying
                body.removeAction(forKey: "tickleBounce")
                body.position = orig
                if tummyTickleCount % 6 == 0, let head = headNode {
                    let worldPos = head.worldPosition
                    spawnTearParticle(at: SCNVector3(worldPos.x - 0.15, worldPos.y + 0.06, worldPos.z + 0.4))
                    spawnTearParticle(at: SCNVector3(worldPos.x + 0.15, worldPos.y + 0.06, worldPos.z + 0.4))
                }
            default:
                break
            }
        }

        private func applyTickleLevel(_ level: Int) {
            switch level {
            case 1:  // Light giggle
                // Happy squint
                leftEyeNode?.runAction(SCNAction.run { n in n.scale = SCNVector3(1, 0.5, 1) }, forKey: "petSquint")
                rightEyeNode?.runAction(SCNAction.run { n in n.scale = SCNVector3(1, 0.5, 1) }, forKey: "petSquint")
                // Small smile
                mouthNode?.runAction(SCNAction.run { n in n.scale = SCNVector3(1.2, 0.6, 1) }, forKey: "smile")
                showSpeechBubble("hehe~")

            case 2:  // Laughing
                leftEyeNode?.runAction(SCNAction.run { n in n.scale = SCNVector3(1, 0.3, 1) }, forKey: "petSquint")
                rightEyeNode?.runAction(SCNAction.run { n in n.scale = SCNVector3(1, 0.3, 1) }, forKey: "petSquint")
                // Big open smile
                mouthNode?.runAction(SCNAction.run { n in n.scale = SCNVector3(1.5, 1.0, 1) }, forKey: "smile")
                showSpeechBubble("Ahaha! 😆")

            case 3:  // Hard laughing
                // Eyes squeezed shut
                leftEyeNode?.runAction(SCNAction.run { n in n.scale = SCNVector3(1, 0.15, 1) }, forKey: "petSquint")
                rightEyeNode?.runAction(SCNAction.run { n in n.scale = SCNVector3(1, 0.15, 1) }, forKey: "petSquint")
                // Wide open mouth
                mouthNode?.runAction(SCNAction.run { n in n.scale = SCNVector3(1.8, 1.3, 1) }, forKey: "smile")
                // Cheeks puff up from laughing
                leftCheekNode?.runAction(SCNAction.scale(to: 1.6, duration: 0.2), forKey: "blush")
                rightCheekNode?.runAction(SCNAction.scale(to: 1.6, duration: 0.2), forKey: "blush")
                showSpeechBubble("STOP!! 🤣🤣")

            case 4:  // Crying — too much!
                isCryingFromTickle = true
                // Big sad eyes
                leftEyeNode?.runAction(SCNAction.run { n in n.scale = SCNVector3(1.2, 1.3, 1) }, forKey: "petSquint")
                rightEyeNode?.runAction(SCNAction.run { n in n.scale = SCNVector3(1.2, 1.3, 1) }, forKey: "petSquint")
                // Sad mouth — flip and small
                mouthNode?.runAction(SCNAction.run { n in
                    n.scale = SCNVector3(0.8, 0.5, 1)
                    n.eulerAngles.x = -CGFloat.pi / 5  // flip frown
                }, forKey: "smile")
                // Cheeks return to normal
                leftCheekNode?.runAction(SCNAction.scale(to: 1.0, duration: 0.3), forKey: "blush")
                rightCheekNode?.runAction(SCNAction.scale(to: 1.0, duration: 0.3), forKey: "blush")
                // Stop bouncing, just tremble
                petBodyNode?.removeAction(forKey: "purr")
                let tremble = SCNAction.sequence([
                    SCNAction.moveBy(x: 0.008, y: 0, z: 0, duration: 0.04),
                    SCNAction.moveBy(x: -0.016, y: 0, z: 0, duration: 0.08),
                    SCNAction.moveBy(x: 0.008, y: 0, z: 0, duration: 0.04)
                ])
                petBodyNode?.runAction(.repeatForever(tremble), forKey: "purr")
                showSpeechBubble("😢 waaah...")

            default:
                break
            }
        }

        // MARK: - General Petting (original behavior)
        private func handleGeneralPetting() {
            bodyMeshNode?.runAction(SCNAction.rotateTo(x: 0.08, y: 0, z: 0, duration: 0.2), forKey: "petLean")
            leftEyeNode?.runAction(SCNAction.run { n in n.scale = SCNVector3(1, 0.4, 1) }, forKey: "petSquint")
            rightEyeNode?.runAction(SCNAction.run { n in n.scale = SCNVector3(1, 0.4, 1) }, forKey: "petSquint")
        }

        // MARK: - Tear Particles
        private func spawnTearParticle(at position: SCNVector3) {
            guard let scene = sceneRef else { return }

            let tearGeo = SCNSphere(radius: 0.035)
            let tearMat = SCNMaterial()
            tearMat.diffuse.contents = NSColor(red: 0.5, green: 0.7, blue: 1.0, alpha: 0.8)
            tearMat.emission.contents = NSColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 0.3)
            tearMat.transparency = 0.7
            tearGeo.materials = [tearMat]

            let tear = SCNNode(geometry: tearGeo)
            tear.position = position
            scene.rootNode.addChildNode(tear)

            // Fall down and fade
            let fall = SCNAction.moveBy(x: CGFloat.random(in: -0.05...0.05), y: -0.6, z: 0.05, duration: 0.7)
            fall.timingMode = .easeIn
            let fadeOut = SCNAction.fadeOut(duration: 0.5)
            let group = SCNAction.group([fall, fadeOut])

            tear.runAction(SCNAction.sequence([group, SCNAction.removeFromParentNode()]))
        }

        func handleMouseExited() {
            endPetting()
            if petModeActive {
                DispatchQueue.main.async { [weak self] in self?.onPetModeEnd() }
                petModeActive = false
            }
            NSCursor.arrow.set()
            // Hide laser dot
            laserDotNode?.runAction(SCNAction.scale(to: 0.001, duration: 0.2))
            laserGlowNode?.runAction(SCNAction.fadeOut(duration: 0.2))

            // Resume normal head look-around
            if let head = headNode {
                head.removeAction(forKey: "lookAtMouse")
                let lookAround = SCNAction.sequence([
                    SCNAction.wait(duration: 4),
                    SCNAction.rotateBy(x: 0, y: 0.3, z: 0, duration: 0.5),
                    SCNAction.wait(duration: 1.5),
                    SCNAction.rotateBy(x: 0, y: -0.6, z: 0, duration: 0.8),
                    SCNAction.wait(duration: 1.5),
                    SCNAction.rotateBy(x: 0, y: 0.3, z: 0, duration: 0.5),
                    SCNAction.wait(duration: 3)
                ])
                lookAround.timingMode = .easeInEaseOut
                head.runAction(.repeatForever(lookAround), forKey: "look")
            }
        }

        private func endPetting() {
            guard isPettingActive else { return }
            isPettingActive = false
            petStrokeCount = 0
            tummyTickleCount = 0
            tummyTickleLevel = 0
            isCryingFromTickle = false
            currentPetZone = .general
            bodyMeshNode?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.2), forKey: "petLean")
            leftEyeNode?.runAction(SCNAction.run { n in n.scale = SCNVector3(1, 1, 1) }, forKey: "petSquint")
            rightEyeNode?.runAction(SCNAction.run { n in n.scale = SCNVector3(1, 1, 1) }, forKey: "petSquint")
            petBodyNode?.removeAction(forKey: "purr")
            petBodyNode?.removeAction(forKey: "tickleBounce")
            // Snap pet back to original position and rotation
            if let orig = petOriginalPosition {
                petBodyNode?.runAction(SCNAction.move(to: orig, duration: 0.2))
            }
            petBodyNode?.runAction(SCNAction.rotateTo(x: 0, y: petCharacter.isVRM ? CGFloat.pi : 0, z: 0, duration: 0.2))
            petOriginalPosition = nil
            // Reset mouth
            mouthNode?.runAction(SCNAction.run { n in
                n.scale = SCNVector3(1, 0.5, 1)
                n.eulerAngles.x = CGFloat.pi / 5
            }, forKey: "smile")
            // Reset cheeks
            leftCheekNode?.runAction(SCNAction.scale(to: 1.0, duration: 0.3), forKey: "blush")
            rightCheekNode?.runAction(SCNAction.scale(to: 1.0, duration: 0.3), forKey: "blush")
            // Reset cheek color
            let normalCheekMat = SCNMaterial()
            normalCheekMat.diffuse.contents = NSColor.systemPink.withAlphaComponent(0.3)
            normalCheekMat.emission.contents = NSColor.systemPink.withAlphaComponent(0.08)
            leftCheekNode?.geometry?.materials = [normalCheekMat]
            rightCheekNode?.geometry?.materials = [normalCheekMat]
            NSCursor.arrow.set()
        }

        // MARK: - Laser Dot (Cat Toy)

        private func buildLaserDot(in scene: SCNScene) {
            // Red laser dot on the floor
            let dotGeo = SCNCylinder(radius: 0.06, height: 0.005)
            let dotMat = SCNMaterial()
            dotMat.diffuse.contents = NSColor.systemRed
            dotMat.emission.contents = NSColor.systemRed
            dotGeo.materials = [dotMat]
            let dot = SCNNode(geometry: dotGeo)
            dot.position = SCNVector3(0, 0.003, 0)
            dot.opacity = 0
            dot.name = "laserDot"
            scene.rootNode.addChildNode(dot)
            laserDotNode = dot

            // Glow ring around dot
            let glowGeo = SCNCylinder(radius: 0.12, height: 0.002)
            let glowMat = SCNMaterial()
            glowMat.diffuse.contents = NSColor.systemRed.withAlphaComponent(0.2)
            glowMat.emission.contents = NSColor.systemRed.withAlphaComponent(0.15)
            glowGeo.materials = [glowMat]
            let glow = SCNNode(geometry: glowGeo)
            glow.position = SCNVector3(0, 0.002, 0)
            glow.opacity = 0
            glow.name = "laserGlow"
            scene.rootNode.addChildNode(glow)
            laserGlowNode = glow

            // Pulsing animation for the glow
            let pulse = SCNAction.sequence([
                SCNAction.scale(to: 1.3, duration: 0.4),
                SCNAction.scale(to: 0.8, duration: 0.4)
            ])
            pulse.timingMode = .easeInEaseOut
            glow.runAction(.repeatForever(pulse))
        }

        private func moveLaserDot(to worldPos: SCNVector3) {
            guard let dot = laserDotNode, let glow = laserGlowNode else { return }

            // Clamp to room bounds
            let x = max(-1.0, min(1.0, CGFloat(worldPos.x)))
            let z = max(-0.5, min(1.0, CGFloat(worldPos.z)))

            let targetPos = SCNVector3(x, 0.003, z)
            let glowPos = SCNVector3(x, 0.002, z)

            dot.runAction(SCNAction.move(to: targetPos, duration: 0.05))
            glow.runAction(SCNAction.move(to: glowPos, duration: 0.05))

            // Show if hidden
            if dot.opacity < 0.5 {
                dot.runAction(SCNAction.fadeIn(duration: 0.15))
                glow.runAction(SCNAction.fadeIn(duration: 0.15))
            }
        }

        private func chaseLaserDot(target worldPos: SCNVector3) {
            guard let body = petBodyNode, !isChasing else { return }
            isChasing = true

            let x = max(-1.0, min(1.0, CGFloat(worldPos.x)))
            let z = max(-0.5, min(1.0, CGFloat(worldPos.z)))

            let currentPos = body.position
            let dx = x - CGFloat(currentPos.x)
            let dz = z - CGFloat(currentPos.z)
            let distance = sqrt(dx * dx + dz * dz)

            guard distance > 0.3 else {
                isChasing = false
                return
            }

            // Face the laser
            let angle = atan2(dx, dz) + (petCharacter.isVRM ? CGFloat.pi : 0)
            let faceAction = SCNAction.rotateTo(x: 0, y: angle, z: 0, duration: 0.15)

            // Run to laser (faster than walk)
            let runDuration = Double(distance) * 0.5
            let moveAction = SCNAction.moveBy(x: dx, y: 0, z: dz, duration: runDuration)
            moveAction.timingMode = .easeOut

            // Excited bouncing while running
            let bounceCount = max(1, Int(runDuration / 0.15))
            var bounces: [SCNAction] = []
            for _ in 0..<bounceCount {
                bounces.append(contentsOf: [
                    SCNAction.moveBy(x: 0, y: 0.08, z: 0, duration: 0.075),
                    SCNAction.moveBy(x: 0, y: -0.08, z: 0, duration: 0.075)
                ])
            }

            // Pounce at the end!
            let pounce = SCNAction.sequence([
                SCNAction.moveBy(x: 0, y: 0.25, z: 0, duration: 0.12),
                SCNAction.moveBy(x: 0, y: -0.25, z: 0, duration: 0.1),
                SCNAction.moveBy(x: 0, y: 0.08, z: 0, duration: 0.06),
                SCNAction.moveBy(x: 0, y: -0.08, z: 0, duration: 0.06)
            ])

            let faceCamera = SCNAction.rotateTo(x: 0, y: petCharacter.isVRM ? CGFloat.pi : 0, z: 0, duration: 0.3)

            let chase = SCNAction.sequence([
                faceAction,
                SCNAction.group([moveAction, SCNAction.sequence(bounces)]),
                pounce,
                faceCamera
            ])

            // Stop current behavior and chase
            body.removeAction(forKey: "behavior")
            body.runAction(chase, forKey: "chase") { [weak self] in
                self?.isChasing = false
                // Trigger play stat boost
                let now = Date()
                if now.timeIntervalSince(self?.lastPlayTime ?? .distantPast) > 3.0 {
                    self?.lastPlayTime = now
                    DispatchQueue.main.async {
                        self?.onPlay()
                    }
                }
                // Resume random behaviors after a pause
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    guard let self, let body = self.petBodyNode else { return }
                    self.startRandomBehaviors(body)
                }
            }

            // Arm animation — excited flailing
            leftArmNode?.runAction(SCNAction.sequence([
                SCNAction.rotateTo(x: -0.3, y: 0, z: CGFloat.pi * 0.5, duration: 0.15),
                SCNAction.wait(duration: runDuration),
                SCNAction.rotateTo(x: 0, y: 0, z: CGFloat.pi / 6, duration: 0.2)
            ]))
            rightArmNode?.runAction(SCNAction.sequence([
                SCNAction.rotateTo(x: -0.3, y: 0, z: -CGFloat.pi * 0.5, duration: 0.15),
                SCNAction.wait(duration: runDuration),
                SCNAction.rotateTo(x: 0, y: 0, z: -CGFloat.pi / 6, duration: 0.2)
            ]))

            // Fast tail wag while chasing
            tailNode?.removeAction(forKey: "tailWag")
            let chaseTailWag = SCNAction.sequence([
                SCNAction.rotateBy(x: 0, y: 0.5, z: 0.3, duration: 0.08),
                SCNAction.rotateBy(x: 0, y: -1.0, z: -0.6, duration: 0.16),
                SCNAction.rotateBy(x: 0, y: 0.5, z: 0.3, duration: 0.08)
            ])
            tailNode?.runAction(.repeatForever(chaseTailWag), forKey: "tailWag")
        }

        // MARK: - Fetch Ball Game

        private func throwBall(to worldPos: SCNVector3) {
            guard let ball = toyBallNode, let body = petBodyNode, !isChasing else { return }

            let x = max(-0.8, min(0.8, CGFloat(worldPos.x)))
            let z = max(-0.3, min(0.8, CGFloat(worldPos.z)))

            showSpeechBubble("fetch!")

            // Throw the ball there (arc trajectory)
            ball.runAction(SCNAction.sequence([
                SCNAction.group([
                    SCNAction.move(to: SCNVector3(x, 0.12, z), duration: 0.4),
                    SCNAction.sequence([
                        SCNAction.moveBy(x: 0, y: 0.5, z: 0, duration: 0.2),
                        SCNAction.moveBy(x: 0, y: -0.5, z: 0, duration: 0.2)
                    ]),
                    SCNAction.rotateBy(x: CGFloat.pi * 4, y: CGFloat.pi * 2, z: 0, duration: 0.4)
                ]),
                // Bounce
                SCNAction.moveBy(x: 0, y: 0.15, z: 0, duration: 0.1),
                SCNAction.moveBy(x: 0, y: -0.15, z: 0, duration: 0.1)
            ]))

            // Pet chases ball after a moment of excitement
            isChasing = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self else { return }

                let dx = x - CGFloat(body.position.x)
                let dz = z - CGFloat(body.position.z)
                let distance = sqrt(dx * dx + dz * dz)
                let angle = atan2(dx, dz) + (petCharacter.isVRM ? CGFloat.pi : 0)

                let chase = SCNAction.sequence([
                    SCNAction.rotateTo(x: 0, y: angle, z: 0, duration: 0.15),
                    SCNAction.moveBy(x: dx, y: 0, z: dz, duration: Double(distance) * 0.45),
                    // Pounce on ball
                    SCNAction.moveBy(x: 0, y: 0.2, z: 0, duration: 0.1),
                    SCNAction.moveBy(x: 0, y: -0.2, z: 0, duration: 0.08),
                    SCNAction.rotateTo(x: 0, y: petCharacter.isVRM ? CGFloat.pi : 0, z: 0, duration: 0.3)
                ])

                body.removeAction(forKey: "behavior")
                body.runAction(chase, forKey: "chase") { [weak self] in
                    self?.isChasing = false
                    self?.showSpeechBubble(["got it!", "woof!", "again!"].randomElement()!)

                    // Return ball to original spot
                    ball.runAction(SCNAction.move(to: SCNVector3(0.7, 0.12, 0.6), duration: 0.8))

                    let now = Date()
                    if now.timeIntervalSince(self?.lastPlayTime ?? .distantPast) > 2.0 {
                        self?.lastPlayTime = now
                        DispatchQueue.main.async { self?.onPlay() }
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        guard let self, let body = self.petBodyNode else { return }
                        self.startRandomBehaviors(body)
                    }
                }
            }
        }

        // MARK: - Yarn Play Game

        private func rollYarn(to worldPos: SCNVector3) {
            guard let yarn = yarnBallNode, let body = petBodyNode, !isChasing else { return }

            let x = max(-0.8, min(0.8, CGFloat(worldPos.x)))
            let z = max(-0.3, min(0.8, CGFloat(worldPos.z)))

            // Roll yarn to target
            yarn.runAction(SCNAction.group([
                SCNAction.move(to: SCNVector3(x, 0.1, z), duration: 0.5),
                SCNAction.rotateBy(x: CGFloat.pi * 6, y: 0, z: CGFloat.pi * 3, duration: 0.5)
            ]))

            isChasing = true

            // Pet stalks then pounces
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self else { return }

                let dx = x - CGFloat(body.position.x)
                let dz = z - CGFloat(body.position.z)
                let distance = sqrt(dx * dx + dz * dz)
                let angle = atan2(dx, dz) + (petCharacter.isVRM ? CGFloat.pi : 0)

                // Crouch down first (stalking)
                self.bodyMeshNode?.runAction(SCNAction.sequence([
                    SCNAction.rotateTo(x: 0.15, y: 0, z: 0, duration: 0.2),
                    SCNAction.wait(duration: 0.4),
                    SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.15)
                ]))

                // Butt wiggle before pounce
                self.tailNode?.removeAction(forKey: "tailWag")
                let fastWag = SCNAction.sequence([
                    SCNAction.rotateBy(x: 0, y: 0.5, z: 0.3, duration: 0.06),
                    SCNAction.rotateBy(x: 0, y: -1.0, z: -0.6, duration: 0.12),
                    SCNAction.rotateBy(x: 0, y: 0.5, z: 0.3, duration: 0.06)
                ])
                self.tailNode?.runAction(SCNAction.repeat(fastWag, count: 4))

                let stalkAndPounce = SCNAction.sequence([
                    SCNAction.rotateTo(x: 0, y: angle, z: 0, duration: 0.15),
                    SCNAction.wait(duration: 0.6), // stalking pause
                    // POUNCE!
                    SCNAction.group([
                        SCNAction.moveBy(x: dx, y: 0, z: dz, duration: Double(distance) * 0.3),
                        SCNAction.sequence([
                            SCNAction.moveBy(x: 0, y: 0.35, z: 0, duration: Double(distance) * 0.15),
                            SCNAction.moveBy(x: 0, y: -0.35, z: 0, duration: Double(distance) * 0.15)
                        ])
                    ]),
                    SCNAction.rotateTo(x: 0, y: petCharacter.isVRM ? CGFloat.pi : 0, z: 0, duration: 0.2)
                ])

                body.removeAction(forKey: "behavior")
                body.runAction(stalkAndPounce, forKey: "chase") { [weak self] in
                    self?.isChasing = false
                    self?.showSpeechBubble(["pounce!", "got ya!", "hehe!"].randomElement()!)
                    self?.startTailWag()

                    // Bat yarn around a bit
                    yarn.runAction(SCNAction.sequence([
                        SCNAction.moveBy(x: CGFloat.random(in: -0.3...0.3), y: 0, z: CGFloat.random(in: -0.2...0.2), duration: 0.2),
                        SCNAction.rotateBy(x: CGFloat.pi * 2, y: 0, z: 0, duration: 0.3)
                    ]))

                    let now = Date()
                    if now.timeIntervalSince(self?.lastPlayTime ?? .distantPast) > 2.0 {
                        self?.lastPlayTime = now
                        DispatchQueue.main.async { self?.onPlay() }
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        guard let self, let body = self.petBodyNode else { return }
                        self.startRandomBehaviors(body)
                    }
                }
            }
        }

        // MARK: - Heart Particles in 3D

        private func spawnHeartParticle(at position: SCNVector3) {
            guard let scene = sceneRef else { return }

            let heartGeo = SCNText(string: "\u{2764}\u{FE0F}", extrusionDepth: 0.02)
            heartGeo.font = NSFont.systemFont(ofSize: 0.15)
            heartGeo.flatness = 0.1
            let heartMat = SCNMaterial()
            heartMat.diffuse.contents = NSColor.systemPink
            heartMat.emission.contents = NSColor.systemPink.withAlphaComponent(0.5)
            heartGeo.materials = [heartMat]

            let heart = SCNNode(geometry: heartGeo)
            heart.position = SCNVector3(
                CGFloat(position.x) - 0.07,
                CGFloat(position.y) + 0.2,
                CGFloat(position.z)
            )
            heart.scale = SCNVector3(0.5, 0.5, 0.5)
            scene.rootNode.addChildNode(heart)

            // Float up and fade out
            let floatUp = SCNAction.moveBy(x: CGFloat.random(in: -0.2...0.2), y: 0.8, z: 0, duration: 1.0)
            floatUp.timingMode = .easeOut
            let fadeOut = SCNAction.fadeOut(duration: 0.8)
            let spin = SCNAction.rotateBy(x: 0, y: CGFloat.pi, z: 0, duration: 1.0)
            let group = SCNAction.group([floatUp, fadeOut, spin])

            heart.runAction(SCNAction.sequence([group, SCNAction.removeFromParentNode()]))
        }

        func buildScene(pet: UserDataStore.PetStateData, theme: WidgetTheme) -> SCNScene {
            let scene = SCNScene()
            let palette = ThemeResolver.palette(for: theme)

            // Camera
            let cameraNode = SCNNode()
            cameraNode.camera = SCNCamera()
            cameraNode.camera?.fieldOfView = 38
            cameraNode.camera?.zNear = 0.1
            cameraNode.camera?.zFar = 50
            cameraNode.position = SCNVector3(0, 1.5, 4.2)
            cameraNode.look(at: SCNVector3(0, 0.5, 0))
            scene.rootNode.addChildNode(cameraNode)

            // Lighting — intensity varies with time of day
            let isNight = PetPersonality.isSleepTime
            let hour = Calendar.current.component(.hour, from: Date())
            let isEvening = hour >= 18 && hour < 23
            let keyIntensity: CGFloat = isNight ? 150 : (isEvening ? 450 : 800)
            let fillIntensity: CGFloat = isNight ? 80 : (isEvening ? 160 : 250)
            let ambientIntensity: CGFloat = isNight ? 80 : (isEvening ? 180 : 300)
            let lightColor: NSColor = isNight ? NSColor(red: 0.4, green: 0.45, blue: 0.7, alpha: 1) :
                (isEvening ? NSColor(red: 1.0, green: 0.85, blue: 0.7, alpha: 1) : .white)

            let keyLight = SCNNode()
            keyLight.name = "keyLight"
            keyLight.light = SCNLight()
            keyLight.light?.type = .directional
            keyLight.light?.intensity = keyIntensity
            keyLight.light?.color = lightColor
            keyLight.light?.castsShadow = true
            keyLight.light?.shadowMode = .deferred
            keyLight.light?.shadowSampleCount = 8
            keyLight.light?.shadowRadius = 3
            keyLight.light?.shadowColor = NSColor.black.withAlphaComponent(isNight ? 0.5 : 0.3)
            keyLight.eulerAngles = SCNVector3(-CGFloat.pi / 3, CGFloat.pi / 5, 0)
            scene.rootNode.addChildNode(keyLight)

            let fillLight = SCNNode()
            fillLight.name = "fillLight"
            fillLight.light = SCNLight()
            fillLight.light?.type = .omni
            fillLight.light?.intensity = fillIntensity
            fillLight.light?.color = isNight ? NSColor(red: 0.3, green: 0.3, blue: 0.6, alpha: 0.4) : NSColor(palette.accent).withAlphaComponent(0.4)
            fillLight.position = SCNVector3(-2, 2, 2)
            scene.rootNode.addChildNode(fillLight)

            let ambient = SCNNode()
            ambient.name = "ambientLight"
            ambient.light = SCNLight()
            ambient.light?.type = .ambient
            ambient.light?.intensity = ambientIntensity
            ambient.light?.color = lightColor
            scene.rootNode.addChildNode(ambient)

            // Night glow light — soft warm light near the sleep mat, like a nightlight
            if isNight || isEvening {
                let nightlight = SCNNode()
                nightlight.name = "nightlight"
                nightlight.light = SCNLight()
                nightlight.light?.type = .omni
                nightlight.light?.intensity = isNight ? 120 : 60
                nightlight.light?.color = NSColor(red: 1.0, green: 0.9, blue: 0.6, alpha: 1)
                nightlight.light?.attenuationStartDistance = 0.5
                nightlight.light?.attenuationEndDistance = 3.0
                nightlight.position = SCNVector3(-0.5, 1.0, -0.2)
                scene.rootNode.addChildNode(nightlight)
            }

            // Pet character — pick builder based on character type
            let character = pet.character ?? .fluffy
            self.petCharacter = character
            let pers = character.personality

            // Room — character-specific
            buildRoom(in: scene, palette: palette, personality: pers)

            // Laser dot (cat toy)
            buildLaserDot(in: scene)
            let body = buildVRMPet(character: character, alive: pet.isAlive)
            scene.rootNode.addChildNode(body)
            petBodyNode = body
            sceneRef = scene

            // Animations
            if pet.isAlive {
                startIdleAnimations(body)
            } else {
                // Dead pose - fall over
                body.eulerAngles.z = CGFloat.pi / 2
                body.position.y = 0.25
                body.opacity = 0.5

                // Gray out
                body.enumerateChildNodes { node, _ in
                    if let mat = node.geometry?.firstMaterial {
                        mat.diffuse.contents = NSColor.gray
                    }
                }
            }

            return scene
        }

        private func buildRoom(in scene: SCNScene, palette: ThemePalette, personality pers: PetPersonality) {
            let accent = pers.wallTint
            let secondary = accent.blended(withFraction: 0.4, of: .white) ?? accent

            // Floor — character-specific tint
            let floor = SCNFloor()
            floor.reflectivity = 0.12
            floor.reflectionFalloffEnd = 2.5
            let floorMat = SCNMaterial()
            floorMat.diffuse.contents = pers.floorColor
            floorMat.roughness.contents = NSColor(white: 0.6, alpha: 1)
            floor.materials = [floorMat]
            let floorNode = SCNNode(geometry: floor)
            floorNode.name = "floor"
            scene.rootNode.addChildNode(floorNode)

            // Character-themed round rug
            let rugGeo = SCNCylinder(radius: 1.4, height: 0.01)
            let rugMat = SCNMaterial()
            rugMat.diffuse.contents = pers.rugColor
            rugGeo.materials = [rugMat]
            let rugNode = SCNNode(geometry: rugGeo)
            rugNode.position = SCNVector3(0, 0.005, 0.2)
            scene.rootNode.addChildNode(rugNode)

            // Rug border ring
            let rugBorderGeo = SCNTorus(ringRadius: 1.4, pipeRadius: 0.03)
            let rugBorderMat = SCNMaterial()
            rugBorderMat.diffuse.contents = (pers.rugColor.blended(withFraction: 0.3, of: .white) ?? pers.rugColor).withAlphaComponent(0.35)
            rugBorderGeo.materials = [rugBorderMat]
            let rugBorder = SCNNode(geometry: rugBorderGeo)
            rugBorder.position = SCNVector3(0, 0.015, 0.2)
            scene.rootNode.addChildNode(rugBorder)

            // Back wall — character-tinted pastel
            let wallGeo = SCNPlane(width: 6, height: 4)
            let wallMat = SCNMaterial()
            wallMat.diffuse.contents = pers.wallTint
            wallMat.isDoubleSided = true
            wallGeo.materials = [wallMat]
            let wall = SCNNode(geometry: wallGeo)
            wall.position = SCNVector3(0, 2, -2.5)
            scene.rootNode.addChildNode(wall)

            // Side walls
            let sideGeo = SCNPlane(width: 5, height: 4)
            let sideWallMat = SCNMaterial()
            sideWallMat.diffuse.contents = secondary.withAlphaComponent(0.05)
            sideWallMat.isDoubleSided = true
            sideGeo.materials = [sideWallMat]

            let leftWall = SCNNode(geometry: sideGeo)
            leftWall.position = SCNVector3(-3, 2, 0)
            leftWall.eulerAngles.y = CGFloat.pi / 2
            scene.rootNode.addChildNode(leftWall)

            let rightWall = SCNNode(geometry: sideGeo)
            rightWall.position = SCNVector3(3, 2, 0)
            rightWall.eulerAngles.y = -CGFloat.pi / 2
            scene.rootNode.addChildNode(rightWall)

            // --- Window on back wall ---
            let windowFrame = SCNBox(width: 1.2, height: 1.0, length: 0.05, chamferRadius: 0.04)
            let frameMat = SCNMaterial()
            frameMat.diffuse.contents = NSColor(white: 0.9, alpha: 1)
            windowFrame.materials = [frameMat]
            let windowNode = SCNNode(geometry: windowFrame)
            windowNode.position = SCNVector3(1.2, 2.2, -2.47)
            scene.rootNode.addChildNode(windowNode)

            // Window scene — varies by character personality
            buildWindowScene(pers.windowScene, in: scene)

            // --- Picture frame on back wall ---
            let picFrame = SCNBox(width: 0.7, height: 0.55, length: 0.03, chamferRadius: 0.02)
            let picFrameMat = SCNMaterial()
            picFrameMat.diffuse.contents = NSColor(red: 0.6, green: 0.4, blue: 0.2, alpha: 1)
            picFrame.materials = [picFrameMat]
            let picNode = SCNNode(geometry: picFrame)
            picNode.position = SCNVector3(-1.0, 2.3, -2.47)
            scene.rootNode.addChildNode(picNode)

            // Picture content — character accent
            let picContent = SCNPlane(width: 0.55, height: 0.4)
            let picContentMat = SCNMaterial()
            picContentMat.diffuse.contents = pers.accentColor.withAlphaComponent(0.3)
            picContent.materials = [picContentMat]
            let picContentNode = SCNNode(geometry: picContent)
            picContentNode.position = SCNVector3(-1.0, 2.3, -2.45)
            scene.rootNode.addChildNode(picContentNode)

            // Character emoji in the picture
            let heartGeo = SCNText(string: pers.roomAccent, extrusionDepth: 0.01)
            heartGeo.font = NSFont.systemFont(ofSize: 0.12)
            heartGeo.flatness = 0.1
            let heartMat = SCNMaterial()
            heartMat.diffuse.contents = pers.accentColor
            heartGeo.materials = [heartMat]
            let heartPicNode = SCNNode(geometry: heartGeo)
            heartPicNode.position = SCNVector3(-1.12, 2.2, -2.43)
            scene.rootNode.addChildNode(heartPicNode)

            // --- Shelf on wall ---
            let shelfGeo = SCNBox(width: 1.2, height: 0.05, length: 0.3, chamferRadius: 0.01)
            let shelfMat = SCNMaterial()
            shelfMat.diffuse.contents = NSColor(red: 0.65, green: 0.45, blue: 0.25, alpha: 1)
            shelfGeo.materials = [shelfMat]
            let shelfNode = SCNNode(geometry: shelfGeo)
            shelfNode.position = SCNVector3(-1.8, 1.5, -2.0)
            scene.rootNode.addChildNode(shelfNode)

            // Books on shelf — character-themed colors
            let bookColors = pers.shelfItemColors
            for (i, color) in bookColors.enumerated() {
                let bookGeo = SCNBox(width: 0.08, height: 0.25, length: 0.18, chamferRadius: 0.005)
                let bookMat = SCNMaterial()
                bookMat.diffuse.contents = color.withAlphaComponent(0.7)
                bookGeo.materials = [bookMat]
                let book = SCNNode(geometry: bookGeo)
                book.position = SCNVector3(
                    -2.15 + CGFloat(i) * 0.15,
                    1.65,
                    -2.0
                )
                book.eulerAngles.z = CGFloat.random(in: -0.05...0.05)
                scene.rootNode.addChildNode(book)
            }

            // --- Toy ball — character color ---
            let ball = SCNSphere(radius: 0.12)
            let ballMat = SCNMaterial()
            ballMat.diffuse.contents = pers.toyBallColor.withAlphaComponent(0.7)
            ballMat.metalness.contents = NSColor(white: 0.3, alpha: 1)
            ball.materials = [ballMat]
            let ballNode = SCNNode(geometry: ball)
            ballNode.position = SCNVector3(0.7, 0.12, 0.6)
            ballNode.name = "toyBall"
            scene.rootNode.addChildNode(ballNode)
            toyBallNode = ballNode

            // Ball stripe
            let stripeGeo = SCNTorus(ringRadius: 0.12, pipeRadius: 0.015)
            let stripeMat = SCNMaterial()
            stripeMat.diffuse.contents = NSColor.white.withAlphaComponent(0.6)
            stripeGeo.materials = [stripeMat]
            let stripe = SCNNode(geometry: stripeGeo)
            stripe.eulerAngles.x = CGFloat.pi / 2
            ballNode.addChildNode(stripe)

            // --- Yarn ball — character color ---
            let yarnGeo = SCNSphere(radius: 0.1)
            let yarnMat = SCNMaterial()
            yarnMat.diffuse.contents = pers.yarnColor
            yarnMat.roughness.contents = NSColor(white: 0.8, alpha: 1)
            yarnGeo.materials = [yarnMat]
            let yarnNode = SCNNode(geometry: yarnGeo)
            yarnNode.position = SCNVector3(-0.6, 0.1, 1.0)
            yarnNode.name = "yarnBall"
            scene.rootNode.addChildNode(yarnNode)
            yarnBallNode = yarnNode

            // Yarn string trailing
            let stringGeo = SCNCylinder(radius: 0.008, height: 0.4)
            let stringMat = SCNMaterial()
            stringMat.diffuse.contents = pers.yarnColor.withAlphaComponent(0.5)
            stringGeo.materials = [stringMat]
            let stringNode = SCNNode(geometry: stringGeo)
            stringNode.position = SCNVector3(0, -0.05, 0.05)
            stringNode.eulerAngles.z = CGFloat.pi / 3
            yarnNode.addChildNode(stringNode)

            // --- Cushion / pet bed — character color ---
            let cushGeo = SCNCylinder(radius: 0.35, height: 0.08)
            let cushMat = SCNMaterial()
            cushMat.diffuse.contents = pers.cushionColor
            cushMat.roughness.contents = NSColor(white: 0.8, alpha: 1)
            cushGeo.materials = [cushMat]
            let cushNode = SCNNode(geometry: cushGeo)
            cushNode.position = SCNVector3(0.6, 0.04, -0.2)
            cushNode.name = "cushion"
            scene.rootNode.addChildNode(cushNode)
            cushionNode = cushNode

            // Cushion inner circle
            let cushInner = SCNCylinder(radius: 0.25, height: 0.09)
            let cushInnerMat = SCNMaterial()
            cushInnerMat.diffuse.contents = pers.cushionColor.blended(withFraction: 0.3, of: .white)?.withAlphaComponent(0.35) ?? pers.cushionColor
            cushInner.materials = [cushInnerMat]
            let cushInnerNode = SCNNode(geometry: cushInner)
            cushInnerNode.position = SCNVector3(0, 0.01, 0)
            cushNode.addChildNode(cushInnerNode)

            // --- Small plant (topple-able) ---
            // Pot
            let potGeo = SCNCylinder(radius: 0.1, height: 0.15)
            let potMat = SCNMaterial()
            potMat.diffuse.contents = NSColor(red: 0.75, green: 0.45, blue: 0.3, alpha: 1)
            potGeo.materials = [potMat]
            let potNode = SCNNode(geometry: potGeo)
            potNode.position = SCNVector3(-1.6, 0.075, 0.3)
            potNode.name = "plant"
            scene.rootNode.addChildNode(potNode)
            plantNode = potNode

            // Plant leaves (stacked spheres)
            let leafColors: [NSColor] = [
                NSColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 0.8),
                NSColor(red: 0.25, green: 0.65, blue: 0.35, alpha: 0.7),
                NSColor(red: 0.3, green: 0.75, blue: 0.3, alpha: 0.75)
            ]
            for (i, leafColor) in leafColors.enumerated() {
                let leafGeo = SCNSphere(radius: 0.08 + CGFloat(i) * 0.02)
                let leafMat = SCNMaterial()
                leafMat.diffuse.contents = leafColor
                leafGeo.materials = [leafMat]
                let leaf = SCNNode(geometry: leafGeo)
                leaf.position = SCNVector3(
                    CGFloat.random(in: -0.03...0.03),
                    0.1 + CGFloat(i) * 0.06,
                    CGFloat.random(in: -0.03...0.03)
                )
                potNode.addChildNode(leaf)
            }

            // --- Food bowl ---
            let bowl = SCNTorus(ringRadius: 0.18, pipeRadius: 0.06)
            let bowlMat = SCNMaterial()
            bowlMat.diffuse.contents = NSColor.systemOrange.withAlphaComponent(0.5)
            bowl.materials = [bowlMat]
            let bowlNode = SCNNode(geometry: bowl)
            bowlNode.position = SCNVector3(-1.0, 0.06, 0.8)
            bowlNode.name = "foodBowl"
            scene.rootNode.addChildNode(bowlNode)

            // Food dots in bowl
            for _ in 0..<4 {
                let kibble = SCNSphere(radius: 0.025)
                let kibbleMat = SCNMaterial()
                kibbleMat.diffuse.contents = NSColor(red: 0.6, green: 0.4, blue: 0.2, alpha: 1)
                kibble.materials = [kibbleMat]
                let kibbleNode = SCNNode(geometry: kibble)
                kibbleNode.position = SCNVector3(
                    CGFloat.random(in: -0.08...0.08),
                    0.04,
                    CGFloat.random(in: -0.08...0.08)
                )
                bowlNode.addChildNode(kibbleNode)
            }

            // --- Book stack on floor (topple-able) ---
            let stackNode = SCNNode()
            stackNode.position = SCNVector3(0.8, 0, -1.0)
            stackNode.name = "bookStack"
            let stackColors: [NSColor] = [.systemTeal, .systemIndigo, .systemOrange]
            for (i, color) in stackColors.enumerated() {
                let bGeo = SCNBox(width: 0.3, height: 0.06, length: 0.22, chamferRadius: 0.008)
                let bMat = SCNMaterial()
                bMat.diffuse.contents = color.withAlphaComponent(0.6)
                bGeo.materials = [bMat]
                let bNode = SCNNode(geometry: bGeo)
                bNode.position = SCNVector3(
                    CGFloat.random(in: -0.02...0.02),
                    0.03 + CGFloat(i) * 0.065,
                    0
                )
                bNode.eulerAngles.y = CGFloat(i) * 0.15
                stackNode.addChildNode(bNode)
            }
            scene.rootNode.addChildNode(stackNode)
            bookStackNode = stackNode

            // --- Sleep mat — character's favorite spot ---
            let matGeo = SCNBox(width: 0.7, height: 0.02, length: 0.5, chamferRadius: 0.15)
            let matMat = SCNMaterial()
            matMat.diffuse.contents = pers.matColor
            matMat.roughness.contents = NSColor(white: 0.9, alpha: 1)
            matGeo.materials = [matMat]
            let matNode = SCNNode(geometry: matGeo)
            matNode.position = SCNVector3(-0.5, 0.01, -0.3)
            matNode.name = "sleepMat"
            scene.rootNode.addChildNode(matNode)
            sleepMatNode = matNode

            // Mat pattern — render the emoji as a texture
            let emojiPlane = SCNPlane(width: 0.15, height: 0.15)
            let emojiMat = SCNMaterial()
            let emojiImg = NSImage(size: NSSize(width: 64, height: 64), flipped: false) { rect in
                let font = NSFont.systemFont(ofSize: 48)
                let str = NSAttributedString(string: pers.matEmoji, attributes: [.font: font])
                str.draw(at: NSPoint(x: 4, y: 4))
                return true
            }
            emojiMat.diffuse.contents = emojiImg
            emojiMat.lightingModel = .constant
            emojiMat.transparencyMode = .aOne
            emojiMat.isDoubleSided = true
            emojiPlane.materials = [emojiMat]
            let emojiNode = SCNNode(geometry: emojiPlane)
            emojiNode.eulerAngles.x = -CGFloat.pi / 2
            emojiNode.position = SCNVector3(0, 0.015, 0)
            matNode.addChildNode(emojiNode)

            // Pillow on the mat
            let pillowGeo = SCNBox(width: 0.2, height: 0.06, length: 0.15, chamferRadius: 0.06)
            let pillowMat = SCNMaterial()
            pillowMat.diffuse.contents = pers.matColor.blended(withFraction: 0.4, of: .white) ?? pers.matColor
            pillowMat.roughness.contents = NSColor(white: 0.85, alpha: 1)
            pillowGeo.materials = [pillowMat]
            let pillowNode = SCNNode(geometry: pillowGeo)
            pillowNode.position = SCNVector3(0, 0.04, -0.15)
            pillowNode.eulerAngles.y = 0.1
            matNode.addChildNode(pillowNode)

            // --- Small side table with lamp ---
            let tableGeo = SCNBox(width: 0.3, height: 0.5, length: 0.3, chamferRadius: 0.02)
            let tableMat = SCNMaterial()
            tableMat.diffuse.contents = NSColor(red: 0.55, green: 0.38, blue: 0.22, alpha: 1)
            tableGeo.materials = [tableMat]
            let tableNode = SCNNode(geometry: tableGeo)
            tableNode.position = SCNVector3(1.8, 0.25, -1.2)
            scene.rootNode.addChildNode(tableNode)

            // Lamp on the table
            let lampBaseGeo = SCNCylinder(radius: 0.06, height: 0.04)
            let lampBaseMat = SCNMaterial()
            lampBaseMat.diffuse.contents = NSColor(white: 0.3, alpha: 1)
            lampBaseMat.metalness.contents = NSColor(white: 0.7, alpha: 1)
            lampBaseGeo.materials = [lampBaseMat]
            let lampBase = SCNNode(geometry: lampBaseGeo)
            lampBase.position = SCNVector3(1.8, 0.52, -1.2)
            scene.rootNode.addChildNode(lampBase)

            let lampPoleGeo = SCNCylinder(radius: 0.012, height: 0.25)
            let lampPoleMat = SCNMaterial()
            lampPoleMat.diffuse.contents = NSColor(white: 0.4, alpha: 1)
            lampPoleMat.metalness.contents = NSColor(white: 0.6, alpha: 1)
            lampPoleGeo.materials = [lampPoleMat]
            let lampPole = SCNNode(geometry: lampPoleGeo)
            lampPole.position = SCNVector3(1.8, 0.66, -1.2)
            scene.rootNode.addChildNode(lampPole)

            let lampShadeGeo = SCNCone(topRadius: 0.04, bottomRadius: 0.1, height: 0.12)
            let lampShadeMat = SCNMaterial()
            lampShadeMat.diffuse.contents = pers.accentColor.withAlphaComponent(0.4)
            lampShadeMat.emission.contents = pers.accentColor.withAlphaComponent(0.15)
            lampShadeGeo.materials = [lampShadeMat]
            let lampShade = SCNNode(geometry: lampShadeGeo)
            lampShade.position = SCNVector3(1.8, 0.82, -1.2)
            scene.rootNode.addChildNode(lampShade)

            // --- Wall clock (back wall, right side) ---
            let clockFace = SCNCylinder(radius: 0.2, height: 0.03)
            let clockFaceMat = SCNMaterial()
            clockFaceMat.diffuse.contents = NSColor.white
            clockFace.materials = [clockFaceMat]
            let clockNode = SCNNode(geometry: clockFace)
            clockNode.position = SCNVector3(0.0, 2.6, -2.47)
            clockNode.eulerAngles.x = CGFloat.pi / 2
            scene.rootNode.addChildNode(clockNode)

            // Clock frame ring
            let clockRingGeo = SCNTorus(ringRadius: 0.2, pipeRadius: 0.015)
            let clockRingMat = SCNMaterial()
            clockRingMat.diffuse.contents = NSColor(red: 0.5, green: 0.35, blue: 0.2, alpha: 1)
            clockRingGeo.materials = [clockRingMat]
            let clockRing = SCNNode(geometry: clockRingGeo)
            clockRing.position = SCNVector3(0.0, 2.6, -2.46)
            clockRing.eulerAngles.x = CGFloat.pi / 2
            scene.rootNode.addChildNode(clockRing)

            // Clock hands
            let hourHandGeo = SCNBox(width: 0.015, height: 0.1, length: 0.005, chamferRadius: 0.002)
            let handMat = SCNMaterial()
            handMat.diffuse.contents = NSColor.black
            hourHandGeo.materials = [handMat]
            let hourHand = SCNNode(geometry: hourHandGeo)
            hourHand.pivot = SCNMatrix4MakeTranslation(0, -0.04, 0)
            hourHand.position = SCNVector3(0.0, 2.6, -2.44)
            let hour = Calendar.current.component(.hour, from: Date())
            hourHand.eulerAngles.z = -CGFloat(hour % 12) * CGFloat.pi / 6
            scene.rootNode.addChildNode(hourHand)

            let minHandGeo = SCNBox(width: 0.01, height: 0.14, length: 0.005, chamferRadius: 0.002)
            minHandGeo.materials = [handMat]
            let minHand = SCNNode(geometry: minHandGeo)
            minHand.pivot = SCNMatrix4MakeTranslation(0, -0.05, 0)
            minHand.position = SCNVector3(0.0, 2.6, -2.43)
            let minute = Calendar.current.component(.minute, from: Date())
            minHand.eulerAngles.z = -CGFloat(minute) * CGFloat.pi / 30
            scene.rootNode.addChildNode(minHand)

            // --- Bunting / garland on back wall ---
            let buntingColors: [NSColor] = [pers.accentColor, pers.bodyColor, .systemYellow, pers.toyBallColor, .systemPink]
            for (i, color) in buntingColors.enumerated() {
                let flagGeo = SCNBox(width: 0.08, height: 0.1, length: 0.005, chamferRadius: 0.005)
                let flagMat = SCNMaterial()
                flagMat.diffuse.contents = color.withAlphaComponent(0.5)
                flagMat.isDoubleSided = true
                flagGeo.materials = [flagMat]
                let flagNode = SCNNode(geometry: flagGeo)
                let xPos = -1.8 + CGFloat(i) * 0.22
                let sag = abs(CGFloat(i) - 2.0) * 0.04 // slight sag in middle
                flagNode.position = SCNVector3(xPos, 3.1 - sag, -2.46)
                flagNode.eulerAngles.z = CGFloat.random(in: -0.1...0.1)
                scene.rootNode.addChildNode(flagNode)
            }

            // Bunting string
            let buntingStringGeo = SCNCylinder(radius: 0.004, height: 1.1)
            let buntingStringMat = SCNMaterial()
            buntingStringMat.diffuse.contents = NSColor(white: 0.6, alpha: 0.6)
            buntingStringGeo.materials = [buntingStringMat]
            let buntingString = SCNNode(geometry: buntingStringGeo)
            buntingString.position = SCNVector3(-0.9, 3.12, -2.47)
            buntingString.eulerAngles.z = CGFloat.pi / 2
            scene.rootNode.addChildNode(buntingString)

            // --- Small mirror on right wall ---
            let mirrorFrameGeo = SCNBox(width: 0.04, height: 0.5, length: 0.35, chamferRadius: 0.02)
            let mirrorFrameMat = SCNMaterial()
            mirrorFrameMat.diffuse.contents = NSColor(red: 0.7, green: 0.5, blue: 0.3, alpha: 1)
            mirrorFrameGeo.materials = [mirrorFrameMat]
            let mirrorFrame = SCNNode(geometry: mirrorFrameGeo)
            mirrorFrame.position = SCNVector3(2.97, 2.0, -0.5)
            scene.rootNode.addChildNode(mirrorFrame)

            let mirrorGlassGeo = SCNBox(width: 0.01, height: 0.42, length: 0.27, chamferRadius: 0.01)
            let mirrorGlassMat = SCNMaterial()
            mirrorGlassMat.diffuse.contents = NSColor(red: 0.8, green: 0.85, blue: 0.9, alpha: 0.6)
            mirrorGlassMat.metalness.contents = NSColor(white: 0.9, alpha: 1)
            mirrorGlassMat.reflective.contents = NSColor(white: 0.4, alpha: 1)
            mirrorGlassGeo.materials = [mirrorGlassMat]
            let mirrorGlass = SCNNode(geometry: mirrorGlassGeo)
            mirrorGlass.position = SCNVector3(2.96, 2.0, -0.5)
            scene.rootNode.addChildNode(mirrorGlass)

            // --- Water bowl next to food bowl ---
            let waterBowl = SCNTorus(ringRadius: 0.14, pipeRadius: 0.04)
            let waterBowlMat = SCNMaterial()
            waterBowlMat.diffuse.contents = NSColor.systemBlue.withAlphaComponent(0.4)
            waterBowl.materials = [waterBowlMat]
            let waterBowlNode = SCNNode(geometry: waterBowl)
            waterBowlNode.position = SCNVector3(-0.65, 0.04, 0.9)
            waterBowlNode.name = "waterBowl"
            scene.rootNode.addChildNode(waterBowlNode)

            // Water surface
            let waterSurface = SCNCylinder(radius: 0.12, height: 0.01)
            let waterSurfMat = SCNMaterial()
            waterSurfMat.diffuse.contents = NSColor(red: 0.5, green: 0.7, blue: 0.95, alpha: 0.5)
            waterSurfMat.metalness.contents = NSColor(white: 0.3, alpha: 1)
            waterSurface.materials = [waterSurfMat]
            let waterNode = SCNNode(geometry: waterSurface)
            waterNode.position = SCNVector3(-0.65, 0.05, 0.9)
            scene.rootNode.addChildNode(waterNode)

            // --- Tiny rug pattern — concentric ring accent on the round rug ---
            let rugPattern = SCNTorus(ringRadius: 0.8, pipeRadius: 0.015)
            let rugPatternMat = SCNMaterial()
            rugPatternMat.diffuse.contents = pers.accentColor.withAlphaComponent(0.2)
            rugPattern.materials = [rugPatternMat]
            let rugPatternNode = SCNNode(geometry: rugPattern)
            rugPatternNode.position = SCNVector3(0, 0.012, 0.2)
            scene.rootNode.addChildNode(rugPatternNode)

            // --- Small star mobile hanging from ceiling ---
            let mobileRod = SCNCylinder(radius: 0.01, height: 0.6)
            let rodMat = SCNMaterial()
            rodMat.diffuse.contents = NSColor(white: 0.8, alpha: 1)
            mobileRod.materials = [rodMat]
            let rodNode = SCNNode(geometry: mobileRod)
            rodNode.position = SCNVector3(0, 3.2, -1.0)
            scene.rootNode.addChildNode(rodNode)

            // Hanging stars — use personality accent
            let mobileColors: [NSColor] = [.systemYellow, pers.accentColor, pers.bodyColor, .systemCyan]
            for (i, color) in mobileColors.enumerated() {
                let starShape = SCNSphere(radius: 0.06)
                let sMat = SCNMaterial()
                sMat.diffuse.contents = color.withAlphaComponent(0.6)
                sMat.emission.contents = color.withAlphaComponent(0.2)
                starShape.materials = [sMat]
                let sNode = SCNNode(geometry: starShape)
                let angleOffset = CGFloat(i) * CGFloat.pi / 2
                sNode.position = SCNVector3(
                    sin(angleOffset) * 0.25,
                    2.85,
                    -1.0 + cos(angleOffset) * 0.25
                )
                scene.rootNode.addChildNode(sNode)

                // Thread connecting to rod
                let threadGeo = SCNCylinder(radius: 0.003, height: 0.35)
                let threadMat = SCNMaterial()
                threadMat.diffuse.contents = NSColor(white: 0.7, alpha: 0.5)
                threadGeo.materials = [threadMat]
                let thread = SCNNode(geometry: threadGeo)
                thread.position = SCNVector3(
                    sin(angleOffset) * 0.25,
                    3.02,
                    -1.0 + cos(angleOffset) * 0.25
                )
                scene.rootNode.addChildNode(thread)

                // Gentle swinging
                let swing = SCNAction.sequence([
                    SCNAction.moveBy(x: CGFloat.random(in: -0.05...0.05), y: 0, z: CGFloat.random(in: -0.05...0.05), duration: Double.random(in: 2...4)),
                    SCNAction.moveBy(x: CGFloat.random(in: -0.05...0.05), y: 0, z: CGFloat.random(in: -0.05...0.05), duration: Double.random(in: 2...4))
                ])
                swing.timingMode = .easeInEaseOut
                sNode.runAction(.repeatForever(swing))
            }
        }

        // MARK: - Window Scene Variants

        private func buildWindowScene(_ scene: PetPersonality.WindowScene, in scnScene: SCNScene) {
            let skyGeo = SCNPlane(width: 1.0, height: 0.8)
            let skyMat = SCNMaterial()
            let skyNode = SCNNode(geometry: skyGeo)
            skyNode.position = SCNVector3(1.2, 2.2, -2.44)

            switch scene {
            case .nightSky:
                skyMat.diffuse.contents = NSColor(red: 0.1, green: 0.1, blue: 0.25, alpha: 1.0)
                skyMat.emission.contents = NSColor(red: 0.05, green: 0.05, blue: 0.15, alpha: 1.0)
                skyGeo.materials = [skyMat]
                scnScene.rootNode.addChildNode(skyNode)
                // Stars
                for _ in 0..<8 {
                    let starGeo = SCNSphere(radius: 0.02)
                    let starMat = SCNMaterial()
                    starMat.diffuse.contents = NSColor.white
                    starMat.emission.contents = NSColor(white: 1, alpha: 0.8)
                    starGeo.materials = [starMat]
                    let star = SCNNode(geometry: starGeo)
                    star.position = SCNVector3(
                        1.2 + CGFloat.random(in: -0.4...0.4),
                        2.2 + CGFloat.random(in: -0.3...0.3),
                        -2.43
                    )
                    scnScene.rootNode.addChildNode(star)
                    let twinkle = SCNAction.sequence([
                        SCNAction.fadeOpacity(to: 0.3, duration: Double.random(in: 0.5...1.5)),
                        SCNAction.fadeOpacity(to: 1.0, duration: Double.random(in: 0.5...1.5))
                    ])
                    star.runAction(.repeatForever(twinkle))
                }

            case .sunset:
                skyMat.diffuse.contents = NSColor(red: 0.95, green: 0.6, blue: 0.3, alpha: 1.0)
                skyMat.emission.contents = NSColor(red: 0.8, green: 0.45, blue: 0.2, alpha: 0.5)
                skyGeo.materials = [skyMat]
                scnScene.rootNode.addChildNode(skyNode)
                // Sun disc
                let sunGeo = SCNSphere(radius: 0.12)
                let sunMat = SCNMaterial()
                sunMat.diffuse.contents = NSColor(red: 1.0, green: 0.85, blue: 0.4, alpha: 1)
                sunMat.emission.contents = NSColor(red: 1.0, green: 0.8, blue: 0.3, alpha: 0.8)
                sunGeo.materials = [sunMat]
                let sun = SCNNode(geometry: sunGeo)
                sun.position = SCNVector3(1.2, 2.35, -2.43)
                scnScene.rootNode.addChildNode(sun)
                // Warm glow pulse
                let glow = SCNAction.sequence([
                    SCNAction.scale(to: 1.1, duration: 2),
                    SCNAction.scale(to: 1.0, duration: 2)
                ])
                sun.runAction(.repeatForever(glow))

            case .garden:
                skyMat.diffuse.contents = NSColor(red: 0.55, green: 0.82, blue: 0.95, alpha: 1.0)
                skyMat.emission.contents = NSColor(red: 0.4, green: 0.7, blue: 0.85, alpha: 0.3)
                skyGeo.materials = [skyMat]
                scnScene.rootNode.addChildNode(skyNode)
                // Little flowers/leaves
                let gardenEmojis = ["🌿", "🌸", "🌻", "🍃"]
                for (i, emoji) in gardenEmojis.enumerated() {
                    let textGeo = SCNText(string: emoji, extrusionDepth: 0.005)
                    textGeo.font = NSFont.systemFont(ofSize: 0.08)
                    textGeo.flatness = 0.1
                    let textMat = SCNMaterial()
                    textMat.diffuse.contents = NSColor.white
                    textGeo.materials = [textMat]
                    let node = SCNNode(geometry: textGeo)
                    node.position = SCNVector3(
                        0.9 + CGFloat(i % 2) * 0.35,
                        2.0 + CGFloat(i / 2) * 0.2,
                        -2.43
                    )
                    scnScene.rootNode.addChildNode(node)
                }

            case .ocean:
                skyMat.diffuse.contents = NSColor(red: 0.15, green: 0.4, blue: 0.7, alpha: 1.0)
                skyMat.emission.contents = NSColor(red: 0.1, green: 0.3, blue: 0.5, alpha: 0.4)
                skyGeo.materials = [skyMat]
                scnScene.rootNode.addChildNode(skyNode)
                // Waves (small animated bars)
                for i in 0..<3 {
                    let waveGeo = SCNCylinder(radius: 0.4, height: 0.015)
                    let waveMat = SCNMaterial()
                    waveMat.diffuse.contents = NSColor(red: 0.3, green: 0.6, blue: 0.9, alpha: 0.4)
                    waveGeo.materials = [waveMat]
                    let wave = SCNNode(geometry: waveGeo)
                    wave.position = SCNVector3(1.2, 1.95 + CGFloat(i) * 0.12, -2.43)
                    wave.eulerAngles.z = CGFloat.pi / 2
                    scnScene.rootNode.addChildNode(wave)
                    let bob = SCNAction.sequence([
                        SCNAction.moveBy(x: 0, y: 0.03, z: 0, duration: 1.5 + Double(i) * 0.3),
                        SCNAction.moveBy(x: 0, y: -0.03, z: 0, duration: 1.5 + Double(i) * 0.3)
                    ])
                    bob.timingMode = .easeInEaseOut
                    wave.runAction(.repeatForever(bob))
                }

            case .aurora:
                skyMat.diffuse.contents = NSColor(red: 0.08, green: 0.08, blue: 0.2, alpha: 1.0)
                skyMat.emission.contents = NSColor(red: 0.05, green: 0.05, blue: 0.15, alpha: 0.5)
                skyGeo.materials = [skyMat]
                scnScene.rootNode.addChildNode(skyNode)
                // Aurora bands
                let auroraColors: [NSColor] = [
                    NSColor(red: 0.2, green: 0.8, blue: 0.5, alpha: 0.3),
                    NSColor(red: 0.4, green: 0.6, blue: 0.9, alpha: 0.25),
                    NSColor(red: 0.7, green: 0.3, blue: 0.8, alpha: 0.2)
                ]
                for (i, color) in auroraColors.enumerated() {
                    let bandGeo = SCNCylinder(radius: 0.35, height: 0.02)
                    let bandMat = SCNMaterial()
                    bandMat.diffuse.contents = color
                    bandMat.emission.contents = color.withAlphaComponent(0.4)
                    bandGeo.materials = [bandMat]
                    let band = SCNNode(geometry: bandGeo)
                    band.position = SCNVector3(1.2, 2.3 + CGFloat(i) * 0.1, -2.43)
                    band.eulerAngles.z = CGFloat.pi / 2
                    scnScene.rootNode.addChildNode(band)
                    let shimmer = SCNAction.sequence([
                        SCNAction.fadeOpacity(to: 0.4, duration: 2.0 + Double(i) * 0.5),
                        SCNAction.fadeOpacity(to: 0.8, duration: 2.0 + Double(i) * 0.5)
                    ])
                    band.runAction(.repeatForever(shimmer))
                }
                // A few stars too
                for _ in 0..<5 {
                    let starGeo = SCNSphere(radius: 0.015)
                    let starMat = SCNMaterial()
                    starMat.diffuse.contents = NSColor.white
                    starMat.emission.contents = NSColor(white: 1, alpha: 0.7)
                    starGeo.materials = [starMat]
                    let star = SCNNode(geometry: starGeo)
                    star.position = SCNVector3(
                        1.2 + CGFloat.random(in: -0.4...0.4),
                        2.2 + CGFloat.random(in: -0.3...0.3),
                        -2.42
                    )
                    scnScene.rootNode.addChildNode(star)
                }
            }
        }


        // MARK: - VRM Character Builder

        /// Load a VRM (glTF binary) avatar model from bundled resources.
        private func buildVRMPet(character: UserDataStore.PetCharacter, alive: Bool) -> SCNNode {
            let root = SCNNode()
            root.name = "vrm_root"
            root.position = SCNVector3(0, 0, 0)

            let fileName = character.vrmFileName
            guard let url = Bundle.main.url(forResource: fileName, withExtension: "vrm") else {
                let fallback = SCNSphere(radius: 0.4)
                let mat = SCNMaterial()
                mat.diffuse.contents = character.personality.bodyColor
                mat.roughness.contents = NSColor(white: 0.7, alpha: 1)
                fallback.materials = [mat]
                let node = SCNNode(geometry: fallback)
                node.position = SCNVector3(0, 0.5, 0)
                root.addChildNode(node)
                bodyMeshNode = node
                return root
            }

            do {
                let result = try GLBLoader.loadFull(from: url)
                let vrmNode = result.rootNode

                // Store bone references for skeletal animation
                vrmBones = result.bones
                vrmMorpherNode = result.morpherNode
                vrmBlendShapeMap = result.blendShapeMap

                // Normalize the model size to fit comfortably in our room (~1.1 units tall)
                let (minBound, maxBound) = vrmNode.boundingBox
                let modelHeight = CGFloat(maxBound.y - minBound.y)
                let modelWidth = CGFloat(maxBound.x - minBound.x)
                let maxDimension = max(modelHeight, modelWidth)
                let targetHeight: CGFloat = 1.1
                let scaleFactor = maxDimension > 0 ? Float(targetHeight / maxDimension) : 1.0
                vrmNode.scale = SCNVector3(scaleFactor, scaleFactor, scaleFactor)

                // Center horizontally, place feet on ground
                let centerX = Float(minBound.x + maxBound.x) / 2.0
                let bottomY = Float(minBound.y)
                vrmNode.position = SCNVector3(
                    CGFloat(-centerX * scaleFactor),
                    CGFloat(-bottomY * scaleFactor + 0.05),
                    0
                )

                root.addChildNode(vrmNode)
                bodyMeshNode = vrmNode

                // Set head bone for look-around animations
                headNode = headBoneVRM ?? neckBone ?? vrmNode

                // Set limb node references for existing animation code paths
                leftArmNode = leftUpperArmBone
                rightArmNode = rightUpperArmBone
                leftFootNode = leftFootBone
                rightFootNode = rightFootBone

                // Apply natural rest pose (break T-pose)
                applyVRMRestPose()

                // Start blend shape blinking
                startVRMBlinking()

            } catch {
                print("⚠️ Failed to load VRM model '\(fileName)': \(error.localizedDescription)")
                let fallback = SCNSphere(radius: 0.4)
                let mat = SCNMaterial()
                mat.diffuse.contents = character.personality.bodyColor
                mat.roughness.contents = NSColor(white: 0.7, alpha: 1)
                fallback.materials = [mat]
                let node = SCNNode(geometry: fallback)
                node.position = SCNVector3(0, 0.5, 0)
                root.addChildNode(node)
                bodyMeshNode = node
            }

            return root
        }

        /// Apply a natural idle pose to VRM skeleton (arms at sides, not T-pose).
        private func applyVRMRestPose() {
            // Rotate arms down from T-pose (~75 degrees)
            leftUpperArmBone?.simdEulerAngles = SIMD3(0, 0, Float.pi * 0.42)
            rightUpperArmBone?.simdEulerAngles = SIMD3(0, 0, -Float.pi * 0.42)

            // Slight bend at elbows for natural look
            leftForeArmBone?.simdEulerAngles = SIMD3(0, 0, Float.pi * 0.06)
            rightForeArmBone?.simdEulerAngles = SIMD3(0, 0, -Float.pi * 0.06)

            // Slight forward lean for cute posture
            spine1Bone?.simdEulerAngles = SIMD3(Float.pi * 0.015, 0, 0)

            // Slight head tilt for charm
            headBoneVRM?.simdEulerAngles = SIMD3(-Float.pi * 0.02, 0, 0)
        }

        /// Periodic blink using VRM blend shapes.
        private func startVRMBlinking() {
            guard !vrmBlendShapeMap.isEmpty else { return }
            Timer.scheduledTimer(withTimeInterval: Double.random(in: 3.0...5.5), repeats: true) { [weak self] timer in
                guard let self, let morpher = self.vrmMorpherNode?.morpher else {
                    timer.invalidate()
                    return
                }
                guard let blinkIdx = self.vrmBlendShapeMap["Blink"] else { return }
                // Double-blink sometimes
                let doDouble = Bool.random() && Bool.random()
                DispatchQueue.main.async {
                    SCNTransaction.begin()
                    SCNTransaction.animationDuration = 0.06
                    morpher.setWeight(1.0, forTargetAt: blinkIdx)
                    SCNTransaction.commit()

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        SCNTransaction.begin()
                        SCNTransaction.animationDuration = 0.06
                        morpher.setWeight(0, forTargetAt: blinkIdx)
                        SCNTransaction.commit()

                        if doDouble {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                                SCNTransaction.begin()
                                SCNTransaction.animationDuration = 0.06
                                morpher.setWeight(1.0, forTargetAt: blinkIdx)
                                SCNTransaction.commit()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    SCNTransaction.begin()
                                    SCNTransaction.animationDuration = 0.06
                                    morpher.setWeight(0, forTargetAt: blinkIdx)
                                    SCNTransaction.commit()
                                }
                            }
                        }
                    }
                }
            }
        }

        /// Set a named VRM blend shape weight with animation.
        private func setVRMBlendShape(_ name: String, weight: CGFloat, duration: TimeInterval = 0.2) {
            guard let morpher = vrmMorpherNode?.morpher,
                  let index = vrmBlendShapeMap[name] else { return }
            SCNTransaction.begin()
            SCNTransaction.animationDuration = duration
            morpher.setWeight(weight, forTargetAt: index)
            SCNTransaction.commit()
        }

        // MARK: - Animations

        private func startIdleAnimations(_ root: SCNNode) {
            // Ensure avatar always faces the camera (towards user)
            // VRM/glTF models face -Z by default; camera is at +Z, so rotate 180°
            root.eulerAngles.y = petCharacter.isVRM ? CGFloat.pi : 0

            if petCharacter.isVRM, !vrmBones.isEmpty {
                // VRM bone-based breathing: subtle spine sway
                if let spine = spineBone {
                    let breathe = SCNAction.sequence([
                        SCNAction.rotateBy(x: 0.03, y: 0, z: 0, duration: 1.5),
                        SCNAction.rotateBy(x: -0.03, y: 0, z: 0, duration: 1.5)
                    ])
                    breathe.timingMode = .easeInEaseOut
                    spine.runAction(.repeatForever(breathe), forKey: "breathe")
                }

                // Subtle hip sway (weight shift)
                if let hips = hipsBone {
                    let hipSway = SCNAction.sequence([
                        SCNAction.rotateBy(x: 0, y: 0, z: 0.02, duration: 2.5),
                        SCNAction.rotateBy(x: 0, y: 0, z: -0.04, duration: 5.0),
                        SCNAction.rotateBy(x: 0, y: 0, z: 0.02, duration: 2.5)
                    ])
                    hipSway.timingMode = .easeInEaseOut
                    hips.runAction(.repeatForever(hipSway), forKey: "hipSway")
                }

                // Gentle whole-body bounce
                let breathe = SCNAction.sequence([
                    SCNAction.moveBy(x: 0, y: 0.03, z: 0, duration: 1.5),
                    SCNAction.moveBy(x: 0, y: -0.03, z: 0, duration: 1.5)
                ])
                breathe.timingMode = .easeInEaseOut
                root.runAction(.repeatForever(breathe), forKey: "breathe")

                // Arm micro-sway (natural, not stiff)
                if let leftArm = leftUpperArmBone {
                    let armSway = SCNAction.sequence([
                        SCNAction.rotateBy(x: 0.02, y: 0, z: 0, duration: 2.0),
                        SCNAction.rotateBy(x: -0.02, y: 0, z: 0, duration: 2.0)
                    ])
                    armSway.timingMode = .easeInEaseOut
                    leftArm.runAction(.repeatForever(armSway), forKey: "armSway")
                }
                if let rightArm = rightUpperArmBone {
                    let armSway = SCNAction.sequence([
                        SCNAction.rotateBy(x: -0.02, y: 0, z: 0, duration: 2.2),
                        SCNAction.rotateBy(x: 0.02, y: 0, z: 0, duration: 2.2)
                    ])
                    armSway.timingMode = .easeInEaseOut
                    rightArm.runAction(.repeatForever(armSway), forKey: "armSway")
                }
            } else {
                // Non-VRM breathing
                let breathe = SCNAction.sequence([
                    SCNAction.moveBy(x: 0, y: 0.06, z: 0, duration: 1.5),
                    SCNAction.moveBy(x: 0, y: -0.06, z: 0, duration: 1.5)
                ])
                breathe.timingMode = .easeInEaseOut
                root.runAction(.repeatForever(breathe), forKey: "breathe")
            }

            // Subtle side sway (whole body)
            let sway = SCNAction.sequence([
                SCNAction.rotateBy(x: 0, y: 0, z: 0.04, duration: 2.0),
                SCNAction.rotateBy(x: 0, y: 0, z: -0.08, duration: 4.0),
                SCNAction.rotateBy(x: 0, y: 0, z: 0.04, duration: 2.0)
            ])
            sway.timingMode = .easeInEaseOut
            root.runAction(.repeatForever(sway), forKey: "sway")

            // Head look-around (uses head bone for VRM, headNode otherwise)
            if let head = headNode {
                let lookAround = SCNAction.sequence([
                    SCNAction.wait(duration: 4),
                    SCNAction.rotateBy(x: 0, y: 0.25, z: 0, duration: 0.5),
                    SCNAction.wait(duration: 1.5),
                    SCNAction.rotateBy(x: 0, y: -0.5, z: 0, duration: 0.8),
                    SCNAction.wait(duration: 1.5),
                    SCNAction.rotateBy(x: 0, y: 0.25, z: 0, duration: 0.5),
                    SCNAction.wait(duration: 3)
                ])
                lookAround.timingMode = .easeInEaseOut
                head.runAction(.repeatForever(lookAround), forKey: "look")

                // Occasional head tilt (cute!)
                let headTilt = SCNAction.sequence([
                    SCNAction.wait(duration: Double.random(in: 7...12)),
                    SCNAction.rotateBy(x: 0, y: 0, z: 0.12, duration: 0.3),
                    SCNAction.wait(duration: 1.0),
                    SCNAction.rotateBy(x: 0, y: 0, z: -0.12, duration: 0.3)
                ])
                headTilt.timingMode = .easeInEaseOut
                head.runAction(.repeatForever(headTilt), forKey: "headTilt")
            }

            // Tail wag
            startTailWag()

            // Check if it's sleep time — if so, go to sleep immediately
            if PetPersonality.isSleepTime {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.startSleeping()
                }
            } else {
                // Random idle thoughts (sometimes, not always)
                startRandomIdleThoughts(root)
                // Random behaviors: walk, dance, jump — cycled
                startRandomBehaviors(root)
            }
        }

        private func startRandomIdleThoughts(_ root: SCNNode) {
            let pers = petCharacter.personality

            func scheduleNext() {
                // Long delays — pet mostly stays quiet, only occasionally says something
                let delay = Double.random(in: 45...150)
                let wait = SCNAction.wait(duration: delay)
                let speak = SCNAction.run { [weak self] _ in
                    guard let self else { return }
                    // ~30% chance each cycle
                    if Int.random(in: 0...2) == 0 {
                        DispatchQueue.main.async {
                            let thought = pers.contextualThought(
                                hunger: self.currentHunger,
                                happiness: self.currentHappiness
                            )
                            self.showSpeechBubble(thought)
                        }
                    }
                }
                root.runAction(SCNAction.sequence([wait, speak]), forKey: "idleThought") { [weak root] in
                    guard let root else { return }
                    DispatchQueue.main.async {
                        scheduleNext()
                    }
                }
            }
            scheduleNext()
        }

        private func startTailWag() {
            guard let tail = tailNode else { return }
            let wag = SCNAction.sequence([
                SCNAction.rotateBy(x: 0, y: 0.3, z: 0.2, duration: 0.2),
                SCNAction.rotateBy(x: 0, y: -0.6, z: -0.4, duration: 0.4),
                SCNAction.rotateBy(x: 0, y: 0.3, z: 0.2, duration: 0.2)
            ])
            wag.timingMode = .easeInEaseOut
            tail.runAction(.repeatForever(wag), forKey: "tailWag")
        }

        private func startRandomBehaviors(_ root: SCNNode) {
            // Don't start behaviors while sleeping
            guard !isSleeping else { return }
            // Weighted behaviors — sitting is most common, activities happen sometimes
            let behaviors: [(weight: Int, action: () -> SCNAction)] = [
                (4, { [weak self] in self?.sitAction() ?? SCNAction.wait(duration: 1) }),
                (3, { [weak self] in self?.sitAndReadAction(root) ?? SCNAction.wait(duration: 1) }),
                (2, { [weak self] in self?.sitAndDrawAction() ?? SCNAction.wait(duration: 1) }),
                (2, { [weak self] in self?.playWithTrainsAction(root) ?? SCNAction.wait(duration: 1) }),
                (2, { [weak self] in self?.walkAction(root) ?? SCNAction.wait(duration: 1) }),
                (1, { [weak self] in self?.playWithToyAction(root) ?? SCNAction.wait(duration: 1) }),
                (1, { [weak self] in self?.danceAction(root) ?? SCNAction.wait(duration: 1) }),
                (1, { self.jumpAction() }),
                (1, { [weak self] in self?.stretchAction() ?? SCNAction.wait(duration: 1) }),
                (1, { [weak self] in self?.boredAction() ?? SCNAction.wait(duration: 1) }),
                (1, { [weak self] in self?.screenEscapeAction() ?? SCNAction.wait(duration: 1) }),
                (1, { [weak self] in self?.batYarnAction(root) ?? SCNAction.wait(duration: 1) }),
            ]

            // Build weighted pool
            var pool: [() -> SCNAction] = []
            for b in behaviors {
                for _ in 0..<b.weight {
                    pool.append(b.action)
                }
            }

            func runNext() {
                let pause = SCNAction.wait(duration: Double.random(in: 5...9))
                let action = pool.randomElement()!()
                // After each behavior, clamp position to keep pet visible
                let clamp = SCNAction.run { _ in
                    let pos = root.position
                    let clampedX = max(-0.8, min(0.8, CGFloat(pos.x)))
                    let clampedZ = max(-0.4, min(1.0, CGFloat(pos.z)))
                    if abs(CGFloat(pos.x) - clampedX) > 0.01 || abs(CGFloat(pos.z) - clampedZ) > 0.01 {
                        root.runAction(SCNAction.move(to: SCNVector3(clampedX, pos.y, clampedZ), duration: 0.4))
                    }
                }
                let seq = SCNAction.sequence([pause, action, clamp])
                root.runAction(seq, forKey: "behavior") { [weak root] in
                    guard let root else { return }
                    DispatchQueue.main.async {
                        runNext()
                    }
                }
            }
            runNext()
        }

        // MARK: - Sleep System

        func updateSleepState() {
            let shouldSleep = PetPersonality.isSleepTime
            guard shouldSleep != isSleeping else { return }

            if shouldSleep {
                startSleeping()
                dimLights()
            } else {
                wakeUp()
                brightenLights()
            }
        }

        private func dimLights() {
            guard let scene = sceneRef else { return }
            let nightColor = NSColor(red: 0.4, green: 0.45, blue: 0.7, alpha: 1)
            if let key = scene.rootNode.childNode(withName: "keyLight", recursively: false) {
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 2.0
                key.light?.intensity = 150
                key.light?.color = nightColor
                SCNTransaction.commit()
            }
            if let fill = scene.rootNode.childNode(withName: "fillLight", recursively: false) {
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 2.0
                fill.light?.intensity = 80
                SCNTransaction.commit()
            }
            if let amb = scene.rootNode.childNode(withName: "ambientLight", recursively: false) {
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 2.0
                amb.light?.intensity = 80
                amb.light?.color = nightColor
                SCNTransaction.commit()
            }
            // Add nightlight if not present
            if scene.rootNode.childNode(withName: "nightlight", recursively: false) == nil {
                let nightlight = SCNNode()
                nightlight.name = "nightlight"
                nightlight.light = SCNLight()
                nightlight.light?.type = .omni
                nightlight.light?.intensity = 0
                nightlight.light?.color = NSColor(red: 1.0, green: 0.9, blue: 0.6, alpha: 1)
                nightlight.light?.attenuationStartDistance = 0.5
                nightlight.light?.attenuationEndDistance = 3.0
                nightlight.position = SCNVector3(-0.5, 1.0, -0.2)
                scene.rootNode.addChildNode(nightlight)
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 2.0
                nightlight.light?.intensity = 120
                SCNTransaction.commit()
            }
        }

        private func brightenLights() {
            guard let scene = sceneRef else { return }
            if let key = scene.rootNode.childNode(withName: "keyLight", recursively: false) {
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 2.0
                key.light?.intensity = 800
                key.light?.color = NSColor.white
                SCNTransaction.commit()
            }
            if let fill = scene.rootNode.childNode(withName: "fillLight", recursively: false) {
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 2.0
                fill.light?.intensity = 250
                SCNTransaction.commit()
            }
            if let amb = scene.rootNode.childNode(withName: "ambientLight", recursively: false) {
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 2.0
                amb.light?.intensity = 300
                amb.light?.color = NSColor.white
                SCNTransaction.commit()
            }
            // Remove nightlight
            if let nl = scene.rootNode.childNode(withName: "nightlight", recursively: false) {
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 2.0
                nl.light?.intensity = 0
                SCNTransaction.commit()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    nl.removeFromParentNode()
                }
            }
        }

        private func startSleeping() {
            guard let body = petBodyNode, !isSleeping else { return }
            isSleeping = true

            // Stop all active behaviors
            body.removeAction(forKey: "behavior")
            body.removeAction(forKey: "idleThought")
            body.removeAction(forKey: "chase")

            let pers = petCharacter.personality

            // Walk to the mat
            let matPos = sleepMatNode?.position ?? SCNVector3(-0.5, 0, -0.3)
            let dx = CGFloat(matPos.x) - CGFloat(body.position.x)
            let dz = CGFloat(matPos.z) - CGFloat(body.position.z)
            let dist = sqrt(dx * dx + dz * dz)
            let angle = atan2(dx, dz) + (petCharacter.isVRM ? CGFloat.pi : 0)

            let walkToMat = SCNAction.sequence([
                SCNAction.rotateTo(x: 0, y: angle, z: 0, duration: 0.3),
                SCNAction.moveBy(x: dx, y: 0, z: dz, duration: Double(dist) * 1.0),
                SCNAction.rotateTo(x: 0, y: petCharacter.isVRM ? CGFloat.pi : 0, z: 0, duration: 0.3)
            ])

            // Show sleepy speech
            showSpeechBubble(pers.sleepyThoughts.first ?? "zzz... 💤")

            // Lay down animation
            let isVRM = petCharacter.isVRM
            let layDown = SCNAction.run { [weak self] _ in
                guard let self else { return }
                DispatchQueue.main.async {
                    self.showExpression(.sleepy)

                    if isVRM, !self.vrmBones.isEmpty {
                        // VRM bone-based sleep: curl up using skeleton
                        // Close eyes via blend shape
                        self.setVRMBlendShape("Blink", weight: 1.0, duration: 0.5)

                        // Curl spine forward
                        self.spineBone?.runAction(SCNAction.rotateTo(x: 0.4, y: 0, z: 0, duration: 0.8))
                        self.spine1Bone?.runAction(SCNAction.rotateTo(x: 0.3, y: 0, z: 0, duration: 0.8))

                        // Head droops
                        self.headBoneVRM?.runAction(SCNAction.rotateTo(x: 0.3, y: 0, z: 0.1, duration: 0.8))

                        // Bring arms inward (hugging self)
                        self.leftUpperArmBone?.runAction(SCNAction.rotateTo(x: 0.3, y: 0, z: CGFloat.pi * 0.3, duration: 0.6))
                        self.rightUpperArmBone?.runAction(SCNAction.rotateTo(x: 0.3, y: 0, z: -CGFloat.pi * 0.3, duration: 0.6))
                        self.leftForeArmBone?.runAction(SCNAction.rotateTo(x: 0.8, y: 0, z: 0, duration: 0.6))
                        self.rightForeArmBone?.runAction(SCNAction.rotateTo(x: 0.8, y: 0, z: 0, duration: 0.6))

                        // Bend knees
                        self.leftUpperLegBone?.runAction(SCNAction.rotateTo(x: -0.5, y: 0, z: 0, duration: 0.8))
                        self.rightUpperLegBone?.runAction(SCNAction.rotateTo(x: -0.5, y: 0, z: 0, duration: 0.8))
                        self.leftLowerLegBone?.runAction(SCNAction.rotateTo(x: 0.8, y: 0, z: 0, duration: 0.8))
                        self.rightLowerLegBone?.runAction(SCNAction.rotateTo(x: 0.8, y: 0, z: 0, duration: 0.8))

                        // Lower hips
                        self.hipsBone?.runAction(SCNAction.moveBy(x: 0, y: -0.15, z: 0, duration: 0.8))
                    } else if isVRM {
                        // VRM without bones: tilt whole model
                        if pers.sleepStyle == "sprawled" {
                            self.bodyMeshNode?.runAction(SCNAction.rotateTo(x: CGFloat.pi / 2.2, y: 0, z: 0, duration: 0.8))
                        } else if pers.sleepStyle == "on back" {
                            self.bodyMeshNode?.runAction(SCNAction.rotateTo(x: CGFloat.pi / 2.5, y: 0, z: 0, duration: 0.8))
                        } else {
                            self.bodyMeshNode?.runAction(SCNAction.rotateTo(x: 0.3, y: 0, z: CGFloat.pi / 3, duration: 0.8))
                        }
                    } else {
                        // Programmatic models: animate individual body parts
                        if pers.sleepStyle == "sprawled" {
                            self.bodyMeshNode?.runAction(SCNAction.rotateTo(x: CGFloat.pi / 2.2, y: 0, z: 0, duration: 0.8))
                            self.leftArmNode?.runAction(SCNAction.rotateTo(x: -0.3, y: 0, z: CGFloat.pi * 0.6, duration: 0.6))
                            self.rightArmNode?.runAction(SCNAction.rotateTo(x: -0.3, y: 0, z: -CGFloat.pi * 0.6, duration: 0.6))
                            self.leftFootNode?.runAction(SCNAction.rotateTo(x: -0.2, y: 0.3, z: 0, duration: 0.6))
                            self.rightFootNode?.runAction(SCNAction.rotateTo(x: -0.2, y: -0.3, z: 0, duration: 0.6))
                        } else if pers.sleepStyle == "on back" {
                            self.bodyMeshNode?.runAction(SCNAction.rotateTo(x: CGFloat.pi / 2.5, y: 0, z: 0, duration: 0.8))
                            self.leftArmNode?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: CGFloat.pi * 0.4, duration: 0.6))
                            self.rightArmNode?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: -CGFloat.pi * 0.4, duration: 0.6))
                        } else {
                            self.bodyMeshNode?.runAction(SCNAction.rotateTo(x: 0.3, y: 0, z: CGFloat.pi / 3, duration: 0.8))
                            self.leftArmNode?.runAction(SCNAction.rotateTo(x: -0.5, y: 0, z: 0.3, duration: 0.6))
                            self.rightArmNode?.runAction(SCNAction.rotateTo(x: -0.5, y: 0, z: -0.3, duration: 0.6))
                            self.leftFootNode?.runAction(SCNAction.rotateTo(x: -0.4, y: 0, z: 0, duration: 0.6))
                            self.rightFootNode?.runAction(SCNAction.rotateTo(x: -0.4, y: 0, z: 0, duration: 0.6))
                        }

                        // Close eyes — squash Y to thin line (only for programmatic models)
                        let closeEyes = SCNAction.customAction(duration: 0.5) { node, elapsed in
                            let t = elapsed / 0.5
                            node.scale = SCNVector3(1.0, max(0.05, 1.0 - Float(t) * 0.95), 1.0)
                        }
                        self.leftEyeNode?.runAction(closeEyes)
                        self.rightEyeNode?.runAction(closeEyes.copy() as! SCNAction)
                    }

                    // Lower body toward ground
                    body.runAction(SCNAction.moveBy(x: 0, y: -0.2, z: 0, duration: 0.8))

                    // Start Zzz animation
                    self.startZzzAnimation(above: body)
                }
            }

            body.runAction(SCNAction.sequence([walkToMat, SCNAction.wait(duration: 0.3), layDown]), forKey: "sleep")

            // Gentle breathing animation while sleeping
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self, self.isSleeping else { return }
                let breathe = SCNAction.sequence([
                    SCNAction.scale(by: 1.03, duration: 1.5),
                    SCNAction.scale(by: 1.0 / 1.03, duration: 1.5)
                ])
                self.bodyMeshNode?.runAction(.repeatForever(breathe), forKey: "breathing")
            }
        }

        private func wakeUp() {
            guard let body = petBodyNode, isSleeping else { return }
            isSleeping = false

            let pers = petCharacter.personality

            // Stop breathing and Zzz
            bodyMeshNode?.removeAction(forKey: "breathing")
            zzzNode?.removeFromParentNode()
            zzzNode = nil

            // Show wake-up speech
            showSpeechBubble(pers.morningGreetings.randomElement() ?? "good morning~ ☀️")

            // Sit up animation
            bodyMeshNode?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.6))
            body.runAction(SCNAction.moveBy(x: 0, y: 0.2, z: 0, duration: 0.6))

            if petCharacter.isVRM, !vrmBones.isEmpty {
                // VRM: reset all bones to rest pose, open eyes
                setVRMBlendShape("Blink", weight: 0, duration: 0.4)
                hipsBone?.runAction(SCNAction.moveBy(x: 0, y: 0.15, z: 0, duration: 0.6))
                leftUpperLegBone?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.4))
                rightUpperLegBone?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.4))
                leftLowerLegBone?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.4))
                rightLowerLegBone?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.4))
                spineBone?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.4))
                spine1Bone?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.4))
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.applyVRMRestPose()
                }
            } else if !petCharacter.isVRM {
                // Reset limbs (programmatic models only)
                leftArmNode?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: CGFloat.pi / 6, duration: 0.4))
                rightArmNode?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: -CGFloat.pi / 6, duration: 0.4))
                leftFootNode?.runAction(SCNAction.move(to: SCNVector3(-0.18, -0.45, 0.05), duration: 0.4))
                rightFootNode?.runAction(SCNAction.move(to: SCNVector3(0.18, -0.45, 0.05), duration: 0.4))

                // Open eyes — restore full Y scale
                let openEyes = SCNAction.customAction(duration: 0.4) { node, elapsed in
                    let t = elapsed / 0.4
                    node.scale = SCNVector3(1.0, max(0.05, Float(t)), 1.0)
                }
                leftEyeNode?.runAction(openEyes)
                rightEyeNode?.runAction(openEyes.copy() as! SCNAction)
            }

            // Stretch/wake animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                guard let self else { return }

                if self.petCharacter.isVRM, !self.vrmBones.isEmpty {
                    // VRM bone-based stretch: arms up then back to rest
                    self.leftUpperArmBone?.runAction(SCNAction.sequence([
                        SCNAction.rotateTo(x: -CGFloat.pi * 0.6, y: 0, z: CGFloat.pi * 0.5, duration: 0.4),
                        SCNAction.wait(duration: 0.6),
                        SCNAction.rotateTo(x: 0, y: 0, z: CGFloat.pi * 0.42, duration: 0.3)
                    ]))
                    self.rightUpperArmBone?.runAction(SCNAction.sequence([
                        SCNAction.rotateTo(x: -CGFloat.pi * 0.6, y: 0, z: -CGFloat.pi * 0.5, duration: 0.4),
                        SCNAction.wait(duration: 0.6),
                        SCNAction.rotateTo(x: 0, y: 0, z: -CGFloat.pi * 0.42, duration: 0.3)
                    ]))
                    // Spine arches back then forward
                    self.spineBone?.runAction(SCNAction.sequence([
                        SCNAction.rotateTo(x: -0.2, y: 0, z: 0, duration: 0.4),
                        SCNAction.wait(duration: 0.6),
                        SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.3)
                    ]))
                } else if self.petCharacter.isVRM {
                    // VRM without bones: bounce wake-up
                    self.bodyMeshNode?.runAction(SCNAction.sequence([
                        SCNAction.scale(by: 1.15, duration: 0.3),
                        SCNAction.scale(by: 1.0 / 1.15, duration: 0.3)
                    ]))
                } else {
                    // Programmatic: big arm stretch
                    self.leftArmNode?.runAction(SCNAction.sequence([
                        SCNAction.rotateTo(x: -CGFloat.pi * 0.6, y: 0, z: CGFloat.pi * 0.5, duration: 0.4),
                        SCNAction.wait(duration: 0.8),
                        SCNAction.rotateTo(x: 0, y: 0, z: CGFloat.pi / 6, duration: 0.3)
                    ]))
                    self.rightArmNode?.runAction(SCNAction.sequence([
                        SCNAction.rotateTo(x: -CGFloat.pi * 0.6, y: 0, z: -CGFloat.pi * 0.5, duration: 0.4),
                        SCNAction.wait(duration: 0.8),
                        SCNAction.rotateTo(x: 0, y: 0, z: -CGFloat.pi / 6, duration: 0.3)
                    ]))
                }

                // Resume behaviors
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                    guard let self, let body = self.petBodyNode else { return }
                    self.startRandomBehaviors(body)
                    self.startRandomIdleThoughts(body)
                }
            }
        }

        private func startZzzAnimation(above body: SCNNode) {
            guard let scene = sceneRef else { return }

            // Remove old Zzz
            zzzNode?.removeFromParentNode()

            let container = SCNNode()
            container.name = "zzzContainer"
            scene.rootNode.addChildNode(container)
            zzzNode = container

            func emitZzz() {
                guard isSleeping else {
                    container.removeFromParentNode()
                    return
                }

                let zText = SCNText(string: "z", extrusionDepth: 0.01)
                zText.font = NSFont.systemFont(ofSize: CGFloat.random(in: 0.15...0.25), weight: .bold)
                let zMat = SCNMaterial()
                zMat.diffuse.contents = NSColor.white.withAlphaComponent(0.7)
                zMat.lightingModel = .constant
                zText.materials = [zMat]

                let zNode = SCNNode(geometry: zText)
                let bodyPos = body.position
                zNode.position = SCNVector3(
                    CGFloat(bodyPos.x) + CGFloat.random(in: -0.1...0.2),
                    CGFloat(bodyPos.y) + 1.5,
                    CGFloat(bodyPos.z) + 0.3
                )
                zNode.scale = SCNVector3(0.5, 0.5, 0.5)

                let constraint = SCNBillboardConstraint()
                constraint.freeAxes = .all
                zNode.constraints = [constraint]
                container.addChildNode(zNode)

                // Float up and fade
                zNode.runAction(SCNAction.sequence([
                    SCNAction.group([
                        SCNAction.moveBy(x: CGFloat.random(in: -0.2...0.2), y: 0.8, z: 0, duration: 2.0),
                        SCNAction.sequence([
                            SCNAction.fadeIn(duration: 0.3),
                            SCNAction.wait(duration: 1.0),
                            SCNAction.fadeOut(duration: 0.7)
                        ]),
                        SCNAction.scale(to: 0.8, duration: 2.0),
                        SCNAction.rotateBy(x: 0, y: 0, z: CGFloat.random(in: -0.5...0.5), duration: 2.0)
                    ]),
                    SCNAction.removeFromParentNode()
                ]))

                // Schedule next
                DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 1.5...3.0)) {
                    emitZzz()
                }
            }

            emitZzz()
        }

        // MARK: - Sitting (most common)

        private func sitAction() -> SCNAction {
            guard let body = petBodyNode else { return SCNAction.wait(duration: 1) }
            let sitDuration = Double.random(in: 5...10)
            // Squat down slightly, legs spread
            let sitDown = SCNAction.run { [weak self] _ in
                DispatchQueue.main.async {
                    self?.showExpression(.content)
                    body.runAction(SCNAction.moveBy(x: 0, y: -0.12, z: 0, duration: 0.3), forKey: "sitDown")
                    self?.leftFootNode?.runAction(SCNAction.moveBy(x: -0.06, y: 0.05, z: 0.04, duration: 0.3))
                    self?.rightFootNode?.runAction(SCNAction.moveBy(x: 0.06, y: 0.05, z: 0.04, duration: 0.3))
                }
            }
            let wait = SCNAction.wait(duration: sitDuration)
            let standUp = SCNAction.run { [weak self] _ in
                DispatchQueue.main.async {
                    body.runAction(SCNAction.moveBy(x: 0, y: 0.12, z: 0, duration: 0.3), forKey: "standUp")
                    self?.leftFootNode?.runAction(SCNAction.moveBy(x: 0.06, y: -0.05, z: -0.04, duration: 0.3))
                    self?.rightFootNode?.runAction(SCNAction.moveBy(x: -0.06, y: -0.05, z: -0.04, duration: 0.3))
                }
            }
            return SCNAction.sequence([sitDown, wait, standUp, SCNAction.wait(duration: 0.4)])
        }

        // MARK: - Sit and Read

        private func sitAndReadAction(_ root: SCNNode) -> SCNAction {
            guard let body = petBodyNode else { return SCNAction.wait(duration: 1) }
            let readDuration = Double.random(in: 6...12)

            let start = SCNAction.run { [weak self] _ in
                DispatchQueue.main.async {
                    self?.showExpression(.focused)
                    // Sit down
                    body.runAction(SCNAction.moveBy(x: 0, y: -0.12, z: 0, duration: 0.3))
                    // Create a little book in front of the pet
                    let bookGeo = SCNBox(width: 0.22, height: 0.02, length: 0.16, chamferRadius: 0.01)
                    let bookMat = SCNMaterial()
                    bookMat.diffuse.contents = NSColor(red: 0.3, green: 0.5, blue: 0.7, alpha: 1)
                    bookGeo.materials = [bookMat]
                    let book = SCNNode(geometry: bookGeo)
                    book.name = "readingBook"
                    book.position = SCNVector3(CGFloat(body.position.x), 0.7, CGFloat(body.position.z) + 0.35)
                    book.eulerAngles.x = -0.3
                    book.scale = SCNVector3(0.01, 0.01, 0.01)
                    root.addChildNode(book)
                    book.runAction(SCNAction.scale(to: 1, duration: 0.2))

                    // Pages
                    let pageGeo = SCNBox(width: 0.19, height: 0.015, length: 0.14, chamferRadius: 0)
                    let pageMat = SCNMaterial()
                    pageMat.diffuse.contents = NSColor(white: 0.95, alpha: 1)
                    pageGeo.materials = [pageMat]
                    let pages = SCNNode(geometry: pageGeo)
                    pages.position = SCNVector3(0, 0.012, 0)
                    book.addChildNode(pages)

                    // Arms reach toward book
                    self?.leftArmNode?.runAction(SCNAction.rotateTo(x: -0.6, y: 0, z: 0.2, duration: 0.3))
                    self?.rightArmNode?.runAction(SCNAction.rotateTo(x: -0.6, y: 0, z: -0.2, duration: 0.3))

                    // Head tilts down to look at book
                    self?.headNode?.runAction(SCNAction.rotateTo(x: 0.2, y: 0, z: 0, duration: 0.3))

                    // Occasional page turn
                    let pageTurn = SCNAction.sequence([
                        SCNAction.wait(duration: Double.random(in: 2...4)),
                        SCNAction.run { _ in
                            DispatchQueue.main.async {
                                self?.rightArmNode?.runAction(SCNAction.sequence([
                                    SCNAction.rotateTo(x: -0.8, y: 0.2, z: -0.2, duration: 0.15),
                                    SCNAction.rotateTo(x: -0.6, y: 0, z: -0.2, duration: 0.15),
                                ]))
                            }
                        }
                    ])
                    body.runAction(SCNAction.repeat(pageTurn, count: 3), forKey: "pageTurn")
                }
            }

            let wait = SCNAction.wait(duration: readDuration)

            let end = SCNAction.run { [weak self] _ in
                DispatchQueue.main.async {
                    body.removeAction(forKey: "pageTurn")
                    // Remove book
                    root.childNode(withName: "readingBook", recursively: false)?.runAction(SCNAction.sequence([
                        SCNAction.scale(to: 0.01, duration: 0.2),
                        SCNAction.removeFromParentNode()
                    ]))
                    // Stand up + reset arms/head
                    body.runAction(SCNAction.moveBy(x: 0, y: 0.12, z: 0, duration: 0.3))
                    self?.leftArmNode?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: CGFloat.pi / 5, duration: 0.3))
                    self?.rightArmNode?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: -CGFloat.pi / 5, duration: 0.3))
                    self?.headNode?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.3))
                }
            }

            return SCNAction.sequence([start, wait, end, SCNAction.wait(duration: 0.4)])
        }

        // MARK: - Sit and Draw

        private func sitAndDrawAction() -> SCNAction {
            guard let body = petBodyNode else { return SCNAction.wait(duration: 1) }
            let drawDuration = Double.random(in: 5...9)

            let start = SCNAction.run { [weak self] _ in
                DispatchQueue.main.async {
                    self?.showExpression(.focused)
                    body.runAction(SCNAction.moveBy(x: 0, y: -0.12, z: 0, duration: 0.3))
                    // One arm draws (wiggling motion)
                    self?.leftArmNode?.runAction(SCNAction.rotateTo(x: -0.5, y: 0, z: 0.1, duration: 0.3))
                    let drawWiggle = SCNAction.sequence([
                        SCNAction.rotateBy(x: 0, y: 0, z: 0.08, duration: 0.2),
                        SCNAction.rotateBy(x: 0, y: 0, z: -0.16, duration: 0.4),
                        SCNAction.rotateBy(x: 0, y: 0, z: 0.08, duration: 0.2),
                    ])
                    self?.rightArmNode?.runAction(SCNAction.sequence([
                        SCNAction.rotateTo(x: -0.7, y: 0, z: -0.1, duration: 0.3),
                        SCNAction.repeatForever(drawWiggle)
                    ]), forKey: "drawing")
                    self?.headNode?.runAction(SCNAction.rotateTo(x: 0.15, y: 0, z: 0.05, duration: 0.3))
                }
            }
            let wait = SCNAction.wait(duration: drawDuration)
            let end = SCNAction.run { [weak self] _ in
                DispatchQueue.main.async {
                    self?.rightArmNode?.removeAction(forKey: "drawing")
                    body.runAction(SCNAction.moveBy(x: 0, y: 0.12, z: 0, duration: 0.3))
                    self?.leftArmNode?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: CGFloat.pi / 5, duration: 0.3))
                    self?.rightArmNode?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: -CGFloat.pi / 5, duration: 0.3))
                    self?.headNode?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.3))
                    self?.showExpression(.happy)
                }
            }
            return SCNAction.sequence([start, wait, end, SCNAction.wait(duration: 0.4)])
        }

        // MARK: - Play with Trains

        private func playWithTrainsAction(_ root: SCNNode) -> SCNAction {
            guard let body = petBodyNode else { return SCNAction.wait(duration: 1) }

            let start = SCNAction.run { [weak self] _ in
                DispatchQueue.main.async {
                    self?.showExpression(.excited)
                    body.runAction(SCNAction.moveBy(x: 0, y: -0.12, z: 0, duration: 0.3))

                    // Create a tiny train
                    let trainRoot = SCNNode()
                    trainRoot.name = "toyTrain"

                    // Engine
                    let engineGeo = SCNBox(width: 0.12, height: 0.08, length: 0.08, chamferRadius: 0.02)
                    let engineMat = SCNMaterial()
                    engineMat.diffuse.contents = NSColor.systemRed
                    engineGeo.materials = [engineMat]
                    let engine = SCNNode(geometry: engineGeo)
                    trainRoot.addChildNode(engine)

                    // Chimney
                    let chimneyGeo = SCNCylinder(radius: 0.02, height: 0.05)
                    chimneyGeo.materials = [engineMat]
                    let chimney = SCNNode(geometry: chimneyGeo)
                    chimney.position = SCNVector3(0.03, 0.06, 0)
                    engine.addChildNode(chimney)

                    // Car
                    let carGeo = SCNBox(width: 0.1, height: 0.06, length: 0.07, chamferRadius: 0.015)
                    let carMat = SCNMaterial()
                    carMat.diffuse.contents = NSColor.systemBlue
                    carGeo.materials = [carMat]
                    let car = SCNNode(geometry: carGeo)
                    car.position = SCNVector3(-0.13, -0.01, 0)
                    trainRoot.addChildNode(car)

                    // Wheels
                    let wheelMat = SCNMaterial()
                    wheelMat.diffuse.contents = NSColor(white: 0.2, alpha: 1)
                    for node in [engine, car] {
                        for side: CGFloat in [-1, 1] {
                            let wheelGeo = SCNCylinder(radius: 0.02, height: 0.01)
                            wheelGeo.materials = [wheelMat]
                            let wheel = SCNNode(geometry: wheelGeo)
                            wheel.position = SCNVector3(0, -0.04, side * 0.045)
                            wheel.eulerAngles.x = CGFloat.pi / 2
                            node.addChildNode(wheel)
                        }
                    }

                    trainRoot.position = SCNVector3(CGFloat(body.position.x) + 0.3, 0.06, CGFloat(body.position.z) + 0.4)
                    trainRoot.scale = SCNVector3(0.01, 0.01, 0.01)
                    root.addChildNode(trainRoot)
                    trainRoot.runAction(SCNAction.scale(to: 1, duration: 0.2))

                    // Train moves in a small circle
                    let circle = SCNAction.customAction(duration: 8) { node, elapsed in
                        let t = elapsed / 8
                        let angle = t * 2 * CGFloat.pi
                        let cx = CGFloat(body.position.x) + 0.3
                        let cz = CGFloat(body.position.z) + 0.4
                        let r: CGFloat = 0.3
                        node.position.x = cx + r * cos(angle)
                        node.position.z = cz + r * sin(angle)
                        node.eulerAngles.y = angle + CGFloat.pi / 2
                    }
                    trainRoot.runAction(circle, forKey: "trainMove")

                    // Pet watches the train — head follows
                    self?.rightArmNode?.runAction(SCNAction.rotateTo(x: -0.3, y: 0, z: -0.1, duration: 0.3))
                }
            }

            let wait = SCNAction.wait(duration: 9)

            let end = SCNAction.run { [weak self] _ in
                DispatchQueue.main.async {
                    root.childNode(withName: "toyTrain", recursively: false)?.runAction(SCNAction.sequence([
                        SCNAction.scale(to: 0.01, duration: 0.2),
                        SCNAction.removeFromParentNode()
                    ]))
                    body.runAction(SCNAction.moveBy(x: 0, y: 0.12, z: 0, duration: 0.3))
                    self?.rightArmNode?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: -CGFloat.pi / 5, duration: 0.3))
                    self?.headNode?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.3))
                }
            }

            return SCNAction.sequence([start, wait, end, SCNAction.wait(duration: 0.4)])
        }

        // MARK: - Bored

        private func boredAction() -> SCNAction {
            guard let body = petBodyNode else { return SCNAction.wait(duration: 1) }
            let start = SCNAction.run { [weak self] _ in
                DispatchQueue.main.async {
                    self?.showExpression(.bored)
                    // Sigh: body deflates slightly
                    body.runAction(SCNAction.sequence([
                        SCNAction.scale(to: 0.97, duration: 0.5),
                        SCNAction.wait(duration: 2),
                        SCNAction.scale(to: 1.0, duration: 0.5),
                    ]), forKey: "sigh")
                    // Head droops
                    self?.headNode?.runAction(SCNAction.sequence([
                        SCNAction.rotateTo(x: 0.15, y: 0, z: 0.05, duration: 0.5),
                        SCNAction.wait(duration: 3),
                        SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.5),
                    ]))
                }
            }
            return SCNAction.sequence([start, SCNAction.wait(duration: 5)])
        }

        // MARK: - Expressions

        private enum PetExpression {
            case happy, content, focused, excited, bored, sleepy
        }

        private func showExpression(_ expression: PetExpression) {
            switch expression {
            case .happy:
                // Wide eyes, big cheeks
                leftCheekNode?.runAction(SCNAction.scale(to: 1.2, duration: 0.2))
                rightCheekNode?.runAction(SCNAction.scale(to: 1.2, duration: 0.2))
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                    self?.leftCheekNode?.runAction(SCNAction.scale(to: 1.0, duration: 0.3))
                    self?.rightCheekNode?.runAction(SCNAction.scale(to: 1.0, duration: 0.3))
                }
            case .content:
                // Soft squint — eyes close slightly
                for eye in [leftEyeNode, rightEyeNode] {
                    eye?.runAction(SCNAction.sequence([
                        SCNAction.run { n in n.scale = SCNVector3(1, 0.6, 1) },
                        SCNAction.wait(duration: 3),
                        SCNAction.run { n in n.scale = SCNVector3(1, 1, 1) },
                    ]))
                }
            case .focused:
                // Pupils shrink slightly (concentrating)
                leftPupilNode?.runAction(SCNAction.scale(to: 0.85, duration: 0.2))
                rightPupilNode?.runAction(SCNAction.scale(to: 0.85, duration: 0.2))
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
                    self?.leftPupilNode?.runAction(SCNAction.scale(to: 1.0, duration: 0.3))
                    self?.rightPupilNode?.runAction(SCNAction.scale(to: 1.0, duration: 0.3))
                }
            case .excited:
                // Big pupils + cheek blush
                leftPupilNode?.runAction(SCNAction.scale(to: 1.2, duration: 0.15))
                rightPupilNode?.runAction(SCNAction.scale(to: 1.2, duration: 0.15))
                leftCheekNode?.runAction(SCNAction.scale(to: 1.3, duration: 0.2))
                rightCheekNode?.runAction(SCNAction.scale(to: 1.3, duration: 0.2))
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                    self?.leftPupilNode?.runAction(SCNAction.scale(to: 1.0, duration: 0.3))
                    self?.rightPupilNode?.runAction(SCNAction.scale(to: 1.0, duration: 0.3))
                    self?.leftCheekNode?.runAction(SCNAction.scale(to: 1.0, duration: 0.3))
                    self?.rightCheekNode?.runAction(SCNAction.scale(to: 1.0, duration: 0.3))
                }
            case .bored:
                // Half-lidded eyes
                for eye in [leftEyeNode, rightEyeNode] {
                    eye?.runAction(SCNAction.sequence([
                        SCNAction.run { n in n.scale = SCNVector3(1, 0.4, 1) },
                        SCNAction.wait(duration: 3),
                        SCNAction.run { n in n.scale = SCNVector3(1, 1, 1) },
                    ]))
                }
            case .sleepy:
                // Eyes droop closed
                leftEyeNode?.runAction(SCNAction.run { n in n.scale = SCNVector3(1, 0.15, 1) })
                rightEyeNode?.runAction(SCNAction.run { n in n.scale = SCNVector3(1, 0.15, 1) })
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
                    self?.leftEyeNode?.runAction(SCNAction.run { n in n.scale = SCNVector3(1, 1, 1) })
                    self?.rightEyeNode?.runAction(SCNAction.run { n in n.scale = SCNVector3(1, 1, 1) })
                }
            }
        }

        // MARK: - Walk Animation

        private func walkAction(_ root: SCNNode) -> SCNAction {
            // Pick a random target position — constrained to visible area
            let targetX = CGFloat.random(in: -0.7...0.7)
            let targetZ = CGFloat.random(in: -0.3...0.7)
            let currentPos = root.position
            let dx = targetX - CGFloat(currentPos.x)
            let dz = targetZ - CGFloat(currentPos.z)
            let distance = sqrt(dx * dx + dz * dz)
            let walkDuration = Double(distance) * 1.2  // speed

            // Face the direction of movement
            // VRM models face -Z, so add pi offset for correct walk facing
            let angle = atan2(dx, dz) + (petCharacter.isVRM ? CGFloat.pi : 0)
            let faceDirection = SCNAction.rotateTo(x: 0, y: angle, z: 0, duration: 0.3)

            // Leg movement (alternate feet up/down)
            let stepDuration = 0.25
            let stepCount = max(2, Int(walkDuration / stepDuration))
            var legActions: [SCNAction] = []
            if petCharacter.isVRM, !vrmBones.isEmpty {
                // VRM bone-based walk: alternate leg swings + arm counter-swing + bounce
                let stepsVRM = max(2, Int(walkDuration / 0.3))
                for i in 0..<stepsVRM {
                    let isLeft = i % 2 == 0
                    let stepAction = SCNAction.run { [weak self] _ in
                        guard let self else { return }
                        let swingAngle: Float = 0.35
                        let armSwing: Float = 0.2
                        // Legs: swing forward/backward alternately
                        self.leftUpperLegBone?.runAction(SCNAction.rotateTo(
                            x: CGFloat(isLeft ? -swingAngle : swingAngle), y: 0, z: 0, duration: 0.15))
                        self.rightUpperLegBone?.runAction(SCNAction.rotateTo(
                            x: CGFloat(isLeft ? swingAngle : -swingAngle), y: 0, z: 0, duration: 0.15))
                        // Knee bend on back leg
                        self.leftLowerLegBone?.runAction(SCNAction.rotateTo(
                            x: CGFloat(isLeft ? 0 : 0.4), y: 0, z: 0, duration: 0.15))
                        self.rightLowerLegBone?.runAction(SCNAction.rotateTo(
                            x: CGFloat(isLeft ? 0.4 : 0), y: 0, z: 0, duration: 0.15))
                        // Arms counter-swing
                        self.leftUpperArmBone?.runAction(SCNAction.rotateBy(
                            x: CGFloat(isLeft ? armSwing : -armSwing), y: 0, z: 0, duration: 0.15))
                        self.rightUpperArmBone?.runAction(SCNAction.rotateBy(
                            x: CGFloat(isLeft ? -armSwing : armSwing), y: 0, z: 0, duration: 0.15))
                    }
                    let bounce = SCNAction.sequence([
                        SCNAction.moveBy(x: 0, y: 0.04, z: 0, duration: 0.15),
                        SCNAction.moveBy(x: 0, y: -0.04, z: 0, duration: 0.15)
                    ])
                    bounce.timingMode = .easeInEaseOut
                    legActions.append(SCNAction.group([stepAction, bounce]))
                }
            } else if petCharacter.isVRM {
                // VRM without bones: cute hop/bounce
                let hopCount = max(2, Int(walkDuration / 0.3))
                for _ in 0..<hopCount {
                    let hop = SCNAction.sequence([
                        SCNAction.moveBy(x: 0, y: 0.08, z: 0, duration: 0.15),
                        SCNAction.moveBy(x: 0, y: -0.08, z: 0, duration: 0.15)
                    ])
                    hop.timingMode = .easeInEaseOut
                    legActions.append(hop)
                }
            } else {
                for i in 0..<stepCount {
                    let isLeft = i % 2 == 0
                    let foot = isLeft ? leftFootNode : rightFootNode
                    let otherFoot = isLeft ? rightFootNode : leftFootNode
                    let arm = isLeft ? leftArmNode : rightArmNode
                    let otherArm = isLeft ? rightArmNode : leftArmNode

                    let stepUp = SCNAction.run { _ in
                        foot?.runAction(SCNAction.moveBy(x: 0, y: 0.06, z: 0, duration: stepDuration * 0.4))
                        otherFoot?.runAction(SCNAction.moveBy(x: 0, y: -0.06, z: 0, duration: stepDuration * 0.4))
                        // Swing arms opposite to legs
                        arm?.runAction(SCNAction.rotateBy(x: 0.2, y: 0, z: 0, duration: stepDuration * 0.4))
                        otherArm?.runAction(SCNAction.rotateBy(x: -0.2, y: 0, z: 0, duration: stepDuration * 0.4))
                    }
                    legActions.append(stepUp)
                    legActions.append(SCNAction.wait(duration: stepDuration))
                }
            }

            // Reset limbs after walk + check for topples
            let resetLimbs = SCNAction.run { [weak self] _ in
                guard let self else { return }
                if self.petCharacter.isVRM, !self.vrmBones.isEmpty {
                    // Reset VRM bones to rest pose
                    self.leftUpperLegBone?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.2))
                    self.rightUpperLegBone?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.2))
                    self.leftLowerLegBone?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.2))
                    self.rightLowerLegBone?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.2))
                    self.applyVRMRestPose()
                } else {
                    self.leftFootNode?.runAction(SCNAction.move(to: SCNVector3(-0.18, -0.45, 0.05), duration: 0.2))
                    self.rightFootNode?.runAction(SCNAction.move(to: SCNVector3(0.18, -0.45, 0.05), duration: 0.2))
                    self.leftArmNode?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: CGFloat.pi / 6, duration: 0.2))
                    self.rightArmNode?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: -CGFloat.pi / 6, duration: 0.2))
                }
                // Check if pet knocked anything over
                if let body = self.petBodyNode {
                    self.checkForTopples(at: body.position)
                }
            }

            let moveToTarget = SCNAction.moveBy(x: dx, y: 0, z: dz, duration: walkDuration)
            moveToTarget.timingMode = .easeInEaseOut

            // Face back to camera after arriving
            let faceCamera = SCNAction.rotateTo(x: 0, y: petCharacter.isVRM ? CGFloat.pi : 0, z: 0, duration: 0.4)

            return SCNAction.sequence([
                faceDirection,
                SCNAction.group([moveToTarget, SCNAction.sequence(legActions)]),
                resetLimbs,
                faceCamera
            ])
        }

        // MARK: - Dance Animation

        private func danceAction(_ root: SCNNode) -> SCNAction {
            let beatDuration = 0.3
            let beats = 12  // 12-beat dance routine

            var danceSteps: [SCNAction] = []

            for i in 0..<beats {
                let step = SCNAction.run { [weak self] _ in
                    guard let self else { return }

                    // Body bounce on every beat
                    self.petBodyNode?.runAction(SCNAction.sequence([
                        SCNAction.moveBy(x: 0, y: 0.12, z: 0, duration: beatDuration * 0.4),
                        SCNAction.moveBy(x: 0, y: -0.12, z: 0, duration: beatDuration * 0.4)
                    ]))

                    // Alternate arm raises
                    if i % 4 == 0 {
                        // Both arms up
                        self.leftArmNode?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: CGFloat.pi * 0.7, duration: beatDuration))
                        self.rightArmNode?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: -CGFloat.pi * 0.7, duration: beatDuration))
                    } else if i % 4 == 1 {
                        // Right arm up, left down
                        self.leftArmNode?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: CGFloat.pi / 6, duration: beatDuration))
                        self.rightArmNode?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: -CGFloat.pi * 0.7, duration: beatDuration))
                    } else if i % 4 == 2 {
                        // Left arm up, right down
                        self.leftArmNode?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: CGFloat.pi * 0.7, duration: beatDuration))
                        self.rightArmNode?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: -CGFloat.pi / 6, duration: beatDuration))
                    } else {
                        // Hip sway
                        self.bodyMeshNode?.runAction(SCNAction.sequence([
                            SCNAction.rotateBy(x: 0, y: 0, z: 0.12, duration: beatDuration * 0.5),
                            SCNAction.rotateBy(x: 0, y: 0, z: -0.24, duration: beatDuration * 0.5)
                        ]))
                    }

                    // Spin on beat 6
                    if i == 6 {
                        self.petBodyNode?.runAction(SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: beatDuration * 2))
                    }

                    // Head bob
                    self.headNode?.runAction(SCNAction.sequence([
                        SCNAction.rotateBy(x: 0.08, y: 0, z: 0, duration: beatDuration * 0.3),
                        SCNAction.rotateBy(x: -0.08, y: 0, z: 0, duration: beatDuration * 0.3)
                    ]))
                }
                danceSteps.append(step)
                danceSteps.append(SCNAction.wait(duration: beatDuration))
            }

            // Reset arms after dance
            let resetArms = SCNAction.run { [weak self] _ in
                self?.leftArmNode?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: CGFloat.pi / 6, duration: 0.3))
                self?.rightArmNode?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: -CGFloat.pi / 6, duration: 0.3))
                self?.bodyMeshNode?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.2))
            }

            danceSteps.append(resetArms)
            return SCNAction.sequence(danceSteps)
        }

        // MARK: - Jump Animation

        private func jumpAction() -> SCNAction {
            SCNAction.sequence([
                SCNAction.moveBy(x: 0, y: 0.5, z: 0, duration: 0.2),
                SCNAction.rotateBy(x: 0, y: CGFloat.pi, z: 0, duration: 0.25),
                SCNAction.moveBy(x: 0, y: -0.5, z: 0, duration: 0.2),
                SCNAction.moveBy(x: 0, y: 0.15, z: 0, duration: 0.1),
                SCNAction.moveBy(x: 0, y: -0.15, z: 0, duration: 0.1)
            ])
        }

        // MARK: - Stretch Animation

        private func stretchAction() -> SCNAction {
            SCNAction.run { [weak self] _ in
                guard let self else { return }
                // Arms stretch up
                self.leftArmNode?.runAction(SCNAction.sequence([
                    SCNAction.rotateTo(x: 0, y: 0, z: CGFloat.pi * 0.8, duration: 0.5),
                    SCNAction.wait(duration: 1.0),
                    SCNAction.rotateTo(x: 0, y: 0, z: CGFloat.pi / 6, duration: 0.4)
                ]))
                self.rightArmNode?.runAction(SCNAction.sequence([
                    SCNAction.rotateTo(x: 0, y: 0, z: -CGFloat.pi * 0.8, duration: 0.5),
                    SCNAction.wait(duration: 1.0),
                    SCNAction.rotateTo(x: 0, y: 0, z: -CGFloat.pi / 6, duration: 0.4)
                ]))
                // Body stretches up slightly
                self.bodyMeshNode?.runAction(SCNAction.sequence([
                    SCNAction.scale(to: 1.08, duration: 0.5),
                    SCNAction.wait(duration: 0.8),
                    SCNAction.scale(to: 1.0, duration: 0.4)
                ]))
                // Yawn — open mouth wider
                self.mouthNode?.runAction(SCNAction.sequence([
                    SCNAction.scale(to: 1.6, duration: 0.3),
                    SCNAction.wait(duration: 1.0),
                    SCNAction.scale(to: 1.0, duration: 0.3)
                ]))
            }
        }

        // MARK: - Play With Toy

        private func playWithToyAction(_ root: SCNNode) -> SCNAction {
            // Pick a random toy to walk to and play with
            let toys = [toyBallNode, yarnBallNode, cushionNode].compactMap { $0 }
            guard let toy = toys.randomElement() else { return jumpAction() }

            let toyPos = toy.position
            let currentPos = root.position
            let dx = CGFloat(toyPos.x) - CGFloat(currentPos.x)
            let dz = CGFloat(toyPos.z) - CGFloat(currentPos.z)
            let distance = sqrt(dx * dx + dz * dz)
            let walkDuration = Double(distance) * 0.8

            let angle = atan2(dx, dz) + (petCharacter.isVRM ? CGFloat.pi : 0)
            let face = SCNAction.rotateTo(x: 0, y: angle, z: 0, duration: 0.2)
            let walkTo = SCNAction.moveBy(x: dx, y: 0, z: dz, duration: walkDuration)
            walkTo.timingMode = .easeInEaseOut

            // Play animation at the toy
            let playWithIt = SCNAction.run { [weak self] _ in
                guard let self else { return }

                if toy === self.toyBallNode {
                    // Bat the ball — it rolls away
                    self.showSpeechBubble("wheee!")
                    let rollDir = CGFloat.random(in: -1...1)
                    toy.runAction(SCNAction.sequence([
                        SCNAction.group([
                            SCNAction.moveBy(x: rollDir * 0.5, y: 0, z: CGFloat.random(in: -0.3...0.3), duration: 0.4),
                            SCNAction.rotateBy(x: CGFloat.pi * 3, y: 0, z: CGFloat.pi * 2, duration: 0.4)
                        ]),
                        SCNAction.moveBy(x: rollDir * 0.2, y: 0, z: 0.1, duration: 0.3)
                    ]))
                    // Paw bat animation
                    self.rightArmNode?.runAction(SCNAction.sequence([
                        SCNAction.rotateTo(x: -0.6, y: 0, z: -CGFloat.pi * 0.4, duration: 0.15),
                        SCNAction.rotateTo(x: 0, y: 0, z: -CGFloat.pi / 6, duration: 0.2)
                    ]))
                } else if toy === self.yarnBallNode {
                    // Bat the yarn
                    self.showSpeechBubble("hehe!")
                    let rollX = CGFloat.random(in: -0.4...0.4)
                    toy.runAction(SCNAction.group([
                        SCNAction.moveBy(x: rollX, y: 0, z: 0.3, duration: 0.3),
                        SCNAction.rotateBy(x: CGFloat.pi * 4, y: 0, z: 0, duration: 0.3)
                    ]))
                    // Both paws
                    self.leftArmNode?.runAction(SCNAction.sequence([
                        SCNAction.rotateTo(x: -0.5, y: 0, z: CGFloat.pi * 0.3, duration: 0.12),
                        SCNAction.rotateTo(x: 0, y: 0, z: CGFloat.pi / 6, duration: 0.2)
                    ]))
                    self.rightArmNode?.runAction(SCNAction.sequence([
                        SCNAction.rotateTo(x: -0.5, y: 0, z: -CGFloat.pi * 0.3, duration: 0.12),
                        SCNAction.rotateTo(x: 0, y: 0, z: -CGFloat.pi / 6, duration: 0.2)
                    ]))
                } else if toy === self.cushionNode {
                    // Sit on cushion momentarily
                    self.showSpeechBubble("comfy~")
                    self.petBodyNode?.runAction(SCNAction.sequence([
                        SCNAction.moveBy(x: 0, y: -0.15, z: 0, duration: 0.2),
                        SCNAction.wait(duration: 2.0),
                        SCNAction.moveBy(x: 0, y: 0.15, z: 0, duration: 0.2)
                    ]))
                    // Squint eyes contentedly
                    self.leftEyeNode?.runAction(SCNAction.sequence([
                        SCNAction.scale(to: 0.5, duration: 0.2),
                        SCNAction.wait(duration: 1.5),
                        SCNAction.scale(to: 1.0, duration: 0.2)
                    ]))
                    self.rightEyeNode?.runAction(SCNAction.sequence([
                        SCNAction.scale(to: 0.5, duration: 0.2),
                        SCNAction.wait(duration: 1.5),
                        SCNAction.scale(to: 1.0, duration: 0.2)
                    ]))
                }
            }

            let faceCamera = SCNAction.rotateTo(x: 0, y: petCharacter.isVRM ? CGFloat.pi : 0, z: 0, duration: 0.3)

            return SCNAction.sequence([
                face,
                walkTo,
                playWithIt,
                SCNAction.wait(duration: toy === cushionNode ? 2.5 : 0.8),
                faceCamera
            ])
        }

        // MARK: - Bat Yarn (Chase it)

        private func batYarnAction(_ root: SCNNode) -> SCNAction {
            guard let yarn = yarnBallNode else { return jumpAction() }

            return SCNAction.run { [weak self] _ in
                guard let self, let body = self.petBodyNode else { return }

                // Bat yarn to a random spot
                let newX = CGFloat.random(in: -0.6...0.6)
                let newZ = CGFloat.random(in: 0...0.8)
                yarn.runAction(SCNAction.group([
                    SCNAction.move(to: SCNVector3(newX, 0.1, newZ), duration: 0.5),
                    SCNAction.rotateBy(x: CGFloat.pi * 5, y: 0, z: CGFloat.pi * 3, duration: 0.5)
                ]))

                self.showSpeechBubble("catch!")

                // Chase the yarn after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    let dx = newX - CGFloat(body.position.x)
                    let dz = newZ - CGFloat(body.position.z)
                    let angle = atan2(dx, dz) + (self.petCharacter.isVRM ? CGFloat.pi : 0)
                    let dist = sqrt(dx * dx + dz * dz)

                    let chase = SCNAction.sequence([
                        SCNAction.rotateTo(x: 0, y: angle, z: 0, duration: 0.15),
                        SCNAction.moveBy(x: dx, y: 0, z: dz, duration: Double(dist) * 0.4),
                        SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.2)
                    ])
                    body.runAction(chase)
                }
            }
        }

        // MARK: - Screen Escape Animation

        private func screenEscapeAction() -> SCNAction {
            return SCNAction.run { [weak self] _ in
                guard let self, let body = self.petBodyNode else { return }

                // The "screen wall" is toward camera — keep within visible bounds
                let screenZ: CGFloat = 1.2
                let startX = CGFloat(body.position.x)
                let startZ = CGFloat(body.position.z)

                // Step 1: Walk toward the screen (camera direction)
                let dz1 = screenZ - CGFloat(body.position.z)
                let walkToScreen = SCNAction.sequence([
                    SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.2),
                    SCNAction.moveBy(x: 0, y: 0, z: dz1, duration: 0.8)
                ])

                // Hop steps while walking
                self.leftFootNode?.runAction(SCNAction.sequence([
                    SCNAction.rotateTo(x: -0.3, y: 0, z: 0, duration: 0.2),
                    SCNAction.rotateTo(x: 0.3, y: 0, z: 0, duration: 0.2),
                    SCNAction.rotateTo(x: -0.3, y: 0, z: 0, duration: 0.2),
                    SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.2)
                ]))
                self.rightFootNode?.runAction(SCNAction.sequence([
                    SCNAction.rotateTo(x: 0.3, y: 0, z: 0, duration: 0.2),
                    SCNAction.rotateTo(x: -0.3, y: 0, z: 0, duration: 0.2),
                    SCNAction.rotateTo(x: 0.3, y: 0, z: 0, duration: 0.2),
                    SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.2)
                ]))

                body.runAction(walkToScreen) {
                    // Step 2: Press face against screen — lean forward
                    self.showSpeechBubble("hello?? 👀")
                    self.bodyMeshNode?.runAction(SCNAction.sequence([
                        SCNAction.rotateTo(x: -0.15, y: 0, z: 0, duration: 0.3),
                    ]))
                    // Head tilts curiously
                    self.headNode?.runAction(SCNAction.sequence([
                        SCNAction.rotateTo(x: 0, y: 0, z: 0.2, duration: 0.3),
                        SCNAction.wait(duration: 0.5),
                        SCNAction.rotateTo(x: 0, y: 0, z: -0.2, duration: 0.3),
                    ]))

                    // Step 3: Knock on the screen — tap arm forward repeatedly
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        self.showSpeechBubble("*knock knock*")

                        // Right arm knocks forward
                        let knockOnce = SCNAction.sequence([
                            SCNAction.rotateTo(x: -CGFloat.pi * 0.45, y: 0, z: -0.1, duration: 0.12),
                            SCNAction.rotateTo(x: -CGFloat.pi * 0.3, y: 0, z: -0.1, duration: 0.1),
                        ])
                        self.rightArmNode?.runAction(SCNAction.sequence([
                            knockOnce, knockOnce, knockOnce,
                            SCNAction.rotateTo(x: 0, y: 0, z: -CGFloat.pi / 6, duration: 0.2)
                        ]))

                        // Body bounces slightly with each knock
                        let knockBounce = SCNAction.sequence([
                            SCNAction.moveBy(x: 0, y: 0, z: 0.03, duration: 0.12),
                            SCNAction.moveBy(x: 0, y: 0, z: -0.03, duration: 0.1),
                        ])
                        body.runAction(SCNAction.sequence([knockBounce, knockBounce, knockBounce]))
                    }

                    // Step 4: Inspect the right corner
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
                        self.showSpeechBubble("hmm... 🤔")
                        self.bodyMeshNode?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.2))

                        // Shuffle to the right side (constrained to stay visible)
                        let moveRight = SCNAction.sequence([
                            SCNAction.rotateTo(x: 0, y: -CGFloat.pi * 0.3, z: 0, duration: 0.2),
                            SCNAction.moveBy(x: 0.6, y: 0, z: 0, duration: 0.7),
                        ])
                        body.runAction(moveRight) {
                            // Peer into the corner — head tilts and leans
                            self.headNode?.runAction(SCNAction.sequence([
                                SCNAction.rotateTo(x: 0.15, y: -0.3, z: -0.25, duration: 0.3),
                                SCNAction.wait(duration: 0.6),
                                SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.2),
                            ]))
                            self.bodyMeshNode?.runAction(SCNAction.sequence([
                                SCNAction.rotateTo(x: 0, y: -0.15, z: -0.1, duration: 0.3),
                                SCNAction.wait(duration: 0.6),
                                SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.2),
                            ]))

                            // Paw at the corner
                            self.rightArmNode?.runAction(SCNAction.sequence([
                                SCNAction.wait(duration: 0.2),
                                SCNAction.rotateTo(x: -0.5, y: -0.3, z: -0.2, duration: 0.2),
                                SCNAction.rotateTo(x: -0.6, y: -0.4, z: -0.3, duration: 0.15),
                                SCNAction.rotateTo(x: -0.5, y: -0.3, z: -0.2, duration: 0.15),
                                SCNAction.wait(duration: 0.3),
                                SCNAction.rotateTo(x: 0, y: 0, z: -CGFloat.pi / 6, duration: 0.2),
                            ]))
                        }
                    }

                    // Step 5: Move to left corner and check there too
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                        self.showSpeechBubble("is there a gap? 🧐")

                        let moveLeft = SCNAction.sequence([
                            SCNAction.rotateTo(x: 0, y: CGFloat.pi * 0.3, z: 0, duration: 0.2),
                            SCNAction.moveBy(x: -1.2, y: 0, z: 0, duration: 1.0),
                        ])
                        body.runAction(moveLeft) {
                            // Look around the left corner
                            self.headNode?.runAction(SCNAction.sequence([
                                SCNAction.rotateTo(x: 0.15, y: 0.3, z: 0.25, duration: 0.3),
                                SCNAction.wait(duration: 0.4),
                            ]))
                        }
                    }

                    // Step 6: Try to squeeze paw/leg through the "gap"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 7.0) {
                        self.showSpeechBubble("almost..! 😤")

                        // Face forward again
                        body.runAction(SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.2))
                        self.headNode?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.2))

                        // Press body against screen
                        self.bodyMeshNode?.runAction(SCNAction.rotateTo(x: -0.1, y: 0, z: 0, duration: 0.2))

                        // Left arm reaches way forward (through the "screen")
                        self.leftArmNode?.runAction(SCNAction.sequence([
                            SCNAction.rotateTo(x: -CGFloat.pi * 0.55, y: 0, z: 0.2, duration: 0.3),
                            // Wiggle the paw trying to push through
                            SCNAction.rotateTo(x: -CGFloat.pi * 0.6, y: 0.1, z: 0.15, duration: 0.15),
                            SCNAction.rotateTo(x: -CGFloat.pi * 0.55, y: -0.1, z: 0.25, duration: 0.15),
                            SCNAction.rotateTo(x: -CGFloat.pi * 0.65, y: 0.1, z: 0.15, duration: 0.15),
                            SCNAction.rotateTo(x: -CGFloat.pi * 0.55, y: -0.1, z: 0.25, duration: 0.15),
                            SCNAction.rotateTo(x: -CGFloat.pi * 0.6, y: 0.05, z: 0.2, duration: 0.1),
                            // Hold it stretched out
                            SCNAction.wait(duration: 0.5),
                        ]))

                        // Right arm also tries
                        self.rightArmNode?.runAction(SCNAction.sequence([
                            SCNAction.wait(duration: 0.5),
                            SCNAction.rotateTo(x: -CGFloat.pi * 0.55, y: 0, z: -0.2, duration: 0.3),
                            SCNAction.rotateTo(x: -CGFloat.pi * 0.6, y: -0.1, z: -0.15, duration: 0.15),
                            SCNAction.rotateTo(x: -CGFloat.pi * 0.55, y: 0.1, z: -0.25, duration: 0.15),
                            SCNAction.rotateTo(x: -CGFloat.pi * 0.6, y: -0.1, z: -0.15, duration: 0.15),
                            SCNAction.wait(duration: 0.4),
                        ]))

                        // Left foot tries to squeeze through too — kicks forward
                        self.leftFootNode?.runAction(SCNAction.sequence([
                            SCNAction.wait(duration: 1.0),
                            SCNAction.rotateTo(x: -0.6, y: 0, z: 0, duration: 0.2),
                            SCNAction.rotateTo(x: -0.7, y: 0, z: 0, duration: 0.15),
                            SCNAction.rotateTo(x: -0.55, y: 0, z: 0, duration: 0.15),
                            SCNAction.rotateTo(x: -0.7, y: 0, z: 0, duration: 0.15),
                            SCNAction.wait(duration: 0.3),
                            SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.2),
                        ]))

                        // Body pushes forward
                        body.runAction(SCNAction.sequence([
                            SCNAction.moveBy(x: 0, y: 0, z: 0.1, duration: 0.3),
                            SCNAction.moveBy(x: 0, y: 0, z: 0.05, duration: 0.15),
                            SCNAction.moveBy(x: 0, y: 0, z: -0.05, duration: 0.15),
                            SCNAction.moveBy(x: 0, y: 0, z: 0.05, duration: 0.15),
                            SCNAction.moveBy(x: 0, y: 0, z: -0.15, duration: 0.2),
                        ]))
                    }

                    // Step 7: Give up — sigh and walk back
                    DispatchQueue.main.asyncAfter(deadline: .now() + 9.5) {
                        self.showSpeechBubble("hmph! 😤")

                        // Reset arms, body, head
                        self.leftArmNode?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: CGFloat.pi / 6, duration: 0.3))
                        self.rightArmNode?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: -CGFloat.pi / 6, duration: 0.3))
                        self.bodyMeshNode?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.3))
                        self.headNode?.runAction(SCNAction.sequence([
                            // Dejected head shake
                            SCNAction.rotateTo(x: 0.1, y: 0.15, z: 0, duration: 0.15),
                            SCNAction.rotateTo(x: 0.1, y: -0.15, z: 0, duration: 0.3),
                            SCNAction.rotateTo(x: 0.1, y: 0.15, z: 0, duration: 0.3),
                            SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.2),
                        ]))

                        // Turn around and walk back to center
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            let returnX = CGFloat.random(in: -0.5...0.5)
                            let returnZ = CGFloat.random(in: 0...0.5)
                            let dx = returnX - CGFloat(body.position.x)
                            let dz = returnZ - CGFloat(body.position.z)
                            let angle = atan2(dx, dz) + (self.petCharacter.isVRM ? CGFloat.pi : 0)
                            let dist = sqrt(dx * dx + dz * dz)

                            body.runAction(SCNAction.sequence([
                                SCNAction.rotateTo(x: 0, y: angle, z: 0, duration: 0.3),
                                SCNAction.moveBy(x: dx, y: 0, z: dz, duration: Double(dist) * 0.6),
                                SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.2),
                            ]))

                            // Sad tail droop momentarily
                            self.tailNode?.removeAction(forKey: "tailWag")
                            self.tailNode?.runAction(SCNAction.sequence([
                                SCNAction.rotateTo(x: 0.3, y: 0, z: 0, duration: 0.3),
                                SCNAction.wait(duration: 1.5),
                                SCNAction.rotateTo(x: -0.2, y: 0, z: 0, duration: 0.3),
                            ])) {
                                self.startTailWag()
                            }

                            self.showSpeechBubble("fine... 😒")
                        }
                    }
                }
            }
        }

        // MARK: - Topple Check (called during walk)

        private func checkForTopples(at position: SCNVector3) {
            let toppleTargets: [(node: SCNNode?, name: String, originalPos: SCNVector3)] = [
                (bookStackNode, "bookStack", SCNVector3(0.8, 0, -1.0)),
                (plantNode, "plant", SCNVector3(-1.6, 0.075, 0.3)),
            ]

            for target in toppleTargets {
                guard let node = target.node else { continue }
                // Already toppled?
                if toppledObjects.contains(where: { $0 === node }) { continue }

                let dx = CGFloat(position.x) - CGFloat(node.position.x)
                let dz = CGFloat(position.z) - CGFloat(node.position.z)
                let dist = sqrt(dx * dx + dz * dz)

                if dist < 0.5 {
                    // Topple it!
                    toppledObjects.append(node)
                    let toppleDir: CGFloat = dx > 0 ? 1 : -1

                    node.runAction(SCNAction.sequence([
                        SCNAction.group([
                            SCNAction.rotateBy(x: toppleDir * 0.8, y: 0, z: toppleDir * 0.4, duration: 0.25),
                            SCNAction.moveBy(x: toppleDir * 0.15, y: -0.02, z: 0, duration: 0.25)
                        ]),
                    ]))

                    // Pet reacts — "oopsie!" then goes to fix it
                    showSpeechBubble(["oopsie!", "uh oh!", "oh no!", "whoops!"].randomElement()!)

                    // After a pause, go pick it up
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                        self?.fixToppledObject(node, originalPos: target.originalPos)
                    }
                }
            }
        }

        private func fixToppledObject(_ node: SCNNode, originalPos: SCNVector3) {
            guard let body = petBodyNode else { return }

            let dx = CGFloat(node.position.x) - CGFloat(body.position.x)
            let dz = CGFloat(node.position.z) - CGFloat(body.position.z)
            let angle = atan2(dx, dz) + (petCharacter.isVRM ? CGFloat.pi : 0)
            let dist = sqrt(dx * dx + dz * dz)

            let walkToIt = SCNAction.sequence([
                SCNAction.rotateTo(x: 0, y: angle, z: 0, duration: 0.2),
                SCNAction.moveBy(x: dx, y: 0, z: dz, duration: Double(dist) * 0.8)
            ])

            let fixIt = SCNAction.run { [weak self] _ in
                // Pet bends down (lean forward)
                self?.bodyMeshNode?.runAction(SCNAction.sequence([
                    SCNAction.rotateTo(x: 0.25, y: 0, z: 0, duration: 0.3),
                    SCNAction.wait(duration: 0.5),
                    SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.3)
                ]))
                // Arms reach down
                self?.leftArmNode?.runAction(SCNAction.sequence([
                    SCNAction.rotateTo(x: -0.5, y: 0, z: 0.1, duration: 0.3),
                    SCNAction.wait(duration: 0.5),
                    SCNAction.rotateTo(x: 0, y: 0, z: CGFloat.pi / 6, duration: 0.3)
                ]))
                self?.rightArmNode?.runAction(SCNAction.sequence([
                    SCNAction.rotateTo(x: -0.5, y: 0, z: -0.1, duration: 0.3),
                    SCNAction.wait(duration: 0.5),
                    SCNAction.rotateTo(x: 0, y: 0, z: -CGFloat.pi / 6, duration: 0.3)
                ]))

                self?.showSpeechBubble(["all fixed!", "there we go!", "good as new!"].randomElement()!)

                // Fix the object — restore position and rotation
                node.runAction(SCNAction.sequence([
                    SCNAction.wait(duration: 0.3),
                    SCNAction.group([
                        SCNAction.move(to: originalPos, duration: 0.4),
                        SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.4)
                    ])
                ]))

                // Remove from toppled list
                self?.toppledObjects.removeAll { $0 === node }
            }

            let faceCamera = SCNAction.rotateTo(x: 0, y: petCharacter.isVRM ? CGFloat.pi : 0, z: 0, duration: 0.3)

            body.runAction(SCNAction.sequence([walkToIt, fixIt, SCNAction.wait(duration: 1.2), faceCamera]), forKey: "fixTopple")
        }

        // MARK: - Speech Bubble

        private func showSpeechBubble(_ text: String) {
            guard let scene = sceneRef, let body = petBodyNode else { return }

            // Remove any existing speech bubble
            scene.rootNode.childNode(withName: "speechBubble", recursively: false)?.removeFromParentNode()

            // Don't show speech bubbles while sleeping (except sleepy mumbles handled separately)
            // Render the bubble + text as a 2D image with word wrapping.
            let fontSize: CGFloat = 26
            let font = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            paragraphStyle.lineBreakMode = .byWordWrapping
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.black,
                .paragraphStyle: paragraphStyle
            ]

            // Constrain max width so long thoughts wrap
            let maxTextWidth: CGFloat = 320
            let hPad: CGFloat = 20
            let vPad: CGFloat = 14
            let triHeight: CGFloat = 12

            let constraintRect = CGSize(width: maxTextWidth, height: .greatestFiniteMagnitude)
            let textRect = (text as NSString).boundingRect(
                with: constraintRect,
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attributes
            )
            let textWidth = ceil(textRect.width)
            let textHeight = ceil(textRect.height)
            let imgWidth = textWidth + hPad * 2
            let imgHeight = textHeight + vPad * 2 + triHeight

            let image = NSImage(size: NSSize(width: imgWidth, height: imgHeight), flipped: true) { _ in
                let bubbleRect = NSRect(x: 0, y: 0, width: imgWidth, height: imgHeight - triHeight)
                let bubblePath = NSBezierPath(roundedRect: bubbleRect, xRadius: 12, yRadius: 12)
                NSColor.white.withAlphaComponent(0.92).setFill()
                bubblePath.fill()

                // Subtle border
                NSColor.black.withAlphaComponent(0.08).setStroke()
                bubblePath.lineWidth = 1
                bubblePath.stroke()

                // Triangle pointer at bottom center
                let triPath = NSBezierPath()
                let cx = imgWidth / 2
                triPath.move(to: NSPoint(x: cx - 7, y: imgHeight - triHeight))
                triPath.line(to: NSPoint(x: cx, y: imgHeight))
                triPath.line(to: NSPoint(x: cx + 7, y: imgHeight - triHeight))
                triPath.close()
                NSColor.white.withAlphaComponent(0.92).setFill()
                triPath.fill()

                // Draw text with wrapping
                let textOrigin = NSRect(x: hPad, y: vPad, width: maxTextWidth, height: textHeight)
                (text as NSString).draw(in: textOrigin, withAttributes: attributes)
                return true
            }

            // Scale: map pixel size to scene units — adapt to view size so bubble fits in small widgets
            let viewWidth = scnViewRef?.bounds.width ?? 300
            let scaleFactor: CGFloat = max(180, min(280, viewWidth * 0.8))
            let planeWidth = imgWidth / scaleFactor
            let planeHeight = imgHeight / scaleFactor

            let planeGeo = SCNPlane(width: planeWidth, height: planeHeight)
            let planeMat = SCNMaterial()
            planeMat.diffuse.contents = image
            planeMat.isDoubleSided = true
            planeMat.lightingModel = .constant
            planeMat.transparencyMode = .aOne
            planeGeo.materials = [planeMat]

            let bubbleNode = SCNNode(geometry: planeGeo)
            bubbleNode.name = "speechBubble"
            // Position above pet, clamped to stay within visible camera frustum
            // Use a modest Y to avoid clipping at top when widget is small
            let petY = min(1.8, CGFloat(body.position.y) + 1.2)
            let bubbleX = max(-0.5, min(0.5, CGFloat(body.position.x)))
            let bubbleZ = CGFloat(body.position.z) + 0.5 // Closer to camera so it's always visible
            bubbleNode.position = SCNVector3(bubbleX, petY, bubbleZ)

            // Always face camera
            let constraint = SCNBillboardConstraint()
            constraint.freeAxes = .all
            bubbleNode.constraints = [constraint]

            scene.rootNode.addChildNode(bubbleNode)

            // Pop in with slight bounce
            bubbleNode.scale = SCNVector3(0.01, 0.01, 0.01)
            let displayDuration = max(2.5, Double(text.count) * 0.06)  // longer text stays longer
            bubbleNode.runAction(SCNAction.sequence([
                SCNAction.scale(to: 1.05, duration: 0.12),
                SCNAction.scale(to: 1.0, duration: 0.06),
                SCNAction.wait(duration: displayDuration),
                SCNAction.group([
                    SCNAction.scale(to: 0.01, duration: 0.2),
                    SCNAction.fadeOut(duration: 0.2)
                ]),
                SCNAction.removeFromParentNode()
            ]))
        }

        // MARK: - Expression Helpers

        private func wiggleEars() {
            let wiggle = SCNAction.sequence([
                SCNAction.rotateBy(x: 0.2, y: 0, z: 0.15, duration: 0.1),
                SCNAction.rotateBy(x: -0.4, y: 0, z: -0.3, duration: 0.2),
                SCNAction.rotateBy(x: 0.2, y: 0, z: 0.15, duration: 0.1)
            ])
            leftEarNode?.runAction(wiggle)
            rightEarNode?.runAction(wiggle)
        }

        private func showHappyFace() {
            // Bigger cheeks
            leftCheekNode?.runAction(SCNAction.sequence([
                SCNAction.scale(to: 1.5, duration: 0.15),
                SCNAction.wait(duration: 0.6),
                SCNAction.scale(to: 1.0, duration: 0.2)
            ]))
            rightCheekNode?.runAction(SCNAction.sequence([
                SCNAction.scale(to: 1.5, duration: 0.15),
                SCNAction.wait(duration: 0.6),
                SCNAction.scale(to: 1.0, duration: 0.2)
            ]))

            // Pupils dilate (happy = big pupils)
            leftPupilNode?.runAction(SCNAction.sequence([
                SCNAction.scale(to: 1.4, duration: 0.15),
                SCNAction.wait(duration: 0.6),
                SCNAction.scale(to: 1.0, duration: 0.2)
            ]))
            rightPupilNode?.runAction(SCNAction.sequence([
                SCNAction.scale(to: 1.4, duration: 0.15),
                SCNAction.wait(duration: 0.6),
                SCNAction.scale(to: 1.0, duration: 0.2)
            ]))

            // Faster tail wag
            tailNode?.removeAction(forKey: "tailWag")
            let fastWag = SCNAction.sequence([
                SCNAction.rotateBy(x: 0, y: 0.4, z: 0.25, duration: 0.1),
                SCNAction.rotateBy(x: 0, y: -0.8, z: -0.5, duration: 0.2),
                SCNAction.rotateBy(x: 0, y: 0.4, z: 0.25, duration: 0.1)
            ])
            tailNode?.runAction(SCNAction.repeat(fastWag, count: 5)) { [weak self] in
                self?.startTailWag()
            }
        }


        func updateMood(pet: UserDataStore.PetStateData, in scene: SCNScene?) {
            let avg = (pet.health + pet.hunger + pet.happiness) / 3

            // Show/hide cheeks based on mood
            let showCheeks = avg >= 60 && pet.isAlive
            leftCheekNode?.opacity = showCheeks ? 1.0 : 0.0
            rightCheekNode?.opacity = showCheeks ? 1.0 : 0.0

            // Droopy eyes when sad
            let eyeScale: CGFloat = (avg < 30 && pet.isAlive) ? 0.7 : 1.0
            leftEyeNode?.scale = SCNVector3(1, eyeScale, 1)
            rightEyeNode?.scale = SCNVector3(1, eyeScale, 1)

            // Sad pupil position (looking down)
            if avg < 30 && pet.isAlive {
                leftPupilNode?.position = SCNVector3(0, -0.02, 0.06)
                rightPupilNode?.position = SCNVector3(0, -0.02, 0.06)
            } else {
                leftPupilNode?.position = SCNVector3(0, 0, 0.06)
                rightPupilNode?.position = SCNVector3(0, 0, 0.06)
            }

            // Mouth changes with mood
            if pet.isAlive {
                if avg > 70 {
                    // Happy — big smile
                    mouthNode?.scale = SCNVector3(1.2, 1.2, 1.2)
                    mouthNode?.eulerAngles.x = CGFloat.pi / 6
                } else if avg < 30 {
                    // Sad — frown (flip mouth)
                    mouthNode?.scale = SCNVector3(0.8, 0.8, 0.8)
                    mouthNode?.eulerAngles.x = -CGFloat.pi / 6
                } else {
                    // Neutral
                    mouthNode?.scale = SCNVector3(1, 1, 1)
                    mouthNode?.eulerAngles.x = CGFloat.pi / 12
                }
            }

            // Ears droop when sad
            if avg < 30 && pet.isAlive {
                leftEarNode?.position = SCNVector3(-0.25, 0.24, 0)
                rightEarNode?.position = SCNVector3(0.25, 0.24, 0)
            } else {
                leftEarNode?.position = SCNVector3(-0.22, 0.32, 0)
                rightEarNode?.position = SCNVector3(0.22, 0.32, 0)
            }

            // Tail wag speed based on happiness
            if pet.isAlive {
                tailNode?.removeAction(forKey: "tailWag")
                let wagSpeed = pet.happiness > 60 ? 0.15 : (pet.happiness > 30 ? 0.25 : 0.5)
                let amplitude: CGFloat = pet.happiness > 60 ? 0.35 : 0.15
                let wag = SCNAction.sequence([
                    SCNAction.rotateBy(x: 0, y: amplitude, z: amplitude * 0.6, duration: wagSpeed),
                    SCNAction.rotateBy(x: 0, y: -amplitude * 2, z: -amplitude * 1.2, duration: wagSpeed * 2),
                    SCNAction.rotateBy(x: 0, y: amplitude, z: amplitude * 0.6, duration: wagSpeed)
                ])
                wag.timingMode = .easeInEaseOut
                tailNode?.runAction(.repeatForever(wag), forKey: "tailWag")
            }
        }

        // MARK: - Interactive Feeding

        func handleFeedTrigger(_ trigger: Int, in scene: SCNScene?) {
            guard trigger > lastFeedTrigger, let scene, let body = petBodyNode else {
                lastFeedTrigger = trigger
                return
            }
            lastFeedTrigger = trigger

            // Drop food near the pet — character-specific foods
            let pers = petCharacter.personality
            let foodItems = pers.foods
            let foodEmoji = foodItems.randomElement()!
            // Show excited reaction
            showSpeechBubble("\(foodEmoji) yay, food!")

            let dropX = CGFloat(body.position.x) + CGFloat.random(in: -0.5...0.5)
            let dropZ = CGFloat(body.position.z) + CGFloat.random(in: 0.3...0.6)

            // Food bowl
            let bowlGeo = SCNCylinder(radius: 0.12, height: 0.04)
            let bowlMat = SCNMaterial()
            bowlMat.diffuse.contents = NSColor(red: 0.85, green: 0.5, blue: 0.3, alpha: 1)
            bowlMat.roughness.contents = NSColor(white: 0.7, alpha: 1)
            bowlGeo.materials = [bowlMat]
            let bowl = SCNNode(geometry: bowlGeo)
            bowl.name = "foodBowl"
            bowl.position = SCNVector3(dropX, 2.5, dropZ)  // start above
            scene.rootNode.addChildNode(bowl)

            // Food sphere on top
            let foodGeo = SCNSphere(radius: 0.06)
            foodGeo.segmentCount = 16
            let foodMat = SCNMaterial()
            foodMat.diffuse.contents = NSColor(red: 0.9, green: 0.4, blue: 0.3, alpha: 1)
            foodGeo.materials = [foodMat]
            let food = SCNNode(geometry: foodGeo)
            food.position = SCNVector3(0, 0.05, 0)
            bowl.addChildNode(food)

            // Drop animation
            bowl.runAction(SCNAction.sequence([
                SCNAction.move(to: SCNVector3(dropX, 0.02, dropZ), duration: 0.4),
                SCNAction.moveBy(x: 0, y: 0.05, z: 0, duration: 0.08),
                SCNAction.moveBy(x: 0, y: -0.05, z: 0, duration: 0.08),
            ]))

            // Pet notices and walks to the food
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                guard let self, let body = self.petBodyNode else { return }

                // Stop current behavior
                body.removeAction(forKey: "behavior")

                // Face food
                let dx = dropX - CGFloat(body.position.x)
                let dz = dropZ - CGFloat(body.position.z)
                let angle = atan2(dx, dz) + (petCharacter.isVRM ? CGFloat.pi : 0)
                let faceFood = SCNAction.rotateTo(x: 0, y: angle, z: 0, duration: 0.2)

                // Walk to food
                let walkToFood = SCNAction.move(
                    to: SCNVector3(dropX, CGFloat(body.position.y), dropZ - 0.2),
                    duration: 0.6
                )
                walkToFood.timingMode = .easeInEaseOut

                // Foot waddle
                let waddle = SCNAction.sequence([
                    SCNAction.moveBy(x: 0, y: 0.04, z: 0, duration: 0.1),
                    SCNAction.moveBy(x: 0, y: -0.04, z: 0, duration: 0.1)
                ])
                self.leftFootNode?.runAction(SCNAction.repeat(waddle, count: 3))
                self.rightFootNode?.runAction(SCNAction.sequence([
                    SCNAction.wait(duration: 0.1),
                    SCNAction.repeat(waddle, count: 3)
                ]))

                // Eat animation: lean forward + nom nom
                let eatSequence = SCNAction.sequence([
                    faceFood,
                    walkToFood,
                    // Lean down to eat
                    SCNAction.run { _ in
                        DispatchQueue.main.async {
                            self.showExpression(.excited)
                            self.headNode?.runAction(SCNAction.rotateTo(x: 0.3, y: 0, z: 0, duration: 0.2))
                        }
                    },
                    // Nom nom nom (head bobs)
                    SCNAction.repeat(SCNAction.sequence([
                        SCNAction.run { _ in
                            DispatchQueue.main.async {
                                self.headNode?.runAction(SCNAction.sequence([
                                    SCNAction.rotateTo(x: 0.4, y: 0, z: 0, duration: 0.12),
                                    SCNAction.rotateTo(x: 0.25, y: 0, z: 0, duration: 0.12),
                                ]))
                            }
                        },
                        SCNAction.wait(duration: 0.3),
                    ]), count: 4),
                    // Food disappears
                    SCNAction.run { _ in
                        DispatchQueue.main.async {
                            food.runAction(SCNAction.sequence([
                                SCNAction.scale(to: 0.01, duration: 0.2),
                                SCNAction.removeFromParentNode()
                            ]))
                            self.headNode?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.3))
                            self.showExpression(.happy)
                            // Satisfied reaction
                            let reactions = ["yummy~! \(foodEmoji)", "nom nom nom~ \(foodEmoji)", "so good!! \(foodEmoji)", "*happy tummy noises* \(foodEmoji)", "delicious~! \(foodEmoji)"]
                            self.showSpeechBubble(reactions.randomElement()!)
                        }
                    },
                    SCNAction.wait(duration: 0.5),
                    // Remove bowl
                    SCNAction.run { _ in
                        DispatchQueue.main.async {
                            bowl.runAction(SCNAction.sequence([
                                SCNAction.fadeOut(duration: 0.3),
                                SCNAction.removeFromParentNode()
                            ]))
                        }
                    },
                    SCNAction.wait(duration: 0.3),
                ])

                body.runAction(eatSequence, forKey: "eating")
            }
        }
    }
}

private struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed &+ 0x9E3779B97F4A7C15
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
