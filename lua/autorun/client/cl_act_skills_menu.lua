-- Создание шрифта (убедись, что файл шрифта установлен в системе или контенте сервера)
surface.CreateFont("ActMenuFont", {
    font = "Determination Mono(RUS BY LYAJK", -- Убедись, что это имя в окне шрифта Windows
    size = 24, 
    weight = 500, 
    extended = true, -- ОБЯЗАТЕЛЬНО для поддержки кириллицы
    antialias = true,
})

net.Receive("ActOpenSkillsMenu", function()
    local skills = util.JSONToTable(LocalPlayer():GetNWString("ActSkills", "[]")) or {}

    local frame = vgui.Create("DFrame")
    frame:SetSize(450, 550)
    frame:SetTitle("")
    frame:Center()
    frame:MakePopup()
    frame.Paint = function(s, w, h)
        surface.SetDrawColor(0, 0, 0, 250)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(255, 255, 255)
        surface.DrawOutlinedRect(0, 0, w, h, 2)
        -- Заголовок меню
        draw.SimpleText("ВЫБОР НАВЫКА", "ActMenuFont", w/2, 25, Color(255, 255, 255), 1, 1)
    end

    local list = vgui.Create("DScrollPanel", frame)
    list:Dock(FILL)
    list:DockMargin(15, 45, 15, 15)

    -- Панель деталей (развернутый скилл)
    local detailView = vgui.Create("DPanel", frame)
    detailView:SetSize(frame:GetWide() - 20, frame:GetTall() - 60)
    detailView:SetPos(10, 50)
    detailView:SetVisible(false)
    detailView.Paint = function(s, w, h)
        surface.SetDrawColor(0, 0, 0, 255)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(255, 255, 255)
        surface.DrawOutlinedRect(0, 0, w, h, 2)
    end

    local function OpenDetail(id, data)
        detailView:SetVisible(true)
        detailView:Clear()

        local name = data.name or id
        local desc = data.desc or "Описание отсутствует."
        local cost = data.cost or "0"

        -- Название скилла в деталях
        local title = vgui.Create("DLabel", detailView)
        title:SetText(string.upper(name))
        title:SetFont("ActMenuFont")
        title:SetTextColor(Color(255, 255, 0))
        title:Dock(TOP)
        title:SetContentAlignment(5)
        title:DockMargin(0, 20, 0, 10)

        -- Описание и стоимость
        local content = vgui.Create("DLabel", detailView)
        content:SetText("СТОИМОСТЬ: " .. cost .. "% TP\n\n" .. desc)
        content:SetFont("ActMenuFont") -- ПРИМЕНЕНИЕ ШРИФТА
        content:SetWrap(true)
        content:SetAutoStretchVertical(true)
        content:Dock(TOP)
        content:DockMargin(25, 10, 25, 10)
        content:SetTextColor(Color(255, 255, 255))

        -- Кнопка Каст
        local btnCast = vgui.Create("DButton", detailView)
        btnCast:SetText("КАСТОВАТЬ")
        btnCast:SetFont("ActMenuFont") -- ПРИМЕНЕНИЕ ШРИФТА
        btnCast:SetSize(160, 45)
        btnCast:SetPos(detailView:GetWide()/2 - 80, detailView:GetTall() - 110)
        btnCast.Paint = function(s, w, h)
            local col = s:IsHovered() and Color(255, 165, 0) or Color(255, 255, 255)
            surface.SetDrawColor(col)
            surface.DrawOutlinedRect(0, 0, w, h, 2)
            s:SetTextColor(col)
        end
        btnCast.DoClick = function()
            net.Start("ActCastSkill")
                net.WriteString(name)
                net.WriteString(cost)
            net.SendToServer()
            frame:Close()
        end

        -- Кнопка Назад
        local btnBack = vgui.Create("DButton", detailView)
        btnBack:SetText("[ НАЗАД ]")
        btnBack:SetFont("ActMenuFont") -- ПРИМЕНЕНИЕ ШРИФТА
        btnBack:SetSize(120, 30)
        btnBack:SetPos(detailView:GetWide()/2 - 60, detailView:GetTall() - 50)
        btnBack:SetTextColor(Color(200, 200, 200))
        btnBack.Paint = nil
        btnBack.DoClick = function() detailView:SetVisible(false) end
    end

    -- Заполнение списка кнопками скиллов
    for id, data in pairs(skills) do
        local btn = list:Add("DButton")
        btn:SetText("  * " .. (data.name or id))
        btn:SetFont("ActMenuFont") -- ПРИМЕНЕНИЕ ШРИФТА
        btn:SetTextColor(Color(255, 255, 255))
        btn:Dock(TOP)
        btn:SetTall(45)
        btn:DockMargin(0, 0, 0, 8)
        btn:SetContentAlignment(4)
        
        btn.Paint = function(s, w, h)
            if s:IsHovered() then
                surface.SetDrawColor(255, 255, 255, 40)
                surface.DrawRect(0, 0, w, h)
                s:SetTextColor(Color(255, 255, 0))
            else
                s:SetTextColor(Color(255, 255, 255))
            end
        end
        btn.DoClick = function() OpenDetail(id, data) end
    end
end)

-- Обработка цветного чата
-- Обработка цветного чата
net.Receive("ActBroadcastCast", function()
    local name = net.ReadString()
    local col = net.ReadColor()
    local skill = net.ReadString()
    local cost = net.ReadString()

    -- Цвета для оформления
    local white = Color(255, 255, 255)
    local orange = Color(255, 160, 64) -- Тот самый оранжевый

    -- Вывод: [Имя] (цвет HEX) кастует "[Скилл]" (цвет HEX) за [N]% потока! (оранжевый)
    chat.AddText(
        col, name, 
        white, " кастует \"", 
        col, skill, 
        white, "\" за ", 
        orange, cost .. "% потока!"
    )
end)