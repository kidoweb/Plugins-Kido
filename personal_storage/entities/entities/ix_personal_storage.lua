if (SERVER) then
	AddCSLuaFile()
end

ENT.Base = "base_gmodentity"
ENT.Type = "anim"
ENT.PrintName = "Личное хранилище"
ENT.Category = "Helix"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.ShowPlayerInteraction = true
ENT.RenderGroup = RENDERGROUP_BOTH
ENT.bNoPersist = false 

if (SERVER) then
	function ENT:Initialize()
		self:SetModel("models/props_c17/lockers001a.mdl")
		self:SetSolid(SOLID_VPHYSICS)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)

		local physObj = self:GetPhysicsObject()
		if (IsValid(physObj)) then
			physObj:EnableMotion(false)
			physObj:Sleep()
		end
	end

	function ENT:SpawnFunction(client, trace)
		local entity = ents.Create("ix_personal_storage")
		entity:SetPos(trace.HitPos + trace.HitNormal * 8)
		entity:SetAngles(Angle(0, client:EyeAngles().y + 180, 0))
		entity:Spawn()
		entity:Activate()

		return entity
	end

	function ENT:Use(activator)
		if (!IsValid(activator) or !activator:IsPlayer()) then
			return
		end

		local plugin = ix.plugin.Get("personal_storage")
		if (!plugin or !plugin.config) then
			activator:Notify("Плагин личного хранилища недоступен.")
			return
		end

		local character = activator:GetCharacter()
		if (!character) then
			activator:Notify("У вас нет персонажа!")
			return
		end

		local distance = activator:GetPos():Distance(self:GetPos())
		if (distance > plugin.config.maxDistance) then
			activator:Notify("Вы слишком далеко от хранилища!")
			return
		end

		plugin:OpenStorage(activator, character, self)
	end
else
	ENT.PopulateEntityInfo = true

	function ENT:OnPopulateEntityInfo(container)
		local text = container:AddRow("name")
		text:SetImportant()
		text:SetText("Личное хранилище")
		text:SizeToContents()
	end
end
