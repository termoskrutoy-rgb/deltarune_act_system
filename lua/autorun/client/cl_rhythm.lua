_G.RhythmGame = _G.RhythmGame or {}
RhythmGame.Charts = RhythmGame.Charts or {}
RhythmGame.RecordingTable = {}

surface.CreateFont("RhythmFont", {
    font = "Determination Mono(RUS BY LYAJK", 
    size = 40, weight = 500, antialias = true,
})

local LANES = { KEY_D, KEY_F, KEY_J, KEY_K }
local KEY_NAMES = { [1] = "D", [2] = "F", [3] = "J", [4] = "K" }

RhythmGame.Active = false
RhythmGame.IsRecording = false
RhythmGame.StartTime = 0
RhythmGame.Notes = {}
RhythmGame.Score = 0
RhythmGame.Combo = 0
RhythmGame.MaxNotes = 0
RhythmGame.LaneAlpha = { 0, 0, 0, 0 }
RhythmGame.KeyPressedState = {}
RhythmGame.LastRating = ""
RhythmGame.RatingAlpha = 0
RhythmGame.RatingColor = Color(255, 255, 255)
RhythmGame.CurrentSongPath = ""
RhythmGame.CurrentChartID = ""

function RhythmGame:LoadCharts()
    table.Empty(self.Charts)
    local files = file.Find("charts/*.lua", "LUA")
    if files then
        for _, filename in ipairs(files) do
            include("charts/" .. filename)
        end
    end
end

function RhythmGame:ExportToClipboard()
    if #self.RecordingTable == 0 then return end
    local fileName = string.StripExtension(string.GetFileFromFilename(self.CurrentSongPath))
    local safeID = fileName:lower():gsub("%s+", "_")
    
    local str = "RhythmGame.Charts[%q] = {\n    name = %q,\n    file = %q,\n    author = %q,\n    notes = {\n"
    str = string.format(str, safeID, fileName, self.CurrentSongPath, LocalPlayer():Nick())
    for _, n in ipairs(self.RecordingTable) do
        str = str .. string.format("        { time = %.3f, lane = %d },\n", n.time, n.lane)
    end
    str = str .. "    }\n}"
    SetClipboardText(str)
    notification.AddLegacy("Код чарта в буфере!", NOTIFY_GENERIC, 5)
end

function RhythmGame:HitNote(lane)
    if self.IsRecording then return end
    local elapsed = CurTime() - self.StartTime
    for i = 1, #self.Notes do
        local n = self.Notes[i]
        if n.lane == lane then
            local diff = math.abs(n.time - elapsed)
            if diff < 0.25 then
                if diff < 0.06 then 
                    self.LastRating, self.Score, self.RatingColor = "PERFECT", self.Score + 100, Color(255, 220, 0)
                    self.Combo = self.Combo + 1
                elseif diff < 0.12 then 
                    self.LastRating, self.Score, self.RatingColor = "GREAT", self.Score + 50, Color(50, 255, 50)
                    self.Combo = self.Combo + 1
                else 
                    self.LastRating, self.Score, self.RatingColor = "OK", self.Score + 20, Color(200, 200, 200) 
                    self.Combo = 0 
                end
                self.RatingAlpha = 255
                table.remove(self.Notes, i)
                return true
            end
        end
    end
    return false
end

function RhythmGame:PlayPath(path, isRecording, notesData, chartID)
    self:Stop() 
    self.Active = true
    self.IsRecording = isRecording
    self.CurrentSongPath = path
    self.CurrentChartID = chartID or "unknown_chart"
    self.Notes = notesData or {}
    self.MaxNotes = #self.Notes
    self.Score = 0
    self.Combo = 0

    sound.PlayFile("sound/" .. path, "noplay", function(station, err, errname)
        if IsValid(station) then
            self.MusicSide = station
            self.MusicSide:SetVolume(0.2)
            self.MusicSide:Play()
            self.StartTime = CurTime()
        else
            self.Active = false
        end
    end)
end

function RhythmGame:Stop()
    if not self.Active then return end 

    if not self.IsRecording and self.MaxNotes > 0 then
        local accuracy = math.Clamp((self.Score / (self.MaxNotes * 100)) * 100, 0, 100)
        net.Start("Rhythm_Log")
            net.WriteString(self.CurrentChartID)
            net.WriteFloat(accuracy)
        net.SendToServer()
    end
    
    if self.IsRecording then self:ExportToClipboard() end
    if self.MusicSide and IsValid(self.MusicSide) then self.MusicSide:Stop() end
    
    self.MusicSide = nil
    self.Active = false
    self.IsRecording = false
    self.Notes = {}
    self.Combo = 0
end

hook.Add("HUDPaint", "RhythmGameMain", function()
    if not RhythmGame.Active then return end
    
    if input.IsKeyDown(KEY_EQUAL) or input.IsKeyDown(KEY_PAD_PLUS) then
        RhythmGame:Stop()
        return
    end

    if IsValid(RhythmGame.MusicSide) and RhythmGame.MusicSide:GetState() == 0 then
        if (CurTime() - RhythmGame.StartTime) > 1.5 then RhythmGame:Stop() return end
    end

    local sw, sh = ScrW(), ScrH()
    local cx, ft, elapsed = sw/2, FrameTime(), CurTime() - RhythmGame.StartTime
    local colW, judgeY = 80, sh * 0.8

    for laneID, key in ipairs(LANES) do
        local isDown = input.IsKeyDown(key)
        if isDown and not RhythmGame.KeyPressedState[key] then
            if RhythmGame.IsRecording then 
                table.insert(RhythmGame.RecordingTable, { time = math.Round(elapsed, 3), lane = laneID })
            else 
                RhythmGame:HitNote(laneID) 
            end
            LocalPlayer():EmitSound("mania_hit.wav", 75, 100, 0.2)
            RhythmGame.KeyPressedState[key] = true
        elseif not isDown then RhythmGame.KeyPressedState[key] = false end
        RhythmGame.LaneAlpha[laneID] = Lerp(ft * 15, RhythmGame.LaneAlpha[laneID], isDown and 1 or 0)
    end

    -- Фон дорожек
    surface.SetDrawColor(0, 0, 0, 240)
    surface.DrawRect(cx - colW*2, 0, colW*4, sh)
    
    for i = 1, 4 do
        local x, a = cx - colW*2 + (i-1)*colW, RhythmGame.LaneAlpha[i]
        surface.SetDrawColor(255, 255, 255, 15)
        surface.DrawOutlinedRect(x, 0, colW, sh, 1)
        draw.SimpleText(KEY_NAMES[i], "RhythmFont", x + colW/2, judgeY + 20, Color(255,255,255, 50 + 205*a), 1)
    end

    -- Линия судейства (Judge Bar)
    surface.SetDrawColor(255, 255, 255, 150)
    surface.DrawRect(cx - colW*2, judgeY, colW*4, 3)

    if RhythmGame.IsRecording then
        -- ИНФОРМАЦИЯ ДЛЯ ЗАПИСИ
        local blink = math.abs(math.sin(CurTime() * 4)) * 255
        draw.SimpleText("● ЗАПИСЬ РИТМА", "RhythmFont", cx, 80, Color(255, 0, 0, blink), 1)
        draw.SimpleText("Ноты: " .. #RhythmGame.RecordingTable, "RhythmFont", cx, 130, Color(255, 255, 255, 200), 1)

        if IsValid(RhythmGame.MusicSide) then
            local dur = RhythmGame.MusicSide:GetLength()
            local cur = RhythmGame.MusicSide:GetTime()
            local timeStr = string.format("%d:%02d / %d:%02d", math.floor(cur / 60), math.floor(cur % 60), math.floor(dur / 60), math.floor(dur % 60))
            draw.SimpleText(timeStr, "RhythmFont", cx, sh - 60, Color(255, 255, 255, 150), 1)
            surface.SetDrawColor(255, 255, 255, 100)
            surface.DrawRect(cx - 150, sh - 30, (cur / dur) * 300, 5)
        end
    else
        -- РЕЖИМ ИГРЫ (НОТЫ)
        for i = #RhythmGame.Notes, 1, -1 do
            local n = RhythmGame.Notes[i]
            local noteY = judgeY - (n.time - elapsed) * 600
            if noteY > -50 and noteY < sh then
                surface.SetDrawColor(255, 255, 255)
                surface.DrawRect(cx - colW*2 + (n.lane-1)*colW + 5, noteY - 10, colW - 10, 20)
            end
            if noteY > judgeY + 50 then
                RhythmGame.LastRating, RhythmGame.RatingColor, RhythmGame.RatingAlpha = "MISS", Color(255,50,50), 255
                RhythmGame.Combo = 0
                table.remove(RhythmGame.Notes, i)
            end
        end
        if RhythmGame.Combo > 2 then
            draw.SimpleText(RhythmGame.Combo, "RhythmFont", cx, judgeY - 250, Color(255, 255, 255, 200), 1, 1)
        end
    end

    if RhythmGame.RatingAlpha > 0 then
        local col = RhythmGame.RatingColor
        col.a = RhythmGame.RatingAlpha
        draw.SimpleText(RhythmGame.LastRating, "RhythmFont", cx, judgeY - 150, col, 1, 1)
        RhythmGame.RatingAlpha = math.max(0, RhythmGame.RatingAlpha - ft * 350)
    end
end)

hook.Add("PlayerBindPress", "RhythmGameBlock", function(ply, bind, pressed)
    if RhythmGame.Active then return true end
end)

hook.Add("InputMouseApply", "RhythmGameMouse", function(cmd)
    if RhythmGame.Active then
        cmd:SetMouseX(0); cmd:SetMouseY(0)
        return true
    end
end)

concommand.Add("rhythm_record", function(ply, cmd, args) if args[1] then RhythmGame:PlayPath(args[1], true) end end)
concommand.Add("rhythm_play_chart", function(ply, cmd, args)
    local id = args[1]
    if id and RhythmGame.Charts[id] then
        local chart = RhythmGame.Charts[id]
        RhythmGame:PlayPath(chart.file, false, table.Copy(chart.notes), id)
    end
end)
concommand.Add("rhythm_stop", function() RhythmGame:Stop() end)

RhythmGame:LoadCharts()