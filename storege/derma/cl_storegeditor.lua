local PANEL = {}

function PANEL:Init()
	local entity = ix.gui.storeg.entity

	self:SetSize(320, 480)
	self:MoveLeftOf(ix.gui.storeg, 8)
	self:MakePopup()
	self:CenterVertical()
	self:SetTitle(L"storegEditor")
	self.lblTitle:SetTextColor(color_white)

	self.name = self:Add("DTextEntry")
	self.name:Dock(TOP)
	self.name:SetText(entity:GetDisplayName())
	self.name:SetPlaceholderText(L"name")
	self.name.OnEnter = function(this)
		if (entity:GetDisplayName() != this:GetText()) then
			self:updateStoreg("name", this:GetText())
		end
	end

	self.description = self:Add("DTextEntry")
	self.description:Dock(TOP)
	self.description:DockMargin(0, 4, 0, 0)
	self.description:SetText(entity:GetDescription())
	self.description:SetPlaceholderText(L"description")
	self.description.OnEnter = function(this)
		if (entity:GetDescription() != this:GetText()) then
			self:updateStoreg("description", this:GetText())
		end
	end

	self.model = self:Add("DTextEntry")
	self.model:Dock(TOP)
	self.model:DockMargin(0, 4, 0, 0)
	self.model:SetText(entity:GetModel())
	self.model:SetPlaceholderText(L"model")
	self.model.OnEnter = function(this)
		if (entity:GetModel():lower() != this:GetText():lower()) then
			self:updateStoreg("model", this:GetText():lower())
		end
	end

	self.bubble = self:Add("DCheckBoxLabel")
	self.bubble:SetText(L"storegNoBubble")
	self.bubble:Dock(TOP)
	self.bubble:DockMargin(0, 4, 0, 0)
	self.bubble:SetValue(entity:GetNoBubble() and 1 or 0)
	self.bubble.OnChange = function(this, value)
		if (this.noSend) then
			this.noSend = nil
		else
			self:updateStoreg("bubble", value)
		end
	end

	self.faction = self:Add("DButton")
	self.faction:SetText(L"storegFaction")
	self.faction:Dock(TOP)
	self.faction:SetTextColor(color_white)
	self.faction:DockMargin(0, 4, 0, 0)
	self.faction.DoClick = function(this)
		if (IsValid(ix.gui.editorFaction)) then
			ix.gui.editorFaction:Remove()
		end

		ix.gui.editorFaction = vgui.Create("ixStoregFactionEditor")
		ix.gui.editorFaction.updateStoreg = self.updateStoreg
		ix.gui.editorFaction.entity = entity
		ix.gui.editorFaction:Setup()
	end

	self.searchBar = self:Add("DTextEntry")
	self.searchBar:Dock(TOP)
	self.searchBar:DockMargin(0, 4, 0, 0)
	self.searchBar:SetUpdateOnType(true)
	self.searchBar:SetPlaceholderText("Поиск...")
	self.searchBar.OnValueChange = function(this, value)
		self:ReloadItemList(value)
	end

	local menu

	self.items = self:Add("DListView")
	self.items:Dock(FILL)
	self.items:DockMargin(0, 4, 0, 0)
	self.items:AddColumn(L"name").Header:SetTextColor(color_black)
	self.items:AddColumn(L"category").Header:SetTextColor(color_black)
	self.items:AddColumn(L"storegStatus").Header:SetTextColor(color_black)
	self.items:AddColumn(L"stock").Header:SetTextColor(color_black)
	self.items:SetMultiSelect(false)
	self.items.OnRowRightClick = function(this, index, line)
		if (IsValid(menu)) then
			menu:Remove()
		end

		local uniqueID = line.item

		menu = DermaMenu()
			-- Block/Unblock item
			local isBlocked = entity.items[uniqueID] and entity.items[uniqueID][STOREG_BLOCKED]
			
			if (isBlocked) then
				menu:AddOption(L"storegUnblock", function()
					self:updateStoreg("blocked", {uniqueID, false})
				end):SetImage("icon16/accept.png")
			else
				menu:AddOption(L"storegBlock", function()
					self:updateStoreg("blocked", {uniqueID, true})
				end):SetImage("icon16/cancel.png")
			end

			local itemTable = ix.item.list[uniqueID]

			-- Set the stock of the item
			local stock, menuPanel = menu:AddSubMenu(L"stock")
			menuPanel:SetImage("icon16/table.png")

			-- Edit the maximum stock for this item
			stock:AddOption(L"storegEditMaxStock", function()
				local max = entity:GetMaxStock(uniqueID)

				Derma_StringRequest(
					itemTable.GetName and itemTable:GetName() or L(itemTable.name),
					L"storegStockMaxReq",
					max or 100,
					function(text)
						self:updateStoreg("stockMax", {uniqueID, text})
					end
				)
			end):SetImage("icon16/table_edit.png")

			-- Edit the current stock of this item
			stock:AddOption(L"storegEditCurStock", function()
				Derma_StringRequest(
					itemTable.GetName and itemTable:GetName() or L(itemTable.name),
					L"storegStockCurReq",
					entity:GetStock(uniqueID) or 0,
					function(text)
						self:updateStoreg("stock", {uniqueID, text})
					end
				)
			end):SetImage("icon16/table_edit.png")
		menu:Open()
	end

	self:ReloadItemList()
end

function PANEL:ReloadItemList(filter)
	local entity = ix.gui.storeg.entity
	self.lines = {}

	self.items:Clear()

	for k, v in SortedPairs(ix.item.list) do
		local itemName = v.GetName and v:GetName() or L(v.name)

		if (filter and !itemName:lower():find(filter:lower(), 1, false)) then
			continue
		end

		local isBlocked = entity.items[k] and entity.items[k][STOREG_BLOCKED]
		local current = entity:GetStock(k)
		local max = entity:GetMaxStock(k)
		
		local status
		if (isBlocked) then
			status = L"storegBlocked"
		else
			status = L"storegAllowed"
		end
		
		local panel = self.items:AddLine(
			itemName,
			v.category or L"none",
			status,
			current.."/"..max
		)

		panel.item = k
		self.lines[k] = panel
	end
end

function PANEL:OnRemove()
	if (IsValid(ix.gui.storeg)) then
		ix.gui.storeg:Remove()
	end

	if (IsValid(ix.gui.editorFaction)) then
		ix.gui.editorFaction:Remove()
	end
end

function PANEL:updateStoreg(key, value)
	net.Start("ixStoregEdit")
		net.WriteString(key)
		net.WriteType(value)
	net.SendToServer()
end

vgui.Register("ixStoregEditor", PANEL, "DFrame")
