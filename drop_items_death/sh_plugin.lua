--[[
    Выброс предметов при смерти
    Система выбрасывания предметов при смерти с продвинутыми возможностями
    
    Автор: kido
    Версия: 2.0
--]]

local PLUGIN = PLUGIN

PLUGIN.name = "Выброс предметов при смерти v2.0"
PLUGIN.author = "kido"
PLUGIN.description = "Современная система выбрасывания предметов при смерти с гибкими настройками"
PLUGIN.version = "2.0.0"

-- ============================================================================
-- КОНФИГУРАЦИЯ
-- ============================================================================

-- Основные настройки
ix.config.Add("dropItemsEnabled", true, "Включить выбрасывание предметов при смерти", nil, {
    category = "Выброс предметов при смерти"
})

ix.config.Add("dropItemsChance", 100, "Шанс выпадения предметов (0-100%)", nil, {
    data = {min = 0, max = 100},
    category = "Выброс предметов при смерти"
})

ix.config.Add("dropItemsRadius", 80, "Радиус разброса предметов", nil, {
    data = {min = 30, max = 200},
    category = "Выброс предметов при смерти"
})

ix.config.Add("dropItemsMaxHeight", 150, "Максимальная высота выброса", nil, {
    data = {min = 50, max = 300},
    category = "Выброс предметов при смерти"
})

ix.config.Add("dropItemsForce", 200, "Сила выброса предметов", nil, {
    data = {min = 50, max = 500},
    category = "Выброс предметов при смерти"
})

ix.config.Add("dropItemsNotifyRadius", 400, "Радиус уведомлений о выпавших предметах", nil, {
    data = {min = 100, max = 1000},
    category = "Выброс предметов при смерти"
})

ix.config.Add("dropItemsMaxCount", 10, "Максимальное количество выбрасываемых предметов", nil, {
    data = {min = 1, max = 50},
    category = "Выброс предметов при смерти"
})

-- Защита от спама
ix.config.Add("dropItemsAntiSpam", true, "Защита от спама смертями", nil, {
    category = "Выброс предметов при смерти"
})

ix.config.Add("dropItemsSpamDelay", 30, "Задержка между выбросами для одного игрока (сек)", nil, {
    data = {min = 5, max = 300},
    category = "Выброс предметов при смерти"
})

-- Условия выброса
ix.config.Add("dropItemsSuicideEnabled", true, "Выбрасывать предметы при самоубийстве", nil, {
    category = "Выброс предметов при смерти"
})

ix.config.Add("dropItemsNPCKillEnabled", true, "Выбрасывать предметы при убийстве NPC", nil, {
    category = "Выброс предметов при смерти"
})

ix.config.Add("dropItemsPropKillEnabled", false, "Выбрасывать предметы при убийстве пропом", nil, {
    category = "Выброс предметов при смерти"
})

-- Эффекты и звуки
ix.config.Add("dropItemsEffectsEnabled", true, "Включить визуальные эффекты", nil, {
    category = "Выброс предметов при смерти"
})

ix.config.Add("dropItemsSoundsEnabled", true, "Включить звуковые эффекты", nil, {
    category = "Выброс предметов при смерти"
})

-- ============================================================================
-- ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ
-- ============================================================================

PLUGIN.playerDropCooldowns = PLUGIN.playerDropCooldowns or {}
PLUGIN.dropStatistics = PLUGIN.dropStatistics or {
    totalDrops = 0,
    totalItems = 0,
    playerStats = {}
}

-- ============================================================================
-- ЯЗЫКОВЫЕ КОНСТАНТЫ
-- ============================================================================

ix.lang.AddTable("english", {
    dropItemsNotification = "%s lost %d item(s)",
    dropItemsBlacklistAdded = "Item '%s' added to drop blacklist",
    dropItemsBlacklistRemoved = "Item '%s' removed from drop blacklist", 
    dropItemsBlacklistEmpty = "Drop blacklist is empty",
    dropItemsBlacklistList = "Blacklisted items: %s",
    dropItemsCooldown = "Drop cooldown active for %d seconds",
    dropItemsStatsHeader = "=== Drop Items Death Statistics ===",
    dropItemsStatsTotal = "Total drops: %d | Total items: %d",
    dropItemsStatsPlayer = "Player %s: %d drops, %d items",
    dropItemsConfigReloaded = "Drop Items Death configuration reloaded",
    dropItemsTestDrop = "Test drop executed for %s",
    dropItemsNoItems = "No items to drop",
    dropItemsDisabled = "Drop items system is disabled"
})

ix.lang.AddTable("russian", {
    dropItemsNotification = "%s потерял %d предмет(ов)",
    dropItemsBlacklistAdded = "Предмет '%s' добавлен в черный список выпадения",
    dropItemsBlacklistRemoved = "Предмет '%s' удален из черного списка выпадения",
    dropItemsBlacklistEmpty = "Черный список выпадения пуст",
    dropItemsBlacklistList = "Предметы в черном списке: %s",
    dropItemsCooldown = "Кулдаун выброса активен еще %d секунд",
    dropItemsStatsHeader = "=== Статистика Drop Items Death ===",
    dropItemsStatsTotal = "Всего сбросов: %d | Всего предметов: %d",
    dropItemsStatsPlayer = "Игрок %s: %d сбросов, %d предметов",
    dropItemsConfigReloaded = "Конфигурация Drop Items Death перезагружена",
    dropItemsTestDrop = "Тестовый сброс выполнен для %s",
    dropItemsNoItems = "Нет предметов для выброса",
    dropItemsDisabled = "Система выброса предметов отключена"
})

-- ============================================================================
-- УТИЛИТЫ
-- ============================================================================

-- Включаем файлы
ix.util.Include("sv_plugin.lua")
ix.util.Include("sv_commands.lua")
ix.util.Include("cl_plugin.lua")
ix.util.Include("sh_config.lua")

-- Сетевые строки
if (SERVER) then
    util.AddNetworkString("ixDropItemsEffect")
    util.AddNetworkString("ixDropItemsSound")
    util.AddNetworkString("ixDropItemsNotify")
    util.AddNetworkString("ixDropItemsAdminData")
    util.AddNetworkString("ixDropItemsBlacklistData")
    util.AddNetworkString("ixDropItemsCategoryData")
    util.AddNetworkString("ixDropItemsStatsData")
end

-- ============================================================================
-- ОСНОВНЫЕ ФУНКЦИИ
-- ============================================================================

function PLUGIN:IsItemBlacklisted(item)
    if (!item) then return true end
    
    -- Проверяем включен ли выброс для этого предмета
    if (!self:IsItemDropEnabled(item.uniqueID)) then
        return true
    end
    
    -- Проверяем флаги предмета
    if (item.noDrop or item.permanent or item.important) then
        return true
    end
    
    return false
end

function PLUGIN:CanPlayerDrop(client)
    if (!IsValid(client)) then return false end
    
    -- Проверяем включена ли система
    if (!ix.config.Get("dropItemsEnabled", true)) then
        return false
    end
    
    -- Проверяем кулдаун
    if (ix.config.Get("dropItemsAntiSpam", true)) then
        local cooldown = self.playerDropCooldowns[client:SteamID64()]
        if (cooldown and cooldown > CurTime()) then
            return false
        end
    end
    
    return true
end

function PLUGIN:SetPlayerDropCooldown(client)
    if (!IsValid(client)) then return end
    
    local delay = ix.config.Get("dropItemsSpamDelay", 30)
    self.playerDropCooldowns[client:SteamID64()] = CurTime() + delay
end

function PLUGIN:UpdateStatistics(client, itemCount)
    self.dropStatistics.totalDrops = self.dropStatistics.totalDrops + 1
    self.dropStatistics.totalItems = self.dropStatistics.totalItems + itemCount
    
    if (IsValid(client)) then
        local steamID = client:SteamID64()
        if (!self.dropStatistics.playerStats[steamID]) then
            self.dropStatistics.playerStats[steamID] = {
                name = client:GetName(),
                drops = 0,
                items = 0
            }
        end
        
        self.dropStatistics.playerStats[steamID].drops = self.dropStatistics.playerStats[steamID].drops + 1
        self.dropStatistics.playerStats[steamID].items = self.dropStatistics.playerStats[steamID].items + itemCount
        self.dropStatistics.playerStats[steamID].name = client:GetName() -- Обновляем имя
    end
end
