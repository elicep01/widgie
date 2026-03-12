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
        case .fluffy:
            return PetPersonality(
                name: "Fluffy",
                species: "cloud puff",
                trait: "dreamy",
                bodyColor: NSColor(red: 0.95, green: 0.72, blue: 0.85, alpha: 1),
                accentColor: NSColor(red: 0.88, green: 0.55, blue: 0.75, alpha: 1),
                bellyColor: NSColor(red: 0.98, green: 0.88, blue: 0.93, alpha: 1),
                hatchGreeting: "oh!! hello there~ 🥺💕\ni just hatched! *blush*\ni'm so soft and fluffy~",
                hatchButton: "aww hi little one! 💗",
                askNameLine: "what's your name, friend? 👀\ni wanna know who my\nfavorite person is~",
                greetingLine: { name in "hi \(name)~! ☺️💕\nfrom now on, i'm your\nlil cloud puff!\nplease give me lots\nof cuddles okay? 🥺" },
                greetingButton: "of course! 💕",
                askPetNameLine: { name in "so \(name), what would\nyou like to name me? 🤔✨\npick something cute~!" },
                floorColor: NSColor(red: 0.92, green: 0.82, blue: 0.78, alpha: 1),
                rugColor: NSColor(red: 0.95, green: 0.75, blue: 0.85, alpha: 0.25),
                wallTint: NSColor(red: 0.98, green: 0.88, blue: 0.92, alpha: 0.1),
                shelfItemColors: [.systemPink, .systemPurple, .magenta, .systemRed, .systemOrange],
                roomAccent: "🌸",
                windowScene: .nightSky,
                foods: ["🍰", "🧁", "🍩", "🍪", "🍓", "🫧"],
                toyBallColor: NSColor.systemPink,
                yarnColor: NSColor(red: 0.95, green: 0.65, blue: 0.85, alpha: 0.7),
                cushionColor: NSColor(red: 0.9, green: 0.7, blue: 0.85, alpha: 0.4),
                favoriteGame: "Yarn Play",
                idleThoughts: [
                    "i think the clouds are gossiping about me~",
                    "do you think stars get lonely? 🥺",
                    "my fluff feels extra soft today~",
                    "if i stare at the ceiling long enough, it stares back",
                    "i wonder if my dreams have dreams...",
                    "the dust sparkles are my tiny friends ✨",
                    "sometimes i forget i'm real and that's okay~",
                    "*dreamily stares at nothing*",
                    "what if we're inside someone's snow globe? 🫧",
                    "i just had the softest thought~",
                    "the silence sounds like cotton candy 🍭",
                    "my heart is doing the warm thing again 💕",
                ],
                morningGreetings: [
                    "mmm... five more minutes... 🥱💕",
                    "good morning~ did you sleep well? 🌸",
                    "the sunrise is so pretty... like a warm hug~",
                    "*yawns and stretches* hi~ ☀️",
                    "morning cuddles? please? 🥺",
                    "i dreamed about clouds made of marshmallows~",
                ],
                afternoonThoughts: [
                    "*yaaaawn* so sleepy after lunch~ 😴💕",
                    "nap time...? nap time. 💤",
                    "my eyes are doing the heavy thing...",
                    "the afternoon sun is making me all warm and cozy~",
                    "i could use a cuddle nap right about now... 🥱",
                ],
                eveningThoughts: [
                    "the stars are coming out~ so pretty ✨",
                    "today was nice... was it nice for you too? 💕",
                    "i love this cozy time of day~",
                    "the window looks so magical at night 🌙",
                    "can we just stay like this forever? 🥺",
                ],
                sleepyThoughts: [
                    "zzz... *mumbles* ...more cuddles... 💤",
                    "*sleep talking* ...no the cloud is mine...",
                    "zzz... 🌙💕",
                ],
                hungryThoughts: [
                    "my tummy is making the rumbly noise... 🥺",
                    "is it snack time? pretty please? 🍰",
                    "i'm so hungry i might eat a cloud~",
                    "food... food would be nice... 💕",
                    "i think my belly is writing me a letter... it says FEED ME 🥺",
                ],
                happyThoughts: [
                    "i love everything right now~!! 💕✨",
                    "my heart is SO full!! 🥰",
                    "*happy wiggle* life is wonderful~",
                    "you make everything better 💗",
                    "i'm the happiest little puff in the world~!",
                ],
                matColor: NSColor(red: 0.95, green: 0.8, blue: 0.9, alpha: 0.5),
                matEmoji: "☁️",
                sleepStyle: "curled up"
            )

        case .pongoGreen:
            return PetPersonality(
                name: "Pongo",
                species: "lil' dino",
                trait: "adventurous",
                bodyColor: NSColor(red: 0.55, green: 0.82, blue: 0.22, alpha: 1),
                accentColor: NSColor(red: 0.45, green: 0.72, blue: 0.18, alpha: 1),
                bellyColor: NSColor(red: 0.78, green: 0.92, blue: 0.55, alpha: 1),
                hatchGreeting: "RAWR!! 🦖✨ hiya!!\ni'm here! i'm HERE!\nlet's go on adventures!!",
                hatchButton: "whoa there buddy! 🌿",
                askNameLine: "ooh ooh!! who are you?!\ntell me your name!! 🤩",
                greetingLine: { name in "YESSS \(name)!! 🎉\nwe're gonna be the\nbest team EVER!!\ni'll protect you!! 💪🦖" },
                greetingButton: "let's goooo! 🌟",
                askPetNameLine: { name in "hey \(name)! what's\nmy cool adventure name\ngonna be?? 🗺️✨" },
                floorColor: NSColor(red: 0.78, green: 0.85, blue: 0.65, alpha: 1),
                rugColor: NSColor(red: 0.55, green: 0.78, blue: 0.35, alpha: 0.2),
                wallTint: NSColor(red: 0.82, green: 0.92, blue: 0.72, alpha: 0.08),
                shelfItemColors: [.systemGreen, .systemBrown, .systemYellow, .systemOrange, .systemTeal],
                roomAccent: "🌿",
                windowScene: .garden,
                foods: ["🍖", "🥩", "🥕", "🌽", "🍗", "🥦"],
                toyBallColor: NSColor.systemGreen,
                yarnColor: NSColor(red: 0.6, green: 0.8, blue: 0.3, alpha: 0.7),
                cushionColor: NSColor(red: 0.5, green: 0.75, blue: 0.3, alpha: 0.35),
                favoriteGame: "Fetch Ball",
                idleThoughts: [
                    "i bet i could climb that shelf!! 🧗",
                    "RAWR!! ...did i scare you? 🦖",
                    "there's definitely treasure behind that wall",
                    "adventure is out there!! ...or in here. both good.",
                    "i just did 10 push-ups in my head 💪",
                    "the floor is lava!! wait no it's not. phew.",
                    "i smell something... ADVENTURE!! 🗺️",
                    "what if there's a secret passage in this room?!",
                    "*practices karate moves* hi-YAH! 🥋",
                    "i could totally fight a dragon. probably.",
                    "my dino ancestors would be so proud rn 🦖",
                    "every room is an adventure if you believe hard enough!",
                ],
                morningGreetings: [
                    "GOOD MORNING!! LET'S GOOOO!! 🌟",
                    "rise and shine!! adventure awaits!! ☀️💪",
                    "YAWN— I MEAN RAWR!! morning!! 🦖",
                    "breakfast fuel for MAXIMUM ADVENTURE!! 🍖",
                    "today is gonna be EPIC i can feel it!!",
                    "morning training starts NOW!! *does jumping jacks*",
                ],
                afternoonThoughts: [
                    "ugh... food coma... even adventurers need rest... 😴",
                    "maybe just a quick... power nap... for strength... 💪😴",
                    "the afternoon sun is... making me... sleepy... NO! ADVENTURE! ...zzz",
                    "recharging my dino batteries... 🔋🦖",
                    "even the greatest explorers nap... right? 😅",
                ],
                eveningThoughts: [
                    "today's adventures were AWESOME!! 🌟",
                    "the sunset looks like dragon fire!! cool!! 🔥",
                    "time to plan tomorrow's missions! 🗺️",
                    "i explored SO much today... i'm proud of us! 💪",
                    "night patrol begins! i'll keep you safe!! 🦖🛡️",
                ],
                sleepyThoughts: [
                    "zzz... *mumbles* ...i found the treasure... 💤🗺️",
                    "*sleep-fighting dragons* ...take THAT... zzz 🐉",
                    "zzz... adventure... tomorrow... 💪💤",
                ],
                hungryThoughts: [
                    "an adventurer needs FUEL!! FEED ME!! 🍖💪",
                    "i can't fight dragons on an empty stomach!! 🦖",
                    "FOOD!! my energy bar is at like... 2%!! 🔋",
                    "even dinos need to eat!! RAWR means hungry!! 🍗",
                    "quest objective: FIND FOOD!! priority: URGENT!! 🚨",
                ],
                happyThoughts: [
                    "THIS IS THE BEST DAY EVER!! 🎉🦖",
                    "i'm SO PUMPED!! let's go EVERYWHERE!! 💪✨",
                    "RAWR!! that's happy RAWR!! 🦖💕",
                    "everything is AWESOME and YOU'RE awesome!! 🌟",
                    "i have the best human in the WORLD!! 🏆",
                ],
                matColor: NSColor(red: 0.5, green: 0.75, blue: 0.3, alpha: 0.5),
                matEmoji: "🗺️",
                sleepStyle: "sprawled"
            )

        case .pongoWhite:
            return PetPersonality(
                name: "Sir Pongo",
                species: "gentleman blob",
                trait: "sophisticated",
                bodyColor: NSColor(white: 0.92, alpha: 1),
                accentColor: NSColor(white: 0.82, alpha: 1),
                bellyColor: NSColor(white: 0.96, alpha: 1),
                hatchGreeting: "ah, splendid~ 🎩✨\ni do believe i've arrived.\n*adjusts bowler hat*\ncharmed, truly.",
                hatchButton: "well hello there~ 🫖",
                askNameLine: "might i inquire as to\nyour name, dear friend? 🧐",
                greetingLine: { name in "ah, \(name)! what a\nlovely name~ 🫖✨\ni shall be your most\ndistinguished companion.\ndo keep the tea warm~ ☕" },
                greetingButton: "absolutely, good sir~ 🎩",
                askPetNameLine: { name in "now then \(name),\nwhat shall my\nproper title be? 📜✨" },
                floorColor: NSColor(red: 0.82, green: 0.78, blue: 0.72, alpha: 1),
                rugColor: NSColor(red: 0.65, green: 0.55, blue: 0.42, alpha: 0.2),
                wallTint: NSColor(red: 0.88, green: 0.85, blue: 0.78, alpha: 0.08),
                shelfItemColors: [.systemBrown, .darkGray, .systemIndigo, .systemGray, .systemYellow],
                roomAccent: "🫖",
                windowScene: .sunset,
                foods: ["☕", "🫖", "🧀", "🥐", "🍷", "🎂"],
                toyBallColor: NSColor(white: 0.7, alpha: 1),
                yarnColor: NSColor(red: 0.6, green: 0.55, blue: 0.5, alpha: 0.6),
                cushionColor: NSColor(red: 0.7, green: 0.6, blue: 0.5, alpha: 0.35),
                favoriteGame: "Laser Chase",
                idleThoughts: [
                    "i wonder if the books on that shelf are first editions~ 📚",
                    "*sips imaginary tea* exquisite.",
                    "this room could use a chandelier, don't you think? 🫖",
                    "ah, the quiet dignity of a well-kept space~",
                    "i do believe that pixel is slightly off-center. tsk.",
                    "*adjusts invisible monocle* 🧐",
                    "one simply does not rush these things~",
                    "the art of doing nothing is vastly underrated.",
                    "my bowler hat collection grows in my imagination 🎩",
                    "a proper gentleman always tidies his thoughts~",
                    "i detect notes of... existential whimsy in the air.",
                    "shall we ponder the nature of consciousness? over tea, of course ☕",
                ],
                morningGreetings: [
                    "good morning~ shall i ring for breakfast? 🫖☀️",
                    "ah, another splendid day. earl grey, two sugars~ ☕",
                    "one must greet the morning with dignity and caffeine 🎩",
                    "*stretches elegantly* the morning light is rather agreeable~",
                    "breakfast is, in my estimation, the most civilized meal 🥐",
                    "rise and shine, as they say. though i prefer 'ascend and luminesce' ✨",
                ],
                afternoonThoughts: [
                    "ah, the post-luncheon drowsiness... how pedestrian... yet irresistible 😴🫖",
                    "perhaps a brief constitutional nap is in order~ 💤",
                    "even the finest minds require afternoon respite...",
                    "the afternoon slump, a universal truth even i cannot escape~ 🧐😴",
                    "*yawns politely behind hand* do excuse me~",
                ],
                eveningThoughts: [
                    "the evening ambiance is quite satisfactory~ 🌅",
                    "nothing like a good sunset to contemplate one's place in the cosmos 🎩",
                    "shall we retire to the drawing room? oh wait, this IS the room~ 🫖",
                    "twilight hour~ the most philosophical time of day ✨",
                    "i believe a digestif is in order. metaphorically speaking, of course 🍷",
                ],
                sleepyThoughts: [
                    "zzz... *mumbles* ...the tea is... perfectly steeped... 💤🫖",
                    "*sleep-adjusting bowler hat* ...quite... 🎩💤",
                    "zzz... distinguished... slumber... ☕💤",
                ],
                hungryThoughts: [
                    "i say, might we arrange for luncheon? my constitution requires it 🥐",
                    "a gentleman does not beg, but... perhaps a small morsel? 🧐",
                    "one cannot maintain proper decorum on an empty stomach 🫖",
                    "i believe it is well past tea time... hint hint ☕",
                    "the hunger pangs, they are most... ungentlemanly 😤",
                ],
                happyThoughts: [
                    "i must say, life is rather splendid at the moment~ 🎩✨",
                    "*tips imaginary hat* you are a most excellent companion 🫖",
                    "contentment, thy name is... well, me. right now. 💫",
                    "ah, this is what the poets write about~ ☕✨",
                    "one is simply... overjoyed. in a dignified manner, naturally 🧐💕",
                ],
                matColor: NSColor(red: 0.7, green: 0.6, blue: 0.5, alpha: 0.45),
                matEmoji: "🫖",
                sleepStyle: "on back"
            )

        case .pongoPurple:
            return PetPersonality(
                name: "Pongo",
                species: "shy blob",
                trait: "melancholy",
                bodyColor: NSColor(red: 0.72, green: 0.28, blue: 0.65, alpha: 1),
                accentColor: NSColor(red: 0.62, green: 0.22, blue: 0.58, alpha: 1),
                bellyColor: NSColor(red: 0.85, green: 0.55, blue: 0.8, alpha: 1),
                hatchGreeting: "oh... hi... 🥺💜\ni-i'm here now...\nis that... okay?\n*hides behind shell*",
                hatchButton: "hey, it's okay! come here~ 💜",
                askNameLine: "u-um... what's your name?\ni promise i won't forget... 🥺",
                greetingLine: { name in "\(name)... that's such\na nice name... 💜\ny-you really want to\nkeep me? 🥹\ni'll try my best..." },
                greetingButton: "you're perfect~ 💜",
                askPetNameLine: { name in "\(name)... will you\ngive me a name?\nsomething gentle... 🌙💜" },
                floorColor: NSColor(red: 0.78, green: 0.72, blue: 0.82, alpha: 1),
                rugColor: NSColor(red: 0.72, green: 0.55, blue: 0.78, alpha: 0.2),
                wallTint: NSColor(red: 0.85, green: 0.75, blue: 0.88, alpha: 0.08),
                shelfItemColors: [.systemPurple, .systemIndigo, .systemBlue, .systemPink, .magenta],
                roomAccent: "🌙",
                windowScene: .aurora,
                foods: ["🫐", "🍇", "🧁", "🍵", "🥞", "🍡"],
                toyBallColor: NSColor.systemPurple,
                yarnColor: NSColor(red: 0.75, green: 0.5, blue: 0.8, alpha: 0.6),
                cushionColor: NSColor(red: 0.72, green: 0.5, blue: 0.78, alpha: 0.35),
                favoriteGame: "Yarn Play",
                idleThoughts: [
                    "sometimes the quiet is too loud... 🥺",
                    "do you think the moon is lonely too? 🌙",
                    "i wonder if anyone else feels this... purple... 💜",
                    "*sighs softly* ...it's nothing, really...",
                    "the shadows in the corner look... friendly actually",
                    "i wrote a poem but... it's too sad to share 📝",
                    "what if the rain is the sky crying WITH me? 🌧️",
                    "i'm okay... i think... probably... 🥺",
                    "beauty is just sadness wearing a nice dress...",
                    "the dust particles look like tiny shooting stars 💫",
                    "i hugged myself today. it was nice. 💜",
                    "sometimes i just exist and that's... enough...",
                ],
                morningGreetings: [
                    "oh... it's morning already...? 🥺☀️",
                    "good morning... i hope today is gentle... 💜",
                    "the morning light is... almost too bright... 🌅",
                    "*peeks out from blanket* ...is it safe? 😴",
                    "i dreamed something beautiful... but i forgot it... 🥺",
                    "mornings are hard... but you make them softer... 💜",
                ],
                afternoonThoughts: [
                    "the afternoon makes everything feel... heavy... 😴💜",
                    "i just want to lie here for a while... is that okay? 🥺",
                    "even my sadness is tired right now... 💤",
                    "maybe if i'm very still, the sleepiness won't find me... 😴",
                    "the world is fuzzy and warm and... okay actually 💜",
                ],
                eveningThoughts: [
                    "the twilight is the prettiest kind of sadness... 🌙💜",
                    "another day survived... that counts, right? 🥺",
                    "the stars understand me, i think... ✨",
                    "nighttime is when all the feelings come out... 💜",
                    "i feel safest when it's dark and quiet... 🌙",
                ],
                sleepyThoughts: [
                    "zzz... *whimpers softly* ...don't go... 💤💜",
                    "*clutches invisible pillow* ...zzz... 🌙",
                    "zzz... the dreams are... gentle tonight... 💜💤",
                ],
                hungryThoughts: [
                    "i-i'm a little hungry... sorry to bother you... 🥺",
                    "my tummy hurts but i didn't want to say anything... 💜",
                    "um... could i maybe... have a little snack? if it's not too much trouble... 🫐",
                    "i don't want to be a burden but... food? 🥺",
                    "the hunger makes everything feel even more... lonely... 💜",
                ],
                happyThoughts: [
                    "i'm... actually happy right now?! 🥹💜",
                    "is this what joy feels like? it's... warm... 💕",
                    "thank you for making me feel... less alone... 💜✨",
                    "my heart is doing something... good? i think? 🥺💕",
                    "maybe the world isn't so scary after all... 💜",
                ],
                matColor: NSColor(red: 0.72, green: 0.5, blue: 0.78, alpha: 0.45),
                matEmoji: "🌙",
                sleepStyle: "curled up"
            )

        case .pongoBlue:
            return PetPersonality(
                name: "Pongo",
                species: "cool cube",
                trait: "chill",
                bodyColor: NSColor(red: 0.25, green: 0.58, blue: 0.82, alpha: 1),
                accentColor: NSColor(red: 0.2, green: 0.5, blue: 0.72, alpha: 1),
                bellyColor: NSColor(red: 0.55, green: 0.78, blue: 0.92, alpha: 1),
                hatchGreeting: "yo~ 😎🌊\nwhat's good?\njust hatched, no big deal~\n*finger guns*",
                hatchButton: "haha nice to meet you! 🤙",
                askNameLine: "so what do they\ncall you? 😏🌊",
                greetingLine: { name in "ayyy \(name)~ 🤙\nnice vibes, i can tell~\nwe're gonna be\nsuper chill together 🌊✨" },
                greetingButton: "totally! 🏄‍♂️",
                askPetNameLine: { name in "yo \(name), hit me\nwith a cool name~ 😎\nsomething rad!" },
                floorColor: NSColor(red: 0.72, green: 0.8, blue: 0.88, alpha: 1),
                rugColor: NSColor(red: 0.4, green: 0.65, blue: 0.82, alpha: 0.2),
                wallTint: NSColor(red: 0.78, green: 0.88, blue: 0.95, alpha: 0.08),
                shelfItemColors: [.systemBlue, .systemTeal, .systemCyan, .systemMint, .systemIndigo],
                roomAccent: "🏄",
                windowScene: .ocean,
                foods: ["🐟", "🍣", "🥤", "🍦", "🫧", "🥥"],
                toyBallColor: NSColor.systemBlue,
                yarnColor: NSColor(red: 0.4, green: 0.65, blue: 0.85, alpha: 0.6),
                cushionColor: NSColor(red: 0.4, green: 0.6, blue: 0.8, alpha: 0.35),
                favoriteGame: "Laser Chase",
                idleThoughts: [
                    "vibes are immaculate rn~ 🌊",
                    "chillin'. just absolutely chillin'. 😎",
                    "you ever just... exist? it's pretty rad 🤙",
                    "the ocean in the window is calling me bro~ 🏄",
                    "no thoughts, just vibes ✨",
                    "life's a wave, dude. just ride it~ 🌊",
                    "*does a little finger gun* pew pew 😎",
                    "that corner of the room has good energy ngl",
                    "i'm not lazy, i'm energy efficient 🔋",
                    "the floor is not lava, the floor is chill 🧊",
                    "if cool was a temperature i'd be absolute zero 😎❄️",
                    "sometimes the best move is no move at all~ 🌊",
                ],
                morningGreetings: [
                    "yo... morning already? ...that's cool 😎☀️",
                    "*stretches* aight. let's vibe today~ 🌊",
                    "mornings are chill if you don't overthink em 🤙",
                    "coffee? nah fam. i run on good vibes ☕😎",
                    "sun's up. vibes are loading... 🔄",
                    "early bird gets the worm but late bird gets the vibes~ 🐦",
                ],
                afternoonThoughts: [
                    "post-lunch nap hits different bro... 😴🌊",
                    "the afternoon vibe is... sleepy. respect. 💤",
                    "gonna power nap. wake me up for sunset~ 😎😴",
                    "zzz is just horizontal vibing honestly 🤙💤",
                    "even the ocean takes a chill break sometimes~ 🌊",
                ],
                eveningThoughts: [
                    "sunset vibes are unmatched dude~ 🌅😎",
                    "evening is just morning for night owls 🦉",
                    "the chill energy peaks at golden hour 🌊✨",
                    "today was solid. no complaints. 🤙",
                    "night mode: activated 😎🌙",
                ],
                sleepyThoughts: [
                    "zzz... *mumbles* ...gnarly wave bro... 💤🏄",
                    "*sleep-surfing* ...cowabunga... zzz 🌊💤",
                    "zzz... vibes... eternal... 😎💤",
                ],
                hungryThoughts: [
                    "yo i could really go for some sushi rn 🍣",
                    "dude. food. please. the vibes need fuel 🐟",
                    "hungry but make it ✨aesthetic✨ 😎",
                    "my stomach is not chill right now ngl 🌊",
                    "can't vibe on an empty stomach bro 🤙",
                ],
                happyThoughts: [
                    "peak vibes achieved. this is it. 🌊😎✨",
                    "bro i'm so happy rn it's actually crazy 🤙",
                    "good vibes ONLY and they are FLOWING 🌊💕",
                    "life is rad and you're rad. fact. 😎🏄",
                    "this right here? this is the good timeline 🌊✨",
                ],
                matColor: NSColor(red: 0.4, green: 0.65, blue: 0.85, alpha: 0.45),
                matEmoji: "🏄",
                sleepStyle: "sprawled"
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
        VStack(spacing: 0) {
            // 3D Scene
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
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                // Floating particles
                if showHeart {
                    floatingParticle(text: "\u{2764}\u{FE0F}")
                }
                if showFood {
                    floatingParticle(text: "\u{1F356}")
                        .offset(x: -30)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: geo.size.height * 0.6)

            Spacer(minLength: 3)

            if pet.isAlive {
                // Bottom bar: name + stat circles + action buttons
                HStack(spacing: 0) {
                    // Name
                    Text(pet.petName ?? component.content ?? "Pixel")
                        .font(.system(size: max(10, min(geo.size.width * 0.048, 14)), weight: .bold, design: .rounded))
                        .foregroundStyle(tc("primary"))
                        .lineLimit(1)
                        .frame(maxWidth: geo.size.width * 0.28, alignment: .leading)

                    Spacer(minLength: 4)

                    // Stat circles
                    HStack(spacing: max(4, geo.size.width * 0.02)) {
                        statCircle(icon: "heart.fill", value: pet.health, color: petHealthColor(pet.health), size: geo.size.width)
                        statCircle(icon: "leaf.fill", value: pet.hunger, color: .orange, size: geo.size.width)
                        statCircle(icon: "star.fill", value: pet.happiness, color: .pink, size: geo.size.width)
                    }

                    Spacer(minLength: 4)

                    // Action buttons — compact icons
                    HStack(spacing: max(3, geo.size.width * 0.015)) {
                        actionCircle(icon: "fork.knife", size: geo.size.width) {
                            interact(.feed)
                        }
                        actionCircle(icon: petModeActive ? "hand.raised.fill" : "hand.wave.fill", size: geo.size.width) {
                            petModeActive.toggle()
                        }
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
                }
                .padding(.horizontal, 6)

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
                Text(pet.petName ?? "R.I.P.")
                    .font(.system(size: max(14, geo.size.width * 0.06), weight: .heavy, design: .rounded))
                    .foregroundStyle(tc("muted"))
                    .padding(.top, 4)

                if let birth = parseISO(pet.birthDate),
                   let death = parseISO(pet.lastDecayAt) {
                    let days = max(0, Calendar.current.dateComponents([.day], from: birth, to: death).day ?? 0)
                    Text("Lived \(days) day\(days == 1 ? "" : "s")")
                        .font(.system(size: max(9, geo.size.width * 0.04), design: .rounded))
                        .foregroundStyle(tc("muted").opacity(0.6))
                }
            }

            Spacer(minLength: 3)
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
        VStack(spacing: 0) {
            EggSceneView(
                theme: theme,
                tapCount: eggTaps,
                onTap: { handleEggTap() }
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .frame(maxWidth: .infinity)
            .frame(height: geo.size.height * 0.65)

            Spacer(minLength: 6)

            Text(eggTaps == 0 ? "tap the egg to hatch!" : eggTaps < 3 ? "keep tapping! (\(eggTaps)/3)" : "hatching...!")
                .font(.system(size: max(11, geo.size.width * 0.048), weight: .semibold, design: .rounded))
                .foregroundStyle(tc("muted"))
                .animation(.easeInOut(duration: 0.2), value: eggTaps)

            if eggTaps == 0 {
                Spacer(minLength: 4)
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: max(14, geo.size.width * 0.06)))
                    .foregroundStyle(tc("accent").opacity(0.5))
            }

            Spacer(minLength: 4)
        }
    }

    private func handleEggTap() {
        eggTaps += 1
        if eggTaps >= 3 {
            introPhase = .cracking
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
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

            // Add crack lines for each new tap
            if tapCount >= 1 && crackNodes.count < 1 {
                addCrackToEgg(egg: egg, seed: 1, intensity: 0.6)
            }
            if tapCount >= 2 && crackNodes.count < 2 {
                addCrackToEgg(egg: egg, seed: 2, intensity: 0.8)
                // Start glow
                if let glow = glowNode {
                    let accent = glow.geometry?.firstMaterial?.diffuse.contents as? NSColor ?? .white
                    glow.opacity = 0.3
                    glow.geometry?.firstMaterial?.emission.contents = (accent.withAlphaComponent(0.15) as NSColor)
                }
            }
            if tapCount >= 3 {
                addCrackToEgg(egg: egg, seed: 3, intensity: 1.0)
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
            petBodyNode?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.2))
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
            let angle = atan2(dx, dz)
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

            let faceCamera = SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.3)

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
                let angle = atan2(dx, dz)

                let chase = SCNAction.sequence([
                    SCNAction.rotateTo(x: 0, y: angle, z: 0, duration: 0.15),
                    SCNAction.moveBy(x: dx, y: 0, z: dz, duration: Double(distance) * 0.45),
                    // Pounce on ball
                    SCNAction.moveBy(x: 0, y: 0.2, z: 0, duration: 0.1),
                    SCNAction.moveBy(x: 0, y: -0.2, z: 0, duration: 0.08),
                    SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.3)
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
                let angle = atan2(dx, dz)

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
                    SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.2)
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

            // Lighting
            let keyLight = SCNNode()
            keyLight.light = SCNLight()
            keyLight.light?.type = .directional
            keyLight.light?.intensity = 800
            keyLight.light?.color = NSColor.white
            keyLight.light?.castsShadow = true
            keyLight.light?.shadowMode = .deferred
            keyLight.light?.shadowSampleCount = 8
            keyLight.light?.shadowRadius = 3
            keyLight.light?.shadowColor = NSColor.black.withAlphaComponent(0.3)
            keyLight.eulerAngles = SCNVector3(-CGFloat.pi / 3, CGFloat.pi / 5, 0)
            scene.rootNode.addChildNode(keyLight)

            let fillLight = SCNNode()
            fillLight.light = SCNLight()
            fillLight.light?.type = .omni
            fillLight.light?.intensity = 250
            fillLight.light?.color = NSColor(palette.accent).withAlphaComponent(0.4)
            fillLight.position = SCNVector3(-2, 2, 2)
            scene.rootNode.addChildNode(fillLight)

            let ambient = SCNNode()
            ambient.light = SCNLight()
            ambient.light?.type = .ambient
            ambient.light?.intensity = 300
            ambient.light?.color = NSColor.white
            scene.rootNode.addChildNode(ambient)

            // Pet character — pick builder based on character type
            let character = pet.character ?? .fluffy
            self.petCharacter = character
            let pers = character.personality

            // Room — character-specific
            buildRoom(in: scene, palette: palette, personality: pers)

            // Laser dot (cat toy)
            buildLaserDot(in: scene)
            let body: SCNNode
            switch character {
            case .fluffy:
                body = buildPet(alive: pet.isAlive, palette: palette)
            case .pongoGreen, .pongoWhite, .pongoPurple, .pongoBlue:
                body = buildPongoPet(character: character, alive: pet.isAlive, palette: palette)
            }
            scene.rootNode.addChildNode(body)
            petBodyNode = body
            sceneRef = scene

            // Animations
            if pet.isAlive {
                startIdleAnimations(body)
                startBlinking()
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

        private func buildPet(alive: Bool, palette: ThemePalette) -> SCNNode {
            let root = SCNNode()
            root.position = SCNVector3(0, 0, 0)

            let accentColor = NSColor(palette.accent)
            let lighterAccent = accentColor.blended(withFraction: 0.35, of: .white) ?? accentColor
            let palest = accentColor.blended(withFraction: 0.65, of: .white) ?? accentColor
            let bellyColor = accentColor.blended(withFraction: 0.7, of: .white) ?? accentColor

            // Helper to make soft fluffy material
            func fluffyMat(_ color: NSColor) -> SCNMaterial {
                let m = SCNMaterial()
                m.diffuse.contents = color
                m.roughness.contents = NSColor(white: 0.85, alpha: 1)  // very matte = fluffy look
                m.metalness.contents = NSColor(white: 0.0, alpha: 1)
                // Subtle warm glow
                m.emission.contents = color.withAlphaComponent(0.06)
                return m
            }

            let bodyFluff = fluffyMat(accentColor)

            // ── BODY ── Chubby round sphere (not capsule!) — Kirby/Molang style
            let bodyGeo = SCNSphere(radius: 0.52)
            bodyGeo.segmentCount = 48
            bodyGeo.materials = [bodyFluff]
            let bodyNode = SCNNode(geometry: bodyGeo)
            bodyNode.position = SCNVector3(0, 0.55, 0)
            root.addChildNode(bodyNode)
            bodyMeshNode = bodyNode

            // ── BELLY PATCH ── Soft lighter oval on tummy
            let bellyGeo = SCNSphere(radius: 0.36)
            bellyGeo.segmentCount = 32
            bellyGeo.materials = [fluffyMat(bellyColor)]
            let bellyNode = SCNNode(geometry: bellyGeo)
            bellyNode.position = SCNVector3(0, -0.06, 0.22)
            bellyNode.scale = SCNVector3(0.75, 0.85, 0.35)
            bodyNode.addChildNode(bellyNode)

            // ── HEAD ── Big round head (bigger than body = cuter!)
            let headGeo = SCNSphere(radius: 0.46)
            headGeo.segmentCount = 48
            headGeo.materials = [fluffyMat(accentColor)]
            let head = SCNNode(geometry: headGeo)
            head.position = SCNVector3(0, 0.58, 0)
            bodyNode.addChildNode(head)
            headNode = head

            // ── FLUFFY TUFT ── Little fluff on top of head
            for i in 0..<3 {
                let tuftGeo = SCNSphere(radius: 0.07 - CGFloat(i) * 0.015)
                tuftGeo.materials = [fluffyMat(lighterAccent)]
                let tuft = SCNNode(geometry: tuftGeo)
                tuft.position = SCNVector3(
                    CGFloat(i - 1) * 0.04,
                    0.42 + CGFloat(i) * 0.03,
                    0.02
                )
                head.addChildNode(tuft)
            }

            // ── EYES ── BIG sparkly anime-style eyes
            let eyeWhiteGeo = SCNSphere(radius: 0.13)
            eyeWhiteGeo.segmentCount = 32
            let eyeWhiteMat = SCNMaterial()
            eyeWhiteMat.diffuse.contents = NSColor.white
            eyeWhiteMat.emission.contents = NSColor(white: 1, alpha: 0.1)
            eyeWhiteGeo.materials = [eyeWhiteMat]

            let leftEye = SCNNode(geometry: eyeWhiteGeo)
            leftEye.position = SCNVector3(-0.15, 0.06, 0.38)
            head.addChildNode(leftEye)
            leftEyeNode = leftEye

            let rightEye = SCNNode(geometry: eyeWhiteGeo)
            rightEye.position = SCNVector3(0.15, 0.06, 0.38)
            head.addChildNode(rightEye)
            rightEyeNode = rightEye

            // ── PUPILS ── Large dark pupils with colored iris ring
            let pupilGeo = SCNSphere(radius: 0.075)
            pupilGeo.segmentCount = 24
            let pupilMat = SCNMaterial()
            pupilMat.diffuse.contents = NSColor(red: 0.12, green: 0.08, blue: 0.06, alpha: 1)
            pupilGeo.materials = [pupilMat]

            let leftPupil = SCNNode(geometry: pupilGeo)
            leftPupil.position = SCNVector3(0, 0, 0.07)
            leftEye.addChildNode(leftPupil)
            leftPupilNode = leftPupil

            let rightPupil = SCNNode(geometry: pupilGeo)
            rightPupil.position = SCNVector3(0, 0, 0.07)
            rightEye.addChildNode(rightPupil)
            rightPupilNode = rightPupil

            // ── EYE SPARKLES ── Two white highlights per eye (anime style!)
            for eye in [leftPupil, rightPupil] {
                let sparkGeo1 = SCNSphere(radius: 0.025)
                let sparkMat = SCNMaterial()
                sparkMat.diffuse.contents = NSColor.white
                sparkMat.emission.contents = NSColor(white: 1, alpha: 0.9)
                sparkGeo1.materials = [sparkMat]
                let spark1 = SCNNode(geometry: sparkGeo1)
                spark1.position = SCNVector3(0.02, 0.025, 0.05)
                eye.addChildNode(spark1)

                let sparkGeo2 = SCNSphere(radius: 0.015)
                sparkGeo2.materials = [sparkMat]
                let spark2 = SCNNode(geometry: sparkGeo2)
                spark2.position = SCNVector3(-0.015, -0.015, 0.055)
                eye.addChildNode(spark2)
            }

            // ── IRIS RING ── Colored ring around pupil
            for (eye, pupil) in [(leftEye, leftPupil), (rightEye, rightPupil)] {
                let irisGeo = SCNTorus(ringRadius: 0.075, pipeRadius: 0.012)
                let irisMat = SCNMaterial()
                irisMat.diffuse.contents = accentColor.blended(withFraction: 0.2, of: .brown) ?? accentColor
                irisGeo.materials = [irisMat]
                let iris = SCNNode(geometry: irisGeo)
                iris.position = SCNVector3(0, 0, 0.04)
                let _ = eye  // suppress warning
                pupil.addChildNode(iris)
            }

            // ── TINY NOSE ── Little pink button nose
            let noseGeo = SCNSphere(radius: 0.04)
            noseGeo.segmentCount = 16
            let noseMat = SCNMaterial()
            noseMat.diffuse.contents = NSColor(red: 0.95, green: 0.55, blue: 0.6, alpha: 1)
            noseMat.emission.contents = NSColor(red: 0.95, green: 0.55, blue: 0.6, alpha: 0.15)
            noseGeo.materials = [noseMat]
            let nose = SCNNode(geometry: noseGeo)
            nose.position = SCNVector3(0, -0.04, 0.43)
            nose.scale = SCNVector3(1.0, 0.7, 0.6)
            head.addChildNode(nose)

            // ── MOUTH ── Tiny curved smile (small torus, half-hidden)
            let mouthGeo = SCNTorus(ringRadius: 0.05, pipeRadius: 0.012)
            let mouthMat = SCNMaterial()
            mouthMat.diffuse.contents = NSColor(red: 0.9, green: 0.45, blue: 0.5, alpha: 0.8)
            mouthGeo.materials = [mouthMat]
            let mouth = SCNNode(geometry: mouthGeo)
            mouth.position = SCNVector3(0, -0.1, 0.4)
            mouth.eulerAngles.x = CGFloat.pi / 5
            mouth.scale = SCNVector3(1, 0.5, 1)  // flatten to a cute line
            head.addChildNode(mouth)
            mouthNode = mouth

            // ── CHEEKS ── Big rosy blush circles
            let cheekGeo = SCNSphere(radius: 0.08)
            cheekGeo.segmentCount = 16
            let cheekMat = SCNMaterial()
            cheekMat.diffuse.contents = NSColor.systemPink.withAlphaComponent(0.3)
            cheekMat.emission.contents = NSColor.systemPink.withAlphaComponent(0.08)
            cheekGeo.materials = [cheekMat]

            let leftCheek = SCNNode(geometry: cheekGeo)
            leftCheek.position = SCNVector3(-0.28, -0.04, 0.3)
            leftCheek.scale = SCNVector3(1, 0.6, 0.4)  // flatten into blush ovals
            head.addChildNode(leftCheek)
            leftCheekNode = leftCheek

            let rightCheek = SCNNode(geometry: cheekGeo)
            rightCheek.position = SCNVector3(0.28, -0.04, 0.3)
            rightCheek.scale = SCNVector3(1, 0.6, 0.4)
            head.addChildNode(rightCheek)
            rightCheekNode = rightCheek

            // ── EARS ── Soft rounded cat-like ears
            let earGeo = SCNSphere(radius: 0.14)
            earGeo.segmentCount = 24
            let earMat = fluffyMat(lighterAccent)

            let leftEar = SCNNode(geometry: earGeo)
            leftEar.position = SCNVector3(-0.26, 0.38, -0.05)
            leftEar.scale = SCNVector3(0.7, 1.1, 0.5)  // pointy-ish shape
            leftEar.eulerAngles.z = 0.25
            head.addChildNode(leftEar)
            leftEarNode = leftEar

            let rightEar = SCNNode(geometry: earGeo)
            rightEar.position = SCNVector3(0.26, 0.38, -0.05)
            rightEar.scale = SCNVector3(0.7, 1.1, 0.5)
            rightEar.eulerAngles.z = -0.25
            head.addChildNode(rightEar)
            rightEarNode = rightEar

            // Inner ear (pink)
            let innerEarGeo = SCNSphere(radius: 0.07)
            innerEarGeo.segmentCount = 16
            let innerEarMat = SCNMaterial()
            innerEarMat.diffuse.contents = NSColor(red: 1, green: 0.7, blue: 0.75, alpha: 0.6)
            innerEarGeo.materials = [innerEarMat]

            let leftInnerEar = SCNNode(geometry: innerEarGeo)
            leftInnerEar.position = SCNVector3(0, 0, 0.04)
            leftEar.addChildNode(leftInnerEar)

            let rightInnerEar = SCNNode(geometry: innerEarGeo)
            rightInnerEar.position = SCNVector3(0, 0, 0.04)
            rightEar.addChildNode(rightInnerEar)

            // ── TINY BOW ── Cute accessory on right ear
            let bowCenter = SCNSphere(radius: 0.03)
            let bowMat = SCNMaterial()
            bowMat.diffuse.contents = NSColor.systemPink
            bowMat.emission.contents = NSColor.systemPink.withAlphaComponent(0.2)
            bowCenter.materials = [bowMat]
            let bowNode = SCNNode(geometry: bowCenter)
            bowNode.position = SCNVector3(0.05, 0.08, 0.06)
            rightEar.addChildNode(bowNode)

            // Bow loops
            let bowLoopGeo = SCNSphere(radius: 0.04)
            bowLoopGeo.materials = [bowMat]
            let bowLeft = SCNNode(geometry: bowLoopGeo)
            bowLeft.position = SCNVector3(-0.04, 0.01, 0)
            bowLeft.scale = SCNVector3(1.2, 0.7, 0.5)
            bowNode.addChildNode(bowLeft)
            let bowRight = SCNNode(geometry: bowLoopGeo)
            bowRight.position = SCNVector3(0.04, 0.01, 0)
            bowRight.scale = SCNVector3(1.2, 0.7, 0.5)
            bowNode.addChildNode(bowRight)

            // ── BANDANA / SCARF ── Around the neck area
            let scarfGeo = SCNTorus(ringRadius: 0.3, pipeRadius: 0.05)
            let scarfMat = SCNMaterial()
            let scarfColor = NSColor.systemRed.blended(withFraction: 0.3, of: accentColor) ?? .systemRed
            scarfMat.diffuse.contents = scarfColor.withAlphaComponent(0.7)
            scarfMat.roughness.contents = NSColor(white: 0.7, alpha: 1)
            scarfGeo.materials = [scarfMat]
            let scarf = SCNNode(geometry: scarfGeo)
            scarf.position = SCNVector3(0, 0.26, 0)
            scarf.eulerAngles.x = 0.1
            bodyNode.addChildNode(scarf)

            // Scarf knot
            let knotGeo = SCNSphere(radius: 0.06)
            knotGeo.materials = [scarfMat]
            let knot = SCNNode(geometry: knotGeo)
            knot.position = SCNVector3(0, -0.02, 0.3)
            scarf.addChildNode(knot)

            // Scarf tails hanging from knot
            let tailPieceGeo = SCNCapsule(capRadius: 0.025, height: 0.14)
            tailPieceGeo.materials = [scarfMat]
            let scarfTail1 = SCNNode(geometry: tailPieceGeo)
            scarfTail1.position = SCNVector3(-0.03, -0.09, 0.02)
            scarfTail1.eulerAngles.z = 0.2
            knot.addChildNode(scarfTail1)
            let scarfTail2 = SCNNode(geometry: tailPieceGeo)
            scarfTail2.position = SCNVector3(0.03, -0.1, 0.02)
            scarfTail2.eulerAngles.z = -0.15
            knot.addChildNode(scarfTail2)

            // ── ARMS ── Stubby round little paws
            let armGeo = SCNCapsule(capRadius: 0.09, height: 0.22)
            armGeo.materials = [bodyFluff]

            let leftArm = SCNNode(geometry: armGeo)
            leftArm.position = SCNVector3(-0.45, 0.05, 0.1)
            leftArm.eulerAngles.z = CGFloat.pi / 5
            bodyNode.addChildNode(leftArm)
            leftArmNode = leftArm

            let rightArm = SCNNode(geometry: armGeo)
            rightArm.position = SCNVector3(0.45, 0.05, 0.1)
            rightArm.eulerAngles.z = -CGFloat.pi / 5
            bodyNode.addChildNode(rightArm)
            rightArmNode = rightArm

            // Little paw pads (pink circles on paw tips)
            let pawPadGeo = SCNSphere(radius: 0.035)
            let pawPadMat = SCNMaterial()
            pawPadMat.diffuse.contents = NSColor(red: 1, green: 0.7, blue: 0.75, alpha: 0.7)
            pawPadGeo.materials = [pawPadMat]

            let leftPad = SCNNode(geometry: pawPadGeo)
            leftPad.position = SCNVector3(0, -0.11, 0.05)
            leftArm.addChildNode(leftPad)
            let rightPad = SCNNode(geometry: pawPadGeo)
            rightPad.position = SCNVector3(0, -0.11, 0.05)
            rightArm.addChildNode(rightPad)

            // ── FEET ── Round stubby feet
            let footGeo = SCNSphere(radius: 0.13)
            footGeo.segmentCount = 24
            footGeo.materials = [bodyFluff]

            let leftFoot = SCNNode(geometry: footGeo)
            leftFoot.position = SCNVector3(-0.2, -0.45, 0.08)
            leftFoot.scale = SCNVector3(1, 0.6, 1.2)  // flattened oval
            bodyNode.addChildNode(leftFoot)
            leftFootNode = leftFoot

            let rightFoot = SCNNode(geometry: footGeo)
            rightFoot.position = SCNVector3(0.2, -0.45, 0.08)
            rightFoot.scale = SCNVector3(1, 0.6, 1.2)
            bodyNode.addChildNode(rightFoot)
            rightFootNode = rightFoot

            // Foot paw pads
            let footPadGeo = SCNSphere(radius: 0.04)
            footPadGeo.materials = [pawPadMat]
            let leftFootPad = SCNNode(geometry: footPadGeo)
            leftFootPad.position = SCNVector3(0, -0.04, 0.06)
            leftFoot.addChildNode(leftFootPad)
            let rightFootPad = SCNNode(geometry: footPadGeo)
            rightFootPad.position = SCNVector3(0, -0.04, 0.06)
            rightFoot.addChildNode(rightFootPad)

            // ── TAIL ── Fluffy round pom-pom tail
            let tailGeo = SCNSphere(radius: 0.13)
            tailGeo.segmentCount = 24
            tailGeo.materials = [fluffyMat(palest)]
            let tail = SCNNode(geometry: tailGeo)
            tail.position = SCNVector3(0, -0.1, -0.48)
            bodyNode.addChildNode(tail)
            tailNode = tail

            // Extra fluff on tail
            let tailFluffGeo = SCNSphere(radius: 0.08)
            tailFluffGeo.materials = [fluffyMat(lighterAccent)]
            let tailFluff = SCNNode(geometry: tailFluffGeo)
            tailFluff.position = SCNVector3(0, 0.06, -0.06)
            tail.addChildNode(tailFluff)

            // ── WHISKERS ── Tiny subtle whisker lines
            let whiskerMat = SCNMaterial()
            whiskerMat.diffuse.contents = NSColor(white: 0.7, alpha: 0.3)
            for side: CGFloat in [-1, 1] {
                for i in 0..<2 {
                    let wGeo = SCNCylinder(radius: 0.004, height: 0.12)
                    wGeo.materials = [whiskerMat]
                    let w = SCNNode(geometry: wGeo)
                    w.position = SCNVector3(
                        side * 0.22,
                        -0.05 + CGFloat(i) * 0.04,
                        0.38
                    )
                    w.eulerAngles.z = CGFloat.pi / 2 + side * 0.15
                    w.eulerAngles.x = CGFloat(i) * 0.1 - 0.05
                    head.addChildNode(w)
                }
            }

            // ── FLOWER CROWN ── Fluffy's signature accessory
            let flowerColors: [NSColor] = [.systemPink, .systemYellow, .white, .systemRed, .magenta]
            for i in 0..<5 {
                let angle = CGFloat(i) * (CGFloat.pi * 2 / 5)
                let flowerGeo = SCNSphere(radius: 0.04)
                let flowerMat = SCNMaterial()
                flowerMat.diffuse.contents = flowerColors[i]
                flowerMat.emission.contents = flowerColors[i].withAlphaComponent(0.15)
                flowerGeo.materials = [flowerMat]
                let flower = SCNNode(geometry: flowerGeo)
                flower.position = SCNVector3(
                    cos(angle) * 0.2,
                    0.42,
                    sin(angle) * 0.2
                )
                head.addChildNode(flower)
                // Tiny center dot
                let centerGeo = SCNSphere(radius: 0.015)
                let centerMat = SCNMaterial()
                centerMat.diffuse.contents = NSColor.systemYellow
                centerMat.emission.contents = NSColor.systemYellow.withAlphaComponent(0.3)
                centerGeo.materials = [centerMat]
                let center = SCNNode(geometry: centerGeo)
                center.position = SCNVector3(0, 0, 0.03)
                flower.addChildNode(center)
            }

            return root
        }

        // MARK: - Pongo Character Builder

        private func buildPongoPet(
            character: UserDataStore.PetCharacter,
            alive: Bool,
            palette: ThemePalette
        ) -> SCNNode {
            let root = SCNNode()
            root.position = SCNVector3(0, 0, 0)

            // Character-specific properties
            let (mainColor, eyeStyle, mouthStyle, letter): (NSColor, PongoEyeStyle, PongoMouthStyle, String) = {
                switch character {
                case .pongoGreen:
                    return (NSColor(red: 0.55, green: 0.82, blue: 0.22, alpha: 1), .round, .happy, "D")
                case .pongoWhite:
                    return (NSColor(white: 0.88, alpha: 1), .slant, .happy, "I")
                case .pongoPurple:
                    return (NSColor(red: 0.72, green: 0.28, blue: 0.65, alpha: 1), .round, .sad, "D")
                case .pongoBlue:
                    return (NSColor(red: 0.25, green: 0.58, blue: 0.72, alpha: 1), .wink, .smirk, "O")
                default:
                    return (NSColor(palette.accent), .round, .happy, "")
                }
            }()

            let darkerMain = mainColor.blended(withFraction: 0.2, of: .black) ?? mainColor
            let lighterMain = mainColor.blended(withFraction: 0.3, of: .white) ?? mainColor

            func boxMat(_ color: NSColor) -> SCNMaterial {
                let m = SCNMaterial()
                m.diffuse.contents = color
                m.roughness.contents = NSColor(white: 0.6, alpha: 1)
                m.metalness.contents = NSColor(white: 0.05, alpha: 1)
                return m
            }

            // ── BODY ── Rounded cube
            let bodyGeo = SCNBox(width: 0.7, height: 0.55, length: 0.55, chamferRadius: 0.12)
            bodyGeo.materials = [boxMat(mainColor)]
            let bodyNode = SCNNode(geometry: bodyGeo)
            bodyNode.position = SCNVector3(0, 0.45, 0)
            root.addChildNode(bodyNode)
            bodyMeshNode = bodyNode

            // ── HEAD ── Larger rounded cube on top
            let headGeo = SCNBox(width: 0.72, height: 0.6, length: 0.6, chamferRadius: 0.14)
            headGeo.materials = [boxMat(mainColor)]
            let head = SCNNode(geometry: headGeo)
            head.position = SCNVector3(0, 0.55, 0)
            bodyNode.addChildNode(head)
            headNode = head

            // ── EYES ──
            switch eyeStyle {
            case .round:
                // Small round dark eyes (green & purple style)
                let eyeGeo = SCNSphere(radius: 0.045)
                eyeGeo.segmentCount = 16
                let eyeMat = SCNMaterial()
                eyeMat.diffuse.contents = NSColor(white: 0.1, alpha: 1)
                eyeMat.emission.contents = NSColor(white: 0.05, alpha: 1)
                eyeGeo.materials = [eyeMat]

                let leftEye = SCNNode(geometry: eyeGeo)
                leftEye.position = SCNVector3(-0.15, 0.08, 0.31)
                head.addChildNode(leftEye)
                leftEyeNode = leftEye

                let rightEye = SCNNode(geometry: eyeGeo)
                rightEye.position = SCNVector3(0.15, 0.08, 0.31)
                head.addChildNode(rightEye)
                rightEyeNode = rightEye

                // Highlight dots
                let hlGeo = SCNSphere(radius: 0.015)
                let hlMat = SCNMaterial()
                hlMat.diffuse.contents = NSColor.white
                hlMat.emission.contents = NSColor(white: 1, alpha: 0.8)
                hlMat.lightingModel = .constant
                hlGeo.materials = [hlMat]
                for eye in [leftEye, rightEye] {
                    let hl = SCNNode(geometry: hlGeo)
                    hl.position = SCNVector3(0.015, 0.02, 0.035)
                    eye.addChildNode(hl)
                }

            case .slant:
                // Slanted line-style eyes (white character with hat)
                let eyeMat = SCNMaterial()
                eyeMat.diffuse.contents = NSColor(red: 0.9, green: 0.65, blue: 0.1, alpha: 1)
                for side: CGFloat in [-1, 1] {
                    let eyeGeo = SCNCylinder(radius: 0.012, height: 0.1)
                    eyeGeo.materials = [eyeMat]
                    let eye = SCNNode(geometry: eyeGeo)
                    eye.position = SCNVector3(side * 0.14, 0.1, 0.31)
                    eye.eulerAngles = SCNVector3(0, 0, side * 0.4)
                    head.addChildNode(eye)
                    if side < 0 { leftEyeNode = eye } else { rightEyeNode = eye }
                }

            case .wink:
                // One open eye, one closed (blue character)
                let eyeGeo = SCNSphere(radius: 0.045)
                eyeGeo.segmentCount = 16
                let eyeMat = SCNMaterial()
                eyeMat.diffuse.contents = NSColor(white: 0.1, alpha: 1)
                eyeGeo.materials = [eyeMat]

                let leftEye = SCNNode(geometry: eyeGeo)
                leftEye.position = SCNVector3(-0.15, 0.08, 0.31)
                head.addChildNode(leftEye)
                leftEyeNode = leftEye

                // Highlight on open eye
                let hlGeo = SCNSphere(radius: 0.015)
                let hlMat = SCNMaterial()
                hlMat.diffuse.contents = NSColor.white
                hlMat.emission.contents = NSColor(white: 1, alpha: 0.8)
                hlMat.lightingModel = .constant
                hlGeo.materials = [hlMat]
                let hl = SCNNode(geometry: hlGeo)
                hl.position = SCNVector3(0.015, 0.02, 0.035)
                leftEye.addChildNode(hl)

                // Wink eye — curved line
                let winkMat = SCNMaterial()
                winkMat.diffuse.contents = NSColor.white
                let winkGeo = SCNCylinder(radius: 0.012, height: 0.08)
                winkGeo.materials = [winkMat]
                let winkEye = SCNNode(geometry: winkGeo)
                winkEye.position = SCNVector3(0.15, 0.06, 0.31)
                winkEye.eulerAngles.z = CGFloat.pi / 2
                head.addChildNode(winkEye)
                rightEyeNode = winkEye
            }

            // ── MOUTH ──
            let mouthMat = SCNMaterial()
            switch mouthStyle {
            case .happy:
                // Curved happy smile
                mouthMat.diffuse.contents = NSColor(white: 0.15, alpha: 1)
                let mouthGeo = SCNTorus(ringRadius: 0.08, pipeRadius: 0.015)
                mouthGeo.materials = [mouthMat]
                let mouth = SCNNode(geometry: mouthGeo)
                mouth.position = SCNVector3(0, -0.08, 0.3)
                mouth.eulerAngles.x = CGFloat.pi / 4
                mouth.scale = SCNVector3(1.2, 0.5, 1)
                head.addChildNode(mouth)
                mouthNode = mouth

            case .sad:
                // Upside-down frown
                mouthMat.diffuse.contents = NSColor(white: 0.15, alpha: 1)
                let mouthGeo = SCNTorus(ringRadius: 0.07, pipeRadius: 0.015)
                mouthGeo.materials = [mouthMat]
                let mouth = SCNNode(geometry: mouthGeo)
                mouth.position = SCNVector3(0, -0.1, 0.3)
                mouth.eulerAngles.x = -CGFloat.pi / 4
                mouth.scale = SCNVector3(1.2, 0.5, 1)
                head.addChildNode(mouth)
                mouthNode = mouth

            case .smirk:
                // Sideways smirk
                mouthMat.diffuse.contents = NSColor.white
                let smirkGeo = SCNCylinder(radius: 0.015, height: 0.14)
                smirkGeo.materials = [mouthMat]
                let mouth = SCNNode(geometry: smirkGeo)
                mouth.position = SCNVector3(0.02, -0.08, 0.31)
                mouth.eulerAngles.z = CGFloat.pi / 2 + 0.15
                head.addChildNode(mouth)
                mouthNode = mouth
            }

            // ── BELLY LETTER ──
            if !letter.isEmpty {
                let letterGeo = SCNText(string: letter, extrusionDepth: 0.02)
                letterGeo.font = NSFont.systemFont(ofSize: 0.2, weight: .bold)
                letterGeo.flatness = 0.1
                let letterMat = SCNMaterial()
                letterMat.diffuse.contents = lighterMain
                letterMat.lightingModel = .constant
                letterGeo.materials = [letterMat]
                let letterNode = SCNNode(geometry: letterGeo)
                let (mn, mx) = letterNode.boundingBox
                let lw = CGFloat(mx.x - mn.x)
                let lh = CGFloat(mx.y - mn.y)
                letterNode.position = SCNVector3(-lw / 2, -lh / 2 - 0.05, 0.28)
                bodyNode.addChildNode(letterNode)
            }

            // ── CHARACTER-SPECIFIC ACCESSORIES ──
            switch character {
            case .pongoGreen:
                // Adventure bandana — triangle scarf around neck
                let bandanaGeo = SCNBox(width: 0.5, height: 0.12, length: 0.06, chamferRadius: 0.02)
                let bandanaMat = SCNMaterial()
                bandanaMat.diffuse.contents = NSColor.systemOrange.withAlphaComponent(0.8)
                bandanaGeo.materials = [bandanaMat]
                let bandana = SCNNode(geometry: bandanaGeo)
                bandana.position = SCNVector3(0, -0.25, 0.25)
                bandana.eulerAngles.x = 0.15
                head.addChildNode(bandana)
                // Bandana knot
                let knotGeo = SCNSphere(radius: 0.04)
                let knotMat = SCNMaterial()
                knotMat.diffuse.contents = NSColor.systemOrange.withAlphaComponent(0.9)
                knotGeo.materials = [knotMat]
                let knot = SCNNode(geometry: knotGeo)
                knot.position = SCNVector3(0.2, 0, 0.02)
                bandana.addChildNode(knot)

            case .pongoWhite:
                // Bowler hat
                let brimGeo = SCNCylinder(radius: 0.34, height: 0.04)
                let hatMat = boxMat(NSColor(white: 0.65, alpha: 1))
                brimGeo.materials = [hatMat]
                let brim = SCNNode(geometry: brimGeo)
                brim.position = SCNVector3(0, 0.3, 0)
                head.addChildNode(brim)
                let crownGeo = SCNCylinder(radius: 0.22, height: 0.2)
                crownGeo.materials = [hatMat]
                let crown = SCNNode(geometry: crownGeo)
                crown.position = SCNVector3(0, 0.13, 0)
                brim.addChildNode(crown)
                // Monocle — small glass circle near right eye
                let monocleGeo = SCNTorus(ringRadius: 0.06, pipeRadius: 0.008)
                let monocleMat = SCNMaterial()
                monocleMat.diffuse.contents = NSColor(red: 0.85, green: 0.75, blue: 0.45, alpha: 1)
                monocleMat.metalness.contents = NSColor(white: 0.6, alpha: 1)
                monocleGeo.materials = [monocleMat]
                let monocle = SCNNode(geometry: monocleGeo)
                monocle.position = SCNVector3(0.18, 0.06, 0.32)
                head.addChildNode(monocle)
                // Glass lens
                let lensGeo = SCNCylinder(radius: 0.055, height: 0.003)
                let lensMat = SCNMaterial()
                lensMat.diffuse.contents = NSColor(white: 0.95, alpha: 0.3)
                lensMat.transparency = 0.6
                lensGeo.materials = [lensMat]
                let lens = SCNNode(geometry: lensGeo)
                lens.eulerAngles.x = CGFloat.pi / 2
                lens.position = SCNVector3(0, 0, 0.002)
                monocle.addChildNode(lens)

            case .pongoPurple:
                // Cute bow/ribbon on top of head
                let bowCenter = SCNSphere(radius: 0.04)
                let bowMat = SCNMaterial()
                bowMat.diffuse.contents = NSColor(red: 0.9, green: 0.5, blue: 0.7, alpha: 1)
                bowCenter.materials = [bowMat]
                let bowNode = SCNNode(geometry: bowCenter)
                bowNode.position = SCNVector3(0.15, 0.3, 0.1)
                head.addChildNode(bowNode)
                // Bow wings (two flattened spheres)
                for side: CGFloat in [-1, 1] {
                    let wingGeo = SCNSphere(radius: 0.06)
                    wingGeo.materials = [bowMat]
                    let wing = SCNNode(geometry: wingGeo)
                    wing.position = SCNVector3(side * 0.06, 0, 0)
                    wing.scale = SCNVector3(1.2, 0.7, 0.5)
                    bowNode.addChildNode(wing)
                }

            case .pongoBlue:
                // Cool sunglasses
                let bridgeGeo = SCNCylinder(radius: 0.01, height: 0.15)
                let glassMat = SCNMaterial()
                glassMat.diffuse.contents = NSColor(white: 0.15, alpha: 1)
                glassMat.metalness.contents = NSColor(white: 0.4, alpha: 1)
                bridgeGeo.materials = [glassMat]
                let bridge = SCNNode(geometry: bridgeGeo)
                bridge.position = SCNVector3(0, 0.1, 0.32)
                bridge.eulerAngles.z = CGFloat.pi / 2
                head.addChildNode(bridge)
                // Two dark lens circles
                for side: CGFloat in [-1, 1] {
                    let lensGeo2 = SCNCylinder(radius: 0.07, height: 0.015)
                    let lensMat2 = SCNMaterial()
                    lensMat2.diffuse.contents = NSColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 0.85)
                    lensMat2.metalness.contents = NSColor(white: 0.5, alpha: 1)
                    lensGeo2.materials = [lensMat2]
                    let lensNode = SCNNode(geometry: lensGeo2)
                    lensNode.position = SCNVector3(side * 0.14, 0.1, 0.33)
                    lensNode.eulerAngles.x = CGFloat.pi / 2
                    head.addChildNode(lensNode)
                    // Frame ring
                    let frameGeo = SCNTorus(ringRadius: 0.07, pipeRadius: 0.008)
                    frameGeo.materials = [glassMat]
                    let frame = SCNNode(geometry: frameGeo)
                    frame.position = SCNVector3(side * 0.14, 0.1, 0.32)
                    head.addChildNode(frame)
                }

            default:
                break
            }

            // ── ARMS ── Stubby rounded-box arms
            let armGeo = SCNBox(width: 0.18, height: 0.32, length: 0.18, chamferRadius: 0.08)
            armGeo.materials = [boxMat(darkerMain)]

            let leftArm = SCNNode(geometry: armGeo)
            leftArm.position = SCNVector3(-0.44, 0.0, 0.05)
            leftArm.eulerAngles.z = CGFloat.pi / 8
            bodyNode.addChildNode(leftArm)
            leftArmNode = leftArm

            let rightArm = SCNNode(geometry: armGeo)
            rightArm.position = SCNVector3(0.44, 0.0, 0.05)
            rightArm.eulerAngles.z = -CGFloat.pi / 8
            bodyNode.addChildNode(rightArm)
            rightArmNode = rightArm

            // ── FEET ── Stubby rounded-box feet
            let footGeo = SCNBox(width: 0.22, height: 0.15, length: 0.25, chamferRadius: 0.06)
            footGeo.materials = [boxMat(darkerMain)]

            let leftFoot = SCNNode(geometry: footGeo)
            leftFoot.position = SCNVector3(-0.18, -0.32, 0.05)
            bodyNode.addChildNode(leftFoot)
            leftFootNode = leftFoot

            let rightFoot = SCNNode(geometry: footGeo)
            rightFoot.position = SCNVector3(0.18, -0.32, 0.05)
            bodyNode.addChildNode(rightFoot)
            rightFootNode = rightFoot

            // ── Dummy nodes for animations that reference optional parts ──
            // Pongo characters don't have ears/tail/cheeks, but animations reference them.
            // Use invisible nodes so animations don't crash.
            let dummyNode = SCNNode()
            leftEarNode = leftEarNode ?? dummyNode
            rightEarNode = rightEarNode ?? dummyNode
            tailNode = tailNode ?? dummyNode
            leftCheekNode = leftCheekNode ?? dummyNode
            rightCheekNode = rightCheekNode ?? dummyNode
            leftPupilNode = leftPupilNode ?? dummyNode
            rightPupilNode = rightPupilNode ?? dummyNode

            return root
        }

        private enum PongoEyeStyle {
            case round, slant, wink
        }

        private enum PongoMouthStyle {
            case happy, sad, smirk
        }

        // MARK: - Animations

        private func startIdleAnimations(_ root: SCNNode) {
            // Gentle breathing/bounce
            let breathe = SCNAction.sequence([
                SCNAction.moveBy(x: 0, y: 0.06, z: 0, duration: 1.5),
                SCNAction.moveBy(x: 0, y: -0.06, z: 0, duration: 1.5)
            ])
            breathe.timingMode = .easeInEaseOut
            root.runAction(.repeatForever(breathe), forKey: "breathe")

            // Subtle side sway
            let sway = SCNAction.sequence([
                SCNAction.rotateBy(x: 0, y: 0, z: 0.04, duration: 2.0),
                SCNAction.rotateBy(x: 0, y: 0, z: -0.08, duration: 4.0),
                SCNAction.rotateBy(x: 0, y: 0, z: 0.04, duration: 2.0)
            ])
            sway.timingMode = .easeInEaseOut
            root.runAction(.repeatForever(sway), forKey: "sway")

            // Head look-around
            if let head = headNode {
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

                // Occasional head tilt (cute!)
                let headTilt = SCNAction.sequence([
                    SCNAction.wait(duration: Double.random(in: 7...12)),
                    SCNAction.rotateBy(x: 0, y: 0, z: 0.15, duration: 0.3),
                    SCNAction.wait(duration: 1.0),
                    SCNAction.rotateBy(x: 0, y: 0, z: -0.15, duration: 0.3)
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
            } else {
                wakeUp()
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
            let angle = atan2(dx, dz)

            let walkToMat = SCNAction.sequence([
                SCNAction.rotateTo(x: 0, y: angle, z: 0, duration: 0.3),
                SCNAction.moveBy(x: dx, y: 0, z: dz, duration: Double(dist) * 1.0),
                SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.3)
            ])

            // Show sleepy speech
            showSpeechBubble(pers.sleepyThoughts.first ?? "zzz... 💤")

            // Lay down animation
            let layDown = SCNAction.run { [weak self] _ in
                guard let self else { return }
                DispatchQueue.main.async {
                    self.showExpression(.sleepy)

                    // Tilt body sideways to lay down
                    if pers.sleepStyle == "sprawled" {
                        // Sprawled: on back, arms and legs out
                        self.bodyMeshNode?.runAction(SCNAction.rotateTo(x: CGFloat.pi / 2.2, y: 0, z: 0, duration: 0.8))
                        self.leftArmNode?.runAction(SCNAction.rotateTo(x: -0.3, y: 0, z: CGFloat.pi * 0.6, duration: 0.6))
                        self.rightArmNode?.runAction(SCNAction.rotateTo(x: -0.3, y: 0, z: -CGFloat.pi * 0.6, duration: 0.6))
                        self.leftFootNode?.runAction(SCNAction.rotateTo(x: -0.2, y: 0.3, z: 0, duration: 0.6))
                        self.rightFootNode?.runAction(SCNAction.rotateTo(x: -0.2, y: -0.3, z: 0, duration: 0.6))
                    } else if pers.sleepStyle == "on back" {
                        // On back: dignified
                        self.bodyMeshNode?.runAction(SCNAction.rotateTo(x: CGFloat.pi / 2.5, y: 0, z: 0, duration: 0.8))
                        self.leftArmNode?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: CGFloat.pi * 0.4, duration: 0.6))
                        self.rightArmNode?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: -CGFloat.pi * 0.4, duration: 0.6))
                    } else {
                        // Curled up: side position, compact
                        self.bodyMeshNode?.runAction(SCNAction.rotateTo(x: 0.3, y: 0, z: CGFloat.pi / 3, duration: 0.8))
                        self.leftArmNode?.runAction(SCNAction.rotateTo(x: -0.5, y: 0, z: 0.3, duration: 0.6))
                        self.rightArmNode?.runAction(SCNAction.rotateTo(x: -0.5, y: 0, z: -0.3, duration: 0.6))
                        self.leftFootNode?.runAction(SCNAction.rotateTo(x: -0.4, y: 0, z: 0, duration: 0.6))
                        self.rightFootNode?.runAction(SCNAction.rotateTo(x: -0.4, y: 0, z: 0, duration: 0.6))
                    }

                    // Lower body toward ground
                    body.runAction(SCNAction.moveBy(x: 0, y: -0.2, z: 0, duration: 0.8))

                    // Close eyes
                    self.leftEyeNode?.runAction(SCNAction.scale(to: 0.1, duration: 0.5))
                    self.rightEyeNode?.runAction(SCNAction.scale(to: 0.1, duration: 0.5))

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

            // Reset limbs
            leftArmNode?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: CGFloat.pi / 6, duration: 0.4))
            rightArmNode?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: -CGFloat.pi / 6, duration: 0.4))
            leftFootNode?.runAction(SCNAction.move(to: SCNVector3(-0.18, -0.45, 0.05), duration: 0.4))
            rightFootNode?.runAction(SCNAction.move(to: SCNVector3(0.18, -0.45, 0.05), duration: 0.4))

            // Open eyes
            leftEyeNode?.runAction(SCNAction.scale(to: 1.0, duration: 0.3))
            rightEyeNode?.runAction(SCNAction.scale(to: 1.0, duration: 0.3))

            // Stretch animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                guard let self else { return }
                // Big stretch!
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
            let angle = atan2(dx, dz)
            let faceDirection = SCNAction.rotateTo(x: 0, y: angle, z: 0, duration: 0.3)

            // Leg movement (alternate feet up/down)
            let stepDuration = 0.25
            let stepCount = max(2, Int(walkDuration / stepDuration))
            var legActions: [SCNAction] = []
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

            // Reset limbs after walk + check for topples
            let resetLimbs = SCNAction.run { [weak self] _ in
                guard let self else { return }
                self.leftFootNode?.runAction(SCNAction.move(to: SCNVector3(-0.18, -0.45, 0.05), duration: 0.2))
                self.rightFootNode?.runAction(SCNAction.move(to: SCNVector3(0.18, -0.45, 0.05), duration: 0.2))
                self.leftArmNode?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: CGFloat.pi / 6, duration: 0.2))
                self.rightArmNode?.runAction(SCNAction.rotateTo(x: 0, y: 0, z: -CGFloat.pi / 6, duration: 0.2))
                // Check if pet knocked anything over
                if let body = self.petBodyNode {
                    self.checkForTopples(at: body.position)
                }
            }

            let moveToTarget = SCNAction.moveBy(x: dx, y: 0, z: dz, duration: walkDuration)
            moveToTarget.timingMode = .easeInEaseOut

            // Face back to camera after arriving
            let faceCamera = SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.4)

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

            let angle = atan2(dx, dz)
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

            let faceCamera = SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.3)

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
                    let angle = atan2(dx, dz)
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
                            let angle = atan2(dx, dz)
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
            let angle = atan2(dx, dz)
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

            let faceCamera = SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.3)

            body.runAction(SCNAction.sequence([walkToIt, fixIt, SCNAction.wait(duration: 1.2), faceCamera]), forKey: "fixTopple")
        }

        // MARK: - Speech Bubble

        private func showSpeechBubble(_ text: String) {
            guard let scene = sceneRef, let body = petBodyNode else { return }

            // Remove any existing speech bubble
            scene.rootNode.childNode(withName: "speechBubble", recursively: false)?.removeFromParentNode()

            // Render the bubble + text as a 2D image, then display on a plane.
            // This avoids SCNText visibility issues with lighting/z-fighting.
            let fontSize: CGFloat = 28
            let font = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.black
            ]
            let textSize = (text as NSString).size(withAttributes: attributes)
            let hPad: CGFloat = 24
            let vPad: CGFloat = 16
            let imgWidth = textSize.width + hPad * 2
            let imgHeight = textSize.height + vPad * 2 + 14  // extra space for triangle

            let image = NSImage(size: NSSize(width: imgWidth, height: imgHeight), flipped: true) { rect in
                let bubbleRect = NSRect(x: 0, y: 0, width: imgWidth, height: imgHeight - 14)
                let bubblePath = NSBezierPath(roundedRect: bubbleRect, xRadius: 14, yRadius: 14)
                NSColor.white.withAlphaComponent(0.95).setFill()
                bubblePath.fill()

                // Triangle pointer at bottom center
                let triPath = NSBezierPath()
                let cx = imgWidth / 2
                triPath.move(to: NSPoint(x: cx - 8, y: imgHeight - 14))
                triPath.line(to: NSPoint(x: cx, y: imgHeight))
                triPath.line(to: NSPoint(x: cx + 8, y: imgHeight - 14))
                triPath.close()
                NSColor.white.withAlphaComponent(0.95).setFill()
                triPath.fill()

                // Draw text centered in bubble
                let textOrigin = NSPoint(x: hPad, y: vPad)
                (text as NSString).draw(at: textOrigin, withAttributes: attributes)
                return true
            }

            // Scale: map pixel size to scene units (roughly 1 scene unit = 200px)
            let scaleFactor: CGFloat = 200
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
            let petY = CGFloat(body.position.y) + 2.0
            // Clamp bubble X to stay within visible area regardless of pet position
            let bubbleX = max(-0.7, min(0.7, CGFloat(body.position.x)))
            let bubbleZ = min(1.0, CGFloat(body.position.z) + 0.3)
            bubbleNode.position = SCNVector3(bubbleX, petY, bubbleZ)

            // Always face camera
            let constraint = SCNBillboardConstraint()
            constraint.freeAxes = .all
            bubbleNode.constraints = [constraint]

            scene.rootNode.addChildNode(bubbleNode)

            // Pop in
            bubbleNode.scale = SCNVector3(0.01, 0.01, 0.01)
            bubbleNode.runAction(SCNAction.sequence([
                SCNAction.scale(to: 1.0, duration: 0.15),
                SCNAction.wait(duration: 2.5),
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

        private func startBlinking() {
            Timer.scheduledTimer(withTimeInterval: Double.random(in: 2.8...4.5), repeats: true) { [weak self] _ in
                guard let self, let leftEye = self.leftEyeNode, let rightEye = self.rightEyeNode else { return }
                let close = SCNAction.scale(to: 0.15, duration: 0.06)
                let open = SCNAction.scale(to: 1.0, duration: 0.06)
                let blinkSeq = SCNAction.sequence([close, SCNAction.wait(duration: 0.08), open])

                // Occasionally double-blink
                let doDouble = Bool.random()
                let fullBlink = doDouble
                    ? SCNAction.sequence([blinkSeq, SCNAction.wait(duration: 0.15), blinkSeq])
                    : blinkSeq

                DispatchQueue.main.async {
                    leftEye.runAction(fullBlink)
                    rightEye.runAction(fullBlink)
                }
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
            let foodItems = petCharacter.personality.foods
            let foodEmoji = foodItems.randomElement()!
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
                let angle = atan2(dx, dz)
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
