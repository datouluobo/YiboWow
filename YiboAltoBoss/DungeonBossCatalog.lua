-- MoP Classic single-creature death facts; see Docs/FivePlayerBossRecording.md.
-- Zero means no verified DungeonEncounterID; identity is still map/NPC ID.
local YAB = _G.YAB
local bosses = {
    [33] = {
        [3887] = 1070, -- Cataclysm/ShadowFangKeep/Silverlaine.lua
        [4278] = 1071, -- Cataclysm/ShadowFangKeep/Springvale.lua
        [46962] = 1069, -- Cataclysm/ShadowFangKeep/Ashbury.lua
        [46963] = 1073, -- Cataclysm/ShadowFangKeep/Walden.lua
        [46964] = 1072, -- Cataclysm/ShadowFangKeep/Godfrey.lua
    },
    [34] = {
        [46254] = 1144, -- Vanilla/Retail/StormwindStockaid/Hogger.lua
        [46264] = 1145, -- Vanilla/Retail/StormwindStockaid/LordOverheat.lua
        [46383] = 1146, -- Vanilla/Retail/StormwindStockaid/Moloch.lua
    },
    [43] = {
        [3653] = 587, -- Vanilla/Shared/WailingCaverns/Kresh.lua
        [3654] = 592, -- Vanilla/Shared/WailingCaverns/MutanustheDevourer.lua
        [3669] = 586, -- Vanilla/Shared/WailingCaverns/LordCobrahn.lua
        [3670] = 588, -- Vanilla/Shared/WailingCaverns/LordPythas.lua
        [3671] = 585, -- Vanilla/Shared/WailingCaverns/LadyAnacondra.lua
        [3673] = 590, -- Vanilla/Shared/WailingCaverns/LordSerpentis.lua
        [3674] = 589, -- Vanilla/Shared/WailingCaverns/Skum.lua
        [5775] = 591, -- Vanilla/Shared/WailingCaverns/VerantheEverliving.lua
        [5912] = 0, -- Vanilla/Shared/WailingCaverns/DeviateFaerieDragon.lua
    },
    [47] = {
        [4420] = 0, -- Vanilla/Classic/RazorfenKraul/OverlordRamtusk.lua
        [4421] = 0, -- Vanilla/Classic/RazorfenKraul/CharlgaRazorflank.lua
        [4422] = 0, -- Vanilla/Classic/RazorfenKraul/AgathelostheRaging.lua
        [4424] = 0, -- Vanilla/Classic/RazorfenKraul/AggemThorncurse.lua
        [4425] = 0, -- Vanilla/Classic/RazorfenKraul/BlindHunter.lua
        [4428] = 0, -- Vanilla/Classic/RazorfenKraul/DeathSpeakerJargba.lua
        [4842] = 0, -- Vanilla/Classic/RazorfenKraul/EarthcallerHalmgar.lua
        [6168] = 0, -- Vanilla/Classic/RazorfenKraul/Roogug.lua
    },
    [48] = {
        [4829] = 2767, -- Vanilla/Classic/BlackfathomDeeps/Akumai.lua
        [4830] = 2765, -- Vanilla/Classic/BlackfathomDeeps/OldSerrakis.lua
        [4831] = 2762, -- Vanilla/Classic/BlackfathomDeeps/LadySerevess.lua
        [4832] = 2766, -- Vanilla/Classic/BlackfathomDeeps/TwilightLordKelris.lua
        [4887] = 2761, -- Vanilla/Classic/BlackfathomDeeps/GhamooRa.lua
        [6243] = 2763, -- Vanilla/Classic/BlackfathomDeeps/Gelihast.lua
    },
    [70] = {
        [2748] = 554, -- Vanilla/Shared/Uldaman/Archaedas.lua
        [4854] = 553, -- Vanilla/Shared/Uldaman/Grimlok.lua
        [6910] = 547, -- Vanilla/Shared/Uldaman/Revelosh.lua
        [7023] = 1887, -- Vanilla/Shared/Uldaman/ObsidianSentinel.lua
        [7206] = 551, -- Vanilla/Shared/Uldaman/AncientStoneKeeper.lua
        [7228] = 549, -- Vanilla/Shared/Uldaman/Ironaya.lua
        [7291] = 552, -- Vanilla/Shared/Uldaman/GalgannFirehammer.lua
    },
    [90] = {
        [6229] = 0, -- Vanilla/Shared/Gnomeregan/CrowdPummeler.lua
        [6235] = 0, -- Vanilla/Shared/Gnomeregan/Electrocutioner6000.lua
        [7079] = 0, -- Vanilla/Shared/Gnomeregan/ViscousFallout.lua
        [7361] = 0, -- Vanilla/Shared/Gnomeregan/Grubbis.lua
        [7800] = 0, -- Vanilla/Shared/Gnomeregan/MekgineerThermaplugg.lua
    },
    [109] = {
        [5709] = 493, -- Vanilla/Shared/SunkenTemple/ShadeofEranikus.lua
        [5719] = 490, -- Vanilla/Shared/SunkenTemple/Morphaz.lua
        [5720] = 487, -- Vanilla/Shared/SunkenTemple/Weaver.lua
        [5721] = 486, -- Vanilla/Shared/SunkenTemple/Dreamscythe.lua
        [5722] = 491, -- Vanilla/Shared/SunkenTemple/Hazzas.lua
        [8443] = 492, -- Vanilla/Shared/SunkenTemple/AvatarofHakkar.lua
    },
    [129] = {
        [7354] = 0, -- Vanilla/Classic/RazorfenDowns/Ragglesnout.lua
        [7355] = 0, -- Vanilla/Classic/RazorfenDowns/Tutenkash.lua
        [7356] = 0, -- Vanilla/Classic/RazorfenDowns/PlaguemawtheRotting.lua
        [7357] = 0, -- Vanilla/Classic/RazorfenDowns/MordreshFireEye.lua
        [7358] = 0, -- Vanilla/Classic/RazorfenDowns/AmnennartheColdbringer.lua
        [8567] = 0, -- Vanilla/Classic/RazorfenDowns/Glutton.lua
    },
    [189] = {
        [3974] = 446, -- Vanilla/Shared/ScarletMonastery_Old/HoundmasterLoksey.lua
        [3975] = 448, -- Vanilla/Shared/ScarletMonastery_Old/Herod.lua
        [3983] = 444, -- Vanilla/Shared/ScarletMonastery_Old/InterrogatorVishas.lua
        [4542] = 449, -- Vanilla/Shared/ScarletMonastery_Old/HighInquisitorFairbanks.lua
        [4543] = 0, -- Vanilla/Shared/ScarletMonastery_Old/BloodmageThalnos.lua
        [6487] = 447, -- Vanilla/Shared/ScarletMonastery_Old/ArcanistDoan.lua
    },
    [209] = {
        [7267] = 600, -- Vanilla/Shared/ZulFarrak/ChiefUkorzSandscalp.lua
        [7271] = 597, -- Vanilla/Shared/ZulFarrak/WitchDoctorZumrah.lua
        [7272] = 596, -- Vanilla/Shared/ZulFarrak/ThekatheMartyr.lua
        [7273] = 594, -- Vanilla/Shared/ZulFarrak/Gahzrilla.lua
        [7795] = 593, -- Vanilla/Shared/ZulFarrak/HydromancerVelrath.lua
        [8127] = 595, -- Vanilla/Shared/ZulFarrak/Antusul.lua
    },
    [229] = {
        [9196] = 267, -- Vanilla/Shared/LowerBlackrockSpire/HighlordOmokk.lua
        [9236] = 268, -- Vanilla/Shared/LowerBlackrockSpire/ShadowHunterVoshgajin.lua
        [9237] = 269, -- Vanilla/Shared/LowerBlackrockSpire/WarMasterVoone.lua
        [9568] = 275, -- Vanilla/Shared/LowerBlackrockSpire/OverlordWyrmthalak.lua
        [9736] = 272, -- Vanilla/Shared/LowerBlackrockSpire/QuartermasterZigris.lua
        [9816] = 0, -- Vanilla/Classic/UpperBlackrockSpire/PyroguardEmberseer.lua
        [10220] = 274, -- Vanilla/Shared/LowerBlackrockSpire/Halycon.lua
        [10264] = 0, -- Vanilla/Classic/UpperBlackrockSpire/SolakarFlamewreath.lua
        [10268] = 273, -- Vanilla/Shared/LowerBlackrockSpire/Gizrul.lua
        [10363] = 0, -- Vanilla/Classic/UpperBlackrockSpire/GeneralDrakkisath.lua
        [10430] = 0, -- Vanilla/Classic/UpperBlackrockSpire/TheBeast.lua
        [10509] = 0, -- Vanilla/Classic/UpperBlackrockSpire/JedRunewatcher.lua
        [10584] = 271, -- Vanilla/Shared/LowerBlackrockSpire/UrokDoomhowl.lua
        [10596] = 270, -- Vanilla/Shared/LowerBlackrockSpire/MotherSmolderweb.lua
        [10899] = 0, -- Vanilla/Classic/UpperBlackrockSpire/GoralukAnvilcrack.lua
        [16042] = 0, -- Vanilla/Classic/UpperBlackrockSpire/LordValthalak.lua
    },
    [230] = {
        [8983] = 237, -- Vanilla/Shared/BlackrockDepths/GolemLordArgelmach.lua
        [9016] = 235, -- Vanilla/Shared/BlackrockDepths/BaelGar.lua
        [9017] = 232, -- Vanilla/Shared/BlackrockDepths/LordIncendius.lua
        [9018] = 227, -- Vanilla/Shared/BlackrockDepths/Gerstahn.lua
        [9019] = 245, -- Vanilla/Shared/BlackrockDepths/EmperorDagranThaurissan.lua
        [9024] = 231, -- Vanilla/Shared/BlackrockDepths/PyromancerLoregrain.lua
        [9025] = 228, -- Vanilla/Shared/BlackrockDepths/LordRoccor.lua
        [9033] = 236, -- Vanilla/Shared/BlackrockDepths/GeneralAngerforge.lua
        [9041] = 233, -- Vanilla/Shared/BlackrockDepths/WardenStilgiss.lua
        [9056] = 234, -- Vanilla/Shared/BlackrockDepths/FineousDarkvire.lua
        [9156] = 242, -- Vanilla/Shared/BlackrockDepths/AmbassadorFlamelash.lua
        [9319] = 229, -- Vanilla/Shared/BlackrockDepths/HoundmasterGrebmar.lua
        [9499] = 241, -- Vanilla/Shared/BlackrockDepths/PluggerSpazzring.lua
        [9502] = 239, -- Vanilla/Shared/BlackrockDepths/Phalanx.lua
        [9537] = 238, -- Vanilla/Shared/BlackrockDepths/HurleyBlackbreath.lua
        [9938] = 244, -- Vanilla/Shared/BlackrockDepths/Magmus.lua
    },
    [269] = {
        [17879] = 1920, -- BC/CoT_BlackMorass/Deja.lua
        [17880] = 1921, -- BC/CoT_BlackMorass/Temporus.lua
        [17881] = 1919, -- BC/CoT_BlackMorass/Aeonus.lua
    },
    [279] = {
        [26529] = 2002, -- WotLK/OldStratholme/Meathook.lua
        [26530] = 2004, -- WotLK/OldStratholme/SalrammTheFleshCrafter.lua
    },
    [289] = {
        [1853] = 0, -- Vanilla/Shared/Scholomance_Old/DarkmasterGandling.lua
        [10432] = 0, -- Vanilla/Shared/Scholomance_Old/Vectus.lua
        [10433] = 0, -- Vanilla/Shared/Scholomance_Old/MardukBlackpool.lua
        [10502] = 0, -- Vanilla/Shared/Scholomance_Old/LadyIlluciaBarov.lua
        [10503] = 0, -- Vanilla/Shared/Scholomance_Old/JandiceBarov.lua
        [10504] = 0, -- Vanilla/Shared/Scholomance_Old/LordAlexeiBarov.lua
        [10505] = 0, -- Vanilla/Shared/Scholomance_Old/InstructorMalicia.lua
        [10506] = 0, -- Vanilla/Shared/Scholomance_Old/KirtonostheHerald.lua
        [10507] = 0, -- Vanilla/Shared/Scholomance_Old/TheRavenian.lua
        [10508] = 0, -- Vanilla/Shared/Scholomance_Old/RasFrostwhisper.lua
        [10901] = 0, -- Vanilla/Shared/Scholomance_Old/LorekeeperPolkelt.lua
        [11261] = 0, -- Vanilla/Shared/Scholomance_Old/DoctorTheolenKrastinov.lua
        [11622] = 0, -- Vanilla/Shared/Scholomance_Old/Rattlegore.lua
    },
    [329] = {
        [10435] = 482, -- Vanilla/Shared/Stratholme/MagistrateBarthilas.lua
        [10436] = 479, -- Vanilla/Shared/Stratholme/BaronessAnastari.lua
        [10437] = 480, -- Vanilla/Shared/Stratholme/Narubenkan.lua
        [10438] = 481, -- Vanilla/Shared/Stratholme/MalekithePallid.lua
        [10439] = 483, -- Vanilla/Shared/Stratholme/RamsteintheGorger.lua
        [10516] = 472, -- Vanilla/Shared/Stratholme/TheUnforgiven.lua
        [10558] = 473, -- Vanilla/Shared/Stratholme/HearthsingerForresten.lua
        [10808] = 474, -- Vanilla/Shared/Stratholme/TimmytheCruel.lua
        [10811] = 477, -- Vanilla/Shared/Stratholme/InstructorGalford.lua
        [10997] = 475, -- Vanilla/Shared/Stratholme/WilleyHopebreaker.lua
        [11032] = 476, -- Vanilla/Shared/Stratholme/CommanderMalor.lua
    },
    [349] = {
        [12201] = 429, -- Vanilla/Shared/Maraudon/PrincessTheradras.lua
        [12203] = 426, -- Vanilla/Shared/Maraudon/Landslide.lua
        [12225] = 425, -- Vanilla/Shared/Maraudon/CelebrastheCursed.lua
        [12236] = 424, -- Vanilla/Shared/Maraudon/LordVyletongue.lua
        [12258] = 423, -- Vanilla/Shared/Maraudon/Razorlash.lua
        [13282] = 422, -- Vanilla/Shared/Maraudon/Noxxion.lua
        [13596] = 428, -- Vanilla/Shared/Maraudon/Rotgrip.lua
        [13601] = 427, -- Vanilla/Shared/Maraudon/TinkererGizlock.lua
    },
    [389] = {
        [61408] = 1443, -- Vanilla/Retail/RagefireChasm/Adarogg.lua
        [61412] = 1444, -- Vanilla/Retail/RagefireChasm/Koranthal.lua
        [61463] = 1445, -- Vanilla/Retail/RagefireChasm/Slagmaw.lua
        [61528] = 1446, -- Vanilla/Retail/RagefireChasm/Gordoth.lua
    },
    [429] = {
        [11486] = 361, -- Vanilla/Shared/DireMaul/PrinceTortheldrin.lua
        [11487] = 348, -- Vanilla/Shared/DireMaul/MagisterKelendris.lua
        [11488] = 347, -- Vanilla/Shared/DireMaul/IllyannaRavensoak.lua
        [11489] = 350, -- Vanilla/Shared/DireMaul/TendrisWarpwood.lua
        [11490] = 0, -- Vanilla/Shared/DireMaul/ZevrimThornhoof.lua
        [11492] = 346, -- Vanilla/Shared/DireMaul/Alzzin.lua
        [11496] = 349, -- Vanilla/Shared/DireMaul/Immolthar.lua
        [11501] = 368, -- Vanilla/Shared/DireMaul/KingGordok.lua
        [13280] = 0, -- Vanilla/Shared/DireMaul/Hydrospawn.lua
        [14321] = 364, -- Vanilla/Shared/DireMaul/GuardFengus.lua
        [14322] = 363, -- Vanilla/Shared/DireMaul/StomperKreeg.lua
        [14323] = 365, -- Vanilla/Shared/DireMaul/GuardSlipkik.lua
        [14325] = 366, -- Vanilla/Shared/DireMaul/CaptainKromcrush.lua
        [14326] = 362, -- Vanilla/Shared/DireMaul/GuardMoldar.lua
        [14327] = 0, -- Vanilla/Shared/DireMaul/Lethtendris.lua
    },
    [540] = {
        [16807] = 1936, -- BC/Hellfire_ShatteredHalls/Nethekurse.lua
        [16808] = 1938, -- BC/Hellfire_ShatteredHalls/Kargath.lua
        [16809] = 1937, -- BC/Hellfire_ShatteredHalls/O'mrogg.lua
        [20923] = 1935, -- BC/Hellfire_ShatteredHalls/Porung.lua
    },
    [542] = {
        [17377] = 1923, -- BC/Hellfire_BloodFurnace/Keli'dan.lua
        [17380] = 1924, -- BC/Hellfire_BloodFurnace/Broggok.lua
        [17381] = 1922, -- BC/Hellfire_BloodFurnace/Maker.lua
    },
    [543] = {
        [17306] = 1893, -- BC/Hellfire_Ramp/Gargolmar.lua
        [17308] = 1891, -- BC/Hellfire_Ramp/Omor.lua
    },
    [545] = {
        [17796] = 1943, -- BC/Coil_Steamvault/Steamrigger.lua
        [17797] = 1942, -- BC/Coil_Steamvault/Thespia.lua
        [17798] = 1944, -- BC/Coil_Steamvault/Kalithresh.lua
    },
    [546] = {
        [17770] = 1946, -- BC/Coil_Underbog/Hungarfen.lua
        [17826] = 1947, -- BC/Coil_Underbog/Muselek.lua
        [17882] = 1948, -- BC/Coil_Underbog/Stalker.lua
        [18105] = 1945, -- BC/Coil_Underbog/Ghazan.lua
    },
    [547] = {
        [17941] = 1939, -- BC/Coil_Slavepens/Mennu.lua
        [17942] = 1940, -- BC/Coil_Slavepens/Quagmirran.lua
        [17991] = 1941, -- BC/Coil_Slavepens/Rokmar.lua
    },
    [552] = {
        [20870] = 1916, -- BC/TK_Arcatraz/Zereketh.lua
        [20885] = 1913, -- BC/TK_Arcatraz/Dalliah.lua
        [20886] = 1915, -- BC/TK_Arcatraz/Soccothrates.lua
        [20912] = 1914, -- BC/TK_Arcatraz/Skyriss.lua
    },
    [553] = {
        [17975] = 1926, -- BC/TK_Botanica/Freywinn.lua
        [17976] = 1925, -- BC/TK_Botanica/Sarannis.lua
        [17977] = 1929, -- BC/TK_Botanica/WarpSplinter.lua
        [17978] = 1928, -- BC/TK_Botanica/Thorngrin.lua
        [17980] = 1927, -- BC/TK_Botanica/Laj.lua
    },
    [554] = {
        [19218] = 1933, -- BC/TK_Mechanar/Gyrokill.lua
        [19219] = 1932, -- BC/TK_Mechanar/Capacitus.lua
        [19220] = 1931, -- BC/TK_Mechanar/Pathaleon.lua
        [19221] = 1930, -- BC/TK_Mechanar/Sepethrea.lua
        [19710] = 1934, -- BC/TK_Mechanar/Ironhand.lua
    },
    [555] = {
        [18667] = 1909, -- BC/Auct_ShadowLabyrinth/Inciter.lua
        [18708] = 1910, -- BC/Auct_ShadowLabyrinth/Murmur.lua
        [18731] = 1908, -- BC/Auct_ShadowLabyrinth/Hellmaw.lua
        [18732] = 1911, -- BC/Auct_ShadowLabyrinth/Vorpil.lua
    },
    [556] = {
        [18472] = 1903, -- BC/Auct_SethekkHalls/Syth.lua
        [18473] = 1902, -- BC/Auct_SethekkHalls/Ikiss.lua
        [23035] = 1904, -- BC/Auct_SethekkHalls/Anzu.lua
    },
    [557] = {
        [18341] = 1900, -- BC/Auct_Tombs/Pandemonius.lua
        [18343] = 1901, -- BC/Auct_Tombs/Tavarok.lua
        [18344] = 1899, -- BC/Auct_Tombs/Shaffar.lua
        [22930] = 250, -- BC/Auct_Tombs/Yor.lua
    },
    [558] = {
        [18371] = 1890, -- BC/Auct_Crypts/Shirrak.lua
        [18373] = 1889, -- BC/Auct_Crypts/Maladaar.lua
    },
    [560] = {
        [17848] = 1905, -- BC/CoT_OldHillsbrad/Drake.lua
        [17862] = 1907, -- BC/CoT_OldHillsbrad/Skarloc.lua
        [18096] = 1906, -- BC/CoT_OldHillsbrad/EpochHunter.lua
    },
    [568] = {
        [23574] = 1189, -- Cataclysm/ZulAman/Akilzon5.lua
        [23576] = 1190, -- Cataclysm/ZulAman/Nalorakk5.lua
        [23577] = 1192, -- Cataclysm/ZulAman/Halazzi5.lua
        [23578] = 1191, -- Cataclysm/ZulAman/Janalai5.lua
        [23863] = 1194, -- Cataclysm/ZulAman/Daakara.lua
    },
    [574] = {
        [23953] = 2026, -- WotLK/UtgardeKeep/Keleseth.lua
    },
    [575] = {
        [26668] = 2030, -- WotLK/UtgardePinnacle/SvalaSorrowgrave.lua
        [26687] = 2027, -- WotLK/UtgardePinnacle/GortokPalehoof.lua
        [26693] = 2029, -- WotLK/UtgardePinnacle/SkadiTheRuthless.lua
        [26861] = 2028, -- WotLK/UtgardePinnacle/Ymiron.lua
    },
    [576] = {
        [26723] = 2011, -- WotLK/TheNexus/Keristrasza.lua
        [26731] = 2010, -- WotLK/TheNexus/GrandMagusTelestra.lua
        [26763] = 2009, -- WotLK/TheNexus/Anomalus.lua
        [26794] = 2012, -- WotLK/TheNexus/OrmorokTheTreeShaper.lua
    },
    [578] = {
        [27447] = 2015, -- WotLK/TheOculus/VarosCloudstrider.lua
        [27655] = 2014, -- WotLK/TheOculus/MageLordUrom.lua
        [27656] = 2013, -- WotLK/TheOculus/LeyGuardianEregos.lua
    },
    [585] = {
        [24560] = 1895, -- BC/MagistersTerrace/Delrissa.lua
        [24664] = 1894, -- BC/MagistersTerrace/Kael'thas.lua
        [24723] = 1897, -- BC/MagistersTerrace/Selin.lua
        [24744] = 1898, -- BC/MagistersTerrace/Vexallus.lua
    },
    [595] = {
        [26532] = 2003, -- WotLK/OldStratholme/ChronoLordEpoch.lua
    },
    [599] = {
        [27975] = 1996, -- WotLK/HallsOfStone/MaidenOfGrief.lua
        [27977] = 1994, -- WotLK/HallsOfStone/Krystallus.lua
        [27978] = 1998, -- WotLK/HallsOfStone/SjonnirTheIronshaper.lua
    },
    [600] = {
        [26630] = 1974, -- WotLK/DrakTharon/Trollgore.lua
        [26632] = 1975, -- WotLK/DrakTharon/ProphetTharonja.lua
        [27483] = 1977, -- WotLK/DrakTharon/Dred.lua
    },
    [601] = {
        [28684] = 1971, -- WotLK/AzjolNerub/Krikthir.lua
        [28921] = 1972, -- WotLK/AzjolNerub/Hadronox.lua
        [29120] = 1973, -- WotLK/AzjolNerub/Anubarak.lua
    },
    [602] = {
        [28546] = 1984, -- WotLK/HallsOfLightning/Ionar.lua
        [28586] = 1987, -- WotLK/HallsOfLightning/Bjarngrin.lua
        [28587] = 1985, -- WotLK/HallsOfLightning/Volkhan.lua
        [28923] = 1986, -- WotLK/HallsOfLightning/Loken.lua
    },
    [604] = {
        [29304] = 1978, -- WotLK/Gundrak/Sladran.lua
        [29305] = 1980, -- WotLK/Gundrak/Moorabi.lua
        [29306] = 1981, -- WotLK/Gundrak/Galdarah.lua
        [29307] = 1983, -- WotLK/Gundrak/BloodstoneAnnihilator.lua
        [29932] = 1988, -- WotLK/Gundrak/Eck.lua
    },
    [608] = {
        [29266] = 2661, -- WotLK/VioletHold/Xevoss.lua
        [29312] = 2662, -- WotLK/VioletHold/Lavanthor.lua
        [29313] = 2660, -- WotLK/VioletHold/Ichoron.lua
        [29314] = 2663, -- WotLK/VioletHold/Zuramat.lua
        [29315] = 2658, -- WotLK/VioletHold/Erekem.lua
        [29316] = 2659, -- WotLK/VioletHold/Moragg.lua
        [31134] = 2020, -- WotLK/VioletHold/Cyanigosa.lua
    },
    [619] = {
        [29308] = 1966, -- WotLK/AhnKahet/Taldaram.lua
        [29309] = 1969, -- WotLK/AhnKahet/Nadox.lua
        [29310] = 1967, -- WotLK/AhnKahet/JedogaShadowseeker.lua
        [29311] = 1968, -- WotLK/AhnKahet/Volazj.lua
        [30258] = 1989, -- WotLK/AhnKahet/Amanitar.lua
    },
    [632] = {
        [36497] = 2006, -- WotLK/ForgeofSouls/Bronjahm.lua
        [36502] = 2007, -- WotLK/ForgeofSouls/DevourerofSouls.lua
    },
    [643] = {
        [40765] = 1044, -- Cataclysm/ThroneOfTides/CommanderUlthok.lua
    },
    [644] = {
        [39378] = 1078, -- Cataclysm/HallsOfOrigination/Rajh.lua
        [39425] = 1080, -- Cataclysm/HallsOfOrigination/TempleGuardianAnhuur.lua
        [39587] = 1077, -- Cataclysm/HallsOfOrigination/Isiset.lua
        [39731] = 1074, -- Cataclysm/HallsOfOrigination/Ammunae.lua
        [39732] = 1079, -- Cataclysm/HallsOfOrigination/Setesh.lua
        [39788] = 1075, -- Cataclysm/HallsOfOrigination/Anraphet.lua
    },
    [645] = {
        [39665] = 1040, -- Cataclysm/BlackrockCaverns/RomoggBonecrusher.lua
        [39679] = 1038, -- Cataclysm/BlackrockCaverns/Corla.lua
        [39698] = 1039, -- Cataclysm/BlackrockCaverns/KarshSteelbender.lua
        [39700] = 1037, -- Cataclysm/BlackrockCaverns/Beauty.lua
        [39705] = 1036, -- Cataclysm/BlackrockCaverns/AscendantLordObsidius.lua
    },
    [657] = {
        [43873] = 1041, -- Cataclysm/TheVortexPinnacle/Altairus.lua
        [43875] = 1042, -- Cataclysm/TheVortexPinnacle/Asaad.lua
        [43878] = 1043, -- Cataclysm/TheVortexPinnacle/GrandVizierErtan.lua
    },
    [658] = {
        [36476] = 2001, -- WotLK/PitofSaron/Ick.lua
        [36494] = 1999, -- WotLK/PitofSaron/ForgemasterGarfrost.lua
    },
    [668] = {
        [38112] = 1992, -- WotLK/HallsofReflection/Falric.lua
        [38113] = 1993, -- WotLK/HallsofReflection/Marwyn.lua
    },
    [670] = {
        [39625] = 1051, -- Cataclysm/GrimBatol/GeneralUmbriss.lua
        [40177] = 1050, -- Cataclysm/GrimBatol/ForgemasterThrongus.lua
        [40319] = 1048, -- Cataclysm/GrimBatol/DrahgaShadowburner.lua
        [40484] = 1049, -- Cataclysm/GrimBatol/Erudax.lua
    },
    [725] = {
        [42188] = 1058, -- Cataclysm/TheStonecore/Ozruk.lua
        [42333] = 1057, -- Cataclysm/TheStonecore/HighPriestessAzil.lua
        [43214] = 1059, -- Cataclysm/TheStonecore/Slabhide.lua
        [43438] = 1056, -- Cataclysm/TheStonecore/Corborus.lua
    },
    [755] = {
        [43612] = 1053, -- Cataclysm/LostCityOfTheTolvir/HighProphetBarim.lua
        [43614] = 0, -- Cataclysm/LostCityOfTheTolvir/Lockmaw.lua
        [44577] = 1052, -- Cataclysm/LostCityOfTheTolvir/GeneralHusam.lua
        [44819] = 1055, -- Cataclysm/LostCityOfTheTolvir/Siamat.lua
        [49045] = 0, -- Cataclysm/LostCityOfTheTolvir/Augh.lua
    },
    [859] = {
        [52053] = 1181, -- Cataclysm/ZulGurub/Zanzil.lua
        [52059] = 1180, -- Cataclysm/ZulGurub/Kilnara.lua
        [52155] = 1178, -- Cataclysm/ZulGurub/Venoxis.lua
        [52258] = 0, -- Cataclysm/ZulGurub/CoMGrilek.lua
        [52269] = 0, -- Cataclysm/ZulGurub/CoMRenataki.lua
        [52271] = 0, -- Cataclysm/ZulGurub/CoMHazzarah.lua
        [52286] = 0, -- Cataclysm/ZulGurub/CoMWushoolay.lua
    },
    [938] = {
        [54123] = 1882, -- Cataclysm/EndTime/Sylvanas.lua
        [54431] = 1881, -- Cataclysm/EndTime/Baine.lua
        [54445] = 1883, -- Cataclysm/EndTime/Jaina.lua
        [54544] = 1884, -- Cataclysm/EndTime/Tyrande.lua
    },
    [939] = {
        [55085] = 1272, -- Cataclysm/WellOfEternity/Perotharn.lua
    },
    [940] = {
        [54938] = 1339, -- Cataclysm/HourOfTwilight/Benedictus.lua
    },
    [960] = {
        [56439] = 1439, -- MoP/JadeSerpentTemple/ShaofDoubt.lua
        [56732] = 1416, -- MoP/JadeSerpentTemple/LiuFlameheart.lua
    },
    [961] = {
        [56637] = 1412, -- MoP/StormstoutBrewery/OokOok.lua
        [56717] = 1413, -- MoP/StormstoutBrewery/Hoptallus.lua
        [59479] = 1414, -- MoP/StormstoutBrewery/YanZhu.lua
    },
    [962] = {
        [56589] = 1405, -- MoP/GateSettingSun/Gadok.lua
        [56636] = 1406, -- MoP/GateSettingSun/Rimok.lua
        [56877] = 1419, -- MoP/GateSettingSun/Raigonn.lua
        [56906] = 1397, -- MoP/GateSettingSun/Kiptilak.lua
    },
    [994] = {
        [61398] = 1441, -- MoP/MogushanPalace/WeaponmasterXin.lua
    },
    [1001] = {
        [58632] = 1421, -- MoP/ScarletHalls/Harlan.lua
        [59150] = 1420, -- MoP/ScarletHalls/FlameweaverKoegler.lua
        [59303] = 1422, -- MoP/ScarletHalls/Braun.lua
    },
    [1004] = {
        [59223] = 1424, -- MoP/ScarletCathedral/Korlof.lua
        [59789] = 1423, -- MoP/ScarletCathedral/ThalnosSoulrender.lua
    },
    [1007] = {
        [59080] = 1430, -- MoP/Scholomance/DarkmasterGandling.lua
        [59153] = 1428, -- MoP/Scholomance/Rattlegore.lua
        [59184] = 1427, -- MoP/Scholomance/JandiceBarov.lua
    },
    [1011] = {
        [61485] = 1447, -- MoP/NiuzaoTemple/Pavalak.lua
        [61567] = 1465, -- MoP/NiuzaoTemple/Jinbak.lua
        [61634] = 1502, -- MoP/NiuzaoTemple/Vojak.lua
        [62205] = 1464, -- MoP/NiuzaoTemple/Neronok.lua
    },
}
YAB.DungeonBossCatalog = bosses
