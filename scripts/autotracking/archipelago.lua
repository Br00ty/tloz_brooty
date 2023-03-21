-- this is an example/ default implementation for AP autotracking
-- it will use the mappings defined in item_mapping.lua and location_mapping.lua to track items and locations via thier ids
-- it will also load the AP slot data in the global SLOT_DATA, keep track of the current index of on_item messages in CUR_INDEX
-- addition it will keep track of what items are local items and which one are remote using the globals LOCAL_ITEMS and GLOBAL_ITEMS
-- this is useful since remote items will not reset but local items might
ScriptHost:LoadScript("scripts/autotracking/item_mapping.lua")
ScriptHost:LoadScript("scripts/autotracking/location_mapping.lua")

CUR_INDEX = -1
SLOT_DATA = nil
LOCAL_ITEMS = {}
GLOBAL_ITEMS = {}

function onClear(slot_data)
    if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
        print(string.format("called onClear, slot_data:\n%s", dump_table(slot_data)))
    end
    SLOT_DATA = slot_data
    CUR_INDEX = -1
    -- reset locations
    for _, v in pairs(LOCATION_MAPPING) do
        if v[1] then
            if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
                print(string.format("onClear: clearing location %s", v[1]))
            end
            local obj = Tracker:FindObjectForCode(v[1])
            if obj then
                if v[1]:sub(1, 1) == "@" then
                    obj.AvailableChestCount = obj.ChestCount
                else
                    obj.Active = false
                end
            elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
                print(string.format("onClear: could not find object for code %s", v[1]))
            end
        end
    end
    -- reset items
    for _, v in pairs(ITEM_MAPPING) do
        if v[1] and v[2] then
            if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
                print(string.format("onClear: clearing item %s of type %s", v[1], v[2]))
            end
            local obj = Tracker:FindObjectForCode(v[1])
            if obj then
                if v[2] == "toggle" then
                    obj.Active = false
                elseif v[2] == "progressive" then
                    obj.CurrentStage = 0
                    obj.Active = false
                elseif v[2] == "consumable" then
                    obj.AcquiredCount = 0
                elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
                    print(string.format("onClear: unknown item type %s for code %s", v[2], v[1]))
                end
            elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
                print(string.format("onClear: could not find object for code %s", v[1]))
            end
        end
    end
    LOCAL_ITEMS = {}
    GLOBAL_ITEMS = {}
    -- manually run snes interface functions after onClear in case we are already ingame
    if PopVersion < "0.20.1" or AutoTracker:GetConnectionState("SNES") == 3 then
        -- add snes interface functions here
    end
end

-- called when an item gets collected
function onItem(index, item_id, item_name, player_number)
    if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
        print(string.format("called onItem: %s, %s, %s, %s, %s", index, item_id, item_name, player_number, CUR_INDEX))
    end
    if index <= CUR_INDEX then
        return
    end
    local is_local = player_number == Archipelago.PlayerNumber
    CUR_INDEX = index;
    local v = ITEM_MAPPING[item_id]
    if not v then
        if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
            print(string.format("onItem: could not find item mapping for id %s", item_id))
        end
        return
    end
    if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
        print(string.format("onItem: code: %s, type %s", v[1], v[2]))
    end
    if not v[1] then
        return
    end
    local obj = Tracker:FindObjectForCode(v[1])
    if obj then
        if v[2] == "toggle" then
            obj.Active = true
        elseif v[2] == "progressive" then
            if obj.Active then
                obj.CurrentStage = obj.CurrentStage + 1
            else
                obj.Active = true
            end
        elseif v[2] == "consumable" then
            obj.AcquiredCount = obj.AcquiredCount + obj.Increment
        elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
            print(string.format("onItem: unknown item type %s for code %s", v[2], v[1]))
        end
    elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
        print(string.format("onItem: could not find object for code %s", v[1]))
    end
    -- track local items via snes interface
    if is_local then
        if LOCAL_ITEMS[v[1]] then
            LOCAL_ITEMS[v[1]] = LOCAL_ITEMS[v[1]] + 1
        else
            LOCAL_ITEMS[v[1]] = 1
        end
    else
        if GLOBAL_ITEMS[v[1]] then
            GLOBAL_ITEMS[v[1]] = GLOBAL_ITEMS[v[1]] + 1
        else
            GLOBAL_ITEMS[v[1]] = 1
        end
    end
    if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
        print(string.format("local items: %s", dump_table(LOCAL_ITEMS)))
        print(string.format("global items: %s", dump_table(GLOBAL_ITEMS)))
    end
    if PopVersion < "0.20.1" or AutoTracker:GetConnectionState("SNES") == 3 then
        -- add snes interface functions here for local item tracking
    end
end

--called when a location gets cleared
function onLocation(location_id, location_name)
    if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
        print(string.format("called onLocation: %s, %s", location_id, location_name))
    end
    local v = LOCATION_MAPPING[location_id]
    if not v and AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
        print(string.format("onLocation: could not find location mapping for id %s", location_id))
    end
    if not v[1] then
        return
    end
    local obj = Tracker:FindObjectForCode(v[1])
    if obj then
        if v[1]:sub(1, 1) == "@" then
            obj.AvailableChestCount = obj.AvailableChestCount - 1
        else
            obj.Active = true
        end
    elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
        print(string.format("onLocation: could not find object for code %s", v[1]))
    end
    if location_name == "Take Any Item Left" then
        obj = Tracker:FindObjectForCode("@Overworld/Take Any Item (Shore)/Left")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Take Any Item Left" then
        obj = Tracker:FindObjectForCode("@Overworld/Take Any Item (Bush)/Left")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Take Any Item Left" then
        obj = Tracker:FindObjectForCode("@Overworld/Take Any Item (Northeast Raft Spot)/Left")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Take Any Item Middle" then
        obj = Tracker:FindObjectForCode("@Overworld/Take Any Item (Shore)/Middle")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Take Any Item Middle" then
        obj = Tracker:FindObjectForCode("@Overworld/Take Any Item (Bush)/Middle")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Take Any Item Middle" then
        obj = Tracker:FindObjectForCode("@Overworld/Take Any Item (Northeast Raft Spot)/Middle")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Take Any Item Right" then
        obj = Tracker:FindObjectForCode("@Overworld/Take Any Item (Shore)/Right")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Take Any Item Right" then
        obj = Tracker:FindObjectForCode("@Overworld/Take Any Item (Bush)/Right")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Take Any Item Right" then
        obj = Tracker:FindObjectForCode("@Overworld/Take Any Item (Northeast Raft Spot)/Right")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Arrow Shop Item Left" then
        obj = Tracker:FindObjectForCode("@Overworld/Arrow Shop (Desert)/Left")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Arrow Shop Item Left" then
        obj = Tracker:FindObjectForCode("@Overworld/Arrow Shop (Lake)/Left")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Arrow Shop Item Left" then
        obj = Tracker:FindObjectForCode("@Overworld/Arrow Shop (Graveyard)/Left")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Arrow Shop Item Middle" then
        obj = Tracker:FindObjectForCode("@Overworld/Arrow Shop (Desert)/Middle")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Arrow Shop Item Middle" then
        obj = Tracker:FindObjectForCode("@Overworld/Arrow Shop (Lake)/Middle")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Arrow Shop Item Middle" then
        obj = Tracker:FindObjectForCode("@Overworld/Arrow Shop (Graveyard)/Middle")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Arrow Shop Item Right" then
        obj = Tracker:FindObjectForCode("@Overworld/Arrow Shop (Desert)/Right")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Arrow Shop Item Right" then
        obj = Tracker:FindObjectForCode("@Overworld/Arrow Shop (Lake)/Right")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Arrow Shop Item Right" then
        obj = Tracker:FindObjectForCode("@Overworld/Arrow Shop (Graveyard)/Right")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Candle Shop Item Left" then
        obj = Tracker:FindObjectForCode("@Overworld/Candle Shop (Lost Hills)/Left")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Candle Shop Item Left" then
        obj = Tracker:FindObjectForCode("@Overworld/Candle Shop (Start)/Left")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Candle Shop Item Middle" then
        obj = Tracker:FindObjectForCode("@Overworld/Candle Shop (Lost Hills)/Middle")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Candle Shop Item Middle" then
        obj = Tracker:FindObjectForCode("@Overworld/Candle Shop (Start)/Middle")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Candle Shop Item Right" then
        obj = Tracker:FindObjectForCode("@Overworld/Candle Shop (Lost Hills)/Right")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Candle Shop Item Right" then
        obj = Tracker:FindObjectForCode("@Overworld/Candle Shop (Start)/Right")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Shield Shop Item Left" then
        obj = Tracker:FindObjectForCode("@Overworld/Shield Shop (Corner Bush)/Left")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Shield Shop Item Left" then
        obj = Tracker:FindObjectForCode("@Overworld/Shield Shop (Bomb Wall)/Left")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Shield Shop Item Left" then
        obj = Tracker:FindObjectForCode("@Overworld/Shield Shop (Forgotten Spot)/Left")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Shield Shop Item Middle" then
        obj = Tracker:FindObjectForCode("@Overworld/Shield Shop (Corner Bush)/Middle")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Shield Shop Item Middle" then
        obj = Tracker:FindObjectForCode("@Overworld/Shield Shop (Bomb Wall)/Middle")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Shield Shop Item Middle" then
        obj = Tracker:FindObjectForCode("@Overworld/Shield Shop (Forgotten Spot)/Middle")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Shield Shop Item Right" then
        obj = Tracker:FindObjectForCode("@Overworld/Shield Shop (Corner Bush)/Right")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Shield Shop Item Right" then
        obj = Tracker:FindObjectForCode("@Overworld/Shield Shop (Bomb Wall)/Right")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Shield Shop Item Right" then
        obj = Tracker:FindObjectForCode("@Overworld/Shield Shop (Forgotten Spot)/Right")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Potion Shop Item Left" then
        obj = Tracker:FindObjectForCode("@Overworld/Potion Shop (Desert Bush)/Left")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Potion Shop Item Left" then
        obj = Tracker:FindObjectForCode("@Overworld/Potion Shop (Start Bush)/Left")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Potion Shop Item Left" then
        obj = Tracker:FindObjectForCode("@Overworld/Potion Shop (Desert Bomb Wall)/Left")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Potion Shop Item Left" then
        obj = Tracker:FindObjectForCode("@Overworld/Potion Shop (by D9)/Left")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Potion Shop Item Left" then
        obj = Tracker:FindObjectForCode("@Overworld/Potion Shop (Bomb Wall by D6)/Left")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Potion Shop Item Left" then
        obj = Tracker:FindObjectForCode("@Overworld/Potion Shop (Dead Woods)/Left")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Potion Shop Item Middle" then
        obj = Tracker:FindObjectForCode("@Overworld/Potion Shop (Desert Bush)/Middle")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Potion Shop Item Middle" then
        obj = Tracker:FindObjectForCode("@Overworld/Potion Shop (Start Bush)/Middle")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Potion Shop Item Middle" then
        obj = Tracker:FindObjectForCode("@Overworld/Potion Shop (Desert Bomb Wall)/Middle")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Potion Shop Item Middle" then
        obj = Tracker:FindObjectForCode("@Overworld/Potion Shop (by D9)/Middle")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Potion Shop Item Middle" then
        obj = Tracker:FindObjectForCode("@Overworld/Potion Shop (Bomb Wall by D6)/Middle")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Potion Shop Item Middle" then
        obj = Tracker:FindObjectForCode("@Overworld/Potion Shop (Dead Woods)/Middle")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Potion Shop Item Right" then
        obj = Tracker:FindObjectForCode("@Overworld/Potion Shop (Desert Bush)/Right")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Potion Shop Item Right" then
        obj = Tracker:FindObjectForCode("@Overworld/Potion Shop (Start Bush)/Right")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Potion Shop Item Right" then
        obj = Tracker:FindObjectForCode("@Overworld/Potion Shop (Desert Bomb Wall)/Right")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Potion Shop Item Right" then
        obj = Tracker:FindObjectForCode("@Overworld/Potion Shop (by D9)/Right")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Potion Shop Item Right" then
        obj = Tracker:FindObjectForCode("@Overworld/Potion Shop (Bomb Wall by D6)/Right")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Potion Shop Item Right" then
        obj = Tracker:FindObjectForCode("@Overworld/Potion Shop (Dead Woods)/Right")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 1 Item (Bow)" then
        obj = Tracker:FindObjectForCode("@Eagle Dungeon (D1)/Bow/Freestanding")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 1 Item (Boomerang)" then
        obj = Tracker:FindObjectForCode("@Eagle Dungeon (D1)/Boomerang/Freestanding")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 1 Map" then
        obj = Tracker:FindObjectForCode("@Eagle Dungeon (D1)/Map/Freestanding")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 1 Compass" then
        obj = Tracker:FindObjectForCode("@Eagle Dungeon (D1)/Compass/Freestanding")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 1 Boss" then
        obj = Tracker:FindObjectForCode("@Eagle Dungeon (D1)/Aquamentus/Boss")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 1 Triforce" then
        obj = Tracker:FindObjectForCode("@Eagle Dungeon (D1)/Triforce/Freestanding")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 1 Key Drop (Keese Entrance)" then
        obj = Tracker:FindObjectForCode("@Eagle Dungeon (D1)/Keese Entrance/Key Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 1 Key Drop (Stalfos Middle)" then
        obj = Tracker:FindObjectForCode("@Eagle Dungeon (D1)/Stalfos Middle/Key Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 1 Key Drop (Moblins)" then
        obj = Tracker:FindObjectForCode("@Eagle Dungeon (D1)/Moblins/Key Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 1 Key Drop (Stalfos Water)" then
        obj = Tracker:FindObjectForCode("@Eagle Dungeon (D1)/Stalfos Water/Key Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 1 Key Drop (Stalfos Entrance)" then
        obj = Tracker:FindObjectForCode("@Eagle Dungeon (D1)/Stalfos Entrance/Key Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 1 Key Drop (Wallmasters)" then
        obj = Tracker:FindObjectForCode("@Eagle Dungeon (D1)/Wallmasters/Key Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 2 Item (Magical Boomerang)" then
        obj = Tracker:FindObjectForCode("@Moon (D2)/Magical Boomerang/Freestanding")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 2 Map" then
        obj = Tracker:FindObjectForCode("@Moon (D2)/Map/Freestanding")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 2 Compass" then
        obj = Tracker:FindObjectForCode("@Moon (D2)/Compass/Freestanding")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 2 Boss" then
        obj = Tracker:FindObjectForCode("@Moon (D2)/Dodongo/Boss")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 2 Triforce" then
        obj = Tracker:FindObjectForCode("@Moon (D2)/Triforce/Freestanding")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 2 Key Drop (Ropes West)" then
        obj = Tracker:FindObjectForCode("@Moon (D2)/Ropes West/Key Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 2 Key Drop (Moldorms)" then
        obj = Tracker:FindObjectForCode("@Moon (D2)/Moldorms/Key Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 2 Key Drop (Ropes Middle)" then
        obj = Tracker:FindObjectForCode("@Moon (D2)/Ropes Middle/Key Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 2 Key Drop (Ropes Entrance)" then
        obj = Tracker:FindObjectForCode("@Moon (D2)/Ropes Entrance/Key Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 2 Bomb Drop (Keese)" then
        obj = Tracker:FindObjectForCode("@Moon (D2)/Keese/Bomb Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 2 Bomb Drop (Moblins)" then
        obj = Tracker:FindObjectForCode("@Moon (D2)/Moblins/Bomb Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 2 Rupee Drop (Gels)" then
        obj = Tracker:FindObjectForCode("@Moon (D2)/Gels/Rupee Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 3 Item (Raft)" then
        obj = Tracker:FindObjectForCode("@Manji (D3)/Raft/Freestanding")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 3 Map" then
        obj = Tracker:FindObjectForCode("@Manji (D3)/Map/Freestanding")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 3 Compass" then
        obj = Tracker:FindObjectForCode("@Manji (D3)/Compass/Freestanding")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 3 Boss" then
        obj = Tracker:FindObjectForCode("@Manji (D3)/Manhandla/Boss")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 3 Triforce" then
        obj = Tracker:FindObjectForCode("@Manji (D3)/Triforce/Freestanding")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 3 Key Drop (Zols and Keese West)" then
        obj = Tracker:FindObjectForCode("@Manji (D3)/Zols and Keese West/Key Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 3 Key Drop (Keese North)" then
        obj = Tracker:FindObjectForCode("@Manji (D3)/Keese North/Key Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 3 Key Drop (Zols Central)" then
        obj = Tracker:FindObjectForCode("@Manji (D3)/Zols Central/Key Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 3 Key Drop (Zols South)" then
        obj = Tracker:FindObjectForCode("@Manji (D3)/Zols South/Key Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 3 Key Drop (Zols Entrance)" then
        obj = Tracker:FindObjectForCode("@Manji (D3)/Zols Entrance/Key Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 3 Bomb Drop (Darknuts West)" then
        obj = Tracker:FindObjectForCode("@Manji (D3)/Darknuts West/Bomb Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 3 Bomb Drop (Keese Corridor)" then
        obj = Tracker:FindObjectForCode("@Manji (D3)/Keese Corridor/Bomb Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 3 Bomb Drop (Darknuts Central)" then
        obj = Tracker:FindObjectForCode("@Manji (D3)/Darknuts Central/Bomb Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 3 Rupee Drop (Zols and Keese East)" then
        obj = Tracker:FindObjectForCode("@Manji (D3)/Zols and Keese East/Rupee Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 4 Item (Stepladder)" then
        obj = Tracker:FindObjectForCode("@Snake (D4)/Stepladder/Freestanding")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 4 Map" then
        obj = Tracker:FindObjectForCode("@Snake (D4)/Map/Freestanding")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 4 Compass" then
        obj = Tracker:FindObjectForCode("@Snake (D4)/Compass/Freestanding")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 4 Boss" then
        obj = Tracker:FindObjectForCode("@Snake (D4)/Gleeok/Boss")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 4 Triforce" then
        obj = Tracker:FindObjectForCode("@Snake (D4)/Triforce/Freestanding")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 4 Key Drop (Keese Entrance)" then
        obj = Tracker:FindObjectForCode("@Snake (D4)/Keese Entrance/Key Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 4 Key Drop (Keese Central)" then
        obj = Tracker:FindObjectForCode("@Snake (D4)/Keese Central/Key Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 4 Key Drop (Zols)" then
        obj = Tracker:FindObjectForCode("@Snake (D4)/Zols/Key Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 4 Key Drop (Keese North)" then
        obj = Tracker:FindObjectForCode("@Snake (D4)/Keese North/Key Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 5 Item (Recorder)" then
        obj = Tracker:FindObjectForCode("@Lizard (D5)/Recorder/Freestanding")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 5 Map" then
        obj = Tracker:FindObjectForCode("@Lizard (D5)/Map/Freestanding")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 5 Compass" then
        obj = Tracker:FindObjectForCode("@Lizard (D5)/Compass/Freestanding")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 5 Boss" then
        obj = Tracker:FindObjectForCode("@Lizard (D5)/Digdogger/Boss")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 5 Triforce" then
        obj = Tracker:FindObjectForCode("@Lizard (D5)/Triforce/Freestanding")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 5 Key Drop (Keese North)" then
        obj = Tracker:FindObjectForCode("@Lizard (D5)/Keese North/Key Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 5 Key Drop (Gibdos North)" then
        obj = Tracker:FindObjectForCode("@Lizard (D5)/Gibdos North/Key Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 5 Key Drop (Gibdos Central)" then
        obj = Tracker:FindObjectForCode("@Lizard (D5)/Gibdos Central/Key Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 5 Key Drop (Pols Voice Entrance)" then
        obj = Tracker:FindObjectForCode("@Lizard (D5)/Pols Voice Entrance/Key Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 5 Key Drop (Gibdos Entrance)" then
        obj = Tracker:FindObjectForCode("@Lizard (D5)/Gibdos Entrance/Key Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 5 Key Drop (Gibdos, Keese, and Pols Voice)" then
        obj = Tracker:FindObjectForCode("@Lizard (D5)/Gibdos, Keese, and Pols Voice/Key Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 5 Key Drop (Zols)" then
        obj = Tracker:FindObjectForCode("@Lizard (D5)/Zols (Key)/Key Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 5 Bomb Drop (Gibdos)" then
        obj = Tracker:FindObjectForCode("@Lizard (D5)/Gibdos/Bomb Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 5 Bomb Drop (Dodongos)" then
        obj = Tracker:FindObjectForCode("@Lizard (D5)/Dodongos/Bomb Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 5 Rupee Drop (Zols)" then
        obj = Tracker:FindObjectForCode("@Lizard (D5)/Zols (Rupee)/Rupee Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 6 Item (Magical Rod)" then
        obj = Tracker:FindObjectForCode("@Dragon (D6)/Magical Rod/Freestanding")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 6 Map" then
        obj = Tracker:FindObjectForCode("@Dragon (D6)/Map/Freestanding")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 6 Compass" then
        obj = Tracker:FindObjectForCode("@Dragon (D6)/Compass/Freestanding")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 6 Boss" then
        obj = Tracker:FindObjectForCode("@Dragon (D6)/Gohma/Boss")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 6 Triforce" then
        obj = Tracker:FindObjectForCode("@Dragon (D6)/Triforce/Freestanding")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 6 Key Drop (Wizzrobes Entrance)" then
        obj = Tracker:FindObjectForCode("@Dragon (D6)/Wizzrobes Entrance/Key Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 6 Key Drop (Keese)" then
        obj = Tracker:FindObjectForCode("@Dragon (D6)/Keese/Key Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 6 Key Drop (Wizzrobes North Island)" then
        obj = Tracker:FindObjectForCode("@Dragon (D6)/Wizzrobes North Island/Key Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 6 Key Drop (Wizzrobes North Stream)" then
        obj = Tracker:FindObjectForCode("@Dragon (D6)/Wizzrobes North Stream/Key Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 6 Key Drop (Vires)" then
        obj = Tracker:FindObjectForCode("@Dragon (D6)/Vires/Key Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 6 Bomb Drop (Wizzrobes)" then
        obj = Tracker:FindObjectForCode("@Dragon (D6)/Wizzrobes (Bomb)/Bomb Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 6 Rupee Drop (Wizzrobes)" then
        obj = Tracker:FindObjectForCode("@Dragon (D6)/Wizzrobes (Rupee)/Rupee Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 7 Item (Red Candle)" then
        obj = Tracker:FindObjectForCode("@Demon (D7)/Red Candle/Freestanding")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 7 Map" then
        obj = Tracker:FindObjectForCode("@Demon (D7)/Map/Freestanding")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 7 Compass" then
        obj = Tracker:FindObjectForCode("@Demon (D7)/Compass/Freestanding")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 7 Boss" then
        obj = Tracker:FindObjectForCode("@Demon (D7)/Aquamentus/Boss")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 7 Triforce" then
        obj = Tracker:FindObjectForCode("@Demon (D7)/Triforce/Freestanding")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 7 Key Drop (Ropes)" then
        obj = Tracker:FindObjectForCode("@Demon (D7)/Ropes/Key Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 7 Key Drop (Goriyas)" then
        obj = Tracker:FindObjectForCode("@Demon (D7)/Goriyas/Key Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 7 Key Drop (Stalfos)" then
        obj = Tracker:FindObjectForCode("@Demon (D7)/Stalfos/Key Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 7 Key Drop (Moldorms)" then
        obj = Tracker:FindObjectForCode("@Demon (D7)/Moldorms/Key Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 7 Bomb Drop (Goriyas South)" then
        obj = Tracker:FindObjectForCode("@Demon (D7)/Goriyas South/Bomb Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 7 Bomb Drop (Keese and Spikes)" then
        obj = Tracker:FindObjectForCode("@Demon (D7)/Keese and Spikes/Bomb Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 7 Bomb Drop (Moldorms South)" then
        obj = Tracker:FindObjectForCode("@Demon (D7)/Moldorms South/Bomb Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 7 Bomb Drop (Moldorms North)" then
        obj = Tracker:FindObjectForCode("@Demon (D7)/Moldorms North/Bomb Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 7 Bomb Drop (Goriyas North)" then
        obj = Tracker:FindObjectForCode("@Demon (D7)/Goriyas North (Bomb)/Bomb Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 7 Bomb Drop (Dodongos)" then
        obj = Tracker:FindObjectForCode("@Demon (D7)/Dodongos (Bomb)/Bomb Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 7 Bomb Drop (Digdogger)" then
        obj = Tracker:FindObjectForCode("@Demon (D7)/Digdogger/Bomb Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 7 Rupee Drop (Goriyas Central)" then
        obj = Tracker:FindObjectForCode("@Demon (D7)/Goriyas Central/Rupee Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 7 Rupee Drop (Dodongos)" then
        obj = Tracker:FindObjectForCode("@Demon (D7)/Dodongos (Rupee)/Rupee Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 7 Rupee Drop (Goriyas North)" then
        obj = Tracker:FindObjectForCode("@Demon (D7)/Goriyas North (Rupee)/Rupee Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 8 Item (Magical Key)" then
        obj = Tracker:FindObjectForCode("@Lion (D8)/Magical Key/Freestanding")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 8 Map" then
        obj = Tracker:FindObjectForCode("@Lion (D8)/Map/Freestanding")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 8 Compass" then
        obj = Tracker:FindObjectForCode("@Lion (D8)/Compass/Freestanding")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 8 Item (Book of Magic)" then
        obj = Tracker:FindObjectForCode("@Lion (D8)/Book of Magic/Freestanding")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 8 Boss" then
        obj = Tracker:FindObjectForCode("@Lion (D8)/Gleeok/Boss")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 8 Triforce" then
        obj = Tracker:FindObjectForCode("@Lion (D8)/Triforce/Freestanding")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 8 Key Drop (Darknuts West)" then
        obj = Tracker:FindObjectForCode("@Lion (D8)/Darknuts West/Key Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 8 Key Drop (Darknuts Far West)" then
        obj = Tracker:FindObjectForCode("@Lion (D8)/Darknuts Far West/Key Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 8 Key Drop (Pols Voice South)" then
        obj = Tracker:FindObjectForCode("@Lion (D8)/Pols Voice South/Key Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 8 Key Drop (Pols Voice and Keese)" then
        obj = Tracker:FindObjectForCode("@Lion (D8)/Pols Voice and Keese/Key Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 8 Key Drop (Darknuts Central)" then
        obj = Tracker:FindObjectForCode("@Lion (D8)/Darknuts Central/Key Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 8 Key Drop (Keese and Zols Entrance)" then
        obj = Tracker:FindObjectForCode("@Lion (D8)/Keese and Zols Entrance/Key Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 8 Bomb Drop (Darknuts North)" then
        obj = Tracker:FindObjectForCode("@Lion (D8)/Darknuts North/Bomb Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 8 Bomb Drop (Darknuts East)" then
        obj = Tracker:FindObjectForCode("@Lion (D8)/Darknuts East/Bomb Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 8 Bomb Drop (Pols Voice North)" then
        obj = Tracker:FindObjectForCode("@Lion (D8)/Pols Voice North/Bomb Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 8 Rupee Drop (Manhandla Entrance West)" then
        obj = Tracker:FindObjectForCode("@Lion (D8)/Manhandla Entrance West/Rupee Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 8 Rupee Drop (Manhandla Entrance North)" then
        obj = Tracker:FindObjectForCode("@Lion (D8)/Manhandla Entrance North/Rupee Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 8 Rupee Drop (Darknuts and Gibdos)" then
        obj = Tracker:FindObjectForCode("@Lion (D8)/Darknuts and Gibdos/Rupee Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 9 Item (Silver Arrow)" then
        obj = Tracker:FindObjectForCode("@Death Mountain (D9)/Silver Arrow/Freestanding")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 9 Item (Red Ring)" then
        obj = Tracker:FindObjectForCode("@Death Mountain (D9)/Red Ring/Freestanding")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 9 Map" then
        obj = Tracker:FindObjectForCode("@Death Mountain (D9)/Map/Freestanding")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 9 Compass" then
        obj = Tracker:FindObjectForCode("@Death Mountain (D9)/Compass/Freestanding")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 9 Key Drop (Patra Southwest)" then
        obj = Tracker:FindObjectForCode("@Death Mountain (D9)/Patra Southwest/Key Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 9 Key Drop (Like Likes and Zols East)" then
        obj = Tracker:FindObjectForCode("@Death Mountain (D9)/Like Likes and Zols East/Key Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 9 Key Drop (Wizzrobes and Bubbles East)" then
        obj = Tracker:FindObjectForCode("@Death Mountain (D9)/Wizzrobes and Bubbles East/Key Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 9 Key Drop (Wizzrobes East Island)" then
        obj = Tracker:FindObjectForCode("@Death Mountain (D9)/Wizzrobes East Island/Key Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 9 Bomb Drop (Blue Lanmolas)" then
        obj = Tracker:FindObjectForCode("@Death Mountain (D9)/Blue Lanmolas/Bomb Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 9 Bomb Drop (Gels Lake)" then
        obj = Tracker:FindObjectForCode("@Death Mountain (D9)/Gels Lake/Bomb Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 9 Bomb Drop (Like Likes and Zols Corridor)" then
        obj = Tracker:FindObjectForCode("@Death Mountain (D9)/Like Likes and Zols Corridor/Bomb Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 9 Bomb Drop (Patra Northeast)" then
        obj = Tracker:FindObjectForCode("@Death Mountain (D9)/Patra Northeast/Bomb Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 9 Bomb Drop (Vires)" then
        obj = Tracker:FindObjectForCode("@Death Mountain (D9)/Vires/Bomb Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 9 Rupee Drop (Wizzrobes West Island)" then
        obj = Tracker:FindObjectForCode("@Death Mountain (D9)/Wizzrobes West Island/Rupee Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 9 Rupee Drop (Red Lanmolas)" then
        obj = Tracker:FindObjectForCode("@Death Mountain (D9)/Red Lanmolas/Rupee Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 9 Rupee Drop (Keese Southwest)" then
        obj = Tracker:FindObjectForCode("@Death Mountain (D9)/Keese Southwest/Rupee Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 9 Rupee Drop (Keese Central Island)" then
        obj = Tracker:FindObjectForCode("@Death Mountain (D9)/Keese Central Island/Rupee Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 9 Rupee Drop (Wizzrobes Central)" then
        obj = Tracker:FindObjectForCode("@Death Mountain (D9)/Wizzrobes Central/Rupee Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 9 Rupee Drop (Wizzrobes North Island)" then
        obj = Tracker:FindObjectForCode("@Death Mountain (D9)/Wizzrobes North Island/Rupee Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Level 9 Rupee Drop (Gels East)" then
        obj = Tracker:FindObjectForCode("@Death Mountain (D9)/Gels East/Rupee Drop")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Ganon: Triforce of Power" then
        obj = Tracker:FindObjectForCode("ganon")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
    if location_name == "Zelda: Rescued Zelda!" then
        obj = Tracker:FindObjectForCode("zelda")
        obj.AvailableChestCount = obj.AvailableChestCount - 1
    end
end

-- called when a locations is scouted
function onScout(location_id, location_name, item_id, item_name, item_player)
    if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
        print(string.format("called onScout: %s, %s, %s, %s, %s", location_id, location_name, item_id, item_name,
            item_player))
    end
    -- not implemented yet :(
end

-- called when a bounce message is received 
function onBounce(json)
    if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
        print(string.format("called onBounce: %s", dump_table(json)))
    end
    -- your code goes here
end

-- add AP callbacks
-- un-/comment as needed
Archipelago:AddClearHandler("clear handler", onClear)
Archipelago:AddItemHandler("item handler", onItem)
Archipelago:AddLocationHandler("location handler", onLocation)
-- Archipelago:AddScoutHandler("scout handler", onScout)
-- Archipelago:AddBouncedHandler("bounce handler", onBounce)
