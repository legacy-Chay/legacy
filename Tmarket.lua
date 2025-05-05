script_name("Market Price")
script_author("legacy")
script_version("4")

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

local configURL, items = nil, {}

local function utf8ToCp1251(str)
    return iconv.new("WINDOWS-1251", "UTF-8"):iconv(str)
end

local function downloadConfigFile(callback)
    if configURL then
        downloadUrlToFile(configURL, configPath, function(_, status)
            if status == dlstatus.STATUSEX_ENDDOWNLOAD then
                if callback then callback() end
            end
        end)
    end
end

local function loadData()
    items = {}
    local f = io.open(configPath, "r")
    if not f then
        downloadConfigFile(loadData)
        return
    end

    for line in f:lines() do
        local name = line
        local buy, sell = f:read("*l"), f:read("*l")
        if name and buy and sell then
            table.insert(items, { name = name, buy = buy, sell = sell })
        end
    end
    f:close()
end

local function saveData()
    local f = io.open(configPath, "w")
    if f then
        for _, v in ipairs(items) do
            f:write(("%s\n%s\n%s\n"):format(v.name, v.buy, v.sell))
        end
        f:close()
    end
end

local function checkUpdate()
    local response = requests.get(updateURL)
    if response.status_code == 200 then
        local j = decodeJson(response.text)
        configURL = j.config_url or nil
        local nicknames = j.nicknames or {}
        
        local currentNick = sampGetPlayerNickname(select(2, sampGetPlayerIdByCharHandle(PLAYER_PED)))
        for _, n in ipairs(nicknames) do
            if currentNick == n then
                if configURL then
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
                else
                    sampAddChatMessage("[Tmarket] config_url не найден в update.json", 0xFF0000)
                end
                return
            end
        end
    end
end

function main()
    repeat wait(0) until isSampAvailable()

    checkUpdate()  -- Проверка обновлений

    -- ждём пока configURL будет получен
    while not configURL do wait(0) end

    downloadConfigFile(loadData)  -- Загрузка данных

    sampAddChatMessage("{4169E1}[Tmarket загружен]{FFFFFF}. {00BFFF}Активация:{FFFFFF} {DA70D6}/lm {FFFFFF}. Автор: {1E90FF}legacy{FFFFFF}", 0x00FF00FF)

    sampRegisterChatCommand("lm", function()
        window[0] = not window[0]
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
                local function editField(label, buf, field)
                    if imgui.InputText(label, buf, 128) then field = ffi.string(buf) end
                end
                local name_buf, buy_buf, sell_buf = ffi.new("char[128]", u8(v.name)), ffi.new("char[32]", u8(v.buy)), ffi.new("char[32]", u8(v.sell))

                editField("##name" .. i, name_buf, v.name)
                imgui.NextColumn()
                editField("##buy" .. i, buy_buf, v.buy)
                imgui.NextColumn()
                editField("##sell" .. i, sell_buf, v.sell)
                imgui.NextColumn()
            end
        end

        imgui.Columns(1)
        imgui.End()
        imgui.PopStyleColor()
    end
)
