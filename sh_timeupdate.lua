local PLUGIN = PLUGIN

PLUGIN.name = "Обновление времени"
PLUGIN.description = "Автоматическое обновление времени сервера с реального времени."
PLUGIN.author = "kido"

if (SERVER) then
	function PLUGIN:InitPostEntity()
		local currentDate = os.date("*t")
		
		ix.config.Set("year", currentDate.year)
		ix.config.Set("month", currentDate.month)
		ix.config.Set("day", currentDate.day)
		
		local timeString = currentDate.day .. "." .. currentDate.month .. "." .. currentDate.year
		print("[Time Update] Время автоматически установлено: " .. timeString .. " (используйте /SyncTime для обновления)")
	end
end

ix.command.Add("SyncTime", {
	description = "Синхронизировать время игры с реальным временем сервера.",
	adminOnly = true,
	OnRun = function(self, client)
		if (SERVER) then
			local currentDate = os.date("*t")
			
			ix.config.Set("year", currentDate.year)
			ix.config.Set("month", currentDate.month)
			ix.config.Set("day", currentDate.day)
			
			local timeString = currentDate.day .. "." .. currentDate.month .. "." .. currentDate.year
			client:Notify("Время синхронизировано с сервером: " .. timeString)
			print("[Time Update] " .. client:Name() .. " принудительно синхронизировал время: " .. timeString)
		end
	end
})