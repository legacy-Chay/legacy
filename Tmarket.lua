script_name("Market Price")
script_author("legacy")
script_version("1.1")

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

local function utf8ToCp1251(str)
    return iconv.new("WINDOWS-1251", "UTF-8"):iconv(str)
end

-- Сохранение последней версии
local function saveLastVersion(version)
    local f = io.open(configPath, "r")
    local lines = {}
    if f then
        for line in f:lines() do
            table.insert(lines, line)
        end
        f:close()
    end
    table.insert(lines, "last_version=" .. version)

    f = io.open(configPath, "w")
    if f then
        for _, line in ipairs(lines) do
            f:write(line .. "\n")
        end
        f:close()
    end
end

-- Чтение последней версии из конфигурации
local function getLastVersion()
    local f = io.open(configPath, "r")
    if f then
        for line in f:lines() do
            if line:find("last_version=") then
                return line:sub(14)  -- Извлекаем версию из строки
            end
        end
        f:close()
    end
    return nil
end

local function downloadConfigFile(callback)
    if configURL then
        downloadUrlToFile(configURL, configPath, function(_, status)
            if status == dlstatus.STATUSEX_ENDDOWNLOAD and callback then
                -- Преобразуем файл в кодировку Windows-1251
                local f = io.open(configPath, "r")
                if f then
                    local content = f:read("*a")
                    f:close()

                    -- Конвертируем из UTF-8 в Windows-1251
                    local convertedContent = utf8ToCp1251(content)

                    -- Перезаписываем файл в Windows-1251
                    f = io.open(configPath, "w")
                    f:write(convertedContent)
                    f:close()
                end

                callback()
            end
        end)
    end
end

local function loadData()
    -- Проверяем версию
    local lastVersion = getLastVersion()
    if not lastVersion or lastVersion ~= thisScript().version then
        -- Если версия не совпадает, скачиваем обновление
        checkForUpdate()
    end

    -- Загружаем данные только если файл конфигурации существует
    if not fileExists(configPath) then
        downloadConfigFile(loadData)
    else
        items = {}
        local f = io.open(configPath, "r")
        if f then
            for line in f:lines() do
                local name = line
                local buy, sell = f:read("*l"), f:read("*l")
                if name and buy and sell then
                    table.insert(items, { name = name, buy = buy, sell = sell })
                end
            end
            f:close()
        end
    end
end

local function checkNick(nick)
    local response = requests.get(updateURL)
    if response.status_code == 200 then
        local j = decodeJson(response.text)
        configURL = j.config_url or nil

        -- Если URL обновления есть и версия на сервере отличается от текущей
        if configURL and j.last and thisScript().version ~= j.last then
            -- Скачиваем файл
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

                    -- Сохраняем новую версию
                    saveLastVersion(j.last)
                end
            end)
        end
    end
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
