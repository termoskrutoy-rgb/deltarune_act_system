-- Регистрация сетевых строк
util.AddNetworkString("ActUpdateSkills")
util.AddNetworkString("ActOpenSkillsMenu")
util.AddNetworkString("ActCastSkill")
util.AddNetworkString("ActBroadcastCast")

-- Функция конвертации HEX в Color
local function hexToRGB(hex)
    if not hex or hex == "" then return Color(255, 255, 255) end
    hex = hex:gsub("#","")
    return Color(
        tonumber("0x"..hex:sub(1,2)) or 255, 
        tonumber("0x"..hex:sub(3,4)) or 255, 
        tonumber("0x"..hex:sub(5,6)) or 255
    )
end

-- Функция для получения навыков игрока
local function GetPlayerSkills(ply)
    local raw = ply:GetNWString("ActSkills", "")
    if raw == "" then return {} end
    return util.JSONToTable(raw) or {}
end

-- Команда /skills (открывает меню на клиенте)
hook.Add("PlayerSay", "ActSkillsChatCommand", function(ply, text)
    if text:lower() == "/skills" then
        local skills = GetPlayerSkills(ply)
        
        if table.Count(skills) == 0 then
            ply:ChatPrint("У вас нет навыков!")
            return ""
        end

        net.Start("ActOpenSkillsMenu")
        net.Send(ply)
        return ""
    end
end)

-- Обработка выдачи через тул
net.Receive("ActUpdateSkills", function(len, ply)
    if not ply:IsAdmin() then return end
    local target = net.ReadEntity()
    local skillID = net.ReadString()
    local skillName = net.ReadString()

    if IsValid(target) and target:IsPlayer() then
        local skills = GetPlayerSkills(target)
        skills[skillID] = { name = skillName, date = os.date("%H:%M:%S") }
        
        target:SetNWString("ActSkills", util.TableToJSON(skills))
        ply:ChatPrint("Навык '" .. skillName .. "' выдан игроку " .. target:Nick())
    end
end)

-- Обработка каста (рассылка цветного сообщения)
net.Receive("ActCastSkill", function(len, ply)
    local skillName = net.ReadString()
    local skillCost = net.ReadString()
    
    local charName = ply:GetNWString("ActCharName", ply:Nick())
    local charColorHex = ply:GetNWString("ActCharColor", "ffffff")
    local charColor = hexToRGB(charColorHex)

    -- Рассылаем всем информацию для красивого чата
    net.Start("ActBroadcastCast")
        net.WriteString(charName)
        net.WriteColor(charColor)
        net.WriteString(skillName)
        net.WriteString(skillCost)
    net.Broadcast()
end)