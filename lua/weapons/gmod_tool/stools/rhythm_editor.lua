TOOL.Category = "ACT"
TOOL.Name = "Ритм-Редактор"

-- Конвары для сохранения настроек в меню
TOOL.ClientConVar["speed"] = "600"
TOOL.ClientConVar["song_path"] = "music/hl2_song20_subtle.mp3"
TOOL.ClientConVar["mode"] = "Mania"
TOOL.ClientConVar["selected_chart"] = ""

if CLIENT then
    language.Add("tool.rhythm_editor.name", "Ритм-Редактор")
    language.Add("tool.rhythm_editor.desc", "Инструмент для создания и теста чартов")
    language.Add("tool.rhythm_editor.0", "ЛКМ: Начать запись чарта, ПКМ: Остановить, R: Обновить список")

    -- Функция для обновления списка чартов в выпадающем меню
    local function RefreshCharts(combo)
        combo:Clear()
        local charts = RhythmGame and RhythmGame.Charts or {}
        
        if table.Count(charts) > 0 then
            for id, data in pairs(charts) do
                combo:AddChoice(data.name or id, id)
            end
            combo:SetText("Выберите чарт...")
        else
            combo:SetText("Чарты не найдены")
        end
    end

    function TOOL.BuildCPanel(panel)
        panel:ClearControls()

        panel:Help("ПОРЯДОК СОЗДАНИЯ:\n1. Укажите путь к песне.\n2. Выберите режим (пока только Mania).\n3. Нажмите ЛКМ и настукивайте ритм (D, F, J, K).\n4. После окончания или ПКМ код будет в буфере.")

        -- Настройки скорости (влияют только на визуализацию при тесте)
        panel:NumSlider("Скорость прокрутки", "rhythm_editor_speed", 200, 2000, 0)

        -- ВЫБОР РЕЖИМА
        local modeCombo = panel:ComboBox("Режим игры", "rhythm_editor_mode")
        modeCombo:AddChoice("Mania (4 Keys)")
        modeCombo:SetText("Mania")

        panel:ControlHelp("\n--- СОЗДАНИЕ (RECORD) ---")
        panel:TextEntry("Путь к музыке (sound/...)", "rhythm_editor_song_path")
        
        local btnRecord = panel:Button("НАЧАТЬ ЗАПИСЬ (ЛКМ)")
        btnRecord.DoClick = function()
            local path = GetConVar("rhythm_editor_song_path"):GetString()
            RunConsoleCommand("rhythm_record", path)
        end

        panel:ControlHelp("\n--- ТЕСТИРОВАНИЕ (PLAY) ---")
        
        local chartCombo = panel:ComboBox("Библиотека чартов", "rhythm_editor_selected_chart")
        -- Запоминаем ID при выборе
        chartCombo.OnSelect = function(self, index, value, data)
            RunConsoleCommand("rhythm_editor_selected_chart", data)
        end
        RefreshCharts(chartCombo)

        local btnPlay = panel:Button("ЗАПУСТИТЬ ВЫБРАННЫЙ")
        btnPlay.DoClick = function()
            local id = GetConVar("rhythm_editor_selected_chart"):GetString()
            if id and id ~= "" then
                RunConsoleCommand("rhythm_play_chart", id)
            else
                notification.AddLegacy("Сначала выберите чарт!", NOTIFY_ERROR, 3)
            end
        end

        local btnRefresh = panel:Button("ОБНОВИТЬ СПИСОК (R)")
        btnRefresh.DoClick = function()
            RunConsoleCommand("rhythm_load")
            timer.Simple(0.2, function() if IsValid(chartCombo) then RefreshCharts(chartCombo) end end)
        end

        local btnStop = panel:Button("ОСТАНОВИТЬ ВСЁ (ПКМ)")
        btnStop.DoClick = function() RunConsoleCommand("rhythm_stop") end
    end
end

-- Логика нажатий инструмента
function TOOL:LeftClick(trace)
    if CLIENT and IsFirstTimePredicted() then
        local path = self:GetClientInfo("song_path")
        if path ~= "" then RunConsoleCommand("rhythm_record", path) end
    end
    return true
end

function TOOL:RightClick(trace)
    if CLIENT and IsFirstTimePredicted() then
        RunConsoleCommand("rhythm_stop")
    end
    return true
end

function TOOL:Reload(trace)
    if CLIENT and IsFirstTimePredicted() then
        RunConsoleCommand("rhythm_load")
        notification.AddLegacy("Список чартов обновлен", NOTIFY_GENERIC, 2)
    end
    return true
end