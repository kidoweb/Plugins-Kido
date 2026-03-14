ENT.Type = "anim"
ENT.PrintName = "Склад фракции"
ENT.Category = "Helix"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.isStoreg = true
ENT.bNoPersist = true

function ENT:SetupDataTables()
	self:NetworkVar("Bool", 0, "NoBubble")
	self:NetworkVar("String", 0, "DisplayName")
	self:NetworkVar("String", 1, "Description")
end

function ENT:Initialize()
	if (SERVER) then
		self:SetModel("models/props_c17/FurnitureDrawer001a.mdl")
		self:SetUseType(SIMPLE_USE)
		self:SetMoveType(MOVETYPE_NONE)
		self:DrawShadow(true)
		self:InitPhysObj()

		self:AddCallback("OnAngleChange", function(entity)
			local mins, maxs = entity:GetAxisAlignedBoundingBox()
			entity:SetCollisionBounds(mins, maxs)
		end)

		self.items = {}
		self.messages = {}
		self.factions = {}
		self.classes = {}

		self:SetDisplayName("Склад фракции")
		self:SetDescription("Склад для предметов фракции")

		self.receivers = {}
	end
end

function ENT:InitPhysObj()
	local mins, maxs = self:GetAxisAlignedBoundingBox()
	local bPhysObjCreated = self:PhysicsInitBox(mins, maxs)

	if (bPhysObjCreated) then
		local physObj = self:GetPhysicsObject()
		physObj:EnableMotion(false)
		physObj:Sleep()
	end
end

function ENT:GetAxisAlignedBoundingBox()
	local mins, maxs = self:GetModelBounds()
	mins = Vector(mins.x, mins.y, 0)
	mins, maxs = self:GetRotatedAABB(mins, maxs)

	return mins, maxs
end

function ENT:CanAccess(client)
	local bAccess = false
	local uniqueID = ix.faction.indices[client:Team()].uniqueID

	if (self.factions and !table.IsEmpty(self.factions)) then
		if (self.factions[uniqueID]) then
			bAccess = true
		else
			return false
		end
	end

	if (bAccess and self.classes and !table.IsEmpty(self.classes)) then
		local class = ix.class.list[client:GetCharacter():GetClass()]
		local classID = class and class.uniqueID

		if (classID and !self.classes[classID]) then
			return false
		end
	end

	return true
end

function ENT:GetStock(uniqueID)
	if (self.items[uniqueID]) then
		return self.items[uniqueID][STOREG_STOCK] or 0
	end
	
	return 0
end

function ENT:GetMaxStock(uniqueID)
	if (self.items[uniqueID]) then
		return self.items[uniqueID][STOREG_MAXSTOCK] or 100
	end
	
	return 100
end

function ENT:CanDepositItem(client, uniqueID)
	local data = self.items[uniqueID]

	if (!data or !client:GetCharacter() or !ix.item.list[uniqueID]) then
		return false
	end

	-- Check if item is blocked
	if (data[STOREG_BLOCKED]) then
		return false
	end

	-- Check stock limits
	local stock = self:GetStock(uniqueID)
	local maxStock = self:GetMaxStock(uniqueID)

	if (stock >= maxStock) then
		return false
	end

	return true
end

function ENT:CanWithdrawItem(client, uniqueID)
	local data = self.items[uniqueID]

	if (!data or !client:GetCharacter() or !ix.item.list[uniqueID]) then
		return false
	end

	local stock = self:GetStock(uniqueID)

	if (stock < 1) then
		return false
	end

	return true
end

function ENT:SetAnim()
	for k, v in ipairs(self:GetSequenceList()) do
		if (v:lower():find("idle") and v != "idlenoise") then
			return self:ResetSequence(k)
		end
	end

	if (self:GetSequenceCount() > 1) then
		self:ResetSequence(4)
	end
end

if (SERVER) then
	local PLUGIN = PLUGIN

	function ENT:SpawnFunction(client, trace)
		local angles = (trace.HitPos - client:GetPos()):Angle()
		angles.r = 0
		angles.p = 0
		angles.y = angles.y + 180

		local entity = ents.Create("ix_storeg")
		entity:SetPos(trace.HitPos)
		entity:SetAngles(angles)
		entity:Spawn()

		PLUGIN:SaveData()

		return entity
	end

	function ENT:Use(activator)
		local character = activator:GetCharacter()

		if (!self:CanAccess(activator) or hook.Run("CanPlayerUseStoreg", activator, self) == false) then
			if (self.messages[STOREG_NOTRADE]) then
				activator:ChatPrint(self:GetDisplayName()..": "..self.messages[STOREG_NOTRADE])
			else
				activator:NotifyLocalized("storegNoTrade")
			end

			return
		end

		self.receivers[#self.receivers + 1] = activator

		if (self.messages[STOREG_WELCOME]) then
			activator:ChatPrint(self:GetDisplayName()..": "..self.messages[STOREG_WELCOME])
		end

		local items = {}

		-- Only send what is needed.
		for k, v in pairs(self.items) do
			if (!table.IsEmpty(v) and (CAMI.PlayerHasAccess(activator, "Helix - Управление складом фракции", nil) or !v[STOREG_BLOCKED])) then
				items[k] = v
			end
		end

		activator.ixStoreg = self

		-- force sync to prevent outdated inventories
		if (character) then
			character:GetInventory():Sync(activator, true)
		end

		net.Start("ixStoregOpen")
			net.WriteEntity(self)
			net.WriteTable(items)
		net.Send(activator)

		ix.log.Add(activator, "storegUse", self:GetDisplayName())
	end

	function ENT:SetStock(uniqueID, value)
		self.items[uniqueID] = self.items[uniqueID] or {}
		self.items[uniqueID][STOREG_STOCK] = math.max(value or 0, 0)

		if (self.items[uniqueID][STOREG_MAXSTOCK]) then
			self.items[uniqueID][STOREG_STOCK] = math.min(self.items[uniqueID][STOREG_STOCK], self.items[uniqueID][STOREG_MAXSTOCK])
		end

		net.Start("ixStoregStock")
			net.WriteString(uniqueID)
			net.WriteUInt(self.items[uniqueID][STOREG_STOCK], 16)
		net.Send(self.receivers)
	end

	function ENT:AddStock(uniqueID, value)
		local currentStock = self:GetStock(uniqueID)
		self:SetStock(uniqueID, currentStock + (value or 1))
	end

	function ENT:TakeStock(uniqueID, value)
		local currentStock = self:GetStock(uniqueID)
		self:SetStock(uniqueID, currentStock - (value or 1))
	end
else
	function ENT:CreateBubble()
		self.bubble = ClientsideModel("models/extras/info_speech.mdl", RENDERGROUP_OPAQUE)
		self.bubble:SetPos(self:GetPos() + Vector(0, 0, 84))
		self.bubble:SetModelScale(0.6, 0)
	end

	function ENT:Draw()
		local bubble = self.bubble

		if (IsValid(bubble)) then
			local realTime = RealTime()

			bubble:SetRenderOrigin(self:GetPos() + Vector(0, 0, 84 + math.sin(realTime * 3) * 0.05))
			bubble:SetRenderAngles(Angle(0, realTime * 100, 0))
		end

		self:DrawModel()
	end

	function ENT:Think()
		local noBubble = self:GetNoBubble()

		if (IsValid(self.bubble) and noBubble) then
			self.bubble:Remove()
		elseif (!IsValid(self.bubble) and !noBubble) then
			self:CreateBubble()
		end

		if ((self.nextAnimCheck or 0) < CurTime()) then
			self:SetAnim()
			self.nextAnimCheck = CurTime() + 60
		end

		self:SetNextClientThink(CurTime() + 0.25)

		return true
	end

	function ENT:OnRemove()
		if (IsValid(self.bubble)) then
			self.bubble:Remove()
		end
	end

	ENT.PopulateEntityInfo = true

	function ENT:OnPopulateEntityInfo(container)
		local name = container:AddRow("name")
		name:SetImportant()
		name:SetText(self:GetDisplayName())
		name:SizeToContents()

		local descriptionText = self:GetDescription()

		if (descriptionText != "") then
			local description = container:AddRow("description")
			description:SetText(self:GetDescription())
			description:SizeToContents()
		end
	end
end