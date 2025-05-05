script_name("Market Price")
script_author("legacy")
script_version("1")

local ffi = require("ffi")
local encoding = require("encoding")
local imgui = require("mimgui")
local requests = require("requests")
local dlstatus = require("moonloader").download_status
local iconv = require("iconv")
local u8 = encoding.UTF8
encoding.default = "CP1251"

local search = ffi.new("char[128]", "")
local window = imgui.new.bool(false)
local configPath = getWorkingDirectory() .. "\\config\\market_price.ini"
local updateURL = "https://raw.githubusercontent.com/legacy-Chay/legacy/refs/heads/main/update.json"

local configURL, items, cachedNick = nil, {}, nil

local conv_to_cp1251 = iconv.new("WINDOWS-1251", "UTF-8")
local conv_to_utf8 = iconv.new("UTF-8", "WINDOWS-1251")

local function utf8ToCp1251(str)
    return conv_to_cp1251:iconv(str)
end

local function cp1251ToUtf8(str)
    return conv_to_utf8:iconv(str)
end

local function downloadConfigFile(callback)
    if configURL then
        downloadUrlToFile(configURL, configPath, function(_, status)
            if status == dlstatus.STATUSEX_ENDDOWNLOAD and callback then callback() end
        end)
    end
end

local function loadData()
    items = {}
    local f = io.open(configPath, "rb")  -- "rb" для чтения в raw байтах
    if not f then downloadConfigFile(loadData) return end

    while true do
        local name = f:read("*l")
        local buy = f:read("*l")
        local sell = f:read("*l")
        if not name or not buy or not sell then break end
        table.insert(items, {
            name = cp1251ToUtf8(name),  -- конвертируем из cp1251 в utf8
            buy = cp1251ToUtf8(buy),
            sell = cp1251ToUtf8(sell)
        })
    end
    f:close()
end

local function saveData()
    local f = io.open(configPath, "wb")  -- "wb" для записи в raw байты
    if f then
        for _, v in ipairs(items) do
            f:write(utf8ToCp1251(v.name) .. "\n")  -- конвертируем из utf8 в cp1251
            f:write(utf8ToCp1251(v.buy) .. "\n")
            f:write(utf8ToCp1251(v.sell) .. "\n")
        end
        f:close()
    end
end

local function checkNick(nick)
    local response = requests.get(updateURL)
    if response.status_code == 200 then
        local j = decodeJson(response.text)
        configURL = j.config_url or nil

        if configURL and j.nicknames and type(j.nicknames) == "table" then
            for _, n in ipairs(j.nicknames) do
                if nick == n then
                    if thisScript().version ~= j.last then
                        downloadUrlToFile(j.url, thisScript().path, function(_, status)
                            if status == dlstatus.STATUSEX_ENDDOWNLOAD then
                                local f = io.open(thisScript().path, "r")
                                local content = f:read("*a")
                                f:close()
                                local conv = utf8ToCp1251(content)
                                f = io.open(thisScript().path, "w")
                                f:write(conv)
                                f:close()
                                thisScript():reload()
                            end
                        end)
                    end
                    return true
                end
            end
        else
            sampAddChatMessage("[Tmarket] config_url или nicknames не найдены в update.json", 0xFF0000)
        end
    end
    return false
end

local function getNicknameSafe()
    local result, id = sampGetPlayerIdByCharHandle(PLAYER_PED)
    if result and id >= 0 and id <= 1000 then
        return sampGetPlayerNickname(id)
    end
    return nil
end

function main()
    repeat wait(0) until isSampAvailable()

    repeat
        cachedNick = getNicknameSafe()
        wait(500)
    until cachedNick ~= nil

    if checkNick(cachedNick) then
        downloadConfigFile(loadData)
        sampAddChatMessage("{4169E1}[Tmarket загружен]{FFFFFF}. {00BFFF}Активация:{FFFFFF} {DA70D6}/lm {FFFFFF}. Автор: {1E90FF}legacy{FFFFFF}", 0x00FF00FF)
    else
        sampAddChatMessage("{FF0000}[Tmarket] Ваш ник не имеет доступа к скрипту.", 0xFF0000)
        return
    end

    sampRegisterChatCommand("lm", function()
        if cachedNick and checkNick(cachedNick) then
            window[0] = not window[0]
        end
    end)

    while true do wait(0) end
end

imgui.OnFrame(
    function() return window[0] and not isPauseMenuActive() and not sampIsDialogActive() end,
    function()
        imgui.SetNextWindowSize(imgui.ImVec2(1000, 600), imgui.Cond.FirstUseEver)
        imgui.PushStyleColor(imgui.Col.WindowBg, imgui.ImVec4(0.1, 0.05, 0.2, 1.0))
        imgui.Begin("Market Price by legacy", window)

        imgui.InputTextWithHint("##search", u8("Поиск по товарам..."), search, ffi.sizeof(search))
        imgui.SameLine()
        if imgui.Button(u8("Сохранить")) then saveData() end

        imgui.Separator()
        imgui.Columns(3)
        imgui.Text(u8("Товар")); imgui.NextColumn()
        imgui.Text(u8("Скупка")); imgui.NextColumn()
        imgui.Text(u8("Продажа")); imgui.NextColumn()
        imgui.Separator()

        local filter = u8:decode(ffi.string(search)):lower()
        for i, v in ipairs(items) do
            if filter == "" or v.name:lower():find(filter, 1, true) then
                local name_buf = ffi.new("char[128]", u8(v.name))
                local buy_buf = ffi.new("char[32]", u8(v.buy))
                local sell_buf = ffi.new("char[32]", u8(v.sell))

                if imgui.InputText("##name" .. i, name_buf, 128) then
                    v.name = u8:decode(ffi.string(name_buf))
                end
                imgui.NextColumn()
                if imgui.InputText("##buy" .. i, buy_buf, 32) then
                    v.buy = u8:decode(ffi.string(buy_buf))
                end
                imgui.NextColumn()
                if imgui.InputText("##sell" .. i, sell_buf, 32) then
                    v.sell = u8:decode(ffi.string(sell_buf))
                end
                imgui.NextColumn()
            end
        end

        imgui.Columns(1)
        imgui.End()
        imgui.PopStyleColor()
    end
)
