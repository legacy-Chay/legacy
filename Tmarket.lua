script_name("Market Price")
script_author("legacy")
script_version("2")

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

local configURL = nil
local savedNicknames = {}
local items = {}

local function utf8ToCp1251(str)
    return iconv.new("WINDOWS-1251", "UTF-8"):iconv(str)
end

local function downloadConfigFile(callback)
    if not configURL then return end
    downloadUrlToFile(configURL, configPath, function(_, status)
        if status == dlstatus.STATUSEX_ENDDOWNLOAD and callback then
            callback()
        end
    end)
end

local function loadData()
    items = {}
    local f = io.open(configPath, "r")
    if not f then
        downloadConfigFile(loadData)
        return
    end
    while true do
        local name, buy, sell = f:read("*l"), f:read("*l"), f:read("*l")
        if not (name and buy and sell) then break end
        table.insert(items, { name = name, buy = buy, sell = sell })
    end
    f:close()
end

local function saveData()
    local f = io.open(configPath, "w")
    if not f then return end
    for _, v in ipairs(items) do
        f:write(("%s\n%s\n%s\n"):format(v.name, v.buy, v.sell))
    end
    f:close()
end

local function checkUpdate()
    local response = requests.get(updateURL)
    if response.status_code ~= 200 then return end
    local j = decodeJson(response.text)

    configURL = j.config_url or nil
    local nicknamesUrl = j.nicknames_url or nil  -- URL для никнеймов из update.json

    if not configURL then
        sampAddChatMessage("[Tmarket] config_url не найден в update.json", 0xFF0000)
        return
    end

    -- Загружаем данные с никнеймами из NickName.json через URL, указанный в update.json
    if nicknamesUrl then
        local nicknamesResponse = requests.get(nicknamesUrl)
        if nicknamesResponse.status_code == 200 then
            local nicknamesData = decodeJson(nicknamesResponse.text)
            -- Сохраняем данные о никнеймах
            savedNicknames = nicknamesData.nicknames or {}
        else
            sampAddChatMessage("[Tmarket] Не удалось загрузить никнеймы", 0xFF0000)
        end
    else
        sampAddChatMessage("[Tmarket] nicknames_url не найден в update.json", 0xFF0000)
    end

    -- Проверка обновления скрипта
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
end

local function checkNick()
    if not savedNicknames then return false end

    local nick = sampGetPlayerNickname(select(2, sampGetPlayerIdByCharHandle(PLAYER_PED)))

    for _, n in ipairs(savedNicknames) do
        if nick == n then
            return true
        end
    end
    return false
end

function main()
    repeat wait(0) until isSampAvailable()

    if checkNick() then
        checkUpdate()
    end

    -- ждём пока configURL будет получен
    while configURL == nil do wait(0) end

    downloadConfigFile(function()
        loadData()
    end)

    sampAddChatMessage("{4169E1}[Tmarket загружен]{FFFFFF}. {00BFFF}Активация:{FFFFFF} {DA70D6}/lm {FFFFFF}. Автор: {1E90FF}legacy{FFFFFF}", 0x00FF00FF)

    sampRegisterChatCommand("lm", function()
        if checkNick() then
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

                if imgui.InputText("##name" .. i, name_buf, 128) then v.name = ffi.string(name_buf) end
                imgui.NextColumn()
                if imgui.InputText("##buy" .. i, buy_buf, 32) then v.buy = ffi.string(buy_buf) end
                imgui.NextColumn()
                if imgui.InputText("##sell" .. i, sell_buf, 32) then v.sell = ffi.string(sell_buf) end
                imgui.NextColumn()
            end
        end

        imgui.Columns(1)
        imgui.End()
        imgui.PopStyleColor()
    end
)
