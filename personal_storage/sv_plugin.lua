local PLUGIN = PLUGIN

util.AddNetworkString("ixPersonalStorageMoney")
util.AddNetworkString("ixPersonalStorageMoneyUpdate")

local INV_TYPE = "personal_storage"

local function HasMySQL()
	return istable(mysql)
		and isfunction(mysql.Create)
		and isfunction(mysql.Select)
		and isfunction(mysql.Update)
		and isfunction(mysql.InsertIgnore)
end

function PLUGIN:OnLoaded()
	ix.inventory.Register(INV_TYPE, self.config.storageWidth, self.config.storageHeight)

	if (!HasMySQL()) then
		ErrorNoHalt("[personal_storage] mysql object is unavailable, database features are disabled.\n")
		return
	end

	local query = mysql:Create("ix_personal_storage")
		query:Create("character_id", "INT(11) UNSIGNED NOT NULL")
		query:Create("money", "INT(11) UNSIGNED NOT NULL DEFAULT 0")
		query:Create("inventory_id", "INT(11) UNSIGNED DEFAULT NULL")
		query:PrimaryKey("character_id")
	query:Execute()
end

function PLUGIN:EnsureStorageRow(charID)
	if (!HasMySQL()) then
		return
	end

	local insertQuery = mysql:InsertIgnore("ix_personal_storage")
		insertQuery:Insert("character_id", charID)
		insertQuery:Insert("money", 0)
	insertQuery:Execute()
end

function PLUGIN:GetOrCreateStorageInventory(character, callback)
	if (!HasMySQL()) then
		if (callback) then
			callback(nil)
		end

		return
	end

	local charID = character:GetID()
	local cached = self.storageInventories[charID]

	if (cached) then
		if (callback) then
			callback(cached)
		end

		return
	end

	local query = mysql:Select("ix_personal_storage")
		query:Where("character_id", charID)
		query:Callback(function(result)
			local row = istable(result) and result[1]
			local invID = row and tonumber(row.inventory_id) or nil

			if (invID and invID > 0) then
				local loaded = ix.inventory.Get(invID)

				if (loaded) then
					self.storageInventories[charID] = loaded

					if (callback) then
						callback(loaded)
					end

					return
				end

				ix.inventory.Restore(invID, self.config.storageWidth, self.config.storageHeight, function(inventory)
					self.storageInventories[charID] = inventory

					if (callback) then
						callback(inventory)
					end
				end)

				return
			end

			self:EnsureStorageRow(charID)

			ix.inventory.New(charID, INV_TYPE, function(inventory)
				self.storageInventories[charID] = inventory

				local updateQuery = mysql:Update("ix_personal_storage")
					updateQuery:Where("character_id", charID)
					updateQuery:Update("inventory_id", inventory:GetID())
				updateQuery:Execute()

				if (callback) then
					callback(inventory)
				end
			end)
		end)
	query:Execute()
end

function PLUGIN:GetStorageMoney(character)
	return self.storageMoney[character:GetID()] or 0
end

function PLUGIN:SetStorageMoney(character, amount)
	local charID = character:GetID()
	local value = math.max(0, math.floor(tonumber(amount) or 0))

	self.storageMoney[charID] = value

	if (!HasMySQL()) then
		return
	end

	self:EnsureStorageRow(charID)

	local query = mysql:Update("ix_personal_storage")
		query:Where("character_id", charID)
		query:Update("money", value)
	query:Execute()
end

function PLUGIN:AddStorageMoney(character, amount)
	self:SetStorageMoney(character, self:GetStorageMoney(character) + (tonumber(amount) or 0))
end

function PLUGIN:TakeStorageMoney(character, amount)
	local current = self:GetStorageMoney(character)
	local takeAmount = math.Clamp(math.floor(tonumber(amount) or 0), 0, current)

	self:SetStorageMoney(character, current - takeAmount)

	return takeAmount
end

function PLUGIN:SaveStorageData(character)
	if (!character) then return end
	if (!HasMySQL()) then return end

	local charID = character:GetID()
	local value = self.storageMoney[charID]

	if (value == nil) then return end

	local query = mysql:Update("ix_personal_storage")
		query:Where("character_id", charID)
		query:Update("money", value)
	query:Execute()
end

function PLUGIN:OpenStorage(client, character, entity)
	if (!IsValid(client) or !character or !IsValid(entity)) then
		return
	end

	self:GetOrCreateStorageInventory(character, function(storageInventory)
		if (!IsValid(client) or !IsValid(entity) or !storageInventory) then
			return
		end

		local storageMoney = self:GetStorageMoney(character)

		ix.storage.Open(client, storageInventory, {
			name = "Личное хранилище",
			entity = entity,
			-- У каждого персонажа отдельный инвентарь хранилища, поэтому
			-- блокировка single-user тут только провоцирует ложный "storageInUse".
			bMultipleUsers = true,
			searchText = "Открытие хранилища...",
			searchTime = 0.5,
			OnPlayerClose = function(player)
				local char = IsValid(player) and player:GetCharacter() or nil

				if (char) then
					self:SaveStorageData(char)
				end
			end,
			data = {
				storageMoney = storageMoney,
				characterMoney = character:GetMoney(),
				moneyTransferEnabled = self.config.moneyTransferEnabled
			}
		})

		net.Start("ixPersonalStorageMoneyUpdate")
			net.WriteInt(storageMoney, 32)
			net.WriteInt(character:GetMoney(), 32)
		net.Send(client)
	end)
end

net.Receive("ixPersonalStorageMoney", function(length, client)
	if (!PLUGIN.config.moneyTransferEnabled) then
		return
	end

	if ((client.ixPersonalStorageMoneyNext or 0) > CurTime()) then
		return
	end

	client.ixPersonalStorageMoneyNext = CurTime() + 0.2

	local character = client:GetCharacter()
	local inventory = client.ixOpenStorage

	if (!character or !inventory or !inventory.storageInfo) then
		return
	end

	local entity = inventory.storageInfo.entity

	if (!IsValid(entity) or entity:GetClass() != "ix_personal_storage") then
		return
	end

	if (client:GetPos():Distance(entity:GetPos()) > (PLUGIN.config.maxDistance or 100)) then
		return
	end

	local action = net.ReadString()
	local amount = math.max(0, math.floor(net.ReadInt(32)))

	if (amount <= 0) then
		return
	end

	if (action == "deposit") then
		local charMoney = character:GetMoney()
		local finalAmount = math.Clamp(amount, 0, charMoney)

		if (finalAmount <= 0) then return end

		character:SetMoney(charMoney - finalAmount)
		PLUGIN:AddStorageMoney(character, finalAmount)

		client:Notify("Вы положили " .. ix.currency.Get(finalAmount) .. " в хранилище.")
	elseif (action == "withdraw") then
		local taken = PLUGIN:TakeStorageMoney(character, amount)

		if (taken <= 0) then return end

		character:SetMoney(character:GetMoney() + taken)
		client:Notify("Вы взяли " .. ix.currency.Get(taken) .. " из хранилища.")
	else
		return
	end

	net.Start("ixPersonalStorageMoneyUpdate")
		net.WriteInt(PLUGIN:GetStorageMoney(character), 32)
		net.WriteInt(character:GetMoney(), 32)
	net.Send(client)
end)
