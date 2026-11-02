-- Auto-Zero Humanity Cyberdecks
-- Hides the humanity/allocation line in cyberdeck tooltips when the item's
-- variant list contains Variants.Humanity0Cost (set via the red4ext/TweakXL mod).

local function safeCall(fn, ...)
    local ok, res = pcall(fn, ...)
    if not ok then return nil end
    return res
end

local function getClassName(w)
    local cls = "<?>"; pcall(function() cls = tostring(w:GetClassName()) end); return cls
end
local function getName(w)
    local nm = "<?>"; pcall(function() nm = tostring(w:GetName()) end); return nm
end
local function getNumChildren(w)
    local n = 0; pcall(function() n = w:GetNumChildren() end); return n
end
local function getText(w)
    local t = ""
    local methods = {"GetText", "GetDisplayName", "GetLocalizedText"}
    for _, m in ipairs(methods) do
        if t == "" then
            local v = safeCall(function() return w[m](w) end)
            if v ~= nil then t = tostring(v) end
        end
    end
    if t == "" or t == "nil" then
        for _, p in ipairs({"text", "Text", "displayText", "label", "Label"}) do
            local v = safeCall(function() return w[p] end)
            if v ~= nil and tostring(v) ~= "" then t = tostring(v); break end
        end
    end
    if t == "nil" then t = "" end
    return t
end

local function getChildren(w)
    local kids = {}
    local n = getNumChildren(w)
    if n <= 0 then return kids end
    local accessors = {
        function(ww, i) return ww:GetChild(i) end,
        function(ww, i) return ww:GetWidget(i) end,
        function(ww, i) return ww:GetSlot(i) end,
    }
    for _, acc in ipairs(accessors) do
        if #kids == 0 then
            local ok = true
            local tmp = {}
            for i = 0, n - 1 do
                local c = nil
                local pok = pcall(function() c = acc(w, i) end)
                if not pok then ok = false; break end
                if c then table.insert(tmp, c) end
            end
            if ok and #tmp > 0 then kids = tmp end
        end
    end
    if #kids == 0 then
        for _, prop in ipairs({"children", "Children", "slots", "Slots", "widgets", "Widgets"}) do
            local v = safeCall(function() return w[prop] end)
            if type(v) == "table" then
                for k, val in pairs(v) do
                    if type(val) == "userdata" then table.insert(kids, val) end
                end
                if #kids > 0 then break end
            end
        end
    end
    if #kids == 0 then
        for _, m in ipairs({"GetChildren", "GetAllChildren", "GetSlots"}) do
            local v = safeCall(function() return w[m](w) end)
            if type(v) == "table" then
                for k, val in pairs(v) do
                    if type(val) == "userdata" then table.insert(kids, val) end
                end
                if #kids > 0 then break end
            end
        end
    end
    return kids
end

local humanityWidgets = {}

local function findHumanity(w, path, depth)
    depth = depth or 0
    if not w or depth > 10 then return end
    local name = getName(w)
    local txt = getText(w)
    local fullPath = path .. "/" .. name
    local lower = (name .. " " .. txt):lower()
    -- Only the cyberdeck humanity/allocation panel.
    if lower:find("human") or lower:find("allocationcost") then
        table.insert(humanityWidgets, {widget = w, path = fullPath})
    end
    local kids = getChildren(w)
    for _, c in ipairs(kids) do
        findHumanity(c, fullPath, depth + 1)
    end
end

local function hideWidget(w)
    pcall(function() w:SetVisible(false) end)
    pcall(function() w:SetOpacity(0) end)
    pcall(function() w:SetScale(0, 0) end)
    pcall(function() w:Collapse() end)
end

local function resolveTweakDBIDFromData(data)
    if data == nil then return nil end
    -- Record-extraction methods.
    local recordMethods = {"GetItemRecord", "GetRecord", "GetItemData", "GetStatsObjectRecord"}
    for _, m in ipairs(recordMethods) do
        local rec = nil
        pcall(function() rec = data[m](data) end)
        if rec ~= nil then
            local tid = nil
            for _, gn in ipairs({"GetID", "GetTweakDBID", "GetRecordID"}) do
                pcall(function() tid = rec[gn](rec) end)
                if tid ~= nil then break end
            end
            if tid == nil then
                for _, gn in ipairs({"m_tweakDBID", "tweakDBID", "TweakDBID", "m_id", "id", "ID"}) do
                    local gv = nil
                    pcall(function() gv = rec[gn] end)
                    if gv ~= nil then tid = gv; break end
                end
            end
            if tid ~= nil then return tid end
        end
    end
    -- RPGManager helper.
    local rec = nil
    pcall(function() rec = RPGManager.GetItemRecord(data) end)
    if rec ~= nil then
        local tid = nil
        pcall(function() tid = rec:GetID() end)
        if tid == nil then pcall(function() tid = rec:GetTweakDBID() end) end
        if tid ~= nil then return tid end
    end
    -- Direct ID methods on data.
    for _, m in ipairs({"GetID", "GetTweakDBID", "GetItemID", "GetStatsObjectID"}) do
        local v = nil
        pcall(function() v = data[m](data) end)
        if v ~= nil then return v end
    end
    -- Direct fields on data.
    for _, f in ipairs({"m_tweakDBID", "tweakDBID", "TweakDBID", "m_id", "id", "ID", "m_itemID", "itemID", "ItemID"}) do
        local v = nil
        pcall(function() v = data[f] end)
        if v ~= nil then return v end
    end
    return nil
end

local function tryGetTweakDBID(obj)
    for _, name in ipairs({"itemData", "m_itemData", "data", "m_data", "ItemData", "m_item", "item"}) do
        local d = nil
        pcall(function() d = obj[name] end)
        if d == nil then pcall(function() d = obj[name](obj) end) end
        if d ~= nil then
            local tid = resolveTweakDBIDFromData(d)
            if tid ~= nil then return tid end
        end
    end
    for _, name in ipairs({"m_tweakDBID", "tweakDBID", "TweakDBID", "m_id", "id", "ID"}) do
        local v = nil
        pcall(function() v = obj[name] end)
        if v ~= nil then return v end
    end
    return nil
end

local function itemHasZeroCostVariant(obj)
    local data = nil
    for _, name in ipairs({"itemData", "m_itemData", "data", "m_data", "ItemData"}) do
        pcall(function() data = obj[name] end)
        if data == nil then pcall(function() data = obj[name](obj) end) end
        if data ~= nil then break end
    end
    if data == nil then return false end

    local rec = nil
    pcall(function() rec = data:GetItemRecord() end)
    if rec == nil then pcall(function() rec = RPGManager.GetItemRecord(data) end) end
    if rec == nil then pcall(function() rec = data:GetRecord() end) end
    if rec == nil then return false end

    local variants = nil
    pcall(function() variants = rec:Variants() end)
    if variants == nil then pcall(function() variants = rec.Variants(rec) end) end
    if variants == nil then return false end

    local function containsZero(v)
        if v == nil then return false end
        if tostring(v):find("Humanity0Cost") then return true end
        local vid = nil
        pcall(function() vid = v:GetID() end)
        if vid == nil then pcall(function() vid = v:GetTweakDBID() end) end
        if vid ~= nil and tostring(vid):find("Humanity0Cost") then return true end
        if type(v) == "table" then
            for _, item in pairs(v) do
                if containsZero(item) then return true end
            end
        end
        return false
    end
    return containsZero(variants)
end

local function onTooltip(obj)
    humanityWidgets = {}

    local isZero = itemHasZeroCostVariant(obj)

    for _, prop in ipairs({"Root", "root"}) do
        local w = safeCall(function() return obj[prop] end)
        if w then
            findHumanity(w, "obj." .. prop, 0)
        end
    end

    if isZero then
        for _, entry in ipairs(humanityWidgets) do
            hideWidget(entry.widget)
        end
    end
end

registerForEvent("onInit", function()
    local classMethods = {
        ItemTooltipCommonController = {"Show", "SetData"},
        ItemTooltipStatController = {"SetData"},
    }
    for cls, methods in pairs(classMethods) do
        for _, m in ipairs(methods) do
            pcall(function()
                Observe(cls, m, function(obj, ...)
                    onTooltip(obj)
                end)
            end)
        end
    end
end)
