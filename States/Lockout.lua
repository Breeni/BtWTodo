--[[
    State provider for raid and dungeon lockouts
]]

local ADDON_NAME, Internal = ...
local External = _G[ADDON_NAME]
local L = Internal.L

-- Maps input names to ids
local mapNameToID = {}
-- On ADDON_LOADED we loop through these to get encounter names, instanceID and dungeonEncounterID
local journalEncounterData = {
    89,
    90,
    91,
    92,
    93,
    95,
    96,
    97,
    98,
    99,
    100,
    101,
    102,
    103,
    104,
    105,
    106,
    107,
    108,
    109,
    110,
    111,
    112,
    113,
    114,
    115,
    116,
    117,
    118,
    119,
    122,
    124,
    125,
    126,
    127,
    128,
    129,
    130,
    131,
    132,
    133,
    134,
    139,
    140,
    154,
    155,
    156,
    157,
    158,
    167,
    168,
    169,
    170,
    171,
    172,
    173,
    174,
    175,
    176,
    177,
    178,
    179,
    180,
    181,
    184,
    185,
    186,
    187,
    188,
    189,
    190,
    191,
    192,
    193,
    194,
    195,
    196,
    197,
    198,
    283,
    285,
    289,
    290,
    291,
    292,
    311,
    317,
    318,
    322,
    323,
    324,
    325,
    331,
    332,
    333,
    335,
    339,
    340,
    341,
    342,
    368,
    369,
    370,
    371,
    372,
    373,
    374,
    375,
    376,
    377,
    378,
    379,
    380,
    381,
    383,
    384,
    385,
    386,
    387,
    388,
    389,
    390,
    391,
    392,
    393,
    394,
    395,
    396,
    402,
    403,
    404,
    405,
    406,
    407,
    408,
    409,
    410,
    411,
    412,
    413,
    414,
    415,
    416,
    417,
    418,
    419,
    420,
    421,
    422,
    423,
    424,
    425,
    426,
    427,
    428,
    429,
    430,
    431,
    433,
    436,
    437,
    443,
    444,
    445,
    446,
    447,
    448,
    449,
    450,
    451,
    452,
    453,
    454,
    455,
    456,
    457,
    458,
    459,
    463,
    464,
    465,
    466,
    467,
    468,
    469,
    470,
    471,
    472,
    473,
    474,
    475,
    476,
    477,
    478,
    479,
    480,
    481,
    483,
    484,
    485,
    486,
    487,
    489,
    523,
    524,
    527,
    528,
    529,
    530,
    531,
    532,
    533,
    534,
    535,
    536,
    537,
    538,
    539,
    540,
    541,
    542,
    543,
    544,
    545,
    546,
    547,
    548,
    549,
    550,
    551,
    552,
    553,
    554,
    555,
    556,
    557,
    558,
    559,
    560,
    561,
    562,
    563,
    564,
    565,
    566,
    568,
    569,
    570,
    571,
    572,
    573,
    574,
    575,
    576,
    577,
    578,
    579,
    580,
    581,
    582,
    583,
    584,
    585,
    586,
    587,
    588,
    589,
    590,
    591,
    592,
    593,
    594,
    595,
    596,
    597,
    598,
    599,
    600,
    601,
    602,
    603,
    604,
    605,
    606,
    607,
    608,
    609,
    610,
    611,
    612,
    613,
    614,
    615,
    616,
    617,
    618,
    619,
    620,
    621,
    622,
    623,
    624,
    625,
    626,
    627,
    628,
    629,
    630,
    631,
    632,
    634,
    635,
    636,
    637,
    638,
    639,
    640,
    641,
    642,
    643,
    644,
    649,
    654,
    655,
    656,
    657,
    658,
    659,
    660,
    663,
    664,
    665,
    666,
    668,
    669,
    670,
    671,
    672,
    673,
    674,
    675,
    676,
    677,
    679,
    682,
    683,
    684,
    685,
    686,
    687,
    688,
    689,
    690,
    691,
    692,
    693,
    694,
    695,
    696,
    697,
    698,
    708,
    709,
    713,
    725,
    726,
    727,
    728,
    729,
    737,
    738,
    741,
    742,
    743,
    744,
    745,
    748,
    749,
    814,
    816,
    817,
    818,
    819,
    820,
    821,
    824,
    825,
    826,
    827,
    828,
    829,
    831,
    832,
    833,
    834,
    846,
    849,
    850,
    851,
    852,
    853,
    856,
    857,
    858,
    859,
    860,
    861,
    864,
    865,
    866,
    867,
    868,
    869,
    870,
    881,
    887,
    888,
    889,
    893,
    895,
    896,
    899,
    900,
    901,
    959,
    965,
    966,
    967,
    968,
    971,
    1122,
    1123,
    1128,
    1133,
    1138,
    1139,
    1140,
    1141,
    1142,
    1143,
    1144,
    1145,
    1146,
    1147,
    1148,
    1153,
    1154,
    1155,
    1160,
    1161,
    1162,
    1163,
    1168,
    1185,
    1186,
    1195,
    1196,
    1197,
    1202,
    1203,
    1207,
    1208,
    1209,
    1210,
    1211,
    1214,
    1216,
    1225,
    1226,
    1227,
    1228,
    1229,
    1234,
    1235,
    1236,
    1237,
    1238,
    1262,
    1291,
    1372,
    1391,
    1392,
    1394,
    1395,
    1396,
    1425,
    1426,
    1427,
    1432,
    1433,
    1438,
    1447,
    1452,
    1467,
    1468,
    1469,
    1470,
    1479,
    1480,
    1485,
    1486,
    1487,
    1488,
    1489,
    1490,
    1491,
    1492,
    1497,
    1498,
    1499,
    1500,
    1501,
    1502,
    1512,
    1518,
    1519,
    1520,
    1521,
    1522,
    1523,
    1524,
    1525,
    1526,
    1527,
    1528,
    1529,
    1530,
    1531,
    1532,
    1533,
    1534,
    1535,
    1536,
    1537,
    1538,
    1539,
    1540,
    1541,
    1542,
    1543,
    1544,
    1545,
    1546,
    1547,
    1548,
    1549,
    1550,
    1551,
    1552,
    1553,
    1554,
    1555,
    1556,
    1557,
    1559,
    1560,
    1561,
    1562,
    1563,
    1564,
    1565,
    1566,
    1567,
    1568,
    1569,
    1570,
    1571,
    1572,
    1573,
    1574,
    1575,
    1576,
    1577,
    1578,
    1579,
    1580,
    1581,
    1582,
    1583,
    1584,
    1585,
    1586,
    1587,
    1588,
    1589,
    1590,
    1591,
    1592,
    1593,
    1594,
    1595,
    1596,
    1597,
    1598,
    1599,
    1600,
    1601,
    1602,
    1603,
    1604,
    1605,
    1606,
    1607,
    1608,
    1609,
    1610,
    1611,
    1612,
    1613,
    1614,
    1615,
    1616,
    1617,
    1618,
    1619,
    1620,
    1621,
    1622,
    1623,
    1624,
    1625,
    1626,
    1627,
    1628,
    1629,
    1630,
    1631,
    1632,
    1633,
    1634,
    1635,
    1636,
    1637,
    1638,
    1639,
    1640,
    1641,
    1642,
    1643,
    1644,
    1645,
    1646,
    1647,
    1648,
    1649,
    1650,
    1651,
    1652,
    1653,
    1654,
    1655,
    1656,
    1657,
    1662,
    1663,
    1664,
    1665,
    1667,
    1672,
    1673,
    1686,
    1687,
    1688,
    1693,
    1694,
    1695,
    1696,
    1697,
    1702,
    1703,
    1704,
    1706,
    1711,
    1713,
    1718,
    1719,
    1720,
    1725,
    1726,
    1731,
    1732,
    1737,
    1738,
    1743,
    1744,
    1749,
    1750,
    1751,
    1756,
    1761,
    1762,
    1763,
    1764,
    1769,
    1770,
    1774,
    1783,
    1789,
    1790,
    1795,
    1796,
    1817,
    1818,
    1819,
    1820,
    1825,
    1826,
    1827,
    1829,
    1830,
    1835,
    1836,
    1837,
    1838,
    1856,
    1861,
    1862,
    1867,
    1872,
    1873,
    1878,
    1883,
    1884,
    1885,
    1896,
    1897,
    1898,
    1903,
    1904,
    1905,
    1906,
    1956,
    1979,
    1980,
    1981,
    1982,
    1983,
    1984,
    1985,
    1986,
    1987,
    1992,
    1997,
    2004,
    2009,
    2010,
    2011,
    2012,
    2013,
    2014,
    2015,
    2025,
    2030,
    2031,
    2036,
    2082,
    2083,
    2093,
    2094,
    2095,
    2096,
    2097,
    2098,
    2099,
    2102,
    2109,
    2114,
    2115,
    2116,
    2125,
    2126,
    2127,
    2128,
    2129,
    2130,
    2131,
    2132,
    2133,
    2134,
    2139,
    2140,
    2141,
    2142,
    2143,
    2144,
    2145,
    2146,
    2147,
    2153,
    2154,
    2155,
    2156,
    2157,
    2158,
    2165,
    2166,
    2167,
    2168,
    2169,
    2170,
    2171,
    2172,
    2173,
    2194,
    2195,
    2197,
    2198,
    2199,
    2210,
    2212,
    2213,
    2323,
    2325,
    2328,
    2329,
    2330,
    2331,
    2332,
    2333,
    2334,
    2335,
    2336,
    2337,
    2339,
    2340,
    2341,
    2342,
    2343,
    2344,
    2345,
    2347,
    2348,
    2349,
    2351,
    2352,
    2353,
    2354,
    2355,
    2357,
    2358,
    2359,
    2360,
    2361,
    2362,
    2363,
    2364,
    2365,
    2366,
    2367,
    2368,
    2369,
    2370,
    2372,
    2373,
    2374,
    2375,
    2377,
    2378,
    2381,
    2387,
    2388,
    2389,
    2390,
    2391,
    2392,
    2393,
    2394,
    2395,
    2396,
    2397,
    2398,
    2399,
    2400,
    2401,
    2402,
    2403,
    2404,
    2405,
    2406,
    2407,
    2408,
    2409,
    2410,
    2411,
    2412,
    2413,
    2414,
    2415,
    2416,
    2417,
    2418,
    2419,
    2420,
    2421,
    2422,
    2423,
    2424,
    2425,
    2426,
    2428,
    2429,
    2430,
    2431,
    2432,
    2433,

    2456,

    2435,
    2442,
    2439,
    2444,
    2445,
    2443,
    2446,
    2447,
    2440,
    2441,

    2437,
    2454,
    2436,
    2452,
    2451,
    2448,
    2449,
    2455,
}
if select(4, GetBuildInfo()) >= 90200 then
    tinsert(journalEncounterData, 2458)
    tinsert(journalEncounterData, 2465)
    tinsert(journalEncounterData, 2470)
    tinsert(journalEncounterData, 2459)
    tinsert(journalEncounterData, 2460)
    tinsert(journalEncounterData, 2461)
    tinsert(journalEncounterData, 2463)
    tinsert(journalEncounterData, 2469)
    tinsert(journalEncounterData, 2457)
    tinsert(journalEncounterData, 2467)
end
local dungeonInstanceData = {}
local dungeonEncounterData = {}

local dungeonDifficultiesAll = {1,2,23,8};
local raidDifficultiesAll = {17,14,15,16};
local instanceDifficulties = {
    -- Classic
    [  48] = { 1}, -- Blackfathom Deeps
    [ 230] = { 1, 19}, -- Blackrock Depths
    [ 229] = { 1}, -- Lower Blackrock Spire
    [ 429] = { 1}, -- Dire Maul
    [  90] = { 1}, -- Gnomeregan
    [ 349] = { 1}, -- Maraudon
    [ 389] = { 1}, -- Ragefire Chasm
    [ 129] = { 1}, -- Razorfen Downs
    [  47] = { 1}, -- Razorfen Kraul
    [ 329] = { 1}, -- Stratholme
    [ 109] = { 1}, -- The Temple of Atal'hakkar
    [  34] = { 1}, -- The Stockade
    [  70] = { 1}, -- Uldaman
    [  43] = { 1}, -- Wailing Caverns
    [ 209] = { 1}, -- Zul'Farrak
    [1001] = { 1,  2,  8}, -- Scarlet Halls
    [1004] = { 1,  2,  8, 19}, -- Scarlet Monastery
    [1007] = { 1,  2,  8}, -- Scholomance
    [  36] = { 1,  2}, -- Deadmines
    [  33] = { 1,  2, 19}, -- Shadowfang Keep
    [ 409] = { 9, 18}, -- Molten Core
    [ 469] = { 9, 18}, -- Blackwing Lair
    [ 509] = { 3}, -- Ruins of Ahn'Qiraj
    [ 531] = { 9, 18}, -- Temple of Ahn'Qiraj

    -- The Burning Crusade
    [ 558] = { 1,  2}, -- Auchenai Crypts
    [ 543] = { 1,  2}, -- Hellfire Ramparts
    [ 585] = { 1,  2}, -- Magisters' Terrace
    [ 557] = { 1,  2}, -- Mana-Tombs
    [ 560] = { 1,  2}, -- Old Hillsbrad Foothills
    [ 556] = { 1,  2}, -- Sethekk Halls
    [ 555] = { 1,  2}, -- Shadow Labyrinth
    [ 552] = { 1,  2}, -- The Arcatraz
    [ 269] = { 1,  2}, -- The Black Morass
    [ 542] = { 1,  2}, -- The Blood Furnace
    [ 553] = { 1,  2}, -- The Botanica
    [ 554] = { 1,  2}, -- The Mechanar
    [ 540] = { 1,  2}, -- The Shattered Halls
    [ 547] = { 1,  2, 19}, -- The Slave Pens
    [ 545] = { 1,  2}, -- The Steamvault
    [ 546] = { 1,  2}, -- The Underbog
    [ 532] = { 3}, -- Karazhan
    [ 565] = { 4}, -- Gruul's Lair
    [ 544] = { 4}, -- Magtheridon's Lair
    [ 548] = { 4}, -- Serpentshrine Cavern
    [ 550] = { 4}, -- The Eye
    [ 534] = { 4}, -- The Battle for Mount Hyjal
    [ 564] = {14, 33}, -- Black Temple
    [ 580] = { 4}, -- Sunwell Plateau

    -- Wrath of the Lich King
    [ 619] = { 1,  2}, -- Ahn'kahet: The Old Kingdom
    [ 601] = { 1,  2}, -- Azjol-Nerub
    [ 600] = { 1,  2}, -- Drak'Tharon Keep
    [ 604] = { 1,  2}, -- Gundrak
    [ 602] = { 1,  2}, -- Halls of Lightning
    [ 668] = { 1,  2}, -- Halls of Reflection
    [ 599] = { 1,  2}, -- Halls of Stone
    [ 658] = { 1,  2}, -- Pit of Saron
    [ 595] = { 1,  2}, -- The Culling of Stratholme
    [ 632] = { 1,  2}, -- The Forge of Souls
    [ 576] = { 1,  2}, -- The Nexus
    [ 578] = { 1,  2}, -- The Oculus
    [ 608] = { 1,  2}, -- The Violet Hold
    [ 650] = { 1,  2}, -- Trial of the Champion
    [ 574] = { 1,  2}, -- Utgarde Keep
    [ 575] = { 1,  2}, -- Utgarde Pinnacle
    [ 624] = { 3,  4}, -- Vault of Archavon
    [ 533] = { 3,  4}, -- Naxxramas
    [ 615] = { 3,  4}, -- The Obsidian Sanctum
    [ 616] = { 3,  4}, -- The Eye of Eternity
    [ 649] = { 3,  4,  5,  6}, -- Trial of the Crusader
    [ 631] = { 3,  4,  5,  6}, -- Icecrown Citadel
    [ 603] = {14, 33}, -- Ulduar
    [ 249] = { 3,  4}, -- Onyxia's Lair
    [ 724] = { 3,  4,  5,  6}, -- The Ruby Sanctum

    -- Cataclysm
    [ 645] = { 1,  2}, -- Blackrock Caverns
    [  36] = { 1,  2}, -- Deadmines
    [ 644] = { 1,  2}, -- Halls of Origination
    [ 755] = { 1,  2}, -- Lost City of the Tol'vir
    [  33] = { 1,  2, 19}, -- Shadowfang Keep
    [ 725] = { 1,  2}, -- The Stonecore
    [ 657] = { 1,  2}, -- The Vortex Pinnacle
    [ 643] = { 1,  2}, -- Throne of the Tides
    [ 568] = { 1,  2}, -- Zul'Aman
    [ 859] = { 1,  2}, -- Zul'Gurub
    [ 670] = { 1,  2}, -- Grim Batol
    [ 938] = { 2}, -- End Time
    [ 939] = { 2}, -- Well of Eternity
    [ 940] = { 2}, -- Hour of Twilight
    [ 671] = { 3,  4,  5,  6}, -- The Bastion of Twilight
    [ 669] = { 3,  4,  5,  6}, -- Blackwing Descent
    [ 967] = { 3,  4,  5,  6,  7}, -- Dragon Soul
    [ 720] = {14, 15, 33}, -- Firelands
    [ 754] = { 3,  4,  5,  6}, -- Throne of the Four Winds

    -- Mists of Pandaria
    [ 961] = { 1,  2,  8}, -- Stormstout Brewery
    [ 960] = { 1,  2,  8}, -- Temple of the Jade Serpent
    [ 994] = { 1,  2,  8}, -- Mogu'shan Palace
    [ 962] = { 1,  2,  8}, -- Gate of the Setting Sun
    [1011] = { 1,  2,  8}, -- Siege of Niuzao Temple
    [ 959] = { 1,  2,  8}, -- Shado-Pan Monastery
    [1007] = { 1,  2,  8}, -- Scholomance
    [1001] = { 1,  2,  8}, -- Scarlet Halls
    [1004] = { 1,  2,  8, 19}, -- Scarlet Monastery
    [1008] = { 3,  4,  5,  6,  7}, -- Mogu'shan Vaults
    [1009] = { 3,  4,  5,  6,  7}, -- Heart of Fear
    [ 996] = { 3,  4,  5,  6,  7}, -- Terrace of Endless Spring
    [1098] = { 3,  4,  5,  6,  7}, -- Throne of Thunder
    [1136] = raidDifficultiesAll, -- Siege of Orgrimmar

    -- Warlords of Draenor
    [1175] = dungeonDifficultiesAll, -- Bloodmaul Slag Mines
    [1209] = dungeonDifficultiesAll, -- Skyreach
    [1208] = dungeonDifficultiesAll, -- Grimrail Depot
    [1176] = dungeonDifficultiesAll, -- Shadowmoon Burial Grounds
    [1182] = dungeonDifficultiesAll, -- Auchindoun
    [1279] = dungeonDifficultiesAll, -- The Everbloom
    [1358] = { 1,  2,  8, 19, 23}, -- Upper Blackrock Spire
    [1195] = dungeonDifficultiesAll, -- Iron Docks
    [1205] = raidDifficultiesAll, -- Blackrock Foundry
    [1228] = raidDifficultiesAll, -- Highmaul
    [1228] = raidDifficultiesAll, -- Draenor
    [1448] = raidDifficultiesAll, -- Hellfire Citadel

    -- Legion
    [1493] = dungeonDifficultiesAll, -- Vault of the Wardens
    [1456] = dungeonDifficultiesAll, -- Eye of Azshara
    [1477] = dungeonDifficultiesAll, -- Halls of Valor
    [1492] = dungeonDifficultiesAll, -- Maw of Souls
    [1516] = { 2,  8, 23}, -- The Arcway
    [1501] = dungeonDifficultiesAll, -- Black Rook Hold
    [1466] = dungeonDifficultiesAll, -- Darkheart Thicket
    [1458] = dungeonDifficultiesAll, -- Neltharion's Lair
    [1544] = { 1,  2, 23}, -- Assault on Violet Hold
    [1571] = { 2,  8, 23}, -- Court of Stars
    [1651] = { 2,  8, 23}, -- Return to Karazhan
    [1677] = { 2,  8, 23}, -- Cathedral of Eternal Night
    [1753] = { 2,  8, 23}, -- Seat of the Triumvirate
    [1520] = raidDifficultiesAll, -- The Emerald Nightmare
    [1530] = raidDifficultiesAll, -- The Nighthold
    [1648] = raidDifficultiesAll, -- Trial of Valor
    [1676] = raidDifficultiesAll, -- Tomb of Sargeras
    [1712] = raidDifficultiesAll, -- Antorus, the Burning Throne

    -- Battle for Azeroth
    [1763] = dungeonDifficultiesAll, -- Atal'Dazar
    [1754] = dungeonDifficultiesAll, -- Freehold
    [1594] = dungeonDifficultiesAll, -- The MOTHERLODE!!
    [1771] = dungeonDifficultiesAll, -- Tol Dagor
    [1862] = dungeonDifficultiesAll, -- Waycrest Manor
    [1841] = dungeonDifficultiesAll, -- The Underrot
    [1822] = { 2,  8, 23}, -- Siege of Boralus
    [1877] = dungeonDifficultiesAll, -- Temple of Sethraliss
    [1864] = dungeonDifficultiesAll, -- Shrine of the Storm
    [1762] = { 2,  8, 23}, -- Kings' Rest
    [2097] = { 2,  8, 23}, -- Operation: Mechagon
    [1861] = raidDifficultiesAll, -- Uldir
    [2070] = raidDifficultiesAll, -- Battle of Dazar'alor
    [2096] = raidDifficultiesAll, -- Crucible of Storms
    [2164] = raidDifficultiesAll, -- The Eternal Palace
    [2217] = raidDifficultiesAll, -- Ny'alotha, the Waking City

    -- Shadowlands
    [2286] = dungeonDifficultiesAll, -- The Necrotic Wake
    [2289] = dungeonDifficultiesAll, -- Plaguefall
    [2290] = dungeonDifficultiesAll, -- Mists of Tirna Scithe
    [2287] = dungeonDifficultiesAll, -- Halls of Atonement
    [2285] = dungeonDifficultiesAll, -- Spires of Ascension
    [2293] = dungeonDifficultiesAll, -- Theater of Pain
    [2291] = dungeonDifficultiesAll, -- De Other Side
    [2284] = dungeonDifficultiesAll, -- Sanguine Depths
    [2441] = {23}, -- Tazavesh, the Veiled Market
    [2296] = raidDifficultiesAll, -- Castle Nathria
    [2450] = raidDifficultiesAll, -- Sanctum of Domination
}
if select(4, GetBuildInfo()) >= 90200 then
    instanceDifficulties[2441] = { 2,  8, 23} -- Tazavesh, the Veiled Market
    instanceDifficulties[2481] = raidDifficultiesAll -- Sepulcher of the First Ones
end

local LockoutMixin = CreateFromMixins(External.StateMixin)
function LockoutMixin:Init(instanceID, difficultyID)
	External.StateMixin.Init(self, instanceID)
    self.difficultyID = difficultyID

    self.name = GetRealZoneText(instanceID)
    self.difficultyName = (GetDifficultyInfo(difficultyID))
    self.encounters = dungeonInstanceData[instanceID]
end
function LockoutMixin:GetDifficultyID()
    return self.difficultyID
end
function LockoutMixin:GetDisplayName()
    return string.format(L["Lockout: %s"], self:GetName())
end
function LockoutMixin:GetUniqueKey()
	return "lockout:" .. self:GetID() .. ":" .. self:GetDifficultyID()
end
function LockoutMixin:GetName()
    return format("%s (%s)", self.name, self.difficultyName)
end
function LockoutMixin:GetDifficultyName()
    return self.difficultyName
end
function LockoutMixin:IsBossCompleted(index)
    local encounterID = self.encounters[index]
    if self:GetCharacter():IsPlayer() then
        return C_RaidLocks.IsEncounterComplete(self.id, encounterID, self.difficultyID)
    else
        return self:GetCharacter():GetData("encounterKill", encounterID .. ":" .. self.difficultyID)
    end
end
function LockoutMixin:GetBossName(index)
    local encounterID = self.encounters[index]
    return dungeonEncounterData[encounterID]
end
function LockoutMixin:GetBossCount()
    return #self.encounters
end
function LockoutMixin:GetBossKillCount()
    local count = 0
    if self:GetCharacter():IsPlayer() then
        local mapID, difficultyID = self.id, self.difficultyID
        for _,encounterID in ipairs(self.encounters) do
            if C_RaidLocks.IsEncounterComplete(mapID, encounterID, difficultyID) then
                count = count + 1
            end
        end
    else
        local difficultyID = self.difficultyID
        for _,encounterID in ipairs(self.encounters) do
            if self:GetCharacter():GetData("encounterKill", encounterID .. ":" .. difficultyID) then
                count = count + 1
            end
        end
    end
    return count
end
function LockoutMixin:IsCompleted()
    return self:GetBossKillCount() == self:GetBossCount()
end
function LockoutMixin:RegisterEventsFor(target)
    target:RegisterEvents("PLAYER_ENTERING_WORLD", "ENCOUNTER_END")
end

local LockoutProviderMixin = CreateFromMixins(External.StateProviderMixin)
function LockoutProviderMixin:GetID()
	return "lockout"
end
function LockoutProviderMixin:GetName()
	return L["Lockout"]
end
function LockoutProviderMixin:Acquire(...)
	return CreateAndInitFromMixin(LockoutMixin, ...)
end
function LockoutProviderMixin:GetFunctions()
	return {
		{
			name = "GetValue",
			returnValue = "string",
		},
    }
end
function LockoutProviderMixin:GetDefaults()
	return {}, { -- Text
		{"GetValue"}
	}
end
function LockoutProviderMixin:ParseInput(value)
    local a, b = strsplit(" ", value)
    a, b = tonumber(a), tonumber(b)
	if a ~= nil and b ~= nil then
		return true, a, b
	end
	if mapNameToID[value] then
        return true, unpack(mapNameToID[value])
    end
	return false, L["Invalid dungeon and difficulty"]
end
function LockoutProviderMixin:FillAutoComplete(tbl, text, offset, length)
    local text = strsub(text, offset, length):lower()
    for value in pairs(mapNameToID) do
        local name = value:lower()
        if #name >= #text and strsub(name, offset, length) == text then
            tbl[#tbl+1] = value
        end
    end
    table.sort(tbl)
end
Internal.RegisterStateProvider(CreateFromMixins(LockoutProviderMixin))

local function ADDON_LOADED(_, addon)
    if addon == ADDON_NAME then
        for _,journalEncounterID in ipairs(journalEncounterData) do
            local name, _, _, _, _, _, dungeonEncounterID, instanceID = EJ_GetEncounterInfo(journalEncounterID)
            if instanceID then
                if not dungeonInstanceData[instanceID] then
                    dungeonInstanceData[instanceID] = {}
                end
                local dungeonInstanceBosses = dungeonInstanceData[instanceID]
                dungeonInstanceBosses[#dungeonInstanceBosses+1] = dungeonEncounterID
                dungeonEncounterData[dungeonEncounterID] = name
            end
        end

        for instanceID,difficulties in pairs(instanceDifficulties) do
            local name = GetRealZoneText(instanceID)
            for _,difficultyID in ipairs(difficulties) do
                local key = format("%s (%s)", name, (GetDifficultyInfo(difficultyID)))
                mapNameToID[key] = {instanceID, difficultyID}
            end
        end

        Internal.UnregisterEvent("ADDON_LOADED", ADDON_LOADED)
    end
end
Internal.RegisterEvent("ADDON_LOADED", ADDON_LOADED, -10) -- Load this before todos are processed

local function PLAYER_LOGOUT()
    local player = Internal.GetPlayer()
    local encounterKill = player:GetDataTable("encounterKill")
    wipe(encounterKill)
    for i=1,GetNumSavedInstances() do
        local _, _, _, _, _, extended = GetSavedInstanceInfo(i)
        if not extended then
            local _, _, instanceID, difficultyID = strsplit(":", string.match(GetSavedInstanceChatLink(i), "instancelock:[^|]+"))
            instanceID, difficultyID = tonumber(instanceID), tonumber(difficultyID)

            for _, encounterID in ipairs(dungeonInstanceData[instanceID]) do
                encounterKill[encounterID .. ":" .. difficultyID] = C_RaidLocks.IsEncounterComplete(instanceID, encounterID, difficultyID) and true or nil
            end
        end
    end
end
Internal.RegisterEvent("PLAYER_LOGOUT", PLAYER_LOGOUT)