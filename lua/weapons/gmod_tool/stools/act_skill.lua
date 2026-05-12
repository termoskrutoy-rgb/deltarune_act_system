TOOL.Category = "ACT"
TOOL.Name = "Скилл"
TOOL.ClientConVar["id"] = "heal"
TOOL.ClientConVar["name"] = "Heal Prayer"
TOOL.ClientConVar["desc"] = "Восстанавливает немного здоровья."
TOOL.ClientConVar["cost"] = "16"

if CLIENT then
    language.Add("tool.act_skill.name", "Выдача навыков")
    language.Add("tool.act_skill.desc", "ЛКМ: выдать игроку | ПКМ: выдать себе")

    function TOOL:BuildCPanel()
        self:AddControl("Header", { Description = "Настройка навыка" })
        self:AddControl("TextBox", { Label = "ID (технический)", Command = "act_skill_id" })
        self:AddControl("TextBox", { Label = "Название", Command = "act_skill_name" })
        self:AddControl("TextBox", { Label = "Описание", Command = "act_skill_desc" })
        self:AddControl("TextBox", { Label = "Стоимость (только число)", Command = "act_skill_cost" })
    end
end

function TOOL:LeftClick(tr)
    if CLIENT or not (IsValid(tr.Entity) and tr.Entity:IsPlayer()) then return false end
    
    local skillData = {
        name = self:GetOwner():GetInfo("act_skill_name"),
        desc = self:GetOwner():GetInfo("act_skill_desc"),
        cost = self:GetOwner():GetInfo("act_skill_cost")
    }
    
    local target = tr.Entity
    local skills = util.JSONToTable(target:GetNWString("ActSkills", "[]")) or {}
    skills[self:GetOwner():GetInfo("act_skill_id")] = skillData
    
    target:SetNWString("ActSkills", util.TableToJSON(skills))
    self:GetOwner():ChatPrint("Вы выдали навык '" .. skillData.name .. "' игроку " .. target:Nick())
    return true
end

function TOOL:RightClick(tr)
    if CLIENT then return true end
    local o = self:GetOwner()
    
    local skillData = {
        name = o:GetInfo("act_skill_name"),
        desc = o:GetInfo("act_skill_desc"),
        cost = o:GetInfo("act_skill_cost")
    }
    
    local skills = util.JSONToTable(o:GetNWString("ActSkills", "[]")) or {}
    skills[o:GetInfo("act_skill_id")] = skillData
    
    o:SetNWString("ActSkills", util.TableToJSON(skills))
    o:ChatPrint("Вы выдали навык '" .. skillData.name .. "' себе")
    return true
end