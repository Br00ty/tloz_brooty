---@diagnostic disable: lowercase-global
---[[
function has(item, amount)
    local count = Tracker:ProviderCountForCode(item)
    amount = tonumber(amount)
    if not amount then
      return count > 0
    else
      return count >= amount
    end
end

-- basic functions
function fire()
    return has("candle") or has("candle2") or (has("magicrod") and has("magicbook"))
end

function weapons()
  return has("sword") or has("sword2") or has("sword3") or has("magicrod") or has("candle2")
end

function gleeok_weapons()
  return has("sword") or has("sword2") or has("sword3") or has("magicrod")
end

function arrows()
  return has("arrow") or has("arrow2")
end

function defense(hearts)
  return has("heart", hearts) or (has("bluering") and has("heart", hearts / 2)) or (has("redring") and has("heart", hearts / 4))
end