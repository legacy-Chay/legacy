local ffi = require('ffi')
local encoding = require('encoding')
encoding.default = 'CP1251'
u8 = encoding.UTF8
local samp = require('samp.events')
local imgui = require('mimgui')
local requests = require('requests')

local window = imgui.new.bool(false)
local search_text = ffi.new("char[128]", "")

local categories = {
    {name = "Товар", data = {}},
    {name = "Скупка", data = {}},
    {name = "Продажа", data = {}}
}

local iniFilePath = getWorkingDirectory() .. "\\config\\market_price.ini"
local script_version = "2"

-- Функция для скачивания файла
local function downloadFile(url, path)
    local response = requests.get(url)
    if response.status_code == 200 then
        local file = io.open(path, "wb")
        file:write(response.text)
        file:close()
        sampAddChatMessage("Обновление завершено!", 0x4169E1FF)
    else
        sampAddChatMessage("Не удалось скачать обновление.", 0xFF0000FF)
    end
end

-- Функция для проверки обновлений и скачивания нового скрипта
local function checkForUpdatesAndDownload()
    local url = 'https://raw.githubusercontent.com/legacy-Chay/legacy/refs/heads/main/update.json'  -- Ссылка на файл обновлений
    local response = requests.get(url)
    if response.status_code == 200 then
        local data = decodeJson(response.text)
        local latest_version = data['last']  -- Получаем последнюю версию из update.json
        local update_url = data['url']  -- Получаем URL для скачивания нового скрипта

        if latest_version ~= script_version then
            sampAddChatMessage("Доступно обновление! Текущая версия: " .. script_version .. ", новая версия: " .. latest_version, 0xFF0000FF)
            -- Скачиваем новый файл с указанного URL
            downloadFile(update_url, getWorkingDirectory() .. "\\market_price.lua")
        else
            sampAddChatMessage("Версия актуальна: " .. script_version, 0x4169E1FF)
        end
    else
        sampAddChatMessage("Не удалось получить информацию о версии.", 0xFF0000FF)
    end
end

-- Функция для загрузки данных из файла конфигурации
local function loadCategoryData()
    local file = io.open(iniFilePath, "r")
    if file then
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
    else
        sampAddChatMessage("Ошибка при загрузке конфигурации.", 0xFF0000FF)
    end
end

-- Функция для сохранения данных
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

-- Главная функция скрипта
function main()
    if not isSampfuncsLoaded() or not isSampLoaded() then return end
    while not isSampAvailable() do wait(100) end
    sampAddChatMessage("Market Price Загружен! Открыть меню: /lm", 0x4169E1FF)
    loadCategoryData()

    -- Проверка на обновление при старте
    checkForUpdatesAndDownload()
end

sampRegisterChatCommand('lm', function() window[0] = not window[0] end)

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
