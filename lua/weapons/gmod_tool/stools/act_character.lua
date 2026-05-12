TOOL.Category = "ACT"
TOOL.Name = "Персонаж"
TOOL.ClientConVar["char_name"] = "Крис"
TOOL.ClientConVar["char_color"] = "ffffff"
TOOL.ClientConVar["sprite_path"] = "sprites/kris/"

if CLIENT then
    language.Add("tool.act_character.name", "Настройка Персонажа")
    language.Add("tool.act_character.desc", "ЛКМ: выдать цели | ПКМ: на себя | R: список игроков")

    function TOOL:BuildCPanel()
        self:AddControl("TextBox", { Label = "Имя персонажа", Command = "act_character_char_name" })
        self:AddControl("TextBox", { Label = "Цвет имени (HEX)", Command = "act_character_char_color" })
        self:AddControl("TextBox", { Label = "Папка спрайтов", Command = "act_character_sprite_path" })
    end

    function TOOL:Reload()
        if not IsFirstTimePredicted() then return end
        local f = vgui.Create("DFrame")
        f:SetSize(200, 300) f:SetTitle("Выбор игрока") f:Center() f:MakePopup()
        local s = vgui.Create("DScrollPanel", f) s:Dock(FILL)
        for _, p in ipairs(player.GetAll()) do
            local b = s:Add("DButton") b:SetText(p:Nick()) b:Dock(TOP)
            b.DoClick = function()
                net.Start("ActRemoteSetChar")
                net.WriteEntity(p)
                net.WriteString(GetConVar("act_character_char_name"):GetString())
                net.WriteString(GetConVar("act_character_char_color"):GetString())
                net.WriteString(GetConVar("act_character_sprite_path"):GetString())
                net.SendToServer()
                f:Close()
            end
        end
    end
end

function TOOL:LeftClick(tr)
    if CLIENT or not (IsValid(tr.Entity) and tr.Entity:IsPlayer()) then return false end
    local o = self:GetOwner()
    tr.Entity:SetNWString("ActCharName", o:GetInfo("act_character_char_name"))
    tr.Entity:SetNWString("ActCharColor", o:GetInfo("act_character_char_color"))
    tr.Entity:SetNWString("ActCharSprites", o:GetInfo("act_character_sprite_path"))
    return true
end

function TOOL:RightClick(tr)
    if CLIENT then return true end
    local o = self:GetOwner()
    o:SetNWString("ActCharName", o:GetInfo("act_character_char_name"))
    o:SetNWString("ActCharColor", o:GetInfo("act_character_char_color"))
    o:SetNWString("ActCharSprites", o:GetInfo("act_character_sprite_path"))
    return true
end