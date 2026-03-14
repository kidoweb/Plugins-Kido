--[[
    Drop Items on Death - Server Logic
    Серверная логика выбрасывания предметов
--]]

local PLUGIN = PLUGIN

-- Включить отладочный вывод (поставить true только для диагностики)
local DROP_DEBUG = false
local function dropLog(...) if (DROP_DEBUG) then print("[DropItems]", ...) end end

-- ============================================================================
-- ОСНОВНАЯ ЛОГИКА ВЫБРАСЫВАНИЯ
-- ============================================================================

function PLUGIN:DropPlayerItems(client, attacker, inflictor, characterOverride)
    dropLog("Starting drop for player:", IsValid(client) and client:GetName() or "?")
    
    if (!IsValid(client)) then return false end
    if (!self:CanPlayerDrop(client)) then
        dropLog("Cannot drop - CanPlayerDrop returned false")
        return false
    end
    
    -- Используем переданный персонаж (при смерти) или текущий — чтобы не выбросить вещи нового персонажа после респавна
    local character = characterOverride or client:GetCharacter()
    if (!character) then
        dropLog("Cannot drop - no character")
        return false
    end
    
    local inventory = character:GetInventory()
    if (!inventory) then
        dropLog("Cannot drop - no inventory")
        return false
    end
    
    local items = self:GetInventoryItemsTable(inventory)
    if (table.Count(items) == 0) then
        dropLog("Cannot drop - no items found in inventory")
        return false
    end
    
    if (!self:ShouldDropOnDeath(client, attacker, inflictor)) then
        dropLog("Cannot drop - ShouldDropOnDeath returned false")
        return false
    end
    
    local itemsToDrop = self:GetItemsToDrop(inventory)
    if (#itemsToDrop == 0) then
        dropLog("No items to drop")
        return false
    end
    
    local droppedCount = self:ExecuteItemDrop(client, itemsToDrop)
    if (droppedCount > 0) then
        -- Устанавливаем кулдаун
        self:SetPlayerDropCooldown(client)
        
        -- Обновляем статистику
        self:UpdateStatistics(client, droppedCount)
        
        -- Уведомляем игроков
        self:NotifyPlayersAboutDrop(client, droppedCount)
        
        -- Логируем событие
        self:LogDropEvent(client, attacker, droppedCount)
        
        return true
    end
    
    return false
end

function PLUGIN:ShouldDropOnDeath(client, attacker, inflictor)
    if (attacker == client) then
        if (!ix.config.Get("dropItemsSuicideEnabled", true)) then
            dropLog("Blocking suicide drop")
            return false
        end
    elseif (IsValid(attacker) and attacker:IsPlayer()) then
        return true
    elseif (IsValid(attacker) and attacker:IsNPC()) then
        if (!ix.config.Get("dropItemsNPCKillEnabled", true)) then
            dropLog("Blocking NPC drop")
            return false
        end
    elseif (IsValid(attacker) and !attacker:IsPlayer()) then
        if (!ix.config.Get("dropItemsPropKillEnabled", false)) then
            dropLog("Blocking prop/world drop")
            return false
        end
    end
    
    local chance = ix.config.Get("dropItemsChance", 100)
    if (math.random(1, 100) > chance) then
        dropLog("Blocking due to chance")
        return false
    end
    return true
end

-- Единая функция получения таблицы предметов инвентаря (убирает дублирование)
function PLUGIN:GetInventoryItemsTable(inventory)
    local items = inventory.items or inventory:GetItems() or {}
    if (table.Count(items) == 0 and inventory.slots) then
        for slotID, item in pairs(inventory.slots) do
            if (item and IsValid(item)) then
                items[item:GetID()] = item
            end
        end
    end
    return items
end

function PLUGIN:GetItemsToDrop(inventory)
    local itemsToDrop = {}
    local maxItems = ix.config.Get("dropItemsMaxCount", 10)
    local items = self:GetInventoryItemsTable(inventory)
    
    local availableItems = {}
    for itemID, item in pairs(items) do
        if (self:CanItemDrop(item)) then
            local dropChance = self:GetItemDropChance(item.uniqueID)
            if (math.random(1, 100) <= dropChance) then
                table.insert(availableItems, {
                    item = item,
                    priority = self:GetItemDropPriority(item)
                })
            end
        end
    end
    
    table.sort(availableItems, function(a, b) return a.priority > b.priority end)
    for i = 1, math.min(#availableItems, maxItems) do
        table.insert(itemsToDrop, availableItems[i].item)
    end
    return itemsToDrop
end

function PLUGIN:CanItemDrop(item)
    if (!item) then return false end
    if (self:IsItemBlacklisted(item)) then return false end
    if (item.noDrop or item.permanent or item.important) then return false end
    if (item:GetData("equip")) then return false end
    return true
end

function PLUGIN:GetItemDropPriority(item)
    if (!item) then return 0 end
    
    local priority = 1
    
    -- Базовый приоритет зависит от цены предмета
    if (item.price) then
        priority = priority + math.floor(item.price / 100)
    end
    
    -- Учитываем редкость
    if (item.rarity) then
        priority = priority + item.rarity
    end
    
    -- Увеличиваем приоритет для оружия
    if (item.base and string.find(item.base, "weapon")) then
        priority = priority + 3
    end
    
    return priority
end

function PLUGIN:ExecuteItemDrop(client, itemsToDrop)
    local droppedCount = 0
    local playerPos = client:GetPos()
    local radius = ix.config.Get("dropItemsRadius", 80)
    local maxHeight = ix.config.Get("dropItemsMaxHeight", 150)
    local force = ix.config.Get("dropItemsForce", 200)
    
    for i, item in ipairs(itemsToDrop) do
        -- Вычисляем позицию выброса
        local dropPos = self:CalculateDropPosition(playerPos, radius, i, #itemsToDrop)
        
        -- Выбрасываем предмет
        local success = item:Transfer(nil, nil, nil, client)
        
        if (success and IsValid(item.entity)) then
            -- Устанавливаем позицию
            item.entity:SetPos(dropPos)
            
            -- Добавляем физику
            local phys = item.entity:GetPhysicsObject()
            if (IsValid(phys)) then
                local forceVector = self:CalculateDropForce(playerPos, dropPos, force, maxHeight)
                phys:ApplyForceCenter(forceVector)
                phys:AddAngleVelocity(VectorRand() * 100)
            end
            
            -- Добавляем эффекты
            if (ix.config.Get("dropItemsEffectsEnabled", true)) then
                self:CreateDropEffects(dropPos, item)
            end
            
            droppedCount = droppedCount + 1
        end
    end
    
    return droppedCount
end

function PLUGIN:CalculateDropPosition(centerPos, radius, index, totalItems)
    local angle = (360 / totalItems) * (index - 1)
    local distance = math.random(radius * 0.3, radius)
    
    local dropPos = centerPos + Vector(
        math.cos(math.rad(angle)) * distance,
        math.sin(math.rad(angle)) * distance,
        math.random(20, 50)
    )
    
    -- Проверяем поверхность
    local trace = util.TraceLine({
        start = dropPos + Vector(0, 0, 100),
        endpos = dropPos - Vector(0, 0, 200),
        mask = MASK_SOLID_BRUSHONLY
    })
    
    if (trace.Hit) then
        dropPos = trace.HitPos + Vector(0, 0, 5)
    end
    
    return dropPos
end

function PLUGIN:CalculateDropForce(playerPos, dropPos, baseForce, maxHeight)
    local direction = (dropPos - playerPos):GetNormalized()
    local upwardForce = math.random(maxHeight * 0.5, maxHeight)
    local sidewaysForce = math.random(baseForce * 0.7, baseForce)
    
    return direction * sidewaysForce + Vector(0, 0, upwardForce)
end

-- ============================================================================
-- ЭФФЕКТЫ И УВЕДОМЛЕНИЯ
-- ============================================================================

function PLUGIN:CreateDropEffects(position, item)
    -- Визуальные эффекты
    local effectData = EffectData()
    effectData:SetOrigin(position)
    effectData:SetScale(1)
    util.Effect("ManhackSparks", effectData)
    
    -- Звуковые эффекты
    if (ix.config.Get("dropItemsSoundsEnabled", true)) then
        sound.Play("physics/metal/metal_box_impact_hard" .. math.random(1, 3) .. ".wav", 
                   position, 60, math.random(80, 120))
    end
    
    -- Отправляем эффекты клиентам
    net.Start("ixDropItemsEffect")
        net.WriteVector(position)
        net.WriteString(item.uniqueID or "unknown")
    net.SendPVS(position)
end

function PLUGIN:NotifyPlayersAboutDrop(client, itemCount)
    local notifyRadius = ix.config.Get("dropItemsNotifyRadius", 400)
    local playerPos = client:GetPos()
    
    for _, ply in ipairs(player.GetAll()) do
        if (IsValid(ply) and ply:GetPos():Distance(playerPos) <= notifyRadius) then
            ply:NotifyLocalized("dropItemsNotification", client:GetName(), itemCount)
        end
    end
end

function PLUGIN:LogDropEvent(client, attacker, itemCount)
    local logMessage = string.format(
        "Player %s [%s] dropped %d items on death",
        client:GetName(),
        client:SteamID(),
        itemCount
    )
    
    if (IsValid(attacker) and attacker:IsPlayer()) then
        logMessage = logMessage .. string.format(" (killed by %s [%s])", 
                                                 attacker:GetName(), 
                                                 attacker:SteamID())
    end
    
    ix.log.Add(client, "itemDrop", logMessage)
end

-- ============================================================================
-- ХУКИ И СОБЫТИЯ
-- ============================================================================

-- Сохраняем персонажа на момент смерти, чтобы не выбросить вещи нового персонажа после быстрого респавна
function PLUGIN:PlayerDeath(client, inflictor, attacker)
    local character = IsValid(client) and client:GetCharacter()
    if (!character) then return end
    timer.Simple(0.1, function()
        if (IsValid(client)) then
            self:DropPlayerItems(client, attacker, inflictor, character)
        end
    end)
end

function PLUGIN:PlayerDisconnected(client)
    if (self.playerDropCooldowns and IsValid(client)) then
        self.playerDropCooldowns[client:SteamID64()] = nil
    end
end

-- Периодическая очистка истёкших кулдаунов (раз в 60 сек), без вызова каждый кадр
local COOLDOWN_CLEANUP_TIMER = "ix_dropitems_cooldown_cleanup"
function PLUGIN:CleanupExpiredCooldowns()
    local now = CurTime()
    local cooldowns = self.playerDropCooldowns
    if (cooldowns) then
        for steamID, untilTime in pairs(cooldowns) do
            if (untilTime <= now) then cooldowns[steamID] = nil end
        end
    end
end


-- ============================================================================
-- КОМАНДЫ
-- ============================================================================

ix.command.Add("DropItemsReload", {
    description = "Перезагружает конфигурацию системы выброса предметов",
    adminOnly = true,
    OnRun = function(self, client)
        PLUGIN:LoadData()
        client:NotifyLocalized("dropItemsConfigReloaded")
    end
})

ix.command.Add("DropItemsTest", {
    description = "Тестирует выброс предметов для указанного игрока",
    arguments = {
        bit.bor(ix.type.player, ix.type.optional)
    },
    adminOnly = true,
    OnRun = function(self, client, target)
        target = target or client
        
        if (PLUGIN:DropPlayerItems(target, client, nil)) then
            client:NotifyLocalized("dropItemsTestDrop", target:GetName())
        else
            client:NotifyLocalized("dropItemsNoItems")
        end
    end
})

ix.command.Add("DropItemsStats", {
    description = "Показывает статистику системы выброса предметов",
    adminOnly = true,
    OnRun = function(self, client)
        local stats = PLUGIN.dropStatistics
        
        client:ChatPrint(L("dropItemsStatsHeader", client))
        client:ChatPrint(string.format(L("dropItemsStatsTotal", client), 
                                      stats.totalDrops, stats.totalItems))
        
        for steamID, playerStats in pairs(stats.playerStats) do
            client:ChatPrint(string.format(L("dropItemsStatsPlayer", client),
                                          playerStats.name, 
                                          playerStats.drops, 
                                          playerStats.items))
        end
    end
})

-- ============================================================================
-- ИНИЦИАЛИЗАЦИЯ
-- ============================================================================

function PLUGIN:InitPostEntity()
    self:LoadData()
    timer.Remove(COOLDOWN_CLEANUP_TIMER)
    timer.Create(COOLDOWN_CLEANUP_TIMER, 60, 0, function()
        if (PLUGIN.CleanupExpiredCooldowns) then PLUGIN:CleanupExpiredCooldowns() end
    end)
end

function PLUGIN:ShutDown()
    timer.Remove(COOLDOWN_CLEANUP_TIMER)
    self:SaveData()
end
