--[[
    Drop Items on Death - Administrative Commands
    Административные команды для управления системой
--]]

local PLUGIN = PLUGIN

-- ============================================================================
-- КОМАНДЫ УПРАВЛЕНИЯ ПРЕДМЕТАМИ
-- ============================================================================

ix.command.Add("DropItemToggle", {
    description = "Включить/выключить выпадение предмета",
    arguments = {
        ix.type.string, -- uniqueID предмета
        ix.type.bool    -- enabled (true/false)
    },
    adminOnly = true,
    OnRun = function(self, client, itemID, enabled)
        if (!ix.item.list[itemID]) then
            client:Notify("Предмет '" .. itemID .. "' не найден")
            return
        end
        
        PLUGIN:SetItemSettings(itemID, { enabled = enabled })
        
        local status = enabled and "включено" or "выключено"
        client:Notify("Выпадение предмета '" .. itemID .. "' " .. status)
        
        -- Логируем действие
        ix.log.Add(client, "dropItemsConfig", string.format(
            "Set item '%s' drop enabled to %s", itemID, tostring(enabled)
        ))
    end
})

ix.command.Add("DropItemChance", {
    description = "Установить шанс выпадения предмета (0-100%)",
    arguments = {
        ix.type.string, -- uniqueID предмета
        ix.type.number  -- шанс
    },
    adminOnly = true,
    OnRun = function(self, client, itemID, chance)
        if (!ix.item.list[itemID]) then
            client:Notify("Предмет '" .. itemID .. "' не найден")
            return
        end
        
        chance = math.Clamp(chance, 0, 100)
        PLUGIN:SetItemSettings(itemID, { chance = chance })
        
        client:Notify("Шанс выпадения предмета '" .. itemID .. "' установлен на " .. chance .. "%")
        
        -- Логируем действие
        ix.log.Add(client, "dropItemsConfig", string.format(
            "Set item '%s' drop chance to %d%%", itemID, chance
        ))
    end
})

ix.command.Add("DropItemInfo", {
    description = "Показать информацию о настройках предмета",
    arguments = ix.type.string, -- uniqueID предмета
    adminOnly = true,
    OnRun = function(self, client, itemID)
        if (!ix.item.list[itemID]) then
            client:Notify("Предмет '" .. itemID .. "' не найден")
            return
        end
        
        local item = ix.item.list[itemID]
        local settings = PLUGIN:GetItemSettings(itemID)
        
        client:ChatPrint("=== Информация о предмете '" .. itemID .. "' ===")
        client:ChatPrint("Название: " .. (item.name or itemID))
        client:ChatPrint("Выпадение: " .. (settings.enabled and "Включено" or "Выключено"))
        client:ChatPrint("Шанс: " .. (settings.chance or 0) .. "%")
        client:ChatPrint("Причина: " .. (settings.reason or "Нет"))
    end
})

-- ============================================================================
-- КОМАНДЫ ПРОСМОТРА ВСЕХ ПРЕДМЕТОВ
-- ============================================================================

ix.command.Add("DropItemsList", {
    description = "Показать список всех предметов с настройками",
    adminOnly = true,
    OnRun = function(self, client)
        local allItems = PLUGIN:GetAllItemsWithSettings()
        
        client:ChatPrint("=== Все предметы сервера ===")
        client:ChatPrint("Всего предметов: " .. #allItems)
        client:ChatPrint("ID | Название | Выпадает | Шанс")
        client:ChatPrint("----------------------------------------")
        
        for _, itemData in ipairs(allItems) do
            local status = itemData.enabled and "Да" or "Нет"
            local chance = itemData.chance or 0
            
            client:ChatPrint(string.format("%s | %s | %s | %d%%", 
                itemData.uniqueID, 
                itemData.name, 
                status, 
                chance
            ))
        end
        
        client:ChatPrint("Используйте /DropItemInfo <ID> для подробной информации")
    end
})

-- УДАЛЕНО: Система категорий убрана

-- ============================================================================
-- КОМАНДЫ ТЕСТИРОВАНИЯ И ДИАГНОСТИКИ
-- ============================================================================

ix.command.Add("DropDebug", {
    description = "Показать отладочную информацию о системе выброса",
    adminOnly = true,
    OnRun = function(self, client)
        client:ChatPrint("=== Debug информация Drop Items Death ===")
        
        -- Общие настройки
        client:ChatPrint(string.format("Система включена: %s", 
                                      ix.config.Get("dropItemsEnabled") and "Да" or "Нет"))
        client:ChatPrint(string.format("Базовый шанс: %d%%", 
                                      ix.config.Get("dropItemsChance", 100)))
        client:ChatPrint(string.format("Радиус разброса: %d", 
                                      ix.config.Get("dropItemsRadius", 80)))
        client:ChatPrint(string.format("Максимум предметов: %d", 
                                      ix.config.Get("dropItemsMaxCount", 10)))
        
        -- Статистика
        local stats = PLUGIN.dropStatistics
        client:ChatPrint(string.format("Всего сбросов: %d", stats.totalDrops))
        client:ChatPrint(string.format("Всего предметов: %d", stats.totalItems))
        
        -- Активные кулдауны
        local activeCooldowns = 0
        for steamID, cooldown in pairs(PLUGIN.playerDropCooldowns) do
            if (cooldown > CurTime()) then
                activeCooldowns = activeCooldowns + 1
            end
        end
        client:ChatPrint(string.format("Активных кулдаунов: %d", activeCooldowns))
        
        -- Предметы с отключенным выпадением
        local disabledItems = 0
        for itemID, settings in pairs(PLUGIN.itemSettings) do
            if (!settings.enabled) then
                disabledItems = disabledItems + 1
            end
        end
        client:ChatPrint(string.format("Предметов с отключенным выпадением: %d", disabledItems))
    end
})

ix.command.Add("DropReset", {
    description = "Сбросить все настройки к значениям по умолчанию",
    adminOnly = true,
    OnRun = function(self, client)
        PLUGIN:ResetToDefaults()
        client:Notify("Настройки сброшены к значениям по умолчанию")
        
        -- Логируем действие
        ix.log.Add(client, "dropItemsConfig", "Reset all settings to defaults")
    end
})

ix.command.Add("DropClearCooldowns", {
    description = "Очистить все кулдауны выброса предметов",
    adminOnly = true,
    OnRun = function(self, client)
        PLUGIN.playerDropCooldowns = {}
        client:Notify("Все кулдауны очищены")
        
        -- Логируем действие
        ix.log.Add(client, "dropItemsConfig", "Cleared all drop cooldowns")
    end
})

-- ============================================================================
-- КОМАНДЫ ДЛЯ АДМИН ПАНЕЛИ
-- ============================================================================

ix.command.Add("DropAdminData", {
    description = "Отправить данные админской панели на клиент",
    adminOnly = true,
    OnRun = function(self, client)
        -- Отправляем все предметы с настройками
        local allItems = PLUGIN:GetAllItemsWithSettings()
        
        net.Start("ixDropItemsBlacklistData")
            net.WriteTable(allItems)
        net.Send(client)
        
        -- Отправляем статистику
        net.Start("ixDropItemsStatsData")
            net.WriteTable(PLUGIN.dropStatistics)
        net.Send(client)
    end
})

-- ============================================================================
-- КОМАНДЫ ЭКСПОРТА/ИМПОРТА
-- ============================================================================

ix.command.Add("DropExport", {
    description = "Экспортировать настройки предметов",
    adminOnly = true,
    OnRun = function(self, client)
        local json = PLUGIN:ExportItemSettings()
        
        -- Записываем в файл
        file.Write("drop_items_settings_export.json", json)
        
        client:Notify("Настройки экспортированы в data/drop_items_settings_export.json")
        client:ChatPrint("JSON данные:")
        client:ChatPrint(json)
    end
})

ix.command.Add("DropImport", {
    description = "Импортировать настройки предметов из файла",
    arguments = ix.type.string,
    adminOnly = true,
    OnRun = function(self, client, filename)
        local json = file.Read(filename, "DATA")
        
        if (!json) then
            client:Notify("Файл не найден: " .. filename)
            return
        end
        
        local data = util.JSONToTable(json)
        if (!data) then
            client:Notify("Ошибка чтения JSON из файла")
            return
        end
        
        if (PLUGIN:ImportItemSettings(data)) then
            client:Notify("Настройки успешно импортированы из " .. filename)
            
            -- Логируем действие
            ix.log.Add(client, "dropItemsConfig", "Imported item settings from " .. filename)
        else
            client:Notify("Ошибка импорта настроек")
        end
    end
})

-- ============================================================================
-- КОМАНДЫ ДИАГНОСТИКИ
-- ============================================================================

ix.command.Add("DropDiagnostic", {
    description = "Полная диагностика системы выброса предметов",
    adminOnly = true,
    OnRun = function(self, client)
        client:ChatPrint("=== Диагностика Drop Items Death ===")
        
        -- Проверяем базовые настройки
        client:ChatPrint("Система включена: " .. tostring(ix.config.Get("dropItemsEnabled", true)))
        client:ChatPrint("Суицид включен: " .. tostring(ix.config.Get("dropItemsSuicideEnabled", true)))
        client:ChatPrint("Базовый шанс: " .. ix.config.Get("dropItemsChance", 100) .. "%")
        
        -- Проверяем персонажа и инвентарь
        local character = client:GetCharacter()
        if (!character) then
            client:ChatPrint("❌ Персонаж не загружен")
            return
        end
        
        client:ChatPrint("✅ Персонаж загружен: " .. character:GetName())
        
        local inventory = character:GetInventory()
        if (!inventory) then
            client:ChatPrint("❌ Инвентарь не найден")
            return
        end
        
        client:ChatPrint("✅ Инвентарь найден: " .. tostring(inventory))
        client:ChatPrint("Инвентарь ID: " .. (inventory:GetID() or "unknown"))
        
        if (!inventory.items) then
            client:ChatPrint("❌ inventory.items пуст")
            -- Попробуем альтернативные способы получить предметы
            local items = inventory:GetItems()
            if (items and table.Count(items) > 0) then
                client:ChatPrint("✅ Найдены предметы через GetItems(): " .. table.Count(items))
                inventory.items = items
            else
                client:ChatPrint("❌ GetItems() тоже пуст")
                return
            end
        end
        
        local totalItems = table.Count(inventory.items)
        client:ChatPrint("✅ Предметов в инвентаре: " .. totalItems)
        
        -- Проверяем каждый предмет
        local canDropCount = 0
        local blockedCount = 0
        
        for itemID, item in pairs(inventory.items) do
            local canDrop = PLUGIN:CanItemDrop(item)
            local settings = PLUGIN:GetItemSettings(item.uniqueID)
            
            if (canDrop) then
                canDropCount = canDropCount + 1
                client:ChatPrint("✅ " .. (item.name or item.uniqueID) .. " - chance: " .. (settings.chance or 0) .. "%")
            else
                blockedCount = blockedCount + 1
                client:ChatPrint("❌ " .. (item.name or item.uniqueID) .. " - " .. (settings.reason or "Заблокирован"))
            end
        end
        
        client:ChatPrint("Итого: " .. canDropCount .. " может выпасть, " .. blockedCount .. " заблокировано")
        
        -- Тестируем функции
        client:ChatPrint("--- Тест функций ---")
        client:ChatPrint("CanPlayerDrop: " .. tostring(PLUGIN:CanPlayerDrop(client)))
        client:ChatPrint("ShouldDropOnDeath (self): " .. tostring(PLUGIN:ShouldDropOnDeath(client, client, nil)))
        
        local testItems = PLUGIN:GetItemsToDrop(inventory)
        client:ChatPrint("Предметов к выбросу: " .. #testItems)
        
        client:ChatPrint("=== Конец диагностики ===")
    end
})

ix.command.Add("DropAddTestItem", {
    description = "Добавить тестовый предмет для проверки системы выброса",
    adminOnly = true,
    OnRun = function(self, client)
        local character = client:GetCharacter()
        if (!character) then
            client:Notify("Персонаж не загружен")
            return
        end
        
        local inventory = character:GetInventory()
        if (!inventory) then
            client:Notify("Инвентарь не найден")
            return
        end
        
        -- Попробуем добавить простой предмет (если он существует)
        local testItems = {"crowbar", "pistol", "defaultitem"}
        
        for _, itemID in ipairs(testItems) do
            if (ix.item.list[itemID]) then
                inventory:Add(itemID, 1, {})
                client:Notify("Добавлен тестовый предмет: " .. itemID)
                return
            end
        end
        
        client:Notify("Не найдено подходящих предметов для теста")
    end
})
