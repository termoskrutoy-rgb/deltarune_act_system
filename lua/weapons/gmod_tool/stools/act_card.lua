TOOL.Category = "ACT"
TOOL.Name = "Карточка"
-- Регистрируем правильную переменную
TOOL.ClientConVar["style"] = "default"

if CLIENT then
    language.Add("tool.act_card.name", "Настройка интерфейса")
    language.Add("tool.act_card.desc", "ЛКМ: Установить стиль для всего сервера | ПКМ: Сброс")
    language.Add("tool.act_card.style", "Стиль оформления")

    function TOOL:BuildCPanel()
        local combo = self:AddControl("ComboBox", { Label = "#tool.act_card.style" })
        combo:AddChoice("Стандарт", "default")
        combo:AddChoice("Шахматный", "chess")
        
        -- Выбор записывается в convar тулгана
        combo.OnSelect = function(_, _, _, data)
            RunConsoleCommand("act_card_style", data)
        end
    end
end

function TOOL:LeftClick(tr)
    -- Работаем на клиенте
    if CLIENT then
        -- Получаем значение переменной (теперь имя совпадает)
        local style = GetConVar("act_card_style"):GetString()
        
        net.Start("ActChangeGlobalStyle")
            net.WriteString(style)
        net.SendToServer()
        
        -- Звуковой фидбек для удобства
        surface.PlaySound("buttons/button14.wav")
        return true
    end
    
    return true
end

function TOOL:RightClick(tr)
    if CLIENT then
        net.Start("ActChangeGlobalStyle")
            net.WriteString("default")
        net.SendToServer()
        
        surface.PlaySound("buttons/button11.wav")
        return true
    end
    return true
end