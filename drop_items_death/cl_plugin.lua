--[[
    Drop Items on Death - Client Side
    Клиентская часть с эффектами и интерфейсом
--]]

local PLUGIN = PLUGIN

-- ============================================================================
-- КЛИЕНТСКИЕ ЭФФЕКТЫ
-- ============================================================================

-- Получение эффектов выброса предметов
net.Receive("ixDropItemsEffect", function()
    local position = net.ReadVector()
    local itemID = net.ReadString()
    
    PLUGIN:CreateClientDropEffect(position, itemID)
end)

function PLUGIN:CreateClientDropEffect(position, itemID)
    if (!ix.config.Get("dropItemsEffectsEnabled", true)) then
        return
    end
    
    -- Создаем частицы
    local effectData = EffectData()
    effectData:SetOrigin(position)
    effectData:SetScale(0.5)
    util.Effect("Sparks", effectData)
    
    -- Создаем световой эффект
    local dlight = DynamicLight(util.CRC("dropitem" .. position:Length()))
    if (dlight) then
        dlight.pos = position
        dlight.r = 255
        dlight.g = 200
        dlight.b = 100
        dlight.brightness = 1
        dlight.size = 64
        dlight.decay = 500
        dlight.dietime = CurTime() + 2
    end
    
    -- Добавляем информационный текст
    self:CreateDropInfoDisplay(position, itemID)
end

function PLUGIN:CreateDropInfoDisplay(position, itemID)
    local endTime = CurTime() + 3
    
    hook.Add("PostDrawTranslucentRenderables", "DropItemInfo" .. util.CRC(position:Length()), function()
        if (CurTime() > endTime) then
            hook.Remove("PostDrawTranslucentRenderables", "DropItemInfo" .. util.CRC(position:Length()))
            return
        end
        
        local alpha = math.max(0, (endTime - CurTime()) / 3) * 255
        local distance = LocalPlayer():GetPos():Distance(position)
        
        if (distance > 500) then return end
        
        local ang = (LocalPlayer():GetPos() - position):Angle()
        ang:RotateAroundAxis(ang:Forward(), 90)
        ang:RotateAroundAxis(ang:Right(), 90)
        
        cam.Start3D2D(position + Vector(0, 0, 20 + math.sin(CurTime() * 3) * 5), ang, 0.1)
            surface.SetFont("ixMediumFont")
            surface.SetTextColor(255, 255, 255, alpha)
            
            local text = "Dropped Item"
            local item = ix.item.list[itemID]
            if (item and item.name) then
                text = item.name
            end
            
            local w, h = surface.GetTextSize(text)
            surface.SetTextPos(-w/2, -h/2)
            surface.DrawText(text)
        cam.End3D2D()
    end)
end

-- ============================================================================
-- АДМИНИСТРАТИВНЫЙ ИНТЕРФЕЙС
-- ============================================================================

function PLUGIN:OpenAdminPanel()
    if (IsValid(self.AdminPanel)) then
        self.AdminPanel:Remove()
    end
    
    self.AdminPanel = vgui.Create("ixDropItemsAdmin")
    self.AdminPanel:MakePopup()
end

-- Создаем админ панель
local PANEL = {}

function PANEL:Init()
    self:SetSize(800, 600)
    self:SetTitle("Drop Items Death - Управление")
    self:Center()
    self:SetDeleteOnClose(true)
    
    self:CreateControls()
    self:LoadData()
end

function PANEL:CreateControls()
    -- Главное меню
    self.PropertySheet = self:Add("DPropertySheet")
    self.PropertySheet:Dock(FILL)
    self.PropertySheet:DockMargin(10, 10, 10, 50)
    
    -- Вкладка: Список предметов
    self.ItemsPanel = vgui.Create("DPanel")
    self.PropertySheet:AddSheet("Предметы", self.ItemsPanel, "icon16/package.png")
    self:CreateItemsControls()
    
    -- Вкладка: Статистика
    self.StatsPanel = vgui.Create("DPanel")
    self.PropertySheet:AddSheet("Статистика", self.StatsPanel, "icon16/chart_bar.png")
    self:CreateStatsControls()
    
    -- Кнопки управления
    self.ButtonPanel = self:Add("DPanel")
    self.ButtonPanel:Dock(BOTTOM)
    self.ButtonPanel:SetHeight(40)
    self.ButtonPanel:DockMargin(10, 0, 10, 10)
    
    self.RefreshButton = self.ButtonPanel:Add("DButton")
    self.RefreshButton:SetText("Обновить")
    self.RefreshButton:Dock(RIGHT)
    self.RefreshButton:SetWide(100)
    self.RefreshButton:DockMargin(5, 5, 0, 5)
    self.RefreshButton.DoClick = function()
        self:LoadData()
    end
    
    self.ResetButton = self.ButtonPanel:Add("DButton")
    self.ResetButton:SetText("Сброс")
    self.ResetButton:Dock(RIGHT)
    self.ResetButton:SetWide(100)
    self.ResetButton:DockMargin(5, 5, 5, 5)
    self.ResetButton.DoClick = function()
        self:ResetToDefaults()
    end
end

function PANEL:CreateItemsControls()
    -- Поиск
    local searchPanel = self.ItemsPanel:Add("DPanel")
    searchPanel:Dock(TOP)
    searchPanel:SetHeight(30)
    searchPanel:DockMargin(10, 10, 10, 5)
    
    local searchLabel = searchPanel:Add("DLabel")
    searchLabel:SetText("Поиск:")
    searchLabel:Dock(LEFT)
    searchLabel:SetWide(50)
    searchLabel:DockMargin(0, 0, 5, 0)
    
    self.SearchEntry = searchPanel:Add("DTextEntry")
    self.SearchEntry:Dock(FILL)
    self.SearchEntry:SetPlaceholderText("Введите название или ID предмета...")
    self.SearchEntry.OnTextChanged = function()
        self:FilterItems()
    end
    
    -- Список предметов
    self.ItemsList = self.ItemsPanel:Add("DListView")
    self.ItemsList:Dock(FILL)
    self.ItemsList:DockMargin(10, 5, 10, 10)
    self.ItemsList:SetMultiSelect(false)
    self.ItemsList:AddColumn("ID")
    self.ItemsList:AddColumn("Название")
    self.ItemsList:AddColumn("Выпадает")
    self.ItemsList:AddColumn("Шанс (%)")
    self.ItemsList:AddColumn("Причина")
    
    -- Двойной клик для редактирования
    self.ItemsList.DoDoubleClick = function(list, index, line)
        self:OpenItemEditDialog(line.itemData)
    end
end

function PANEL:OpenItemEditDialog(itemData)
    local frame = vgui.Create("DFrame")
    frame:SetSize(400, 200)
    frame:SetTitle("Настройка предмета: " .. itemData.name)
    frame:Center()
    frame:MakePopup()
    
    -- Включить/выключить
    local enabledCheck = frame:Add("DCheckBoxLabel")
    enabledCheck:SetText("Включить выпадение")
    enabledCheck:SetChecked(itemData.enabled)
    enabledCheck:Dock(TOP)
    enabledCheck:DockMargin(10, 10, 10, 5)
    
    -- Шанс выпадения
    local chanceLabel = frame:Add("DLabel")
    chanceLabel:SetText("Шанс выпадения (%)")
    chanceLabel:Dock(TOP)
    chanceLabel:DockMargin(10, 5, 10, 5)
    
    local chanceSlider = frame:Add("DNumSlider")
    chanceSlider:SetMin(0)
    chanceSlider:SetMax(100)
    chanceSlider:SetValue(itemData.chance or 100)
    chanceSlider:SetDecimals(0)
    chanceSlider:Dock(TOP)
    chanceSlider:DockMargin(10, 0, 10, 10)
    
    -- Кнопки
    local buttonPanel = frame:Add("DPanel")
    buttonPanel:Dock(BOTTOM)
    buttonPanel:SetHeight(40)
    buttonPanel:DockMargin(10, 0, 10, 10)
    
    local saveButton = buttonPanel:Add("DButton")
    saveButton:SetText("Сохранить")
    saveButton:Dock(RIGHT)
    saveButton:SetWide(100)
    saveButton:DockMargin(5, 5, 0, 5)
    saveButton.DoClick = function()
        -- Отправляем изменения на сервер
        RunConsoleCommand("ix", "DropItemToggle", itemData.uniqueID, enabledCheck:GetChecked() and "1" or "0")
        RunConsoleCommand("ix", "DropItemChance", itemData.uniqueID, tostring(chanceSlider:GetValue()))
        
        -- Обновляем локальные данные
        itemData.enabled = enabledCheck:GetChecked()
        itemData.chance = chanceSlider:GetValue()
        
        self:RefreshItemsList()
        frame:Close()
    end
    
    local cancelButton = buttonPanel:Add("DButton")
    cancelButton:SetText("Отмена")
    cancelButton:Dock(RIGHT)
    cancelButton:SetWide(100)
    cancelButton:DockMargin(5, 5, 5, 5)
    cancelButton.DoClick = function()
        frame:Close()
    end
end

function PANEL:CreateStatsControls()
    -- Общая статистика
    self.StatsInfo = self.StatsPanel:Add("DPanel")
    self.StatsInfo:Dock(TOP)
    self.StatsInfo:SetHeight(100)
    self.StatsInfo:DockMargin(10, 10, 10, 10)
    
    -- Список игроков
    self.PlayerStatsList = self.StatsPanel:Add("DListView")
    self.PlayerStatsList:Dock(FILL)
    self.PlayerStatsList:DockMargin(10, 0, 10, 10)
    self.PlayerStatsList:SetMultiSelect(false)
    self.PlayerStatsList:AddColumn("Игрок")
    self.PlayerStatsList:AddColumn("Сбросов")
    self.PlayerStatsList:AddColumn("Предметов")
    self.PlayerStatsList:AddColumn("Среднее")
end

function PANEL:LoadData()
    -- Загружаем данные из сервера
    self:RefreshItems()
    self:RefreshStats()
end

function PANEL:RefreshItems()
    -- Запрашиваем данные с сервера
    RunConsoleCommand("ix", "DropAdminData")
end

function PANEL:RefreshStats()
    -- Получаем статистику через команду сервера
    RunConsoleCommand("ix", "DropItemsStats")
end

function PANEL:RefreshItemsList()
    if (!self.allItemsData) then return end
    
    self.ItemsList:Clear()
    
    local searchText = self.SearchEntry:GetValue():lower()
    
    for _, itemData in ipairs(self.allItemsData) do
        -- Фильтр поиска
        if (searchText == "" or 
            string.find(itemData.uniqueID:lower(), searchText) or 
            string.find(itemData.name:lower(), searchText)) then
            
            local line = self.ItemsList:AddLine(
                itemData.uniqueID,
                itemData.name,
                itemData.enabled and "Да" or "Нет",
                itemData.chance or 0,
                itemData.reason or "Обычный предмет"
            )
            
            line.itemData = itemData
        end
    end
end

function PANEL:FilterItems()
    self:RefreshItemsList()
end

function PANEL:SaveData()
    -- Сохраняем изменения на сервер
    notification.AddLegacy("Настройки сохранены", NOTIFY_GENERIC, 3)
end

function PANEL:ResetToDefaults()
    Derma_Query("Сбросить все настройки к значениям по умолчанию?", 
                "Подтверждение", 
                "Да", function() 
                    -- Отправляем команду сброса на сервер
                    RunConsoleCommand("ix", "DropReset")
                    self:LoadData()
                end,
                "Нет")
end

vgui.Register("ixDropItemsAdmin", PANEL, "DFrame")

-- ============================================================================
-- СЕТЕВЫЕ ОБРАБОТЧИКИ
-- ============================================================================

-- Получение данных предметов
net.Receive("ixDropItemsBlacklistData", function()
    local data = net.ReadTable()
    
    -- Обновляем все открытые админ панели
    for _, panel in pairs(vgui.GetWorldPanel():GetChildren()) do
        if (panel.ClassName == "ixDropItemsAdmin" and IsValid(panel.ItemsList)) then
            panel.allItemsData = data
            panel:RefreshItemsList()
        end
    end
end)

-- УДАЛЕНО: данные категорий

-- Получение статистики
net.Receive("ixDropItemsStatsData", function()
    local data = net.ReadTable()
    -- Обработка статистики
end)

-- ============================================================================
-- КОМАНДЫ И ХУКИ
-- ============================================================================

concommand.Add("ix_dropitems_admin", function()
    if (LocalPlayer():IsAdmin()) then
        PLUGIN:OpenAdminPanel()
    else
        notification.AddLegacy("У вас нет прав для использования этой команды", NOTIFY_ERROR, 5)
    end
end)

-- Добавляем в меню администратора
hook.Add("PopulateToolMenu", "ixDropItemsAdmin", function()
    spawnmenu.AddToolMenuOption("Utilities", "Admin", "ixDropItemsAdmin", "Drop Items Death", "", "", function(panel)
        panel:ClearControls()
        
        panel:AddControl("Header", {
            Text = "Drop Items Death",
            Description = "Система выбрасывания предметов при смерти"
        })
        
        panel:AddControl("Button", {
            Label = "Открыть панель управления",
            Command = "ix_dropitems_admin",
            Text = "Открыть"
        })
        
        panel:AddControl("Label", {
            Text = "Версия: " .. (PLUGIN.version or "2.0.0")
        })
    end)
end)
