script_author('legacy.')
local samp = require('samp.events')
local imgui = require('mimgui')
local encoding = require('encoding')
encoding.default = 'CP1251'
u8 = encoding.UTF8

local renderWindow = imgui.new.bool(false)
local g = {
    items = { ORDERED_LIST = {} },  -- Список товаров с порядком
    market = {
        CLEAR = 0, SLOTS = {}, CURRENT_CHECK = 0, RANGE_CHECK = 0, SHOP_OPEN = false, NEXT_PAGE_ID = 0
    }
}

function main()
    while not isSampAvailable() do wait(0) end
    sampAddChatMessage('{6F7BD0}Legacy scripts загружен {AD2FF7}Активация {FFFFFF} /legacy.', -1)
    sampRegisterChatCommand('legacy', function()
        renderWindow[0] = not renderWindow[0]
    end)
    wait(-1)
end

imgui.OnInitialize(function()
    imgui.GetIO().IniFilename = nil
end)

imgui.OnFrame(
    function() return renderWindow[0] end,
    function()
        local resX, resY = getScreenResolution()
        local sizeX, sizeY = 300, 500
        imgui.SetNextWindowPos(imgui.ImVec2(resX / 2, resY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(sizeX, sizeY), imgui.Cond.FirstUseEver)
        imgui.Begin('Seller', renderWindow)

            if imgui.Button(u8('Сканировать'), imgui.ImVec2(-1)) then
                if not g.market.SHOP_OPEN then return sms('Откройте меню продажи в лавке!') end
                sms('Начали сканирование!')
                g.market.CURRENT_CHECK = 0
                clickNextItem()
            end

            if imgui.Button(u8('Скопировать список'), imgui.ImVec2(-1)) then
                local data = {}
                for _, item in ipairs(g.items.ORDERED_LIST) do
                    local countText = item.amount > 1 and ('\nКоличество: ' .. item.amount) or ''
                    table.insert(data, item.name .. countText)
                end
                setClipboardText(table.concat(data, '\n\n'))
                sms('Список товаров скопирован в буфер.')
            end    

            if imgui.Button(u8('Очистить список'), imgui.ImVec2(-1)) then
                g.items.ORDERED_LIST = {}
            end

            imgui.Separator()

            for _, item in ipairs(g.items.ORDERED_LIST) do
                imgui.Text(u8(item.name))
                if item.amount > 1 then
                    imgui.Text(u8('Количество: ' .. item.amount))
                end
            end

        imgui.End()
    end
)

-- Добавляем товар в список, учитывая количество
function addItemToList(item)
    for _, v in ipairs(g.items.ORDERED_LIST) do
        if v.name == item.name then
            v.amount = v.amount + item.amount
            return
        end
    end
    table.insert(g.items.ORDERED_LIST, item)
end

function samp.onServerMessage(_, text)
    if g.market.CURRENT_CHECK > 0 and text == '[Ошибка] {ffffff}Здесь пусто' then
        clickNextItem()
        return false
    end
end

function samp.onShowDialog(id, _, title, _, _, text)
    if g.market.CURRENT_CHECK > 0 and title == '{BFBBBA}Снятие с продажи' then
        local data = getDataCentralMarketDialog(text)
        -- Товар уже добавляется внутри getDataCentralMarketDialog
        sampSendDialogResponse(id, 0)
        clickNextItem()
        return false
    end
end

function samp.onShowTextDraw(id, data)
    if data.boxColor == -15066598 and data.text == 'usebox' and data.color == -1 and data.style == 0 and data.backgroundColor == -16777216 and data.flags == 19 then
        g.market.RANGE_CHECK = data.position.x
    end
    if data.text == 'ON_SALE' or data.text == 'HA_ЊPOѓA„E' then g.market.SHOP_OPEN = true end
    if #g.market.SLOTS > 0 and g.market.CLEAR == id then g.market.SLOTS = {}; g.market.CLEAR = 0 end
    if data.text == 'LD_SPAC:white' and data.flags == 18 and data.color == 0 and data.position.x < g.market.RANGE_CHECK and g.market.SHOP_OPEN then
        if g.market.CLEAR == 0 then g.market.CLEAR = id end
        if data.letterColor == -1 then table.insert(g.market.SLOTS, id) end
    end
    -- кнопка "Далее"
    if math.abs(data.position.x - 264.12396240234) < 0.0001 and math.abs(data.position.y - 357.74285888672) < 0.0001 then
        g.market.NEXT_PAGE_ID = id
    end
end

function samp.onSendClickTextDraw(id)
    if id == 65535 then
        g.market.SLOTS = {}
        g.market.SHOP_OPEN = false
        g.market.CLEAR = 0
    end
end

function clickNextItem()
    g.market.CURRENT_CHECK = g.market.CURRENT_CHECK + 1
    if g.market.CURRENT_CHECK > #g.market.SLOTS then
        if g.market.NEXT_PAGE_ID > 0 then
            sampSendClickTextdraw(g.market.NEXT_PAGE_ID)
            sms('Переключаемся на следующую страницу...')
            g.market.CURRENT_CHECK = 0
            g.market.SLOTS = {}
            g.market.NEXT_PAGE_ID = 0

            lua_thread.create(function()
                wait(1000)
                while #g.market.SLOTS == 0 do wait(100) end
                sms('Новая страница загружена. Продолжаем сканирование.')
                clickNextItem()
            end)
        else
            g.market.CURRENT_CHECK = 0
            sms('Сканирование завершено.')
        end
        return
    end
    sampSendClickTextdraw(g.market.SLOTS[g.market.CURRENT_CHECK])
end

function getDataCentralMarketDialog(text)
    local data = {}
    local name = text:match('^(.-)\n')
    name = (name:match('^%{[0-9a-fA-F]*%}$') and text:match('^.-\n(.-)\n') or name)
    name = tostring(name:match('{......}.-%s*{......}(.-)%s*{......}') or name:match('{......}(.+){......}')):gsub(' %(объект%)$', '')

    local patch = {text:match('{FE9A2E}Встроена нашивка {ffffff}(%d+%-го) {FE9A2E}уровня {ffffff}%(%+%d+ к (%S+)%){FE9A2E}%.')}
    local upgrade = text:match('Улучшение: {FFC300}(%d+/%d+)')
    local property = text:match('У данного аксессуара применены характеристики с предмета (".-")\n')

    local amount = tonumber(text:match('В наличии:%s*(%d+)%s*шт')) or 1
    local price = string_to_count(text:match('\nСтоимость:%s*(.-)%s*за %d+ шт%.')) or 0

    if upgrade then table.insert(data, upgrade) end
    if #patch == 2 then table.insert(data, 'Нашивка ' .. patch[1] .. ' уровня к ' .. patch[2]) end
    if property then table.insert(data, 'Характеристика ' .. property) end

    local item = {
        name = ('- %s%s\nЦена: %s'):format(name, #data > 0 and ' [' .. table.concat(data, ' | ') .. ']' or '', money_separator(price)),
        amount = amount
    }

    addItemToList(item)

    return item
end

function string_to_count(text)
    local count = ''
    for d in tostring(text):gmatch('%d') do count = count .. d end
    return tonumber(count)
end

function money_separator(n)
    local left,num,right = string.match(n,'^([^%d]*%d)(%d*)(.-)$')
    return '$' .. left..(num:reverse():gsub('(%d%d%d)','%1.'):reverse())..right
end

function sms(text)
    sampAddChatMessage(text, -1)
end
