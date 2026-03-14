PLUGIN.name = "Личное хранилище"
PLUGIN.author = "kido"
PLUGIN.description = "Добавляет личное хранилище для каждого персонажа в виде энтити с возможностью хранения предметов и денег."

-- Конфигурация плагина
PLUGIN.config = {}
PLUGIN.config.storageWidth = 10
PLUGIN.config.storageHeight = 10
PLUGIN.config.maxDistance = 100 -- максимальное расстояние для использования энтити
PLUGIN.config.moneyTransferEnabled = true

-- Хранилище данных в памяти
PLUGIN.storageInventories = {} -- [characterID] = inventory
PLUGIN.storageMoney = {} -- [characterID] = amount

-- Подключение файлов плагина
ix.util.Include("sv_plugin.lua", "server")
ix.util.Include("cl_plugin.lua", "client")
ix.util.Include("sv_hooks.lua", "server")
