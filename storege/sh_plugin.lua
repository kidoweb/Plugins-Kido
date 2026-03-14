-- luacheck: globals STOREG_DEPOSIT STOREG_WITHDRAW STOREG_BOTH STOREG_WELCOME STOREG_LEAVE STOREG_NOTRADE
-- luacheck: globals STOREG_STOCK STOREG_MAXSTOCK STOREG_BLOCKED

local PLUGIN = PLUGIN

PLUGIN.name = "Склад фракции"
PLUGIN.author = "kido"
PLUGIN.description = "Добавляет систему склада фракции с управлением администратором."

CAMI.RegisterPrivilege({
	Name = "Helix - Управление складом фракции",
	MinAccess = "admin"
})

-- Storage modes
PLUGIN.STOREG_DEPOSIT = 1
PLUGIN.STOREG_WITHDRAW = 2
PLUGIN.STOREG_BOTH = 3

-- Keys for storage messages
PLUGIN.STOREG_WELCOME = 1
PLUGIN.STOREG_LEAVE = 2
PLUGIN.STOREG_NOTRADE = 3

-- Keys for item information
PLUGIN.STOREG_STOCK = 1
PLUGIN.STOREG_MAXSTOCK = 2
PLUGIN.STOREG_BLOCKED = 3

if (SERVER) then
	util.AddNetworkString("ixStoregOpen")
	util.AddNetworkString("ixStoregClose")
	util.AddNetworkString("ixStoregTrade")
	util.AddNetworkString("ixStoregEdit")
	util.AddNetworkString("ixStoregEditFinish")
	util.AddNetworkString("ixStoregEditor")
	util.AddNetworkString("ixStoregStock")
	util.AddNetworkString("ixStoregAddItem")

	function PLUGIN:SaveData()
		local data = {}

		for _, entity in ipairs(ents.FindByClass("ix_storeg")) do
			local bodygroups = {}

			for _, v in ipairs(entity:GetBodyGroups() or {}) do
				bodygroups[v.id] = entity:GetBodygroup(v.id)
			end

			data[#data + 1] = {
				name = entity:GetDisplayName(),
				description = entity:GetDescription(),
				pos = entity:GetPos(),
				angles = entity:GetAngles(),
				model = entity:GetModel(),
				skin = entity:GetSkin(),
				bodygroups = bodygroups,
				bubble = entity:GetNoBubble(),
				items = entity.items,
				factions = entity.factions,
				classes = entity.classes
			}
		end

		self:SetData(data)
	end

	function PLUGIN:LoadData()
		for _, v in ipairs(self:GetData() or {}) do
			local entity = ents.Create("ix_storeg")
			entity:SetPos(v.pos)
			entity:SetAngles(v.angles)
			entity:Spawn()

			entity:SetModel(v.model)
			entity:SetSkin(v.skin or 0)
			entity:InitPhysObj()

			entity:SetNoBubble(v.bubble)
			entity:SetDisplayName(v.name)
			entity:SetDescription(v.description)

			for id, bodygroup in pairs(v.bodygroups or {}) do
				entity:SetBodygroup(id, bodygroup)
			end

			local items = {}

			for uniqueID, data in pairs(v.items) do
				items[tostring(uniqueID)] = data
			end

			entity.items = items
			entity.factions = v.factions or {}
			entity.classes = v.classes or {}
		end
	end

	function PLUGIN:CanStoregDepositItem(client, storeg, itemID)
		local itemData = storeg.items[itemID]
		local char = client:GetCharacter()

		if (!itemData or !char) then
			return false
		end

		-- Check if item is blocked
		if (itemData[STOREG_BLOCKED]) then
			return false
		end

		-- Check stock limits
		local stock = itemData[STOREG_STOCK] or 0
		local maxStock = itemData[STOREG_MAXSTOCK]

		if (maxStock and stock >= maxStock) then
			return false
		end

		return true
	end

	ix.log.AddType("storegUse", function(client, ...)
		local arg = {...}
		return string.format("%s использовал склад фракции '%s'.", client:Name(), arg[1])
	end)

	ix.log.AddType("storegDeposit", function(client, ...)
		local arg = {...}
		return string.format("%s положил '%s' в склад фракции '%s'.", client:Name(), arg[1], arg[2])
	end)

	ix.log.AddType("storegWithdraw", function(client, ...)
		local arg = {...}
		return string.format("%s взял '%s' из склада фракции '%s'.", client:Name(), arg[1], arg[2])
	end)

	net.Receive("ixStoregClose", function(length, client)
		local entity = client.ixStoreg

		if (IsValid(entity)) then
			for k, v in ipairs(entity.receivers) do
				if (v == client) then
					table.remove(entity.receivers, k)
					break
				end
			end

			client.ixStoreg = nil
		end
	end)

	local function UpdateEditReceivers(receivers, key, value)
		net.Start("ixStoregEdit")
			net.WriteString(key)
			net.WriteType(value)
		net.Send(receivers)
	end

	net.Receive("ixStoregEdit", function(length, client)
		if (!CAMI.PlayerHasAccess(client, "Helix - Управление складом фракции", nil)) then
			return
		end

		local entity = client.ixStoreg

		if (!IsValid(entity)) then
			return
		end

		local key = net.ReadString()
		local data = net.ReadType()
		local feedback = true

		if (key == "name") then
			entity:SetDisplayName(data)
		elseif (key == "description") then
			entity:SetDescription(data)
		elseif (key == "bubble") then
			entity:SetNoBubble(data)
		elseif (key == "blocked") then
			local uniqueID = data[1]
			local blocked = data[2]

			entity.items[uniqueID] = entity.items[uniqueID] or {}
			entity.items[uniqueID][STOREG_BLOCKED] = blocked

			UpdateEditReceivers(entity.receivers, key, data)
		elseif (key == "stockMax") then
			local uniqueID = data[1]
			data[2] = math.max(math.Round(tonumber(data[2]) or 1), 1)

			entity.items[uniqueID] = entity.items[uniqueID] or {}
			entity.items[uniqueID][STOREG_MAXSTOCK] = data[2]
			entity.items[uniqueID][STOREG_STOCK] = math.Clamp(entity.items[uniqueID][STOREG_STOCK] or 0, 0, data[2])

			data[3] = entity.items[uniqueID][STOREG_STOCK]

			UpdateEditReceivers(entity.receivers, key, data)
		elseif (key == "stock") then
			local uniqueID = data[1]

			entity.items[uniqueID] = entity.items[uniqueID] or {}

			if (!entity.items[uniqueID][STOREG_MAXSTOCK]) then
				data[2] = math.max(math.Round(tonumber(data[2]) or 0), 0)
				entity.items[uniqueID][STOREG_MAXSTOCK] = data[2]
			end

			data[2] = math.Clamp(math.Round(tonumber(data[2]) or 0), 0, entity.items[uniqueID][STOREG_MAXSTOCK])
			entity.items[uniqueID][STOREG_STOCK] = data[2]

			UpdateEditReceivers(entity.receivers, key, data)
		elseif (key == "faction") then
			local faction = ix.faction.teams[data]

			if (faction) then
				entity.factions[data] = !entity.factions[data]

				if (!entity.factions[data]) then
					entity.factions[data] = nil
				end
			end

			local uniqueID = data
			data = {uniqueID, entity.factions[uniqueID]}
		elseif (key == "class") then
			local class

			for _, v in ipairs(ix.class.list) do
				if (v.uniqueID == data) then
					class = v
					break
				end
			end

			if (class) then
				entity.classes[data] = !entity.classes[data]

				if (!entity.classes[data]) then
					entity.classes[data] = nil
				end
			end

			local uniqueID = data
			data = {uniqueID, entity.classes[uniqueID]}
		elseif (key == "model") then
			entity:SetModel(data)
			entity:InitPhysObj()
			entity:SetAnim()
		end

		PLUGIN:SaveData()

		if (feedback) then
			local receivers = {}

			for _, v in ipairs(entity.receivers) do
				if (CAMI.PlayerHasAccess(v, "Helix - Управление складом фракции", nil)) then
					receivers[#receivers + 1] = v
				end
			end

			net.Start("ixStoregEditFinish")
				net.WriteString(key)
				net.WriteType(data)
			net.Send(receivers)
		end
	end)

	net.Receive("ixStoregTrade", function(length, client)
		if ((client.ixStoregTry or 0) < CurTime()) then
			client.ixStoregTry = CurTime() + 0.33
		else
			return
		end

		local entity = client.ixStoreg

		if (!IsValid(entity) or client:GetPos():Distance(entity:GetPos()) > 192) then
			return
		end

		if (!entity:CanAccess(client)) then
			return
		end

		local uniqueID = net.ReadString()
		local isDepositing = net.ReadBool()

		if (entity.items[uniqueID] and
			hook.Run("CanPlayerTradeWithStoreg", client, entity, uniqueID, isDepositing) != false) then

			if (isDepositing) then
				-- Depositing item to storage
				local found = false
				local name

				local stock = entity:GetStock(uniqueID)
				local maxStock = entity:GetMaxStock(uniqueID)

				if (maxStock and stock >= maxStock) then
					return client:NotifyLocalized("storegMaxStock")
				end

				-- Check if item is blocked
				if (entity.items[uniqueID][STOREG_BLOCKED]) then
					return client:NotifyLocalized("storegItemBlocked")
				end

				local invOkay = true

				for k, _ in client:GetCharacter():GetInventory():Iter() do
					if (k.uniqueID == uniqueID and k:GetID() != 0 and ix.item.instances[k:GetID()] and k:GetData("equip", false) == false) then
						invOkay = k:Remove()
						found = true
						name = L(k.name, client)
						break
					end
				end

				if (!found) then
					return
				end

				if (!invOkay) then
					client:GetCharacter():GetInventory():Sync(client, true)
					return client:NotifyLocalized("tellAdmin", "storeg!deposit")
				end

				client:NotifyLocalized("storegDepositSuccess", name)
				entity:AddStock(uniqueID)

				ix.log.Add(client, "storegDeposit", name, entity:GetDisplayName())
			else
				-- Withdrawing item from storage
				local stock = entity:GetStock(uniqueID)

				if (!stock or stock < 1) then
					return client:NotifyLocalized("storegNoStock")
				end

				local name = L(ix.item.list[uniqueID].name, client)

				client:NotifyLocalized("storegWithdrawSuccess", name)

				if (!client:GetCharacter():GetInventory():Add(uniqueID)) then
					ix.item.Spawn(uniqueID, client)
				else
					net.Start("ixStoregAddItem")
						net.WriteString(uniqueID)
					net.Send(client)
				end

				entity:TakeStock(uniqueID)

				ix.log.Add(client, "storegWithdraw", name, entity:GetDisplayName())
			end

			PLUGIN:SaveData()
			hook.Run("CharacterStoregTraded", client, entity, uniqueID, isDepositing)
		else
			client:NotifyLocalized("storegNoTrade")
		end
	end)
else
	net.Receive("ixStoregOpen", function()
		local entity = net.ReadEntity()

		if (!IsValid(entity)) then
			return
		end

		entity.items = net.ReadTable()

		ix.gui.storeg = vgui.Create("ixStoreg")
		ix.gui.storeg:SetReadOnly(false)
		ix.gui.storeg:Setup(entity)
	end)

	net.Receive("ixStoregEditor", function()
		local entity = net.ReadEntity()

		if (!IsValid(entity) or !CAMI.PlayerHasAccess(LocalPlayer(), "Helix - Управление складом фракции", nil)) then
			return
		end

		entity.items = net.ReadTable()
		entity.messages = net.ReadTable()
		entity.factions = net.ReadTable()
		entity.classes = net.ReadTable()

		ix.gui.storeg = vgui.Create("ixStoreg")
		ix.gui.storeg:SetReadOnly(true)
		ix.gui.storeg:Setup(entity)
		ix.gui.storegEditor = vgui.Create("ixStoregEditor")
	end)

	net.Receive("ixStoregEdit", function()
		local panel = ix.gui.storeg

		if (!IsValid(panel)) then
			return
		end

		local entity = panel.entity

		if (!IsValid(entity)) then
			return
		end

		local key = net.ReadString()
		local data = net.ReadType()

		if (key == "blocked") then
			entity.items[data[1]] = entity.items[data[1]] or {}
			entity.items[data[1]][STOREG_BLOCKED] = data[2]

			if (data[2]) then
				panel:removeItem(data[1])
			else
				panel:addItem(data[1])
			end
		elseif (key == "stockMax") then
			local uniqueID = data[1]
			local value = data[2]
			local current = data[3]

			entity.items[uniqueID] = entity.items[uniqueID] or {}
			entity.items[uniqueID][STOREG_MAXSTOCK] = value
			entity.items[uniqueID][STOREG_STOCK] = current
		elseif (key == "stock") then
			local uniqueID = data[1]
			local value = data[2]

			entity.items[uniqueID] = entity.items[uniqueID] or {}

			if (!entity.items[uniqueID][STOREG_MAXSTOCK]) then
				entity.items[uniqueID][STOREG_MAXSTOCK] = value
			end

			entity.items[uniqueID][STOREG_STOCK] = value
		end
	end)

	net.Receive("ixStoregEditFinish", function()
		local panel = ix.gui.storeg
		local editor = ix.gui.storegEditor

		if (!IsValid(panel) or !IsValid(editor)) then
			return
		end

		local entity = panel.entity

		if (!IsValid(entity)) then
			return
		end

		local key = net.ReadString()
		local data = net.ReadType()

		if (key == "name") then
			editor.name:SetText(data)
		elseif (key == "description") then
			editor.description:SetText(data)
		elseif (key == "bubble") then
			editor.bubble.noSend = true
			editor.bubble:SetValue(data and 1 or 0)
		elseif (key == "blocked") then
			local uniqueID = data[1]
			local blocked = data[2]

			if (editor.lines[uniqueID]) then
				editor.lines[uniqueID]:SetValue(3, blocked and L"storegBlocked" or L"storegAllowed")
			end
		elseif (key == "stockMax" or key == "stock") then
			local current = entity:GetStock(data)
			local max = entity:GetMaxStock(data)

			if (editor.lines[data]) then
				editor.lines[data]:SetValue(4, current.."/"..max)
			end
		elseif (key == "faction") then
			local uniqueID = data[1]
			local state = data[2]
			local editPanel = ix.gui.editorFaction

			entity.factions[uniqueID] = state

			if (IsValid(editPanel) and IsValid(editPanel.factions[uniqueID])) then
				editPanel.factions[uniqueID]:SetChecked(state == true)
			end
		elseif (key == "class") then
			local uniqueID = data[1]
			local state = data[2]
			local editPanel = ix.gui.editorFaction

			entity.classes[uniqueID] = state

			if (IsValid(editPanel) and IsValid(editPanel.classes[uniqueID])) then
				editPanel.classes[uniqueID]:SetChecked(state == true)
			end
		elseif (key == "model") then
			editor.model:SetText(entity:GetModel())
		end

		surface.PlaySound("buttons/button14.wav")
	end)

	net.Receive("ixStoregStock", function()
		local panel = ix.gui.storeg

		if (!IsValid(panel)) then
			return
		end

		local entity = panel.entity

		if (!IsValid(entity)) then
			return
		end

		local uniqueID = net.ReadString()
		local amount = net.ReadUInt(16)

		entity.items[uniqueID] = entity.items[uniqueID] or {}
		entity.items[uniqueID][STOREG_STOCK] = amount

		local editor = ix.gui.storegEditor

		if (IsValid(editor)) then
			local max = entity:GetMaxStock(uniqueID)

			if (editor.lines[uniqueID]) then
				editor.lines[uniqueID]:SetValue(4, amount .. "/" .. max)
			end
		end
	end)

	net.Receive("ixStoregAddItem", function()
		local uniqueID = net.ReadString()

		if (IsValid(ix.gui.storeg)) then
			ix.gui.storeg:addItem(uniqueID)
		end
	end)
end

properties.Add("storeg_edit", {
	MenuLabel = "Редактировать склад фракции",
	Order = 999,
	MenuIcon = "icon16/box_edit.png",

	Filter = function(self, entity, client)
		if (!IsValid(entity)) then return false end
		if (entity:GetClass() != "ix_storeg") then return false end
		if (!gamemode.Call( "CanProperty", client, "storeg_edit", entity)) then return false end

		return CAMI.PlayerHasAccess(client, "Helix - Управление складом фракции", nil)
	end,

	Action = function(self, entity)
		self:MsgStart()
			net.WriteEntity(entity)
		self:MsgEnd()
	end,

	Receive = function(self, length, client)
		local entity = net.ReadEntity()

		if (!IsValid(entity)) then return end
		if (!self:Filter(entity, client)) then return end

		entity.receivers[#entity.receivers + 1] = client

		local itemsTable = {}

		for k, v in pairs(entity.items) do
			if (!table.IsEmpty(v)) then
				itemsTable[k] = v
			end
		end

		client.ixStoreg = entity

		net.Start("ixStoregEditor")
			net.WriteEntity(entity)
			net.WriteTable(itemsTable)
			net.WriteTable(entity.messages)
			net.WriteTable(entity.factions)
			net.WriteTable(entity.classes)
		net.Send(client)
	end
})