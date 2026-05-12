util.AddNetworkString("Rhythm_Log")

net.Receive("Rhythm_Log", function(len, ply)
    local chartID = net.ReadString()
    local accuracy = net.ReadFloat()
    
    -- Получаем имя из NWString тула "Персонаж"
    local charName = ply:GetNWString("ActCharName", "")
    if charName == "" then charName = ply:Nick() end

    -- Формируем строку с разделением: [РИТМ] Имя — Чарт — Процент%
    local msg = string.format("[РИТМ] %s — %s — %.0f%%", charName, chartID, accuracy)
    
    -- Рассылка только администраторам
    for _, v in ipairs(player.GetAll()) do
        if v:IsAdmin() or v:IsSuperAdmin() then
            v:ChatPrint(msg)
        end
    end
end)