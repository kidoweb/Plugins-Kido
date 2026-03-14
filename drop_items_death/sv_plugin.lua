--[[
    Drop Items on Death - Server Logic
    Серверная логика выбрасывания предметов
--]]

local PLUGIN = PLUGIN

-- ============================================================================
-- ОСНОВНАЯ ЛОГИКА ВЫБРАСЫВАНИЯ
-- ============================================================================

function PLUGIN:DropPlayerItems(client, attacker, inflictor)
    print("[DropItems] Starting drop for player: " .. client:GetName())
    
    if (!self:CanPlayerDrop(client)) then
        print("[DropItems] Cannot drop - CanPlayerDrop returned false")
        return false
    end
    
    local character = client:GetCharacter()
    if (!character) then
        print("[DropItems] Cannot drop - no character")
        return false
    end
    
    local inventory = character:GetInventory()
    if (!inventory) then
        print("[DropItems] Cannot drop - no inventory")
        return false
    end
    
    -- Проверяем есть ли предметы разными способами
    local items = inventory.items or inventory:GetItems() or {}
    if (table.Count(items) == 0 and inventory.slots) then
        for slotID, item in pairs(inventory.slots) do
            if (item and IsValid(item)) then
                items[item:GetID()] = item
            end
        end
    end
    
    if (table.Count(items) == 0) then
        print("[DropItems] Cannot drop - no items found in inventory")
        return false
    end
    
    print("[DropItems] Found " .. table.Count(items) .. " items in inventory")
    
    -- Проверяем условия выброса
    if (!self:ShouldDropOnDeath(client, attacker, inflictor)) then
        print("[DropItems] Cannot drop - ShouldDropOnDeath returned false")
        return false
    end
    
    -- Получаем предметы для выброса
    local itemsToDrop = self:GetItemsToDrop(inventory)
    print("[DropItems] Items to drop: " .. #itemsToDrop)
    
    if (#itemsToDrop == 0) then
        print("[DropItems] No items to drop")
        return false
    end
    
    -- Выбрасываем предметы
    local droppedCount = self:ExecuteItemDrop(client, itemsToDrop)
    print("[DropItems] Dropped count: " .. droppedCount)
    
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
    print("[DropItems] ShouldDropOnDeath check:")
    print("[DropItems] - Client: " .. (IsValid(client) and client:GetName() or "Invalid"))
    print("[DropItems] - Attacker: " .. (IsValid(attacker) and attacker:GetName() or "Invalid/World"))
    print("[DropItems] - Same player: " .. tostring(attacker == client))
    
    -- Проверяем тип смерти
    if (attacker == client) then
        -- Самоубийство
        local suicideEnabled = ix.config.Get("dropItemsSuicideEnabled", true)
        print("[DropItems] - Suicide kill, enabled: " .. tostring(suicideEnabled))
        if (!suicideEnabled) then
            print("[DropItems] - Blocking suicide drop")
            return false
        end
    elseif (IsValid(attacker) and attacker:IsPlayer()) then
        -- Убийство игроком - ВСЕГДА разрешаем выброс
        print("[DropItems] - Player vs player kill - ALWAYS allow")
        return true
    elseif (IsValid(attacker) and attacker:IsNPC()) then
        -- Убийство NPC
        local npcEnabled = ix.config.Get("dropItemsNPCKillEnabled", true)
        print("[DropItems] - NPC kill, enabled: " .. tostring(npcEnabled))
        if (!npcEnabled) then
            print("[DropItems] - Blocking NPC drop")
            return false
        end
    elseif (IsValid(attacker) and !attacker:IsPlayer()) then
        -- Убийство пропом/миром
        local propEnabled = ix.config.Get("dropItemsPropKillEnabled", false)
        print("[DropItems] - Prop/world kill, enabled: " .. tostring(propEnabled))
        if (!propEnabled) then
            print("[DropItems] - Blocking prop/world drop")
            return false
        end
    else
        print("[DropItems] - Unknown attacker type")
    end
    
    -- Проверяем общий шанс
    local chance = ix.config.Get("dropItemsChance", 100)
    local roll = math.random(1, 100)
    print("[DropItems] - Chance roll: " .. roll .. "/" .. chance)
    if (roll > chance) then
        print("[DropItems] - Blocking due to chance")
        return false
    end
    
    print("[DropItems] - Should drop: YES")
    return true
end

function PLUGIN:GetItemsToDrop(inventory)
    local itemsToDrop = {}
    local maxItems = ix.config.Get("dropItemsMaxCount", 10)
    print("[DropItems] GetItemsToDrop - MaxItems: " .. maxItems)
    
    -- Собираем все доступные предметы
    local availableItems = {}
    local totalItems = 0
    local canDropItems = 0
    
    -- Пробуем несколько способов получить предметы из инвентаря
    local items = inventory.items or inventory:GetItems() or {}
    
    -- Если items всё ещё пустой, попробуем другой подход
    if (table.Count(items) == 0 and inventory.slots) then
        print("[DropItems] Trying to get items from slots")
        for slotID, item in pairs(inventory.slots) do
            if (item and IsValid(item)) then
                items[item:GetID()] = item
            end
        end
    end
    
    print("[DropItems] Found items table with " .. table.Count(items) .. " items")
    
    for itemID, item in pairs(items) do
        totalItems = totalItems + 1
        print("[DropItems] Checking item: " .. (item.uniqueID or "unknown") .. " (name: " .. (item.name or "unnamed") .. ")")
        
        if (self:CanItemDrop(item)) then
            canDropItems = canDropItems + 1
            local dropChance = self:GetItemDropChance(item.uniqueID)
            local roll = math.random(1, 100)
            
            print("[DropItems] - Can drop, chance: " .. dropChance .. "%, roll: " .. roll)
            
            if (roll <= dropChance) then
                table.insert(availableItems, {
                    item = item,
                    priority = self:GetItemDropPriority(item)
                })
                print("[DropItems] - Added to drop list")
            else
                print("[DropItems] - Failed chance roll")
            end
        else
            print("[DropItems] - Cannot drop (blacklisted/special)")
        end
    end
    
    print("[DropItems] Total items in inventory: " .. totalItems)
    print("[DropItems] Items that can drop: " .. canDropItems)
    print("[DropItems] Items passed chance roll: " .. #availableItems)
    
    -- Сортируем по приоритету (больший приоритет = больше шанс выпасть)
    table.sort(availableItems, function(a, b)
        return a.priority > b.priority
    end)
    
    -- Выбираем предметы для выброса
    for i = 1, math.min(#availableItems, maxItems) do
        table.insert(itemsToDrop, availableItems[i].item)
    end
    
    print("[DropItems] Final items to drop: " .. #itemsToDrop)
    return itemsToDrop
end

function PLUGIN:CanItemDrop(item)
    if (!item) then 
        print("[DropItems] CanItemDrop: item is nil")
        return false 
    end
    
    -- Проверяем черный список
    if (self:IsItemBlacklisted(item)) then
        print("[DropItems] CanItemDrop: item blacklisted - " .. (item.uniqueID or "unknown"))
        return false
    end
    
    -- Проверяем специальные флаги
    if (item.noDrop or item.permanent or item.important) then
        print("[DropItems] CanItemDrop: item has special flags - " .. (item.uniqueID or "unknown"))
        return false
    end
    
    -- Проверяем экипированные предметы
    if (item:GetData("equip")) then
        print("[DropItems] CanItemDrop: item is equipped - " .. (item.uniqueID or "unknown"))
        return false
    end
    
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

function PLUGIN:PlayerDeath(client, inflictor, attacker)
    timer.Simple(0.1, function()
        if (IsValid(client)) then
            self:DropPlayerItems(client, attacker, inflictor)
        end
    end)
end

function PLUGIN:PlayerDisconnected(client)
    -- Очищаем данные игрока
    if (self.playerDropCooldowns) then
        self.playerDropCooldowns[client:SteamID64()] = nil
    end
end

function PLUGIN:ShutDown()
    -- Сохраняем данные при выключении сервера
    self:SaveData()
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
end
