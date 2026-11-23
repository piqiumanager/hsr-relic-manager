/*
MIT License

Copyright (c) 2024 Fribbels

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.


*/
globalThis.HSRCore=(()=>{
const gameData={characters:{},lightCones:{}};
const CURRENT_OPTIMIZER_VERSION = 'v4.8.1';
const CURRENT_DATA_VERSION = '4.8v1';
const SHOWCASE_DOWNTIME = false;
const RELIQUARY_DOWNTIME = false;
const DOWNTIME_VERSION = '4.7';
const CharacterAnnouncementMessages = {
    '1514': `${CURRENT_DATA_VERSION} beta - Numbers may change.`,
    '1515': `${CURRENT_DATA_VERSION} beta - Numbers may change.`
};
const Stats = {
    ATK_P: 'ATK%',
    ATK: 'ATK',
    BE: 'Break Effect',
    CD: 'CRIT DMG',
    CR: 'CRIT Rate',
    DEF_P: 'DEF%',
    DEF: 'DEF',
    EHR: 'Effect Hit Rate',
    ERR: 'Energy Regeneration Rate',
    Fire_DMG: 'Fire DMG Boost',
    HP_P: 'HP%',
    HP: 'HP',
    Ice_DMG: 'Ice DMG Boost',
    Imaginary_DMG: 'Imaginary DMG Boost',
    Lightning_DMG: 'Lightning DMG Boost',
    OHB: 'Outgoing Healing Boost',
    Physical_DMG: 'Physical DMG Boost',
    Quantum_DMG: 'Quantum DMG Boost',
    RES: 'Effect RES',
    SPD_P: 'SPD%',
    SPD: 'SPD',
    Wind_DMG: 'Wind DMG Boost',
    Elation: 'Elation'
};
const PERCENT_TO_FLAT_STAT = {
    [Stats.ATK_P]: Stats.ATK,
    [Stats.HP_P]: Stats.HP,
    [Stats.DEF_P]: Stats.DEF
};
const ELEMENTAL_DMG_KEY = 'ELEMENTAL_DMG';
const TwoPieceStatTags = [
    Stats.ATK_P,
    Stats.HP_P,
    Stats.DEF_P,
    Stats.SPD_P,
    Stats.CR,
    Stats.CD,
    Stats.OHB,
    Stats.BE
];
const MainStats = [
    Stats.HP_P,
    Stats.ATK_P,
    Stats.DEF_P,
    Stats.HP,
    Stats.ATK,
    Stats.SPD,
    Stats.CR,
    Stats.CD,
    Stats.EHR,
    Stats.BE,
    Stats.OHB,
    Stats.ERR,
    Stats.Physical_DMG,
    Stats.Fire_DMG,
    Stats.Ice_DMG,
    Stats.Lightning_DMG,
    Stats.Wind_DMG,
    Stats.Quantum_DMG,
    Stats.Imaginary_DMG
];
const AllStats = [
    Stats.ATK_P,
    Stats.ATK,
    Stats.BE,
    Stats.CD,
    Stats.CR,
    Stats.DEF_P,
    Stats.DEF,
    Stats.EHR,
    Stats.ERR,
    Stats.Fire_DMG,
    Stats.HP_P,
    Stats.HP,
    Stats.Ice_DMG,
    Stats.Imaginary_DMG,
    Stats.Lightning_DMG,
    Stats.OHB,
    Stats.Physical_DMG,
    Stats.Quantum_DMG,
    Stats.RES,
    Stats.SPD_P,
    Stats.SPD,
    Stats.Wind_DMG
];
const MainStatsValues = {
    [Stats.HP_P]: {
        5: {
            base: 6.912,
            increment: 2.4192
        },
        4: {
            base: 5.5296,
            increment: 1.9354
        },
        3: {
            base: 4.1472,
            increment: 1.4515
        },
        2: {
            base: 2.7648,
            increment: 0.9677
        }
    },
    [Stats.ATK_P]: {
        5: {
            base: 6.912,
            increment: 2.4192
        },
        4: {
            base: 5.5296,
            increment: 1.9354
        },
        3: {
            base: 4.1472,
            increment: 1.4515
        },
        2: {
            base: 2.7648,
            increment: 0.9677
        }
    },
    [Stats.DEF_P]: {
        5: {
            base: 8.64,
            increment: 3.024
        },
        4: {
            base: 6.912,
            increment: 2.4192
        },
        3: {
            base: 5.184,
            increment: 1.8144
        },
        2: {
            base: 3.456,
            increment: 1.2096
        }
    },
    [Stats.HP]: {
        5: {
            base: 112.896,
            increment: 39.5136
        },
        4: {
            base: 90.3168,
            increment: 31.61088
        },
        3: {
            base: 67.7376,
            increment: 23.70816
        },
        2: {
            base: 45.1584,
            increment: 15.80544
        }
    },
    [Stats.ATK]: {
        5: {
            base: 56.448,
            increment: 19.7568
        },
        4: {
            base: 45.1584,
            increment: 15.80544
        },
        3: {
            base: 33.8688,
            increment: 11.85408
        },
        2: {
            base: 22.5792,
            increment: 7.90272
        }
    },
    [Stats.SPD]: {
        5: {
            base: 4.032,
            increment: 1.4
        },
        4: {
            base: 3.226,
            increment: 1.1
        },
        3: {
            base: 2.419,
            increment: 1.0
        },
        2: {
            base: 1.613,
            increment: 1.0
        }
    },
    [Stats.CR]: {
        5: {
            base: 5.184,
            increment: 1.8144
        },
        4: {
            base: 4.1472,
            increment: 1.4515
        },
        3: {
            base: 3.1104,
            increment: 1.0886
        },
        2: {
            base: 2.0736,
            increment: 0.7258
        }
    },
    [Stats.CD]: {
        5: {
            base: 10.368,
            increment: 3.6288
        },
        4: {
            base: 8.2944,
            increment: 2.9030
        },
        3: {
            base: 6.2208,
            increment: 2.1773
        },
        2: {
            base: 4.1472,
            increment: 1.4515
        }
    },
    [Stats.EHR]: {
        5: {
            base: 6.912,
            increment: 2.4192
        },
        4: {
            base: 5.5296,
            increment: 1.9354
        },
        3: {
            base: 4.1472,
            increment: 1.4515
        },
        2: {
            base: 2.7648,
            increment: 0.9677
        }
    },
    [Stats.BE]: {
        5: {
            base: 10.3680,
            increment: 3.6288
        },
        4: {
            base: 8.2944,
            increment: 2.9030
        },
        3: {
            base: 6.2208,
            increment: 2.1773
        },
        2: {
            base: 4.1472,
            increment: 1.4515
        }
    },
    [Stats.ERR]: {
        5: {
            base: 3.1104,
            increment: 1.0886
        },
        4: {
            base: 2.4883,
            increment: 0.8709
        },
        3: {
            base: 1.8662,
            increment: 0.6532
        },
        2: {
            base: 1.2442,
            increment: 0.4355
        }
    },
    [Stats.OHB]: {
        5: {
            base: 5.5296,
            increment: 1.9354
        },
        4: {
            base: 4.4237,
            increment: 1.5483
        },
        3: {
            base: 3.3178,
            increment: 1.1612
        },
        2: {
            base: 2.2118,
            increment: 0.7741
        }
    },
    [Stats.Physical_DMG]: {
        5: {
            base: 6.2208,
            increment: 2.1773
        },
        4: {
            base: 4.9766,
            increment: 1.7418
        },
        3: {
            base: 3.7325,
            increment: 1.3064
        },
        2: {
            base: 2.4883,
            increment: 0.8709
        }
    },
    [Stats.Fire_DMG]: {
        5: {
            base: 6.2208,
            increment: 2.1773
        },
        4: {
            base: 4.9766,
            increment: 1.7418
        },
        3: {
            base: 3.7325,
            increment: 1.3064
        },
        2: {
            base: 2.4883,
            increment: 0.8709
        }
    },
    [Stats.Ice_DMG]: {
        5: {
            base: 6.2208,
            increment: 2.1773
        },
        4: {
            base: 4.9766,
            increment: 1.7418
        },
        3: {
            base: 3.7325,
            increment: 1.3064
        },
        2: {
            base: 2.4883,
            increment: 0.8709
        }
    },
    [Stats.Lightning_DMG]: {
        5: {
            base: 6.2208,
            increment: 2.1773
        },
        4: {
            base: 4.9766,
            increment: 1.7418
        },
        3: {
            base: 3.7325,
            increment: 1.3064
        },
        2: {
            base: 2.4883,
            increment: 0.8709
        }
    },
    [Stats.Wind_DMG]: {
        5: {
            base: 6.2208,
            increment: 2.1773
        },
        4: {
            base: 4.9766,
            increment: 1.7418
        },
        3: {
            base: 3.7325,
            increment: 1.3064
        },
        2: {
            base: 2.4883,
            increment: 0.8709
        }
    },
    [Stats.Quantum_DMG]: {
        5: {
            base: 6.2208,
            increment: 2.1773
        },
        4: {
            base: 4.9766,
            increment: 1.7418
        },
        3: {
            base: 3.7325,
            increment: 1.3064
        },
        2: {
            base: 2.4883,
            increment: 0.8709
        }
    },
    [Stats.Imaginary_DMG]: {
        5: {
            base: 6.2208,
            increment: 2.1773
        },
        4: {
            base: 4.9766,
            increment: 1.7418
        },
        3: {
            base: 3.7325,
            increment: 1.3064
        },
        2: {
            base: 2.4883,
            increment: 0.8709
        }
    }
};
const SubStats = [
    Stats.ATK_P,
    Stats.ATK,
    Stats.HP_P,
    Stats.HP,
    Stats.DEF_P,
    Stats.DEF,
    Stats.SPD,
    Stats.CR,
    Stats.CD,
    Stats.EHR,
    Stats.RES,
    Stats.BE
];
const SubStatValues = {
    [Stats.SPD]: {
        5: {
            high: 2.6,
            mid: 2.3,
            low: 2.0
        },
        4: {
            high: 2.0,
            mid: 1.8,
            low: 1.6
        },
        3: {
            high: 1.4,
            mid: 1.3,
            low: 1.2
        },
        2: {
            high: 1.2,
            mid: 1.1,
            low: 1.0
        }
    },
    [Stats.HP]: {
        5: {
            high: 42.33751,
            mid: 38.103755,
            low: 33.87
        },
        4: {
            high: 33.87,
            mid: 30.483,
            low: 27.096
        },
        3: {
            high: 25.402506,
            mid: 22.862253,
            low: 20.322
        },
        2: {
            high: 16.935,
            mid: 15.2415,
            low: 13.548
        }
    },
    [Stats.ATK]: {
        5: {
            high: 21.168754,
            mid: 19.051877,
            low: 16.935
        },
        4: {
            high: 16.935,
            mid: 15.2415,
            low: 13.548
        },
        3: {
            high: 12.701252,
            mid: 11.431126,
            low: 10.161
        },
        2: {
            high: 8.4675,
            mid: 7.62075,
            low: 6.774
        }
    },
    [Stats.DEF]: {
        5: {
            high: 21.168754,
            mid: 19.051877,
            low: 16.935
        },
        4: {
            high: 16.935,
            mid: 15.2415,
            low: 13.548
        },
        3: {
            high: 12.701252,
            mid: 11.431126,
            low: 10.161
        },
        2: {
            high: 8.4675,
            mid: 7.62075,
            low: 6.774
        }
    },
    [Stats.HP_P]: {
        5: {
            high: 4.32,
            mid: 3.888,
            low: 3.456
        },
        4: {
            high: 3.456,
            mid: 3.1104,
            low: 2.7648
        },
        3: {
            high: 2.592,
            mid: 2.3328,
            low: 2.0736
        },
        2: {
            high: 1.728,
            mid: 1.5552,
            low: 1.3824
        }
    },
    [Stats.ATK_P]: {
        5: {
            high: 4.32,
            mid: 3.888,
            low: 3.456
        },
        4: {
            high: 3.456,
            mid: 3.1104,
            low: 2.7648
        },
        3: {
            high: 2.592,
            mid: 2.3328,
            low: 2.0736
        },
        2: {
            high: 1.728,
            mid: 1.5552,
            low: 1.3824
        }
    },
    [Stats.DEF_P]: {
        5: {
            high: 5.4,
            mid: 4.86,
            low: 4.32
        },
        4: {
            high: 4.32,
            mid: 3.888,
            low: 3.456
        },
        3: {
            high: 3.24,
            mid: 2.916,
            low: 2.592
        },
        2: {
            high: 2.16,
            mid: 1.944,
            low: 1.728
        }
    },
    [Stats.BE]: {
        5: {
            high: 6.48,
            mid: 5.832,
            low: 5.184
        },
        4: {
            high: 5.184,
            mid: 4.6656,
            low: 4.1472
        },
        3: {
            high: 3.888,
            mid: 3.4992,
            low: 3.1104
        },
        2: {
            high: 2.592,
            mid: 2.3328,
            low: 2.0736
        }
    },
    [Stats.EHR]: {
        5: {
            high: 4.32,
            mid: 3.888,
            low: 3.456
        },
        4: {
            high: 3.456,
            mid: 3.1104,
            low: 2.7648
        },
        3: {
            high: 2.592,
            mid: 2.3328,
            low: 2.0736
        },
        2: {
            high: 1.728,
            mid: 1.5552,
            low: 1.3824
        }
    },
    [Stats.RES]: {
        5: {
            high: 4.32,
            mid: 3.888,
            low: 3.456
        },
        4: {
            high: 3.456,
            mid: 3.1104,
            low: 2.7648
        },
        3: {
            high: 2.592,
            mid: 2.3328,
            low: 2.0736
        },
        2: {
            high: 1.728,
            mid: 1.5552,
            low: 1.3824
        }
    },
    [Stats.CR]: {
        5: {
            high: 3.24,
            mid: 2.916,
            low: 2.592
        },
        4: {
            high: 2.592,
            mid: 2.3328,
            low: 2.0736
        },
        3: {
            high: 1.944,
            mid: 1.7496,
            low: 1.5552
        },
        2: {
            high: 1.296,
            mid: 1.1664,
            low: 1.0368
        }
    },
    [Stats.CD]: {
        5: {
            high: 6.48,
            mid: 5.832,
            low: 5.184
        },
        4: {
            high: 5.184,
            mid: 4.6656,
            low: 4.1472
        },
        3: {
            high: 3.888,
            mid: 3.4992,
            low: 3.1104
        },
        2: {
            high: 2.592,
            mid: 2.3328,
            low: 2.0736
        }
    }
};
const Parts = {
    Head: 'Head',
    Hands: 'Hands',
    Body: 'Body',
    Feet: 'Feet',
    PlanarSphere: 'PlanarSphere',
    LinkRope: 'LinkRope'
};
const PartsArray = [
    Parts.Head,
    Parts.Hands,
    Parts.Body,
    Parts.Feet,
    Parts.PlanarSphere,
    Parts.LinkRope
];
const MainStatParts = {
    Body: 'Body',
    Feet: 'Feet',
    PlanarSphere: 'PlanarSphere',
    LinkRope: 'LinkRope'
};
const MainStatPartsArray = [
    Parts.Body,
    Parts.Feet,
    Parts.PlanarSphere,
    Parts.LinkRope
];
const PartsMainStats = {
    [Parts.Head]: [
        Stats.HP
    ],
    [Parts.Hands]: [
        Stats.ATK
    ],
    [Parts.Body]: [
        Stats.HP_P,
        Stats.ATK_P,
        Stats.DEF_P,
        Stats.CR,
        Stats.CD,
        Stats.OHB,
        Stats.EHR
    ],
    [Parts.Feet]: [
        Stats.HP_P,
        Stats.ATK_P,
        Stats.DEF_P,
        Stats.SPD
    ],
    [Parts.PlanarSphere]: [
        Stats.HP_P,
        Stats.ATK_P,
        Stats.DEF_P,
        Stats.Physical_DMG,
        Stats.Fire_DMG,
        Stats.Ice_DMG,
        Stats.Lightning_DMG,
        Stats.Wind_DMG,
        Stats.Quantum_DMG,
        Stats.Imaginary_DMG
    ],
    [Parts.LinkRope]: [
        Stats.HP_P,
        Stats.ATK_P,
        Stats.DEF_P,
        Stats.BE,
        Stats.ERR
    ]
};
const Sets = {
    PasserbyOfWanderingCloud: 'Passerby of Wandering Cloud',
    MusketeerOfWildWheat: 'Musketeer of Wild Wheat',
    KnightOfPurityPalace: 'Knight of Purity Palace',
    HunterOfGlacialForest: 'Hunter of Glacial Forest',
    ChampionOfStreetwiseBoxing: 'Champion of Streetwise Boxing',
    GuardOfWutheringSnow: 'Guard of Wuthering Snow',
    FiresmithOfLavaForging: 'Firesmith of Lava-Forging',
    GeniusOfBrilliantStars: 'Genius of Brilliant Stars',
    BandOfSizzlingThunder: 'Band of Sizzling Thunder',
    EagleOfTwilightLine: 'Eagle of Twilight Line',
    ThiefOfShootingMeteor: 'Thief of Shooting Meteor',
    WastelanderOfBanditryDesert: 'Wastelander of Banditry Desert',
    LongevousDisciple: 'Longevous Disciple',
    MessengerTraversingHackerspace: 'Messenger Traversing Hackerspace',
    TheAshblazingGrandDuke: 'The Ashblazing Grand Duke',
    PrisonerInDeepConfinement: 'Prisoner in Deep Confinement',
    PioneerDiverOfDeadWaters: 'Pioneer Diver of Dead Waters',
    WatchmakerMasterOfDreamMachinations: 'Watchmaker, Master of Dream Machinations',
    IronCavalryAgainstTheScourge: 'Iron Cavalry Against the Scourge',
    TheWindSoaringValorous: 'The Wind-Soaring Valorous',
    SacerdosRelivedOrdeal: 'Sacerdos\' Relived Ordeal',
    ScholarLostInErudition: 'Scholar Lost in Erudition',
    HeroOfTriumphantSong: 'Hero of Triumphant Song',
    PoetOfMourningCollapse: 'Poet of Mourning Collapse',
    WarriorGoddessOfSunAndThunder: 'Warrior Goddess of Sun and Thunder',
    WavestriderCaptain: 'Wavestrider Captain',
    WorldRemakingDeliverer: 'World-Remaking Deliverer',
    SelfEnshroudedRecluse: 'Self-Enshrouded Recluse',
    EverGloriousMagicalGirl: 'Ever-Glorious Magical Girl',
    DivinerOfDistantReach: 'Diviner of Distant Reach',
    AsNavigatorIseeSeesIt: 'As Navigator Isee Sees It',
    DivineQueryingMasterSmith: 'Divine-Querying Master Smith',
    DreamlitActor: 'Dreamlit Actor',
    TheEdaciousHeretic: 'The Edacious Heretic',
    SpaceSealingStation: 'Space Sealing Station',
    FleetOfTheAgeless: 'Fleet of the Ageless',
    PanCosmicCommercialEnterprise: 'Pan-Cosmic Commercial Enterprise',
    BelobogOfTheArchitects: 'Belobog of the Architects',
    CelestialDifferentiator: 'Celestial Differentiator',
    InertSalsotto: 'Inert Salsotto',
    TaliaKingdomOfBanditry: 'Talia: Kingdom of Banditry',
    SprightlyVonwacq: 'Sprightly Vonwacq',
    RutilantArena: 'Rutilant Arena',
    BrokenKeel: 'Broken Keel',
    FirmamentFrontlineGlamoth: 'Firmament Frontline: Glamoth',
    PenaconyLandOfTheDreams: 'Penacony, Land of the Dreams',
    SigoniaTheUnclaimedDesolation: 'Sigonia, the Unclaimed Desolation',
    IzumoGenseiAndTakamaDivineRealm: 'Izumo Gensei and Takama Divine Realm',
    DuranDynastyOfRunningWolves: 'Duran, Dynasty of Running Wolves',
    ForgeOfTheKalpagniLantern: 'Forge of the Kalpagni Lantern',
    LushakaTheSunkenSeas: 'Lushaka, the Sunken Seas',
    TheWondrousBananAmusementPark: 'The Wondrous BananAmusement Park',
    BoneCollectionsSereneDemesne: 'Bone Collection\'s Serene Demesne',
    GiantTreeOfRaptBrooding: 'Giant Tree of Rapt Brooding',
    ArcadiaOfWovenDreams: 'Arcadia of Woven Dreams',
    RevelryByTheSea: 'Revelry by the Sea',
    AmphoreusTheEternalLand: 'Amphoreus, The Eternal Land',
    TengokuLivestream: 'Tengoku@Livestream',
    PunklordeStageZero: 'Punklorde Stage Zero',
    CityOfConvergingStars: 'City of Converging Stars',
    FallenStarAnchorage: 'Fallen Star Anchorage',
    CosmicLifeSciencesInstitute: 'Cosmic Life Sciences Institute',
    GodsMomentOfJoy: 'God\'s Moment of Joy',
    SubspaceASCCenter: 'Subspace ASC Center'
};
const officialOnly = false;
const characters = gameData.characters;
const lightCones = gameData.lightCones;
const UnreleasedSets = {};
if (officialOnly) {
    for (const character of Object.values(characters)){
        if (character.unreleased) {
            delete characters[character.id];
        }
    }
    for (const lightCone of Object.values(lightCones)){
        if (lightCone.unreleased) {
            delete lightCones[lightCone.id];
        }
    }
}
const PathNames = {
    Abundance: 'Abundance',
    Destruction: 'Destruction',
    Erudition: 'Erudition',
    Harmony: 'Harmony',
    Hunt: 'Hunt',
    Nihility: 'Nihility',
    Preservation: 'Preservation',
    Remembrance: 'Remembrance',
    Elation: 'Elation'
};
const ElementNames = {
    Physical: 'Physical',
    Quantum: 'Quantum',
    Imaginary: 'Imaginary',
    Ice: 'Ice',
    Wind: 'Wind',
    Fire: 'Fire',
    Lightning: 'Lightning'
};
const ElementToDamage = {
    Physical: Stats.Physical_DMG,
    Fire: Stats.Fire_DMG,
    Ice: Stats.Ice_DMG,
    Lightning: Stats.Lightning_DMG,
    Wind: Stats.Wind_DMG,
    Quantum: Stats.Quantum_DMG,
    Imaginary: Stats.Imaginary_DMG
};

const Constants={Parts,Stats,SubStats,PartsMainStats};
const i18next={t:s=>s};
function truncate10ths(x) {
    return Math.floor(x * 10) / 10;
}
function truncate100ths(x) {
    return Math.floor(x * 100) / 100;
}
function truncate1000ths(x) {
    return Math.floor(x * 1000) / 1000;
}
function truncate10000ths(x) {
    return Math.floor(x * 10000) / 10000;
}
function precisionRound(number, precision = 5) {
    if (precision === 5) return Math.round(number * 1e5) / 1e5;
    const factor = Math.pow(10, precision);
    return Math.round(number * factor) / factor;
}
function floorSafe(x) {
    return Math.floor(x + 0.0001);
}
function ceilSafe(x) {
    return Math.ceil(x - 0.0001);
}

function arrayIncludes(array, element) {
    return array.includes(element);
}
function arrayToMap(array, key) {
    return array.reduce((map, obj)=>{
        map[obj[key]] = obj;
        return map;
    }, {});
}
function stringArrayToMap(array) {
    return array.reduce((map, str)=>{
        map[str] = true;
        return map;
    }, {});
}
function filterUnique(arr) {
    return arr.filter((value, index, array)=>array.indexOf(value) === index);
}
function filterUniqueStringify(arr) {
    return arr.filter((value, index, array)=>{
        return index === array.findIndex((item)=>{
            if (typeof value !== 'object' || value === null) {
                return value === item;
            }
            return JSON.stringify(value) === JSON.stringify(item);
        });
    });
}
function getIndexOf(array, item) {
    return array.indexOf(item);
}
const ArrayFilters = {
    nonNullable: (x)=>x != null
};
function arrayOfZeroes(n) {
    return Array.from({
        length: n
    }, ()=>0);
}
function arrayOfValue(n, x) {
    return Array.from({
        length: n
    }, ()=>x);
}
function arraysShallowEqual(a, b) {
    if (a === b) return true;
    if (!a || !b) return false;
    if (a.length !== b.length) return false;
    for(let i = 0; i < a.length; i++){
        if (a[i] !== b[i]) return false;
    }
    return true;
}

function substatPotentialScale(stat) {
    return 6.48 / SubStatValues[stat][5].high;
}
function substatPotentialUnits(stat, value) {
    return value * substatPotentialScale(stat);
}
const GRADE_CONFIG = {
    2: {
        maxEnhance: 6,
        maxMainstat: 12.8562
    },
    3: {
        maxEnhance: 9,
        maxMainstat: 25.8165
    },
    4: {
        maxEnhance: 12,
        maxMainstat: 43.1304
    },
    5: {
        maxEnhance: 15,
        maxMainstat: 64.8
    }
};
const FLAT_STAT_SCALING = {
    [Stats.HP]: 0.4,
    [Stats.ATK]: 0.4,
    [Stats.DEF]: 0.4
};
function applyFlatStatScaling(stats) {
    for (const [pct, flat] of Object.entries(PERCENT_TO_FLAT_STAT)){
        if (flat) stats[flat] = (stats[pct] || 0) * FLAT_STAT_SCALING[flat];
    }
}
const POSSIBLE_SUBSTATS = new Set(Constants.SubStats);
const DMG_MAINSTATS = [
    Stats.Physical_DMG,
    Stats.Fire_DMG,
    Stats.Ice_DMG,
    Stats.Lightning_DMG,
    Stats.Wind_DMG,
    Stats.Quantum_DMG,
    Stats.Imaginary_DMG
];

function substatMinRolls(stat, value) {
    return value / SubStatValues[stat][5].low;
}
function weightedSubstatMinRolls(substats, weights) {
    let rolls = 0;
    for (const substat of substats){
        rolls += substatMinRolls(substat.stat, substat.value) * (weights[substat.stat] || 0);
    }
    return rolls;
}
function mainStatWeight(part, mainStat, meta) {
    if (!hasMainStat(part)) return 0;
    if (meta.parts[part].includes(mainStat)) return 1;
    return meta.stats[mainStat] ?? 0;
}
function getFlatMainstatBoost(meta, mainStat) {
    const stat = PERCENT_TO_FLAT_STAT[mainStat];
    if (!stat || meta.flatMainstatBoost !== stat) return undefined;
    const weight = meta.stats[mainStat] ?? 0;
    if (weight <= 0) return undefined;
    return {
        stat,
        contribution: weight * substatPotentialScale(stat),
        high: weight * substatPotentialUnits(stat, SubStatValues[stat][5].high),
        mid: weight * substatPotentialUnits(stat, SubStatValues[stat][5].mid),
        low: weight * substatPotentialUnits(stat, SubStatValues[stat][5].low)
    };
}
function getEffectiveSubstatAccessors(meta, mainStat) {
    const boost = getFlatMainstatBoost(meta, mainStat);
    return {
        contribution: (stat)=>boost?.stat === stat ? boost.contribution : meta.contributions[stat],
        high: (stat)=>boost?.stat === stat ? boost.high : meta.highRollPotential[stat],
        mid: (stat)=>boost?.stat === stat ? boost.mid : meta.midRollPotential[stat],
        low: (stat)=>boost?.stat === stat ? boost.low : meta.lowRollPotential[stat]
    };
}
function hasMainStat(part) {
    return part === Constants.Parts.Body || part === Constants.Parts.Feet || part === Constants.Parts.LinkRope || part === Constants.Parts.PlanarSphere;
}

var ScoringCase = /*#__PURE__*/ function(ScoringCase) {
    ScoringCase[ScoringCase["SINGLE_STAT"] = 0] = "SINGLE_STAT";
    ScoringCase[ScoringCase["HP"] = 1] = "HP";
    ScoringCase[ScoringCase["ATK"] = 2] = "ATK";
    ScoringCase[ScoringCase["DEF"] = 3] = "DEF";
    ScoringCase[ScoringCase["NORMAL"] = 4] = "NORMAL";
    ScoringCase[ScoringCase["NONE"] = 5] = "NONE";
    return ScoringCase;
}({});
function getHandlingCase(meta) {
    const substats = meta.sortedSubstats;
    if (substats[0][1] === 0) return 5;
    if (substats[1][1] === 0) return 0;
    if (substats[2][1] > 0) return 4;
    if (substats[1][0] === Constants.Stats.HP && substats[0][0] === Constants.Stats.HP_P) return 1;
    if (substats[1][0] === Constants.Stats.HP_P && substats[0][0] === Constants.Stats.HP) return 1;
    if (substats[1][0] === Constants.Stats.ATK && substats[0][0] === Constants.Stats.ATK_P) return 2;
    if (substats[1][0] === Constants.Stats.ATK_P && substats[0][0] === Constants.Stats.ATK) return 2;
    if (substats[1][0] === Constants.Stats.DEF && substats[0][0] === Constants.Stats.DEF_P) return 3;
    if (substats[1][0] === Constants.Stats.DEF_P && substats[0][0] === Constants.Stats.DEF) return 3;
    return 4;
}
function computeOptimalScore(part, mainstat, meta) {
    const handlingCase = getHandlingCase(meta);
    const { high } = getEffectiveSubstatAccessors(meta, mainstat);
    switch(handlingCase){
        case 5:
            return Infinity;
        case 1:
        case 2:
        case 3:
            {
                const stat1 = meta.sortedSubstats[0][0];
                const stat2 = meta.sortedSubstats[1][0];
                const stat1Blocked = stat1 === mainstat;
                const stat2Blocked = stat2 === mainstat;
                if (stat1Blocked && stat2Blocked) return Infinity;
                if (stat1Blocked) return 6 * high(stat2);
                if (stat2Blocked) return 6 * high(stat1);
                return 6 * high(stat1) + high(stat2);
            }
        case 0:
            {
                const stat = meta.sortedSubstats[0][0];
                if (stat === mainstat) return Infinity;
                return 6 * high(stat);
            }
        case 4:
            {
                const mainStat = resolveOptimalMainstat(part, mainstat, meta);
                const { high } = getEffectiveSubstatAccessors(meta, mainStat);
                const filtered = meta.sortedSubstats.filter(([name])=>name !== mainStat);
                const effective = filtered.map(([name])=>high(name)).sort((a, b)=>b - a);
                return 6 * effective[0] + effective[1] + effective[2] + effective[3];
            }
    }
}
function resolveOptimalMainstat(part, mainstat, meta) {
    const optimalMainStats = meta.parts[part] || [];
    if (optimalMainStats.includes(mainstat) || meta.stats[mainstat] === 1 || !hasMainStat(part)) {
        return mainstat;
    }
    const scoreEntries = AllStats.map((stat)=>{
        const value = meta.stats[stat] ?? 0;
        if (optimalMainStats.includes(stat) || meta.stats[stat] === 1) {
            return [
                stat,
                1
            ];
        } else return [
            stat,
            value
        ];
    }).sort((a, b)=>{
        return b[1] - a[1];
    });
    const possibleMainStats = PartsMainStats[part];
    const mainStatIndex = scoreEntries.findIndex(([name, _weight])=>possibleMainStats.includes(name));
    const mainStatWeight = scoreEntries[mainStatIndex][1];
    let mainStat = scoreEntries[mainStatIndex][0];
    let isIdeal = false;
    let isSubstat = true;
    for(let i = mainStatIndex; i < scoreEntries.length; i++){
        const [name, weight] = scoreEntries[i];
        if (weight !== mainStatWeight) break;
        if (!possibleMainStats.includes(name)) continue;
        const newIsIdeal = optimalMainStats.includes(name);
        const newIsSubstat = POSSIBLE_SUBSTATS.has(name);
        if (isIdeal && !newIsIdeal) continue;
        if (!isSubstat && newIsSubstat) continue;
        if (isIdeal === newIsIdeal && isSubstat === newIsSubstat) continue;
        mainStat = name;
        isIdeal = newIsIdeal;
        isSubstat = newIsSubstat;
    }
    return mainStat;
}

const EMPTY_FUTURE_META = {};
function computeFutureScores(relic, meta, idealScore, withMeta) {
    const relicGrade = relic.grade;
    const grade = GRADE_CONFIG[relicGrade] ? relicGrade : 5;
    const config = GRADE_CONFIG[grade];
    const part = relic.part;
    const isSelectablePart = part === Parts.Body || part === Parts.Feet || part === Parts.PlanarSphere || part === Parts.LinkRope;
    let deduction = 0;
    if (isSelectablePart) {
        const w = meta.parts[part].includes(relic.main.stat) ? 1 : meta.stats[relic.main.stat] ?? 0;
        deduction = (w - 1) * config.maxMainstat;
    }
    const normFactor = idealScore === Infinity ? 0 : 100 / idealScore;
    const allSubstats = relic.previewSubstats.length > 0 ? relic.substats.concat(relic.previewSubstats) : relic.substats;
    if (allSubstats.length === 0) {
        return {
            current: 0,
            best: 0,
            average: 0,
            worst: 0,
            rerollAvg: 0,
            blockerAvg: 0,
            meta: EMPTY_FUTURE_META
        };
    }
    const mainStat = relic.main.stat;
    const { contribution, high, mid, low } = getEffectiveSubstatAccessors(meta, mainStat);
    const needsFill = allSubstats.length < 4;
    let availableSubstats;
    if (needsFill) {
        const s0 = allSubstats[0]?.stat;
        const s1 = allSubstats[1]?.stat;
        const s2 = allSubstats[2]?.stat;
        availableSubstats = meta.sortedSubstats.filter((x)=>{
            const s = x[0];
            return s !== mainStat && s !== s0 && s !== s1 && s !== s2;
        });
    } else {
        availableSubstats = undefined;
    }
    const remainingRolls = Math.ceil((config.maxEnhance - relic.enhance) / 3) - (4 - relic.substats.length);
    const highRollPotential = (stat)=>grade === 5 ? high(stat) : SubStatValues[stat][grade].high * contribution(stat);
    const lowRollPotential = (stat)=>grade === 5 ? low(stat) : SubStatValues[stat][grade].low * contribution(stat);
    const midRollPotential = (stat)=>grade === 5 ? mid(stat) : SubStatValues[stat][grade].mid * contribution(stat);
    const rollMidFactor = remainingRolls / 4;
    const subsLen = relic.substats.length;
    const sub0 = allSubstats[0];
    const stat0 = sub0.stat;
    const c0 = contribution(stat0);
    const vc0 = sub0.value * c0;
    const mr0 = midRollPotential(stat0);
    let baseRaw = vc0;
    let currentRaw = vc0;
    let avgRaw = vc0 + rollMidFactor * mr0;
    let addedRollsSum = sub0.addedRolls ?? 0;
    let midRollSum = mr0;
    let maxHighRollPotential = highRollPotential(stat0);
    let minLowRollPotential = lowRollPotential(stat0);
    let minMidRollPotential = mr0;
    let bestUpgradeStat = stat0;
    let worstUpgradeStat = stat0;
    let blockedUpgradeStat = stat0;
    for(let i = 1; i < allSubstats.length; i++){
        const sub = allSubstats[i];
        const stat = sub.stat;
        const c = contribution(stat);
        const vc = sub.value * c;
        const mr = midRollPotential(stat);
        if (i < subsLen) currentRaw += vc;
        baseRaw += vc;
        avgRaw += vc + rollMidFactor * mr;
        addedRollsSum += sub.addedRolls ?? 0;
        midRollSum += mr;
        const highPotential = highRollPotential(stat);
        if (highPotential > maxHighRollPotential) {
            maxHighRollPotential = highPotential;
            bestUpgradeStat = stat;
        }
        const lowPotential = lowRollPotential(stat);
        if (lowPotential < minLowRollPotential) {
            minLowRollPotential = lowPotential;
            worstUpgradeStat = stat;
        }
        if (mr < minMidRollPotential) {
            minMidRollPotential = mr;
            blockedUpgradeStat = stat;
        }
    }
    let bestRaw = baseRaw;
    let worstRaw = baseRaw;
    const current = truncate10ths(precisionRound(Math.max(0, (currentRaw + deduction) * normFactor)));
    if (needsFill) {
        const bestAvailableSubstats = availableSubstats.slice().sort((a, b)=>highRollPotential(b[0]) - highRollPotential(a[0]));
        const worstAvailableSubstats = availableSubstats.slice().sort((a, b)=>lowRollPotential(a[0]) - lowRollPotential(b[0]));
        for(let i = allSubstats.length; i < 4; i++){
            const idx = i - allSubstats.length;
            const bestStat = bestAvailableSubstats[idx][0];
            bestRaw += highRollPotential(bestStat);
            const bestPotential = highRollPotential(bestStat);
            if (bestPotential > maxHighRollPotential) {
                maxHighRollPotential = bestPotential;
                bestUpgradeStat = bestStat;
            }
            const worstStat = worstAvailableSubstats[idx][0];
            worstRaw += lowRollPotential(worstStat);
            const worstPotential = lowRollPotential(worstStat);
            if (worstPotential < minLowRollPotential) {
                minLowRollPotential = worstPotential;
                worstUpgradeStat = worstStat;
            }
            const midPotential = midRollPotential(worstStat);
            if (midPotential < minMidRollPotential) {
                minMidRollPotential = midPotential;
                blockedUpgradeStat = worstStat;
            }
        }
        let avgNewContrib = 0;
        for (const [stat] of availableSubstats)avgNewContrib += midRollPotential(stat);
        avgNewContrib /= availableSubstats.length;
        avgRaw += (4 - allSubstats.length) * avgNewContrib * (1 + rollMidFactor);
    }
    bestRaw += remainingRolls * highRollPotential(bestUpgradeStat);
    const best = Math.max(0, (bestRaw + deduction) * normFactor);
    const average = Math.max(0, (avgRaw + deduction) * normFactor);
    worstRaw += remainingRolls * lowRollPotential(worstUpgradeStat);
    const worst = Math.max(0, (worstRaw + deduction) * normFactor);
    let levelupMetadata = undefined;
    if (withMeta) {
        const bestAddedStats = [];
        if (allSubstats.length < 4 && availableSubstats.length > 0) {
            let topPotential = 0;
            for (const [stat] of availableSubstats){
                topPotential = Math.max(topPotential, highRollPotential(stat));
            }
            for (const [stat] of availableSubstats){
                if (highRollPotential(stat) === topPotential) bestAddedStats.push(stat);
            }
        }
        const candidateSubstats = meta.sortedSubstats.filter((x)=>relic.main.stat !== x[0]);
        const bestUpgradedStats = [];
        const validUpgrades = {
            ...arrayToMap(allSubstats, 'stat'),
            ...stringArrayToMap(bestAddedStats)
        };
        const upgradeCandidates = candidateSubstats.filter((candidateSubstats)=>validUpgrades[candidateSubstats[0]]);
        if (upgradeCandidates.length > 0) {
            let bestPotential = 0;
            for (const [stat] of upgradeCandidates){
                bestPotential = Math.max(bestPotential, highRollPotential(stat));
            }
            for (const [stat] of upgradeCandidates){
                if (validUpgrades[stat] && highRollPotential(stat) === bestPotential) bestUpgradedStats.push(stat);
            }
        }
        bestAddedStats.forEach((s, i)=>bestAddedStats[i] = i18next.t(`common:Stats.${s}`));
        bestUpgradedStats.forEach((s, i)=>bestUpgradedStats[i] = i18next.t(`common:Stats.${s}`));
        levelupMetadata = {
            bestAddedStats: bestAddedStats,
            bestUpgradedStats: bestUpgradedStats
        };
    }
    let rerollAvg = 0;
    let blockerAvg = 0;
    let blockedStat;
    if (relic.grade === 5 && allSubstats.length === 4) {
        const totalRolls = Math.min(addedRollsSum, 5);
        blockedStat = blockedUpgradeStat;
        const blockedMid = midRollPotential(blockedStat);
        rerollAvg = Math.min(midRollSum * (1 + totalRolls / 4), idealScore);
        rerollAvg = (rerollAvg + deduction) * normFactor;
        blockerAvg = Math.min(blockedMid + (midRollSum - blockedMid) * (1 + totalRolls / 3), idealScore);
        blockerAvg = (blockerAvg + deduction) * normFactor;
    }
    return {
        current,
        best,
        average,
        worst,
        rerollAvg,
        blockerAvg,
        meta: levelupMetadata ?? EMPTY_FUTURE_META
    };
}

return {Stats,Parts,Sets,PartsMainStats,SubStats,SubStatValues,MainStatsValues,AllStats,computeOptimalScore,computeFutureScores,applyFlatStatScaling,substatPotentialScale,precisionRound,truncate10ths};
})();