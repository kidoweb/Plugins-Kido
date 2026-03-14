local PLUGIN = PLUGIN

local function HasMySQL()
	return istable(mysql)
		and isfunction(mysql.Select)
		and isfunction(mysql.Update)
end

-- Загрузка данных хранилища при загрузке персонажа
hook.Add("CharacterLoaded", "ixPersonalStorageLoad", function(character)
	if (!HasMySQL()) then
		return
	end

	local charID = character:GetID()
	PLUGIN:EnsureStorageRow(charID)
	
	-- Загружаем деньги из базы данных
	local query = mysql:Select("ix_personal_storage")
		query:Where("character_id", charID)
		query:Callback(function(result)
			if (istable(result) and #result > 0) then
				local data = result[1]
				PLUGIN.storageMoney[charID] = tonumber(data.money) or 0
			else
				PLUGIN.storageMoney[charID] = 0
			end
		end)
	query:Execute()

	-- Ленивая инициализация персонального инвентаря на старте персонажа
	PLUGIN:GetOrCreateStorageInventory(character)
end)

-- Сохранение данных хранилища при сохранении персонажа
hook.Add("CharacterSave", "ixPersonalStorageSave", function(character)
	if (!HasMySQL()) then
		return
	end

	local charID = character:GetID()
	
	-- Сохраняем деньги (включая 0)
	if (PLUGIN.storageMoney[charID] != nil) then
		local query = mysql:Update("ix_personal_storage")
			query:Where("character_id", charID)
			query:Update("money", PLUGIN.storageMoney[charID])
		query:Execute()
	end
	
	-- Инвентарь сохраняется автоматически через систему Helix
end)

-- Очистка данных из памяти при отключении игрока
hook.Add("PlayerDisconnected", "ixPersonalStorageCleanup", function(client)
	local character = client:GetCharacter()
	if (character) then
		local charID = character:GetID()
		
		-- Сохраняем данные перед очисткой
		PLUGIN:SaveStorageData(character)
		
		-- Очищаем из памяти
		PLUGIN.storageInventories[charID] = nil
		PLUGIN.storageMoney[charID] = nil
	end
end)

-- Сохранение данных при выгрузке персонажа
hook.Add("CharacterUnloaded", "ixPersonalStorageUnload", function(character)
	local charID = character:GetID()
	
	-- Сохраняем данные
	PLUGIN:SaveStorageData(character)
	
	-- Очищаем из памяти
	PLUGIN.storageInventories[charID] = nil
	PLUGIN.storageMoney[charID] = nil
end)
