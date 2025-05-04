local ffi = require('ffi')
local encoding = require('encoding')
encoding.default = 'CP1251'
u8 = encoding.UTF8
local samp = require('samp.events')
local imgui = require('mimgui')

local window = imgui.new.bool(false)
local search_text = ffi.new("char[128]", "")

local categories = {
    {name = "Товар", data = {}},
    {name = "Скупка", data = {}},
    {name = "Продажа", data = {}}
}

local iniFilePath = getWorkingDirectory() .. "\\config\\market_price.ini"
local githubFileUrl = "https://github.com/legacy-Chay/legacy/raw/refs/heads/main/market_price.ini"

-- Автообновление
script_version('1')
local dlstatus = require('moonloader').download_status
local requests = require('requests')

local function utf8ToWindows1251(str)
    local iconv = require("iconv")
    local converter = iconv.new("WINDOWS-1251", "UTF-8")
    return converter:iconv(str)
end

local function update()
    local raw = 'https://raw.githubusercontent.com/legacy-user/Ayti/refs/heads/main/update.json'
    local f = {}

    function f:getLastVersion()
        local response = requests.get(raw)
        if response.status_code == 200 then
            return decodeJson(response.text)['last']
        else
            return 'UNKNOWN'
        end
    end

    function f:download()
        local response = requests.get(raw)
        if response.status_code == 200 then
            local url = decodeJson(response.text)['url']
            local filePath = thisScript().path

            downloadUrlToFile(url, filePath, function(id, status)
                if status == dlstatus.STATUSEX_ENDDOWNLOAD then
                    local file = io.open(filePath, "r")
                    if not file then return end
                    local content = file:read("*all")
                    file:close()

                    local convertedContent = utf8ToWindows1251(content)

                    local outputFile = io.open(filePath, "w")
                    outputFile:write(convertedContent)
                    outputFile:close()

                    local lastVersion = decodeJson(response.text)['last']
                    print("Файл загружен, версия " .. lastVersion)

                    thisScript():reload()
                elseif status == dlstatus.STATUSEX_FAILED then
                    print("Ошибка загрузки обновления.")
                end
            end)
        end
    end

    return f
end

-- Загрузка конфигурации
local function loadCategoryData()
    -- Проверка наличия файла
    local file = io.open(iniFilePath, "r")
    if not file then
        -- Если файл не существует, загрузить с GitHub
        print("Файл конфигурации не найден, загружаем с GitHub...")
        local response = requests.get(githubFileUrl)
        if response.status_code == 200 then
            local content = response.text
            local convertedContent = utf8ToWindows1251(content)
            -- Сохранение загруженного файла
            local outputFile = io.open(iniFilePath, "w")
            outputFile:write(convertedContent)
            outputFile:close()
            print("Конфигурация успешно загружена с GitHub.")
        else
            sampAddChatMessage("Ошибка загрузки конфигурации с GitHub.", 0xFF0000FF)
            return
        end
    else
        -- Если файл существует, загружаем данные
        while true do
            local name = file:read("*line")
            if not name or name:gsub("%s+", "") == "" then break end

            local price1 = file:read("*line") or "0"
            local price2 = file:read("*line") or "0"

            table.insert(categories[1].data, {name = name})
            table.insert(categories[2].data, {name = price1})
            table.insert(categories[3].data, {name = price2})
        end
        file:close()
    end
end

-- Сохранение конфигурации
local function saveCategoryData()
    local file = io.open(iniFilePath, "w")
    if file then
        for i = 1, #categories[1].data do
            file:write(categories[1].data[i].name .. "\n")
            file:write(categories[2].data[i].name .. "\n")
            file:write(categories[3].data[i].name .. "\n")
        end
        file:close()
        sampAddChatMessage("Вы сохранили изменения :) ", 0x4169E1FF)
    else
        sampAddChatMessage("Ошибка при сохранении конфигурации.", 0xFF0000FF)
    end
end

-- Основной поток
function main()
    while not isSampAvailable() do wait(100) end

    -- Автообновление
    local lastver = update():getLastVersion()
    if thisScript().version ~= lastver then
        update():download()
        wait(3000)
        return
    end

    sampAddChatMessage("Market Price Загружен! Открыть меню: /lm", 0x4169E1FF)
    loadCategoryData()

    sampRegisterChatCommand('lm', function() window[0] = not window[0] end)

    while true do
        wait(0)
    end
end

-- Интерфейс
imgui.OnFrame(function()
    return window[0] and not isPauseMenuActive() and not sampIsScoreboardOpen()
end, function()
    imgui.SetNextWindowSize(imgui.ImVec2(1000, 600), imgui.Cond.FirstUseEver)
    imgui.PushStyleColor(imgui.Col.WindowBg, imgui.ImVec4(0.1, 0.05, 0.2, 1.0))
    imgui.Begin("Market Price by tema08", window)

    imgui.InputTextWithHint('##search_text', u8('Поиск по таблице товаров'), search_text, ffi.sizeof(search_text))
    local search_query = u8:decode(ffi.string(search_text)):lower()

    imgui.SameLine()
    if imgui.Button(u8("Сохранить изменения")) then
        saveCategoryData()
    end

    imgui.BeginChild("categories_container", imgui.ImVec2(-1, 30), false)

    local box_width = (imgui.GetWindowWidth() - 45) / #categories
    for i, category in ipairs(categories) do
        if i > 1 then imgui.SameLine() end
        imgui.BeginChild('category_' .. i, imgui.ImVec2(box_width, 30), true)
        imgui.SetCursorPosX((box_width - imgui.CalcTextSize(u8(category.name)).x) / 2)
        imgui.SetCursorPosY((30 - imgui.CalcTextSize(u8(category.name)).y) / 2)
        imgui.Text(u8(category.name))
        imgui.EndChild()
    end
    imgui.EndChild()

    local remaining_height = imgui.GetContentRegionAvail().y
    imgui.BeginChild("data_container", imgui.ImVec2(-1, remaining_height), false)
    imgui.Columns(3, "category_columns", false)

    for i = 1, #categories[1].data do
        local item_name = categories[1].data[i].name:lower()
        if search_query == "" or string.find(item_name, search_query, 1, true) then
            local unique_id = tostring(i)

            local new_name = ffi.new("char[128]", u8(categories[1].data[i].name))
            if imgui.InputText("##name_" .. unique_id, new_name, 128) then
                categories[1].data[i].name = ffi.string(new_name)
            end
            imgui.NextColumn()

            local new_price1 = ffi.new("char[128]", u8(categories[2].data[i].name))
            if imgui.InputText("##price1_" .. unique_id, new_price1, 128) then
                categories[2].data[i].name = ffi.string(new_price1)
            end
            imgui.NextColumn()

            local new_price2 = ffi.new("char[128]", u8(categories[3].data[i].name))
            if imgui.InputText("##price2_" .. unique_id, new_price2, 128) then
                categories[3].data[i].name = ffi.string(new_price2)
            end
            imgui.NextColumn()
        end
    end

    imgui.Columns(1)
    imgui.EndChild()
    imgui.End()
    imgui.PopStyleColor()
end)
