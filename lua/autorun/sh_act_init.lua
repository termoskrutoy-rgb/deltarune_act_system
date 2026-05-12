-- Инициализация системы ACT
if SERVER then
    AddCSLuaFile("autorun/client/cl_init.lua")
    include("autorun/server/sv_init.lua")
else
    include("autorun/client/cl_init.lua")
end