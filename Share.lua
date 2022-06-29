local ADDON_NAME, Internal = ...
local L = Internal.L
local External = _G[ADDON_NAME]

local format = string.format
local wipe = table.wipe
local concat = table.concat

local LibSerialize = LibStub("LibSerialize")
local LibDeflate = LibStub("LibDeflate")

local function StringToTable(text)
    local stringType = text:sub(1,1)
    if stringType == "{" then
        local func, err = loadstring("return " .. text, "Import")
        if not func then
            return false, err
        end
        setfenv(func, {});
        return pcall(func)
    else
        return false, L["Invalid string"]
    end
end
local function TableToString(tbl)
    local str = {}
    for k,v in pairs(tbl) do
        if type(k) == "number" then
            k = "[" .. k .. "]"
        elseif type(k) ~= "string" then
            error(format(L["Invalid key type %s"], type(k)))
        end

        if type(v) == "table" then
            v = TableToString(v)
        elseif type(v) == "string" then
            v = format("%q", v)
        elseif type(v) ~= "number" and type(v) ~= "boolean" then
            error(format(L["Invalid value type %s for key %s"], type(v), tostring(k)))
        end

        str[#str+1] = k .. "=" .. tostring(v)
    end
    return "{" .. concat(str, ",") .. "}"
end

local Base64Encode, Base64Decode
do
    local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    function Base64Encode(data)
        return ((data:gsub('.', function(x)
            local r,b='',x:byte()
            for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
            return r;
        end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
            if (#x < 6) then return '' end
            local c=0
            for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
            return b:sub(c+1,c+1)
        end)..({ '', '==', '=' })[#data%3+1])
    end
    function Base64Decode(data)
        data = string.gsub(data, '[^'..b..'=]', '')
        return (data:gsub('.', function(x)
            if (x == '=') then return '' end
            local r,f='',(b:find(x)-1)
            for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
            return r;
        end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
            if (#x ~= 8) then return '' end
            local c=0
            for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
            return string.char(c)
        end))
    end
end

local function Encode(content, format)
    if #format == 1 then
        if format == "N" then
            return "N" .. content
        elseif format == "T" then
            return "T" .. TableToString(content)
        elseif format == "S" then
            return "S" .. LibSerialize:Serialize(content)
        elseif format == "B" then
            return "B" .. Base64Encode(content)
        elseif format == "A" then
            return "A" .. LibDeflate:EncodeForWoWAddonChannel(content)
        elseif format == "Z" then
            return "Z" .. LibDeflate:CompressDeflate(content)
        else
            error("Unsupported format")
        end
    elseif #format > 1 then
        local f, ormat = format:match("^([A-Z])([A-Z]*)$")
        return Encode(Encode(content, ormat), f)
    end
end
local function Decode(content)
    local format, content = content:match("^([A-Z])(.*)$")

    if format == "N" then
        return true, content
    elseif format == "T" then
        return StringToTable(content)
    elseif format == "S" then
        return LibSerialize:Deserialize(content)
    elseif format == "B" then
        return Decode(Base64Decode(content) or "")
    elseif format == "A" then
        return Decode(LibDeflate:DecodeForWoWAddonChannel(content) or "")
    elseif format == "Z" then
        return Decode(LibDeflate:DecompressDeflate(content) or "")
    else
        return false, "Unsupported format"
    end
end

local function VerifySource(source)
    local version = source.version
    local sourceType = source.type
    local name = source.name

    if not name then
        return false, L["Missing name"]
    elseif type(name) ~= "string" then
        return false, L["Invalid name"]
    end

    if sourceType ~= "todo" then
        return false, L["Unsupported type"]
    end
    if version ~= 1 then -- Only supported version
        return false, L["Invalid source version"]
    end

    if type(source.states) ~= "table" then
        return false, L["Invalid states"]
    end
    local maxIndex = 0
    for k,v in pairs(source.states) do
        if type(k) ~= "number" then
            return false, L["Invalid states"]
        end
        maxIndex = math.max(maxIndex, k)
    end
    for i=1,maxIndex do
        local state = source.states[i]
        if type(state) ~= "table" or type(state.type) ~= "string" then
            return false, L["Invalid states"]
        end

        local provider = Internal.GetStateProvider(state.type)
        if not provider then
            return false, format(L["State provider is missing for %s"], state.type)
        end
        if provider:RequiresID() then
            if state.id == nil then
                return false, format(L["ID missing for state provider %s"], state.type)
            end
            if not provider:Supported(state.id, unpack(state.values or {})) then
                return false, format(L["Unsupported ID and/or data for state provider %s"], state.type)
            end
        end
    end

    if type(source.completed) ~= "string" then
        return false, format(L["Code error for %s function"], L["completed"])
    end
    if type(source.text) ~= "string" then
        return false, format(L["Code error for %s function"], L["text"])
    end
    if type(source.click) ~= "string" then
        return false, format(L["Code error for %s function"], L["click"])
    end
    if type(source.tooltip) ~= "string" then
        return false, format(L["Code error for %s function"], L["tooltip"])
    end

    return true
end

function External.Import(source)
    local success, err
    if type(source) == "string" then
        if source == "" then
            return false, ""
        end

        success, source = Decode(source)
        if not success then
            return false, source
        end

        if type(source) == "string" then
            success, source = StringToTable(source)
            if not success then
                return false, source
            end
        end
    end
    if type(source) ~= "table" then
        return false, L["Invalid source type"]
    end

    success, err = VerifySource(source)
    if not success then
        return false, err
    end

    return true, source
end

function Internal.GenerateUUID()
    return format("%08x-%04x-%04x-%08x", time(), math.random(0,0xffff), math.random(0,0xffff), GetTime())
end

function Internal.Export(exportType, id, format)
    assert(exportType == "todo")

    local todo = type(id) == "table" and id or Internal.GetTodo(id)
    assert(type(todo) == "table")

    if not todo.uuid then
        if type(todo.id) == "number" then
            todo.uuid = Internal.GenerateUUID()
        else
            todo.uuid = todo.id
        end
    end

    local result = {}

    result.type = "todo"
    result.version = 1

    result.name = todo.name
    result.uuid = todo.uuid

    result.states = todo.states

    result.completed = todo.completed or ""
    result.text = todo.text or ""
    result.tooltip = todo.tooltip or ""
    result.click = todo.click or ""

    return Encode(result, format or "BZS")
end
function External.ExportTodo(id, format)
    return Internal.Export("todo", id, format)
end
