WOW_PROJECT_ID, WOW_PROJECT_MAINLINE = 1, 1
SlashCmdList = {}
CreateFrame = function() return { SetScript = function() end, RegisterEvent = function() end } end
GetBuildInfo = function() return "12.1.5", "70783", "", 120105 end
GetLocale = function() return "enUS" end
time = function() return 100 end
GetSpecialization = function() return 1 end
GetSpecializationInfo = function() return 253 end
Constants = { PetConsts_PostCata = { NUM_PET_SLOTS_HUNTER = 8,
    MAX_SUMMONABLE_HUNTER_PETS = 5, EXTRA_PET_STABLE_SLOT = 5 } }
YiboCore = { CheckAPIVersion = function() return true end, HasCapability = function() return true end,
    IsInitialized = function() return true end, Characters = { GetCurrentID = function() return "id" end } }
C_StableInfo = {
    GetActivePetList = function() return {} end, GetStabledPetList = function() return {} end,
    GetNumActivePets = function() return 0 end, GetNumStablePets = function() return 1 end,
    IsAtStableMaster = function() return true end, IsBonusPetSlotAvailable = function() return true end,
    GetStablePetInfo = function(index) if index == 6 then return { slotID = 6, petNumber = 42 } end end,
}
assert(loadfile("_NonRelease/YiboBeastPathsRetailPetProbe/Probe.lua"))("YiboBeastPathsRetailPetProbe")
SlashCmdList.YIBOBEASTPATHSRETAILPETPROBE("scan")
local extra = YiboBeastPathsRetailPetProbeDB.characters.id.latest.extraProbe
assert(extra.index == 6 and extra.present == true and extra.slotID == 6 and extra.petNumber == 42)
assert(extra.specializationID == 253 and extra.bonusAvailable.values[1] == true)
WOW_PROJECT_ID = 19
YiboBeastPathsRetailPetProbeDB = nil
SlashCmdList.YIBOBEASTPATHSRETAILPETPROBE("scan")
assert(YiboBeastPathsRetailPetProbeDB == nil)
print("ExtraSlotSpec: target guard and read-only extra-slot observation passed")
