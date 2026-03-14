local PANEL = {}

AccessorFunc(PANEL, "bReadOnly", "ReadOnly", FORCE_BOOL)

function PANEL:Init()
	self:SetSize(ScrW() * 0.45, ScrH() * 0.65)
	self:SetTitle("")
	self:MakePopup()
	self:Center()

	local header = self:Add("DPanel")
	header:SetTall(34)
	header:Dock(TOP)

	self.storegName = header:Add("DLabel")
	self.storegName:Dock(LEFT)
	self.storegName:SetWide(self:GetWide() * 0.5 - 7)
	self.storegName:SetText("Склад фракции")
	self.storegName:SetTextInset(4, 0)
	self.storegName:SetTextColor(color_white)
	self.storegName:SetFont("ixMediumFont")

	self.ourName = header:Add("DLabel")
	self.ourName:Dock(RIGHT)
	self.ourName:SetWide(self:GetWide() * 0.5 - 7)
	self.ourName:SetText(L"you")
	self.ourName:SetTextInset(0, 0)
	self.ourName:SetTextColor(color_white)
	self.ourName:SetFont("ixMediumFont")

	local footer = self:Add("DPanel")
	footer:SetTall(34)
	footer:Dock(BOTTOM)
	footer:SetPaintBackground(false)

	self.storegWithdraw = footer:Add("DButton")
	self.storegWithdraw:SetFont("ixMediumFont")
	self.storegWithdraw:SetWide(self.storegName:GetWide())
	self.storegWithdraw:Dock(LEFT)
	self.storegWithdraw:SetContentAlignment(5)
	self.storegWithdraw:SetText(L"storegWithdraw")
	self.storegWithdraw:SetTextColor(color_white)

	self.storegWithdraw.DoClick = function(this)
		if (IsValid(self.activeWithdraw)) then
			net.Start("ixStoregTrade")
				net.WriteString(self.activeWithdraw.item)
				net.WriteBool(false)
			net.SendToServer()
		end
	end

	self.storegDeposit = footer:Add("DButton")
	self.storegDeposit:SetFont("ixMediumFont")
	self.storegDeposit:SetWide(self.ourName:GetWide())
	self.storegDeposit:Dock(RIGHT)
	self.storegDeposit:SetContentAlignment(5)
	self.storegDeposit:SetText(L"storegDeposit")
	self.storegDeposit:SetTextColor(color_white)
	self.storegDeposit.DoClick = function(this)
		if (IsValid(self.activeDeposit)) then
			net.Start("ixStoregTrade")
				net.WriteString(self.activeDeposit.item)
				net.WriteBool(true)
			net.SendToServer()
		end
	end

	self.storage = self:Add("DScrollPanel")
	self.storage:SetWide(self:GetWide() * 0.5 - 7)
	self.storage:Dock(LEFT)
	self.storage:DockMargin(0, 4, 0, 4)
	self.storage:SetPaintBackground(true)

	self.storageItems = self.storage:Add("DListLayout")
	self.storageItems:SetSize(self.storage:GetSize())
	self.storageItems:DockPadding(0, 0, 0, 4)
	self.storageItems:SetTall(ScrH())

	self.inventory = self:Add("DScrollPanel")
	self.inventory:SetWide(self:GetWide() * 0.5 - 7)
	self.inventory:Dock(RIGHT)
	self.inventory:DockMargin(0, 4, 0, 4)
	self.inventory:SetPaintBackground(true)

	self.inventoryItems = self.inventory:Add("DListLayout")
	self.inventoryItems:SetSize(self.inventory:GetSize())
	self.inventoryItems:DockPadding(0, 0, 0, 4)

	self.storageList = {}
	self.inventoryList = {}
end

function PANEL:addItem(uniqueID, listID)
	local entity = self.entity
	local items = entity.items
	local data = items[uniqueID]

	if ((!listID or listID == "storage") and !IsValid(self.storageList[uniqueID])
	and ix.item.list[uniqueID]) then
		if (data and !data[STOREG_BLOCKED] and (data[STOREG_STOCK] or 0) > 0) then
			local item = self.storageItems:Add("ixStoregItem")
			item:Setup(uniqueID)

			self.storageList[uniqueID] = item
			self.storageItems:InvalidateLayout()
		end
	end

	if ((!listID or listID == "inventory") and !IsValid(self.inventoryList[uniqueID])
	and LocalPlayer():GetCharacter():GetInventory():HasItem(uniqueID)) then
		if (data and !data[STOREG_BLOCKED]) then
			local item = self.inventoryItems:Add("ixStoregItem")
			item:Setup(uniqueID)
			item.isLocal = true

			self.inventoryList[uniqueID] = item
			self.inventoryItems:InvalidateLayout()
		end
	end
end

function PANEL:removeItem(uniqueID, listID)
	if (!listID or listID == "storage") then
		if (IsValid(self.storageList[uniqueID])) then
			self.storageList[uniqueID]:Remove()
			self.storageItems:InvalidateLayout()
		end
	end

	if (!listID or listID == "inventory") then
		if (IsValid(self.inventoryList[uniqueID])) then
			self.inventoryList[uniqueID]:Remove()
			self.inventoryItems:InvalidateLayout()
		end
	end
end

function PANEL:Setup(entity)
	self.entity = entity
	self:SetTitle(entity:GetDisplayName())
	self.storegName:SetText(entity:GetDisplayName())

	self.storegDeposit:SetEnabled(!self:GetReadOnly())
	self.storegWithdraw:SetEnabled(!self:GetReadOnly())

	for k, _ in SortedPairs(entity.items) do
		self:addItem(k, "storage")
	end

	for _, v in SortedPairs(LocalPlayer():GetCharacter():GetInventory():GetItems()) do
		self:addItem(v.uniqueID, "inventory")
	end
end

function PANEL:OnRemove()
	net.Start("ixStoregClose")
	net.SendToServer()

	if (IsValid(ix.gui.storegEditor)) then
		ix.gui.storegEditor:Remove()
	end
end

function PANEL:Think()
	local entity = self.entity

	if (!IsValid(entity)) then
		self:Remove()

		return
	end

	if ((self.nextUpdate or 0) < CurTime()) then
		self:SetTitle(self.entity:GetDisplayName())
		self.storegName:SetText(entity:GetDisplayName())
		self.ourName:SetText(L"you")

		self.nextUpdate = CurTime() + 0.25
	end
end

function PANEL:OnItemSelected(panel)
	if (panel.isLocal) then
		self.storegDeposit:SetText(L"storegDeposit" or "Внести")
	else
		self.storegWithdraw:SetText(L"storegWithdraw" or "Забрать")
	end
end

vgui.Register("ixStoreg", PANEL, "DFrame")

PANEL = {}

function PANEL:Init()
	self:SetTall(36)
	self:DockMargin(4, 4, 4, 0)

	self.icon = self:Add("SpawnIcon")
	self.icon:SetPos(2, 2)
	self.icon:SetSize(32, 32)
	self.icon:SetModel("models/error.mdl")

	self.name = self:Add("DLabel")
	self.name:Dock(FILL)
	self.name:DockMargin(42, 0, 0, 0)
	self.name:SetFont("ixChatFont")
	self.name:SetTextColor(color_white)
	self.name:SetExpensiveShadow(1, Color(0, 0, 0, 200))

	self.click = self:Add("DButton")
	self.click:Dock(FILL)
	self.click:SetText("")
	self.click.Paint = function() end
	self.click.DoClick = function(this)
		if (self.isLocal) then
			ix.gui.storeg.activeDeposit = self
		else
			ix.gui.storeg.activeWithdraw = self
		end

		ix.gui.storeg:OnItemSelected(self)
	end
end

function PANEL:SetCallback(callback)
	self.click.DoClick = function(this)
		callback()
		self.selected = true
	end
end

function PANEL:Setup(uniqueID)
	local item = ix.item.list[uniqueID]

	if (item) then
		self.item = uniqueID
		self.icon:SetModel(item:GetModel(), item:GetSkin())
		self.name:SetText(item:GetName())
		self.itemName = item:GetName()

		self.click:SetHelixTooltip(function(tooltip)
			ix.hud.PopulateItemTooltip(tooltip, item)

			local entity = ix.gui.storeg.entity
			if (entity and entity.items[self.item]) then
				local info = entity.items[self.item]
				local stock = info[STOREG_STOCK] or 0
				local maxStock = info[STOREG_MAXSTOCK] or 100
				
				local stockRow = tooltip:AddRowAfter("name", "stock")
				stockRow:SetText(string.format("На складе: %d/%d", stock, maxStock))
				stockRow:SetBackgroundColor(derma.GetColor("Info", self))
				stockRow:SizeToContents()
			end
		end)
	end
end

function PANEL:Think()
	if ((self.nextUpdate or 0) < CurTime()) then
		local entity = ix.gui.storeg.entity

		if (entity and self.isLocal) then
			local count = LocalPlayer():GetCharacter():GetInventory():GetItemCount(self.item)

			if (count == 0) then
				self:Remove()
			end
		end

		self.nextUpdate = CurTime() + 0.1
	end
end

function PANEL:Paint(w, h)
	if (ix.gui.storeg.activeDeposit == self or ix.gui.storeg.activeWithdraw == self) then
		surface.SetDrawColor(ix.config.Get("color"))
	else
		surface.SetDrawColor(0, 0, 0, 100)
	end

	surface.DrawRect(0, 0, w, h)
end

vgui.Register("ixStoregItem", PANEL, "DPanel")
