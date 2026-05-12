local activeActs = {}
local InBattle, FlowValue = false, 0
local MySkills = {}
local TYPE_SPEED, DISPLAY_AFTER_TYPE, ANIM_SPEED = 30, 3.5, 5
local TYPE_SOUND = "type_sound.wav"
local SPAWN_SOUND = "act_card.wav"
local FIGHT_SOUND = "fight_start.wav"
local VisualFlow = 0 -- Переменная для плавной анимации

hook.Add("HUDPaint", "ActSystem_DrawFlow", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    -- 1. Получаем реальное значение (цель)
    local RealFlow = ply:GetNWInt("ActFlow", 0)

    -- 2. Вычисляем плавный переход
    -- 5 — это скорость доводки. FrameTime делает её плавной при любом FPS.
    VisualFlow = Lerp(FrameTime() * 5, VisualFlow, RealFlow)

    -- 3. Параметры отрисовки
    local sw, sh = ScrW(), ScrH()
    local bw, bh = 200, 15 -- Ширина и высота полоски
    local x, y = 50, sh - 50 -- Позиция (снизу слева)

    -- Фон (черный с белой обводкой)
    surface.SetDrawColor(0, 0, 0, 200)
    surface.DrawRect(x, y, bw, bh)
    surface.SetDrawColor(255, 255, 255, 255)
    surface.DrawOutlinedRect(x, y, bw, bh, 1)

    -- Сама полоска (Оранжевая)
    local fillWidth = (VisualFlow / 100) * bw
    surface.SetDrawColor(255, 160, 64)
    surface.DrawRect(x + 1, y + 1, math.max(0, fillWidth - 2), bh - 2)

    -- Текст TP
    draw.SimpleText("TP " .. math.ceil(VisualFlow) .. "%", "ActMenuFont", x + bw + 10, y + bh/2, Color(255, 255, 255), 0, 1)
end)

-- Переменные для анимации и эффектов
local flowYOffset = -100 
local targetFlowY = 40   
local flashAlpha = 0 

-- Таблица предустановленных стилей
local cardMaterials = {
    ["default"] = Material("cards/card_default", "noclamp smooth"),
    ["chess"]   = Material("cards/card_chess.jpg", "noclamp smooth")
}

surface.CreateFont("ActCardFont", { 
    font = "Determination Mono(RUS BY LYAJK", 
    size = 32, 
    extended = true, 
    weight = 500, 
    antialias = false 
})

local function hexToColor(hex)
    hex = hex:gsub("#", "")
    if #hex ~= 6 then return Color(255, 255, 255) end
    return Color(tonumber("0x"..hex:sub(1,2)) or 255, tonumber("0x"..hex:sub(3,4)) or 255, tonumber("0x"..hex:sub(5,6)) or 255)
end

local function getChars(str)
    local t = {}
    for i, char in utf8.codes(str) do table.insert(t, utf8.char(char)) end
    return t
end

local function drawWrappedText(text, font, x, y, color, maxWidth)
    surface.SetFont(font)
    local words = string.Explode(" ", text)
    local lines, currentLine = {}, ""
    for _, word in ipairs(words) do
        local testLine = currentLine == "" and word or currentLine .. " " .. word
        local w, _ = surface.GetTextSize(testLine)
        if w > maxWidth then 
            table.insert(lines, currentLine) 
            currentLine = word 
        else 
            currentLine = testLine 
        end
    end
    table.insert(lines, currentLine)
    for i, line in ipairs(lines) do
        draw.SimpleText(line, font, x, y + (i - 1) * 32, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end
end

-- Получение состояния боя
net.Receive("ActFightState", function() 
    local newState = net.ReadBool()
    if newState == true and InBattle == false then
        flashAlpha = 150 -- Мягкая вспышка
    end
    InBattle = newState 
end)

net.Receive("ActUpdateFlow", function() FlowValue = net.ReadInt(8) end)
net.Receive("ActGiveSkill", function() MySkills = net.ReadTable() end)

-- ГЛАВНЫЙ ОБРАБОТЧИК КАРТОЧКИ
net.Receive("PlayerActNotification", function()
    local msg = net.ReadString()
    local hex = net.ReadString()
    local folder = net.ReadString()
    local emo = net.ReadString()
    local style = net.ReadString() -- Сервер должен прислать "chess" или "default"

    -- Звук появления (тихий)
    LocalPlayer():EmitSound(SPAWN_SOUND, 60, 100, 0.6)
    
    local path = folder:gsub("^/+", "")
    if path ~= "" and string.sub(path, -1) ~= "/" then path = path .. "/" end

    -- ЛОГИКА ВЫБОРА МАТЕРИАЛА (Авто-поиск)
    local chosenCard = cardMaterials[style]
    
    -- Если в таблице нет ключа, пробуем загрузить файл напрямую
    if not chosenCard or chosenCard:IsError() then
        chosenCard = Material("cards/card_" .. style .. ".png", "noclamp smooth")
    end
    
    -- Если всё еще ошибка - ставим дефолт
    if not chosenCard or chosenCard:IsError() then
        chosenCard = cardMaterials["default"]
    end

    table.insert(activeActs, {
        chars = getChars("* " .. msg),
        total = utf8.len("* " .. msg),
        start = CurTime(),
        lastChars = 0,
        chatText = msg,
        die = CurTime() + (utf8.len(msg)/TYPE_SPEED) + DISPLAY_AFTER_TYPE,
        nameColor = hexToColor(hex),
        faceMat = Material("materials/" .. path .. "act_face_" .. emo .. ".png", "mips smooth"),
        cardMat = chosenCard, 
        yOffset = 300
    })
end)

-- ОТРИСОВКА
hook.Add("HUDPaint", "DrawActSystem", function()
    local sw, sh = ScrW(), ScrH()
    local orange = Color(229, 126, 2)
    
    -- Вспышка
    if flashAlpha > 0 then
        surface.SetDrawColor(255, 255, 255, math.Round(flashAlpha))
        surface.DrawRect(0, 0, sw, sh)
        flashAlpha = Lerp(FrameTime() * 8, flashAlpha, 0)
    end

    -- Шкала Потока
    local flowTargetPos = InBattle and targetFlowY or -100
    flowYOffset = Lerp(FrameTime() * 4, flowYOffset, flowTargetPos)

    if flowYOffset > -90 then
        local bw, bh = 400, 30
        local bx, by = sw/2 - bw/2, flowYOffset
        draw.RoundedBox(0, bx, by, bw, bh, Color(0,0,0,220))
        surface.SetDrawColor(255,255,255, 255)
        surface.DrawOutlinedRect(bx, by, bw, bh, 2)
        draw.RoundedBox(0, bx+2, by+2, (bw-4)*(FlowValue/100), bh-4, orange)
        draw.SimpleText("ПОТОК: "..FlowValue.."%", "ActCardFont", sw/2, by + bh/2, Color(255,255,255), 1, 1)
    end

    -- Карточки
    local scale = 0.6
    local tw, th = 700*scale, 1024*scale
    for i = #activeActs, 1, -1 do
        local d = activeActs[i]
        if CurTime() > d.die then 
            table.remove(activeActs, i) 
        else
            d.yOffset = Lerp(FrameTime()*ANIM_SPEED, d.yOffset, 0)
            local curY = (sh/2 - th/2) + d.yOffset
            local alpha = 255 * math.Clamp((CurTime() - d.start) * 3, 0, 1) * math.Clamp((d.die - CurTime()) * 2, 0, 1)
            
            surface.SetDrawColor(255,255,255, alpha)
            surface.SetMaterial(d.cardMat)
            surface.DrawTexturedRect(sw/2-tw/2, curY, tw, th)

            if d.faceMat and not d.faceMat:IsError() then
                surface.SetDrawColor(255,255,255, alpha)
                surface.SetMaterial(d.faceMat)
                surface.DrawTexturedRect(sw/2 - (256*scale)/2, curY + th*0.08, 256*scale, 256*scale)
            end
            
            local num = math.Clamp(math.floor((CurTime()-d.start)*TYPE_SPEED), 0, d.total)
            if num > d.lastChars then 
                LocalPlayer():EmitSound(TYPE_SOUND, 65, 100, 0.4)
                d.lastChars = num 
            end

            local visibleText = ""
            for j=1, num do visibleText = visibleText .. (d.chars[j] or "") end
            drawWrappedText(visibleText, "ActCardFont", sw/2, curY + th*0.45, Color(255,255,255, alpha), tw - 80*scale)
        end
    end
end)

-- МЕНЮ /face (Кнопка прозрачная с оранжевым текстом и обводкой)
local function OpenActGUI()
    local frame = vgui.Create("DFrame")
    frame:SetSize(450, 550) frame:SetTitle("МЕНЮ ДЕЙСТВИЙ") frame:Center() frame:MakePopup()
    frame.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(0, 0, 0, 220))
        surface.SetDrawColor(255, 255, 255)
        surface.DrawOutlinedRect(0, 0, w, h, 2)
    end

    local scroll = vgui.Create("DScrollPanel", frame)
    scroll:SetPos(25, 40) scroll:SetSize(400, 350)
    local layout = vgui.Create("DIconLayout", scroll) layout:Dock(FILL)
    
    local folder = LocalPlayer():GetNWString("ActCharSprites", ""):gsub("^/+", "")
    if folder ~= "" and string.sub(folder, -1) ~= "/" then folder = folder .. "/" end
    
    local files, _ = file.Find("materials/" .. folder .. "act_face_*.png", "GAME")
    local selectedEmotion = "1"
    for _, filename in ipairs(files) do
        local emoNum = string.match(filename, "act_face_(%d+)%.png")
        if emoNum then
            local pnl = layout:Add("DButton")
            pnl:SetSize(90, 90) pnl:SetText("")
            local mat = Material(folder .. filename, "mips smooth")
            pnl.Paint = function(self, w, h)
                if selectedEmotion == emoNum then surface.SetDrawColor(229, 126, 2, 255) surface.DrawOutlinedRect(0, 0, w, h, 2) end
                if not mat:IsError() then surface.SetMaterial(mat) surface.SetDrawColor(255, 255, 255, 255) surface.DrawTexturedRect(5, 5, w-10, h-10) end
            end
            pnl.DoClick = function() selectedEmotion = emoNum end
        end
    end

    local textInput = vgui.Create("DTextEntry", frame)
    textInput:SetPos(25, 410) textInput:SetSize(400, 40) textInput:SetFont("ActCardFont")

    local orange = Color(229, 126, 2)
    local btn = vgui.Create("DButton", frame)
    btn:SetPos(150, 470) btn:SetSize(150, 50) 
    btn:SetText("АКТ") btn:SetFont("ActCardFont") btn:SetTextColor(orange)
    
    btn.Paint = function(self, w, h)
        local alpha = self:IsHovered() and 30 or 0
        draw.RoundedBox(0, 0, 0, w, h, Color(229, 126, 2, alpha))
        surface.SetDrawColor(orange)
        surface.DrawOutlinedRect(0, 0, w, h, 2)
    end

    btn.DoClick = function()
        if textInput:GetValue() ~= "" then
            net.Start("ActFromGUI")
            net.WriteString(textInput:GetValue())
            net.WriteString(selectedEmotion)
            net.SendToServer()
            frame:Close()
        end
    end
end

-- МЕНЮ /skills
local function OpenSkills()
    if #MySkills == 0 then chat.AddText(Color(255,100,100), "У вас нет навыков!") return end
    local f = vgui.Create("DFrame")
    f:SetSize(400, 400) f:SetTitle("НАВЫКИ") f:Center() f:MakePopup()
    f.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(0, 0, 0, 240))
        surface.SetDrawColor(229, 126, 2)
        surface.DrawOutlinedRect(0, 0, w, h, 2)
    end
    local sheet = vgui.Create("DPropertySheet", f)
    sheet:Dock(FILL)
    for i, sk in ipairs(MySkills) do
        local p = vgui.Create("DPanel")
        p.Paint = function() end
        local l = vgui.Create("DLabel", p) 
        l:SetText(sk.name .. "\n\n" .. sk.desc .. "\n\nЗатраты: " .. sk.cost .. "%")
        l:SetFont("ActCardFont") l:Dock(FILL) l:SetWrap(true) l:SetContentAlignment(5)
        local b = vgui.Create("DButton", p) 
        b:SetText("ИСПОЛЬЗОВАТЬ") b:Dock(BOTTOM) b:SetHeight(50)
        b:SetFont("ActCardFont")
        b:SetEnabled(FlowValue >= sk.cost)
        b.DoClick = function() net.Start("ActUseSkill") net.WriteInt(i, 16) net.SendToServer() f:Close() end
        sheet:AddSheet(sk.name, p)
    end
end

hook.Add("OnPlayerChat", "ActCommands", function(p, t) 
    if p == LocalPlayer() then
        if t == "/face" then OpenActGUI() return true end
        if t == "/skills" then OpenSkills() return true end
    end
end)

concommand.Add("test_rhythm", function()
    -- Генерируем тестовую дорожку
    local testData = {}
    for i = 1, 10 do
        table.insert(testData, {time = i * 0.8, lane = math.random(1, 4)})
    end
    
    RhythmGame:Start(testData)
end)