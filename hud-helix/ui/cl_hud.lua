if CLIENT then

-- ==========================
-- ШРИФТЫ
-- ==========================
surface.CreateFont("CircularHUD_Large", {
    font = "Roboto",
    size = 28,
    weight = 700,
    antialias = true,
    extended = true
})

surface.CreateFont("CircularHUD_Medium", {
    font = "Roboto",
    size = 18,
    weight = 600,
    antialias = true,
    extended = true
})

surface.CreateFont("CircularHUD_Small", {
    font = "Roboto",
    size = 14,
    weight = 500,
    antialias = true,
    extended = true
})

surface.CreateFont("CircularHUD_Ammo", {
    font = "Roboto",
    size = 32,
    weight = 700,
    antialias = true,
    extended = true
})

-- ==========================
-- ЦВЕТОВАЯ СХЕМА
-- ==========================
local COLORS = {
    -- Фон и основа
    BACKGROUND = Color(12, 15, 19, 200),
    RING_BG = Color(45, 55, 75, 120),
    CENTER_BG = Color(20, 25, 35, 240),
    
    -- Статусы
    HEALTH = Color(46, 204, 113, 255),    -- Зеленый
    HEALTH_LOW = Color(231, 76, 60, 255), -- Красный при низком HP
    ARMOR = Color(52, 152, 219, 255),     -- Синий
    STAMINA = Color(241, 196, 15, 255),   -- Желтый
    
    -- Патроны
    AMMO_PRIMARY = Color(149, 165, 166, 255), -- Серый
    AMMO_RESERVE = Color(108, 122, 137, 255), -- Темно-серый
    
    -- Текст
    TEXT_WHITE = Color(255, 255, 255, 255),
    TEXT_LIGHT = Color(189, 195, 199, 255),
    TEXT_MUTED = Color(127, 140, 141, 255),
    
    -- Эффекты
    GLOW = Color(255, 255, 255, 30),
    PULSE = Color(255, 255, 255, 80)
}

-- ==========================
-- АНИМАЦИЯ И УТИЛИТЫ
-- ==========================
local smooth = {}
local targetValues = {}
local lastHealth = 0
local damageTime = 0
local pulseTime = 0

local function SmoothValue(key, target, speed)
    targetValues[key] = target
    smooth[key] = smooth[key] or target
    smooth[key] = Lerp(FrameTime() * (speed or 8), smooth[key], target)
    return smooth[key]
end

local function Scale(val)
    return val * (ScrH() / 1080)
end

-- ==========================
-- ФУНКЦИЯ ДЛЯ РИСОВАНИЯ КРУГОВ
-- ==========================
local function DrawCircle(x, y, radius, segments)
    segments = segments or 32
    local circle = {}
    
    for i = 0, segments do
        local angle = math.rad((i / segments) * 360)
        table.insert(circle, {
            x = x + math.cos(angle) * radius,
            y = y + math.sin(angle) * radius
        })
    end
    
    surface.DrawPoly(circle)
end

-- ==========================
-- РИСОВАНИЕ КРУГОВОГО ПРОГРЕССА
-- ==========================
local function DrawCircularProgress(x, y, radius, progress, thickness, backgroundColor, foregroundColor, startAngle, endAngle)
    startAngle = startAngle or -90
    endAngle = endAngle or 270
    progress = math.Clamp(progress, 0, 1)
    
    local segments = 64
    local angleStep = (endAngle - startAngle) / segments
    local progressAngle = startAngle + (endAngle - startAngle) * progress
    
    -- Фон кольца
    for i = 0, segments do
        local angle1 = math.rad(startAngle + i * angleStep)
        local angle2 = math.rad(startAngle + (i + 1) * angleStep)
        
        local x1_outer = x + math.cos(angle1) * radius
        local y1_outer = y + math.sin(angle1) * radius
        local x1_inner = x + math.cos(angle1) * (radius - thickness)
        local y1_inner = y + math.sin(angle1) * (radius - thickness)
        
        local x2_outer = x + math.cos(angle2) * radius
        local y2_outer = y + math.sin(angle2) * radius
        local x2_inner = x + math.cos(angle2) * (radius - thickness)
        local y2_inner = y + math.sin(angle2) * (radius - thickness)
        
        surface.SetDrawColor(backgroundColor)
        surface.DrawPoly({
            {x = x1_outer, y = y1_outer},
            {x = x2_outer, y = y2_outer},
            {x = x2_inner, y = y2_inner},
            {x = x1_inner, y = y1_inner}
        })
    end
    
    -- Прогресс кольца
    local progressSegments = math.ceil(segments * progress)
    for i = 0, progressSegments - 1 do
        local currentAngle = startAngle + i * angleStep
        if currentAngle <= progressAngle then
            local angle1 = math.rad(currentAngle)
            local angle2 = math.rad(math.min(currentAngle + angleStep, progressAngle))
            
            local x1_outer = x + math.cos(angle1) * radius
            local y1_outer = y + math.sin(angle1) * radius
            local x1_inner = x + math.cos(angle1) * (radius - thickness)
            local y1_inner = y + math.sin(angle1) * (radius - thickness)
            
            local x2_outer = x + math.cos(angle2) * radius
            local y2_outer = y + math.sin(angle2) * radius
            local x2_inner = x + math.cos(angle2) * (radius - thickness)
            local y2_inner = y + math.sin(angle2) * (radius - thickness)
            
            surface.SetDrawColor(foregroundColor)
            surface.DrawPoly({
                {x = x1_outer, y = y1_outer},
                {x = x2_outer, y = y2_outer},
                {x = x2_inner, y = y2_inner},
                {x = x1_inner, y = y1_inner}
            })
        end
    end
end

-- ==========================
-- РИСОВАНИЕ ЦЕНТРАЛЬНОГО КРУГА С ЭФФЕКТАМИ
-- ==========================
local function DrawCenterCircle(x, y, radius, color, text, value, maxValue, glowIntensity)
    -- Убираем фоновые круги - теперь только значения
    
    -- Значение в центре с эффектом тени
    surface.SetFont("CircularHUD_Large")
    
    -- Тень текста
    surface.SetTextColor(0, 0, 0, 100)
    local tw, th = surface.GetTextSize(tostring(value))
    surface.SetTextPos(x - tw/2 + 1, y - th/2 - Scale(5) + 1)
    surface.DrawText(tostring(value))
    
    -- Основной текст
    surface.SetTextColor(COLORS.TEXT_WHITE)
    surface.SetTextPos(x - tw/2, y - th/2 - Scale(5))
    surface.DrawText(tostring(value))
    
    -- Максимальное значение снизу
    if maxValue then
        surface.SetFont("CircularHUD_Small")
        surface.SetTextColor(COLORS.TEXT_MUTED)
        local maxText = "/" .. tostring(maxValue)
        local tw2, th2 = surface.GetTextSize(maxText)
        surface.SetTextPos(x - tw2/2, y + Scale(8))
        surface.DrawText(maxText)
    end
    
    -- Убираем подписи HP, ARMOR, STAMINA
end

-- ==========================
-- КРУГЛОЕ ОТОБРАЖЕНИЕ ПАТРОНОВ В СТИЛЕ ОСНОВНОГО HUD
-- ==========================
local function DrawAmmoDisplay(x, y)
    local ply = LocalPlayer()
    local activeWeapon = ply:GetActiveWeapon()
    
    if not IsValid(activeWeapon) or activeWeapon:GetClass() == "weapon_fists" then
        return
    end
    
    local weaponAmmo = activeWeapon:Clip1() or 0
    local reserveAmmo = ply:GetAmmoCount(activeWeapon:GetPrimaryAmmoType())
    local maxClipSize = activeWeapon:GetMaxClip1()
    
    if maxClipSize <= 0 then
        return
    end
    
    -- Анимированный прогресс патронов
    local ammoProgress = SmoothValue("ammo_display", weaponAmmo / maxClipSize, 10)
    
    -- Параметры круга (соответствуют основному HUD)
    local radius = Scale(50)
    local thickness = Scale(6)
    local centerX = x - Scale(80)
    local centerY = y
    
    -- Цвет патронов с пульсацией при низком количестве
    local ammoColor = COLORS.AMMO_PRIMARY
    local pulse = 1.0
    if ammoProgress < 0.3 then
        ammoColor = COLORS.HEALTH_LOW
        pulse = 0.7 + 0.3 * math.sin(CurTime() * 5)
        ammoColor = Color(ammoColor.r * pulse, ammoColor.g * pulse, ammoColor.b * pulse, ammoColor.a)
    end
    
    -- Рисуем круговой прогресс (как у основных индикаторов)
    DrawCircularProgress(
        centerX, 
        centerY, 
        radius, 
        ammoProgress, 
        thickness, 
        COLORS.RING_BG, 
        ammoColor,
        -90, 
        270
    )
    
    -- Центральный текст с патронами в обойме (крупно)
    surface.SetFont("CircularHUD_Large")
    surface.SetTextColor(COLORS.TEXT_WHITE)
    local primaryText = tostring(weaponAmmo)
    local tw1, th1 = surface.GetTextSize(primaryText)
    surface.SetTextPos(centerX - tw1/2, centerY - th1/2 - Scale(8))
    surface.DrawText(primaryText)
    
    -- Максимальное количество в обойме (мелко, под основным числом)
    surface.SetFont("CircularHUD_Small")
    surface.SetTextColor(COLORS.TEXT_MUTED)
    local maxText = "/" .. tostring(maxClipSize)
    local tw2, th2 = surface.GetTextSize(maxText)
    surface.SetTextPos(centerX - tw2/2, centerY + Scale(5))
    surface.DrawText(maxText)
    
    -- Запасные патроны справа от круга
    surface.SetFont("CircularHUD_Medium")
    surface.SetTextColor(COLORS.AMMO_RESERVE)
    local reserveText = "+" .. tostring(reserveAmmo)
    local tw3, th3 = surface.GetTextSize(reserveText)
    surface.SetTextPos(centerX + radius + Scale(15), centerY - th3/2)
    surface.DrawText(reserveText)
    
    -- Название оружия под кругом (как подпись, но меньше)
    local weaponName = activeWeapon:GetPrintName() or activeWeapon:GetClass()
    -- Сокращаем длинные названия
    if string.len(weaponName) > 12 then
        weaponName = string.sub(weaponName, 1, 12) .. "..."
    end
    
    surface.SetFont("CircularHUD_Small")
    surface.SetTextColor(COLORS.TEXT_LIGHT)
    local weaponW, weaponH = surface.GetTextSize(weaponName)
    surface.SetTextPos(centerX - weaponW/2, centerY + radius + Scale(10))
    surface.DrawText(weaponName)
end

-- ==========================
-- ГЛАВНЫЙ HUD HOOK
-- ==========================
hook.Add("HUDPaint", "CircularRoleplayHUD", function()
    local ply = LocalPlayer()
    local char = ply:GetCharacter()
    
    if not char then return end
    
    -- Получение данных
    local health = ply:Health()
    local maxHealth = ply:GetMaxHealth()
    local armor = ply:Armor()
    local maxArmor = 100 -- Стандартное максимальное значение брони
    
    -- Выносливость через системы HL:RP
    local stamina = 0
    if ix and ix.bar and ix.bar.list and ix.bar.list[3] then
        stamina = (ix.bar.list[3]["GetValue"]() or 0) * 100
    end
    
    -- Отслеживание урона для эффектов
    if health < lastHealth then
        damageTime = CurTime()
    end
    lastHealth = health
    
    -- Анимированные значения
    local healthProgress = SmoothValue("health", health / maxHealth, 12)
    local armorProgress = SmoothValue("armor", armor / maxArmor, 10)
    local staminaProgress = SmoothValue("stamina", stamina / 100, 8)
    
    -- Пульсация при низком здоровье
    pulseTime = pulseTime + FrameTime() * 3
    local healthPulse = 1
    if health < 30 then
        healthPulse = 0.7 + 0.3 * math.sin(pulseTime)
    end
    
    -- Эффект урона (красная вспышка по экрану)
    local damageFlash = math.max(0, 1 - (CurTime() - damageTime) * 4)
    if damageFlash > 0 then
        surface.SetDrawColor(COLORS.HEALTH_LOW.r, COLORS.HEALTH_LOW.g, COLORS.HEALTH_LOW.b, damageFlash * 60)
        surface.DrawRect(0, 0, ScrW(), ScrH())
    end
    
    -- Позиционирование (уменьшаем размер кругов)
    local centerX = Scale(120)
    local centerY = ScrH() - Scale(120)
    local radius = Scale(50)
    local thickness = Scale(6)
    local spacing = Scale(110)
    
    -- ==========================
    -- ЗДОРОВЬЕ (левый круг)
    -- ==========================
    local healthColor = health < 30 and COLORS.HEALTH_LOW or COLORS.HEALTH
    healthColor = Color(healthColor.r * healthPulse, healthColor.g * healthPulse, healthColor.b * healthPulse, healthColor.a)
    
    DrawCircularProgress(
        centerX, 
        centerY, 
        radius, 
        healthProgress, 
        thickness, 
        COLORS.RING_BG, 
        healthColor,
        -90, 
        270
    )
    
    DrawCenterCircle(
        centerX, 
        centerY, 
        Scale(25), 
        COLORS.CENTER_BG, 
        "HP", 
        health, 
        maxHealth,
        healthPulse
    )
    
    -- ==========================
    -- БРОНЯ (средний круг)
    -- ==========================
    local armorX = centerX + spacing
    
    -- Броня отображается только если есть
    if armor > 0 then
        DrawCircularProgress(
            armorX, 
            centerY, 
            radius, 
            armorProgress, 
            thickness, 
            COLORS.RING_BG, 
            COLORS.ARMOR,
            -90, 
            270
        )
        
        DrawCenterCircle(
            armorX, 
            centerY, 
            Scale(25), 
            COLORS.CENTER_BG, 
            "БРОНЯ", 
            armor, 
            maxArmor,
            1.0
        )
    else
        -- Показываем пустой круг если брони нет
        DrawCircularProgress(
            armorX, 
            centerY, 
            radius, 
            0, 
            thickness, 
            COLORS.RING_BG, 
            COLORS.ARMOR,
            -90, 
            270
        )
        
        DrawCenterCircle(
            armorX, 
            centerY, 
            Scale(25), 
            COLORS.CENTER_BG, 
            "БРОНЯ", 
            0, 
            maxArmor,
            0.3
        )
    end
    
    -- ==========================
    -- ВЫНОСЛИВОСТЬ (правый круг)
    -- ==========================
    local staminaX = centerX + spacing * 2
    
    DrawCircularProgress(
        staminaX, 
        centerY, 
        radius, 
        staminaProgress, 
        thickness, 
        COLORS.RING_BG, 
        COLORS.STAMINA,
        -90, 
        270
    )
    
    DrawCenterCircle(
        staminaX, 
        centerY, 
        Scale(25), 
        COLORS.CENTER_BG, 
        "ВЫНОСЛИВОСТЬ", 
        math.Round(stamina), 
        100,
        stamina < 20 and 0.7 + 0.3 * math.sin(CurTime() * 4) or 1.0
    )
    
    -- ==========================
    -- ОТОБРАЖЕНИЕ ПАТРОНОВ СПРАВА
    -- ==========================
    DrawAmmoDisplay(ScrW() - Scale(50), centerY)
    
end)

-- ==========================
-- ОТКЛЮЧЕНИЕ СТАНДАРТНОГО HUD
-- ==========================
local hiddenElements = {
    ["CHudHealth"] = true,
    ["CHudBattery"] = true, 
    ["CHudAmmo"] = true,
    ["CHudSecondaryAmmo"] = true
}

hook.Add("HUDShouldDraw", "CircularHUD_HideDefault", function(name)
    if hiddenElements[name] then
        return false
    end
end)

-- ==========================
-- ПЕРЕОПРЕДЕЛЕНИЯ ДЛЯ СОВМЕСТИМОСТИ
-- ==========================
function PLUGIN:ShouldHideBars() 
    return true 
end

function PLUGIN:CanDrawAmmoHUD() 
    return false 
end

end