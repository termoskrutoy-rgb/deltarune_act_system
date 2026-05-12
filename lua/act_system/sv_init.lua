util.AddNetworkString("PlayerActNotification")
util.AddNetworkString("ActRemoteSetChar")
util.AddNetworkString("ActFromGUI")
util.AddNetworkString("ActChangeGlobalStyle")
util.AddNetworkString("ActFightState")
util.AddNetworkString("ActUpdateFlow")
util.AddNetworkString("ActGiveSkill")
util.AddNetworkString("ActUseSkill")

local GlobalActStyle = "default"
local NextActTime = 0
local InFight = false
local CurrentFlow = 0

-- Расчет кулдауна для очереди
local function CalculateCooldown(text)
    return (#text / 30) + 3.5 + 2
end

-- Глобальные команды
hook.Add("PlayerSay", "ActGlobalCommands", function(ply, text)
    if not ply:IsAdmin() then return end

    -- Начало/Конец боя
    if text == "/fight" then
        InFight = not InFight
        
        -- Синхронизируем состояние боя
        net.Start("ActFightState")
            net.WriteBool(InFight)
        net.Broadcast()

        -- Если бой начался, запускаем звук всем игрокам
        if InFight then
            for _, p in ipairs(player.GetAll()) do
                p:SendLua([[surface.PlaySound("fight_start.wav")]])
            end
        end
        
        return ""
    end

    -- Установка Flow
    if string.sub(text, 1, 6) == "/flow " then
        local val = tonumber(string.sub(text, 7))
        if val then
            CurrentFlow = math.Clamp(val, 0, 100)
            net.Start("ActUpdateFlow")
                net.WriteInt(CurrentFlow, 8)
            net.Broadcast()
        end
        return ""
    end
end)

-- Команда /act (текстовая)
hook.Add("PlayerSay", "ActCommandSystem", function(ply, text)
    if string.sub(text, 1, 5) == "/act " then
        if CurTime() < NextActTime then 
            ply:ChatPrint("Система занята! Подождите немного.") 
            return "" 
        end
        
        local action = string.sub(text, 6)
        NextActTime = CurTime() + CalculateCooldown(action)
        
        net.Start("PlayerActNotification")
            net.WriteString(ply:GetNWString("ActCharName", ply:Nick()) .. " " .. action)
            net.WriteString(ply:GetNWString("ActCharColor", "ffffff"))
            net.WriteString(ply:GetNWString("ActCharSprites", "vgui/white"))
            net.WriteString("1") 
            net.WriteString(GlobalActStyle) -- Передаем текущий стиль (chess или default)
        net.Broadcast()
        
        return ""
    end
end)

-- Выдача скилла через Тулган
net.Receive("ActGiveSkill", function(len, ply)
    if not ply:IsAdmin() then return end
    local target = net.ReadEntity()
    local skillData = net.ReadTable()

    if IsValid(target) and target:IsPlayer() then
        target.PersonalSkills = target.PersonalSkills or {}
        table.insert(target.PersonalSkills, skillData)
        
        net.Start("ActGiveSkill")
            net.WriteTable(target.PersonalSkills)
        net.Send(target)
        
        ply:ChatPrint("Навык '" .. skillData.name .. "' выдан игроку " .. target:Nick())
    end
end)

-- Использование скилла
net.Receive("ActUseSkill", function(len, ply)
    local id = net.ReadInt(16)
    local skills = ply.PersonalSkills or {}
    local skill = skills[id]

    if skill and CurrentFlow >= skill.cost then
        CurrentFlow = CurrentFlow - skill.cost
        
        -- Обновляем шкалу у всех
        net.Start("ActUpdateFlow") 
            net.WriteInt(CurrentFlow, 8) 
        net.Broadcast()
        
        -- Показываем карточку использования
        net.Start("PlayerActNotification")
            net.WriteString(ply:GetNWString("ActCharName", ply:Nick()) .. " использует " .. skill.name .. "!")
            net.WriteString(ply:GetNWString("ActCharColor", "ffffff"))
            net.WriteString(ply:GetNWString("ActCharSprites", "vgui/white"))
            net.WriteString("1")
            net.WriteString(GlobalActStyle)
        net.Broadcast()
    else
        ply:ChatPrint("Недостаточно Flow или навык не найден!")
    end
end)

-- Логика из GUI меню (/face)
net.Receive("ActFromGUI", function(len, ply)
    if CurTime() < NextActTime then 
        ply:ChatPrint("Система занята!")
        return 
    end
    
    local action, emotion = net.ReadString(), net.ReadString()
    NextActTime = CurTime() + CalculateCooldown(action)
    
    net.Start("PlayerActNotification")
        net.WriteString(ply:GetNWString("ActCharName", ply:Nick()) .. " " .. action)
        net.WriteString(ply:GetNWString("ActCharColor", "ffffff"))
        net.WriteString(ply:GetNWString("ActCharSprites", "vgui/white"))
        net.WriteString(emotion)
        net.WriteString(GlobalActStyle)
    net.Broadcast()
end)

-- Установка персонажа админом
net.Receive("ActRemoteSetChar", function(len, ply)
    if not ply:IsAdmin() then return end
    local target = net.ReadEntity()
    if IsValid(target) then
        target:SetNWString("ActCharName", net.ReadString())
        target:SetNWString("ActCharColor", net.ReadString())
        target:SetNWString("ActCharSprites", net.ReadString())
        ply:ChatPrint("Данные персонажа для " .. target:Nick() .. " обновлены.")
    end
end)

-- Смена глобального стиля (из Тулгана)
net.Receive("ActChangeGlobalStyle", function(len, ply)
    if not ply:IsAdmin() then return end
    
    local newStyle = net.ReadString()
    GlobalActStyle = newStyle
    
    PrintMessage(HUD_PRINTTALK, "[ACT] Стиль интерфейса изменен на: " .. newStyle)
end)

-- Команда для админа, чтобы запустить ритм-игру игроку
hook.Add("PlayerSay", "StartRhythmCommand", function(ply, text)
    if text == "/start_music" and ply:IsAdmin() then
        -- Отправляем команду на клиент игрока
        ply:ConCommand("act_rhythm_test")
        return ""
    end
end)