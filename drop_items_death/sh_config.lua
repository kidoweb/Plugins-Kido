--[[
    Drop Items on Death - Configuration System
    Система конфигурации и управления предметами
--]]

local PLUGIN = PLUGIN

-- ============================================================================
-- СИСТЕМА УПРАВЛЕНИЯ ПРЕДМЕТАМИ
-- ============================================================================

PLUGIN.itemSettings = PLUGIN.itemSettings or {}

-- Предустановленные настройки для предметов по умолчанию
PLUGIN.defaultItemSettings = {
    -- Предметы которые НЕ выпадают по умолчанию
    ["idcard"] = { enabled = false, chance = 0, reason = "Документ" },
    ["passport"] = { enabled = false, chance = 0, reason = "Документ" },
    ["license"] = { enabled = false, chance = 0, reason = "Документ" },
    ["keys"] = { enabled = false, chance = 0, reason = "Ключи" },
    ["keycard"] = { enabled = false, chance = 0, reason = "Карта доступа" },
    ["radio"] = { enabled = false, chance = 0, reason = "Особый предмет" },
    ["badge"] = { enabled = false, chance = 0, reason = "Значок" },
    ["uniform"] = { enabled = false, chance = 0, reason = "Форма" },
    
    -- Остальные предметы выпадают по умолчанию с базовым шансом
}

-- ============================================================================
-- ФУНКЦИИ УПРАВЛЕНИЯ НАСТРОЙКАМИ ПРЕДМЕТОВ
-- ============================================================================

function PLUGIN:SetItemSettings(itemIdentifier, settings)
    if (!itemIdentifier) then return false end
    
    self.itemSettings[itemIdentifier] = self.itemSettings[itemIdentifier] or {}
    
    if (settings.enabled ~= nil) then
        self.itemSettings[itemIdentifier].enabled = settings.enabled
    end
    
    if (settings.chance) then
        self.itemSettings[itemIdentifier].chance = math.Clamp(settings.chance, 0, 100)
    end
    
    if (settings.reason) then
        self.itemSettings[itemIdentifier].reason = settings.reason
    end
    
    self:SaveItemSettings()
    return true
end

function PLUGIN:GetItemSettings(itemIdentifier)
    if (!itemIdentifier) then return nil end
    
    -- Проверяем есть ли кастомные настройки
    if (self.itemSettings[itemIdentifier]) then
        return self.itemSettings[itemIdentifier]
    end
    
    -- Проверяем настройки по умолчанию
    if (self.defaultItemSettings[itemIdentifier]) then
        return self.defaultItemSettings[itemIdentifier]
    end
    
    -- Возвращаем настройки по умолчанию для всех остальных предметов
    return {
        enabled = true,
        chance = ix.config.Get("dropItemsChance", 100),
        reason = "Обычный предмет"
    }
end

function PLUGIN:IsItemDropEnabled(itemIdentifier)
    local settings = self:GetItemSettings(itemIdentifier)
    return settings.enabled == true
end

function PLUGIN:GetItemDropChance(itemIdentifier)
    local settings = self:GetItemSettings(itemIdentifier)
    return settings.chance or 0
end

function PLUGIN:GetAllItemsWithSettings()
    local allItems = {}
    
    -- Добавляем все зарегистрированные предметы из ix.item.list
    for uniqueID, item in pairs(ix.item.list or {}) do
        local settings = self:GetItemSettings(uniqueID)
        table.insert(allItems, {
            uniqueID = uniqueID,
            name = item.name or uniqueID,
            enabled = settings.enabled,
            chance = settings.chance,
            reason = settings.reason
        })
    end
    
    return allItems
end

-- ============================================================================
-- ЗАГРУЗКА И СОХРАНЕНИЕ НАСТРОЕК
-- ============================================================================

function PLUGIN:LoadItemSettings()
    self.itemSettings = ix.data.Get("dropItemsSettings", {})
end

function PLUGIN:SaveItemSettings()
    ix.data.Set("dropItemsSettings", self.itemSettings)
end

function PLUGIN:ResetToDefaults()
    self.itemSettings = table.Copy(self.defaultItemSettings)
    self:SaveItemSettings()
end

function PLUGIN:ImportItemSettings(data)
    if (type(data) ~= "table") then return false end
    -- Валидация: только таблицы с ключами-строками и значениями-таблицами с полями enabled/chance/reason
    local validated = {}
    for itemID, settings in pairs(data) do
        if (type(itemID) == "string" and type(settings) == "table") then
            validated[itemID] = {
                enabled = settings.enabled,
                chance = (type(settings.chance) == "number") and math.Clamp(settings.chance, 0, 100) or nil,
                reason = type(settings.reason) == "string" and settings.reason or nil
            }
        end
    end
    self.itemSettings = validated
    self:SaveItemSettings()
    return true
end

function PLUGIN:ExportItemSettings()
    return util.TableToJSON(self.itemSettings, true)
end

-- ============================================================================
-- ИНИЦИАЛИЗАЦИЯ
-- ============================================================================

function PLUGIN:LoadData()
    self:LoadItemSettings()
end

function PLUGIN:SaveData()
    self:SaveItemSettings()
end
