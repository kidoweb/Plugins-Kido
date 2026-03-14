local PLUGIN = PLUGIN

-- Переменные для хранения панели управления деньгами
if (!PLUGIN.moneyPanel) then
	PLUGIN.moneyPanel = nil
	PLUGIN.moneyInfo = nil
end

-- Обработка обновления денег в хранилище
net.Receive("ixPersonalStorageMoneyUpdate", function()
	local storageMoney = net.ReadInt(32)
	local characterMoney = net.ReadInt(32)
	
	-- Обновляем данные в UI, если хранилище открыто
	if (ix.storage.activePanel) then
		local context = ix.storage.activePanel.context
		if (context) then
			context.data = context.data or {}
			context.data.storageMoney = storageMoney
			context.data.characterMoney = characterMoney
			
			-- Обновляем информацию о деньгах, если панель существует
			if (IsValid(PLUGIN.moneyInfo)) then
				PLUGIN.moneyInfo:SetText("У вас: " .. ix.currency.Get(characterMoney) .. " | В хранилище: " .. ix.currency.Get(storageMoney))
			end
		end
	end
end)

-- Хук для добавления панели управления деньгами в UI хранилища
hook.Add("CreateStoragePanel", "ixPersonalStorageMoney", function(panel, inventory, context)
	if (!context or !context.data or !context.data.moneyTransferEnabled) then
		return
	end

	if (!IsValid(context.entity) or context.entity:GetClass() != "ix_personal_storage") then
		return
	end

	-- Создаем панель управления деньгами
	local moneyPanel = panel:Add("Panel")
	moneyPanel:Dock(TOP)
	moneyPanel:SetTall(80)
	moneyPanel:DockMargin(0, 0, 0, 5)
	moneyPanel.Paint = function(self, w, h)
		surface.SetDrawColor(30, 30, 30, 255)
		surface.DrawRect(0, 0, w, h)
		
		surface.SetDrawColor(60, 60, 60, 255)
		surface.DrawOutlinedRect(0, 0, w, h)
	end

	local title = moneyPanel:Add("DLabel")
	title:Dock(TOP)
	title:SetTall(25)
	title:SetText("Управление деньгами")
	title:SetFont("ixSmallFont")
	title:SetTextColor(color_white)
	title:SetContentAlignment(5)
	title:DockMargin(5, 5, 5, 0)

	local moneyInfo = moneyPanel:Add("DLabel")
	moneyInfo:Dock(TOP)
	moneyInfo:SetTall(20)
	moneyInfo:SetText("")
	moneyInfo:SetFont("ixSmallFont")
	moneyInfo:SetTextColor(color_white)
	moneyInfo:SetContentAlignment(5)
	moneyInfo:DockMargin(5, 2, 5, 0)

	-- Сохраняем ссылку на панель и информацию
	PLUGIN.moneyPanel = moneyPanel
	PLUGIN.moneyInfo = moneyInfo

	-- Функция обновления информации о деньгах
	local function UpdateMoneyInfo()
		local storageMoney = context.data.storageMoney or 0
		local characterMoney = context.data.characterMoney or 0
		moneyInfo:SetText("У вас: " .. ix.currency.Get(characterMoney) .. " | В хранилище: " .. ix.currency.Get(storageMoney))
	end

	-- Обновляем информацию о деньгах
	UpdateMoneyInfo()

	-- Кнопки для управления деньгами
	local buttonPanel = moneyPanel:Add("Panel")
	buttonPanel:Dock(TOP)
	buttonPanel:SetTall(30)
	buttonPanel:DockMargin(5, 5, 5, 5)

	local depositButton = buttonPanel:Add("DButton")
	depositButton:Dock(LEFT)
	depositButton:SetWide(120)
	depositButton:SetText("Положить")
	depositButton:SetFont("ixSmallFont")
	depositButton.DoClick = function()
		Derma_StringRequest(
			"Положить деньги",
			"Сколько денег положить в хранилище?",
			"",
			function(text)
				local amount = tonumber(text)
				if (amount and amount > 0) then
					net.Start("ixPersonalStorageMoney")
						net.WriteString("deposit")
						net.WriteInt(amount, 32)
					net.SendToServer()
				end
			end
		)
	end

	local withdrawButton = buttonPanel:Add("DButton")
	withdrawButton:Dock(RIGHT)
	withdrawButton:SetWide(120)
	withdrawButton:SetText("Взять")
	withdrawButton:SetFont("ixSmallFont")
	withdrawButton.DoClick = function()
		Derma_StringRequest(
			"Взять деньги",
			"Сколько денег взять из хранилища?",
			"",
			function(text)
				local amount = tonumber(text)
				if (amount and amount > 0) then
					net.Start("ixPersonalStorageMoney")
						net.WriteString("withdraw")
						net.WriteInt(amount, 32)
					net.SendToServer()
				end
			end
		)
	end
end)

-- Очистка при закрытии хранилища
hook.Add("StorageClosed", "ixPersonalStorageCleanup", function()
	PLUGIN.moneyPanel = nil
	PLUGIN.moneyInfo = nil
end)
