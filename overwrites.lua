-- This file can be used to manually overwrite or add contents to the db
-- which weren't detect by the extractor. Make sure to write proper comments
-- and include as much information as possible, as this should be only the
-- intermediate solution and fixing the extractor instead is the desired goal.


-- [[ Quest: Great Bear Spirit ]]
-- Unit: Great Bear Spirit (11956)
-- Type: Talk/Gossip Menu Requirement
pfDB["quests"]["data"][5929]["obj"] = { ["U"] = { 11956 } }
pfDB["quests"]["data"][5930]["obj"] = { ["U"] = { 11956 } }


-- [[ Quest chain links are not prerequisites ]]
-- The extractor turns every `NextQuestInChain` back-link into a hard `pre` entry
-- (toolbox/extractor.lua, "add pre quests from quest chains"), and QuestFilter then hides
-- the quest until one of those pre-quests has been completed. MaNGOS-derived cores do not
-- gate on that link: `NextQuestInChain` fills `prevChainQuests`, which refuses the quest
-- only while its predecessor is still in the quest log, and never requires it completed.
-- Only `PrevQuestId` and `NextQuestId` become real prerequisites there.
--
-- The quests below have neither on this realm's database, so the server offers them right
-- away while pfQuest draws no node at all. `pre` is dropped and the chain predecessor
-- moved to `prechain`, which database.lua evaluates the way the server does.
-- Example: 2038 "Bingles' Missing Supplies" has PrevQuestId 0, and 2039 "Find Bingles"
-- only points at it through NextQuestInChain.
if pfQuestCompat.client <= 11200 then
  local prechain = {
    [5] = { 163 },
    [11] = { 239 },
    [95] = { 164 },
    [148] = { 165 },
    [260] = { 259 },
    [261] = { 6141 },
    [276] = { 463 },
    [297] = { 436 },
    [353] = { 1097 },
    [364] = { 363 },
    [429] = { 428 },
    [455] = { 468 },
    [466] = { 467 },
    [518] = { 495 },
    [639] = { 638 },
    [729] = { 730 },
    [738] = { 707 },
    [786] = { 785 },
    [788] = { 787, 4641 },
    [811] = { 810 },
    [844] = { 860 },
    [870] = { 886 },
    [969] = { 6606 },
    [1011] = { 4581 },
    [1057] = { 1056 },
    [1062] = { 1061 },
    [1085] = { 1070 },
    [1093] = { 1483 },
    [1131] = { 1130 },
    [1133] = { 1132 },
    [1204] = { 1260 },
    [1275] = { 3765 },
    [1302] = { 1301 },
    [1338] = { 1339 },
    [1362] = { 1361 },
    [1364] = { 1363 },
    [1390] = { 1289 },
    [1395] = { 1477 },
    [1420] = { 1418 },
    [1524] = { 1522, 1523, 2983, 2984 },
    [1530] = { 1528, 1529, 2985, 2986 },
    [1688] = { 1685, 1715 },
    [1699] = { 1698 },
    [1705] = { 1700 },
    [1708] = { 1704 },
    [1710] = { 1703 },
    [1716] = { 1717 },
    [1758] = { 1798 },
    [1796] = { 4736, 4737, 4738, 4739 },
    [1801] = { 2996, 3001 },
    [1824] = { 1823 },
    [1842] = { 1839 },
    [1844] = { 1840 },
    [1846] = { 1841 },
    [1920] = { 1919 },
    [1938] = { 1939 },
    [1944] = { 1943 },
    [1960] = { 1959 },
    [2038] = { 2039 },
    [2040] = { 2041 },
    [2240] = { 2398 },
    [2260] = { 2259 },
    [2281] = { 2260, 2298, 2300 },
    [2298] = { 2299 },
    [2379] = { 2378, 2380 },
    [2518] = { 2519 },
    [2770] = { 2769 },
    [2846] = { 2861 },
    [2865] = { 2864 },
    [2922] = { 2923 },
    [2924] = { 2925 },
    [2930] = { 2931 },
    [2975] = { 2981 },
    [3516] = { 3515 },
    [3761] = { 936, 3762, 3784 },
    [3764] = { 3763, 3789, 3790 },
    [4024] = { 4022, 4023 },
    [4126] = { 4128 },
    [4134] = { 4133 },
    [4136] = { 4324 },
    [4490] = { 3631, 4487, 4488, 4489 },
    [4505] = { 6605 },
    [4621] = { 1036 },
    [4734] = { 4907 },
    [4764] = { 4766 },
    [4768] = { 4769 },
    [4861] = { 6604 },
    [5082] = { 6603 },
    [5092] = { 5066, 5090, 5091 },
    [5096] = { 5093, 5094, 5095 },
    [5149] = { 5142, 5601 },
    [5244] = { 5249, 5250 },
    [5621] = { 5622 },
    [5624] = { 5623 },
    [5625] = { 5626 },
    [5648] = { 5649 },
    [5650] = { 5651 },
    [5921] = { 5923, 5924, 5925 },
    [6061] = { 6065, 6066, 6067 },
    [6062] = { 6068, 6069, 6070 },
    [6063] = { 6071, 6072, 6073, 6721, 6722 },
    [6064] = { 6074, 6075, 6076 },
    [6383] = { 235, 742, 6382 },
    [6543] = { 6541, 6542 },
    [6607] = { 6608, 6609 },
    [6610] = { 6611, 6612 },
    [6622] = { 6623 },
    [6624] = { 6625 },
    [7141] = { 7221 },
    [7142] = { 7222 },
    [7488] = { 7494 },
    [7489] = { 7492 },
    [8280] = { 8275, 8276 },
    [8414] = { 8415 },
    [8867] = { 8870, 8871, 8872, 8873, 8874, 8875 },
    [9052] = { 9063 },
    [9422] = { 9416 },
  }

  for id, list in pairs(prechain) do
    if pfDB["quests"]["data"][id] then
      pfDB["quests"]["data"][id]["pre"] = nil
      pfDB["quests"]["data"][id]["prechain"] = list
    end
  end

  -- These carry a `pre` entry that this realm's database does not link at all - no
  -- PrevQuestId, no NextQuestId and no NextQuestInChain points at them. Most are the
  -- Ahn'Qiraj war effort turn-ins, which the server hands out without any pre-quest.
  local nogate = {
    934, 1288, 3503, 7668, 8492, 8494, 8499, 8503, 8505, 8509, 8511, 8513, 8515, 8517, 8520,
    8522, 8524, 8526, 8528, 8532, 8542, 8545, 8549, 8580, 8582, 8588, 8590, 8600, 8604, 8607,
    8609, 8611, 8613, 8615, 8811, 8812, 8813, 8814, 8815, 8816, 8817, 8818, 8819, 8820, 8821,
    8822, 8823, 8824, 8825, 8826, 8830, 8831, 8832, 8833, 8834, 8835, 8836, 8837, 8838, 8839,
    8840, 8841, 8842, 8843, 8844, 8845, 8846, 8847, 8848, 8849, 8850, 8851, 8852, 8853, 8854,
    8855
  }

  for _, id in pairs(nogate) do
    if pfDB["quests"]["data"][id] then
      pfDB["quests"]["data"][id]["pre"] = nil
    end
  end
end
