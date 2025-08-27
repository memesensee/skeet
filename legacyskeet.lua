local repo = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'

local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local SaveManager = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()

local Window = Library:CreateWindow({
    Title = 'gamesense.lua',
    Center = true,
    AutoShow = true,
    TabPadding = 8,
    MenuFadeTime = 0
})

local Tabs = {
    Main = Window:AddTab('Main'),
    Vis = Window:AddTab('Visual'),
    sk = Window:AddTab('Sky'),
    serve = Window:AddTab('Server'),
    U = Window:AddTab('UI'),
    ['UI Settings'] = Window:AddTab('UI Settings'),
}

-- // Anti-Aim System
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local lp = Players.LocalPlayer

local angle = 0
local direction = 1
local lastYaw = 0
local spinAngle = 0
local jitterDir = 1

-- настройки из UI
local AntiAimEnabled = false
local AntiAimMode = "180" -- дефолт = лицом к камере
_G.isBunnyHopEnabled = _G.isBunnyHopEnabled or false -- глобальная переменная из BHop скрипта

-- отслеживаем пробел
local isSpaceHeld = false
UserInputService.InputBegan:Connect(function(input, gpe)
    if not gpe and input.KeyCode == Enum.KeyCode.Space then
        isSpaceHeld = true
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.Space then
        isSpaceHeld = false
    end
end)

-- // 🔹 Linoria UI
local Aimbox = Tabs.Main:AddLeftGroupbox('Anti-Aim')

Aimbox:AddToggle('AntiAimToggle', {
    Text = 'Anti-aim',
    Default = false,
    Callback = function(Value)
        AntiAimEnabled = Value

        if not Value then
            local char = lp.Character
            if char then
                local humanoid = char:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    humanoid.AutoRotate = true
                end
            end
        end
    end
})

Aimbox:AddDropdown('AntiAimModeDD', {
    Values = { 'aa back', '180', 'spin', 'jitter' },
    Default = '180',
    Multi = false,
    Text = 'Anti-aim mode',
    Callback = function(Value)
        AntiAimMode = Value
    end
})

-- // основной цикл
RunService.RenderStepped:Connect(function()
    if not AntiAimEnabled then return end

    local char = lp.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not humanoid then return end

    humanoid.AutoRotate = false

    -- 🟢 если банихоп включен И зажат пробел → отключаем анти-аим (но AutoRotate не трогаем)
    if _G.isBunnyHopEnabled and isSpaceHeld then
        return
    end

    local camCF = workspace.CurrentCamera.CFrame
    local lookVector = camCF.LookVector
    local yaw = math.atan2(-lookVector.X, -lookVector.Z)

    if AntiAimMode == "aa back" then
        angle = angle + direction * 2.5
        if angle > 25 then
            direction = -1
        elseif angle < -25 then
            direction = 1
        end

        local targetCF = CFrame.new(hrp.Position) * CFrame.Angles(0, yaw + math.pi + math.rad(angle), 0)

        local deltaYaw = math.deg(math.abs(yaw - lastYaw))
        if deltaYaw > 180 then
            deltaYaw = 360 - deltaYaw
        end

        if deltaYaw > 30 then
            hrp.CFrame = targetCF
        else
            hrp.CFrame = hrp.CFrame:Lerp(targetCF, 0.15)
        end

    elseif AntiAimMode == "180" then
        local targetCF = CFrame.new(hrp.Position) * CFrame.Angles(0, yaw + math.pi, 0)
        hrp.CFrame = hrp.CFrame:Lerp(targetCF, 0.2)

    elseif AntiAimMode == "spin" then
        spinAngle = spinAngle + math.rad(10)
        local targetCF = CFrame.new(hrp.Position) * CFrame.Angles(0, spinAngle, 0)
        hrp.CFrame = hrp.CFrame:Lerp(targetCF, 0.3)

    elseif AntiAimMode == "jitter" then
        jitterDir = -jitterDir
        local targetCF = CFrame.new(hrp.Position) * CFrame.Angles(0, yaw + math.pi + math.rad(jitterDir * 20), 0)
        hrp.CFrame = targetCF
    end

    lastYaw = yaw
end)


local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local lp = Players.LocalPlayer

local AntiAimEnabled = false

-- функция поиска ближайшего игрока
local function GetClosestPlayer()
    local closestPlayer = nil
    local shortestDistance = math.huge

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= lp and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local distance = (player.Character.HumanoidRootPart.Position - lp.Character.HumanoidRootPart.Position).Magnitude
            if distance < shortestDistance then
                shortestDistance = distance
                closestPlayer = player
            end
        end
    end
    return closestPlayer
end

-- Toggle Anti-aim
Aimbox:AddToggle('AntiAimToggle', {
    Text = 'LookAtPlayer',
    Default = false,
    Callback = function(Value)
        AntiAimEnabled = Value

        local char = lp.Character
        if char then
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid.AutoRotate = not Value -- выключаем автоповорот, если вкл
            end
        end
    end
})

-- цикл поворота
RunService.RenderStepped:Connect(function()
    if not AntiAimEnabled then return end
    local char = lp.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end

    local closest = GetClosestPlayer()
    if closest and closest.Character and closest.Character:FindFirstChild("HumanoidRootPart") then
        local hrp = char.HumanoidRootPart
        local targetPos = closest.Character.HumanoidRootPart.Position

        -- сохраняем уровень по Y (чтобы не смотрел вверх/вниз)
        local lookVector = Vector3.new(targetPos.X, hrp.Position.Y, targetPos.Z)
        hrp.CFrame = CFrame.new(hrp.Position, lookVector)
    end
end)

-- // WalkSpeed Boost (TP-style movement)
local uis = game:GetService("UserInputService")
local runService = game:GetService("RunService")
local player = game.Players.LocalPlayer
local hrp

player.CharacterAdded:Connect(function(char)
    hrp = char:WaitForChild("HumanoidRootPart")
end)

if player.Character then
    hrp = player.Character:WaitForChild("HumanoidRootPart")
end

-- Состояние кнопок
local moving = {
    W = false,
    S = false,
    A = false,
    D = false,
}

-- Обработка нажатия
uis.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.W then moving.W = true end
    if input.KeyCode == Enum.KeyCode.S then moving.S = true end
    if input.KeyCode == Enum.KeyCode.A then moving.A = true end
    if input.KeyCode == Enum.KeyCode.D then moving.D = true end
end)

-- Обработка отпускания
uis.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.W then moving.W = false end
    if input.KeyCode == Enum.KeyCode.S then moving.S = false end
    if input.KeyCode == Enum.KeyCode.A then moving.A = false end
    if input.KeyCode == Enum.KeyCode.D then moving.D = false end
end)

-- // 🔹 Linoria UI
local MovementBox = Tabs.Main:AddLeftGroupbox('Movement')

MovementBox:AddSlider('WalkTPSpeed', {
    Text = 'WalkSpeed Boost',
    Default = 0,
    Min = 0,
    Max = 100,
    Rounding = 0,
    Suffix = "%",
    Callback = function(Value)
        getgenv().WalkTPSpeed = Value
    end
})

-- Плавное движение
runService.RenderStepped:Connect(function(dt)
    if hrp and getgenv().WalkTPSpeed and getgenv().WalkTPSpeed > 0 then
        local cam = workspace.CurrentCamera
        local moveVec = Vector3.zero

        -- Берём векторы камеры, обнуляем Y (движение только по земле)
        local forward = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z).Unit
        local right = Vector3.new(cam.CFrame.RightVector.X, 0, cam.CFrame.RightVector.Z).Unit

        if moving.W then moveVec = moveVec + forward end
        if moving.S then moveVec = moveVec - forward end
        if moving.A then moveVec = moveVec - right end
        if moving.D then moveVec = moveVec + right end

        if moveVec.Magnitude > 0 then
            local step = moveVec.Unit * getgenv().WalkTPSpeed * dt
            hrp.CFrame = hrp.CFrame + step
        end
    end
end)

-- // JumpPower Slider (Loop)
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local lp = Players.LocalPlayer

getgenv().JumpPowerValue = 0

MovementBox:AddSlider('JumpPowerSlider', {
    Text = 'JumpPower',
    Default = 50,
    Min = 0,
    Max = 250,
    Rounding = 0,
    Suffix = "",
    Callback = function(Value)
        getgenv().JumpPowerValue = Value
    end
})

-- == Instant Teleport to mouse (Linoria) ==
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- функция телепорта
local function InstantTP()
    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local mouse = LocalPlayer:GetMouse()
    if mouse and mouse.Target then
        local pos = mouse.Hit.Position
        hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0)) -- слегка выше земли
    end
end

-- кейпикер (идёт ПЕРВЫМ элементом)
MovementBox:AddLabel('Teleport on mouse')
    :AddKeyPicker('TeleportKey', {
        Default = 'C',        -- стартовый ключ
        Mode = 'Trigger',     -- нам нужен одноразовый триггер
        Text = 'Teleport Key',
        NoUI = false
    })

-- слушаем нажатие выбранного ключа и делаем TP
UIS.InputEnded:Connect(function(input, gpe)
    if gpe then return end
    local opt = Options.TeleportKey
    if not opt then return end

    local key = opt.Value -- может быть Enum.KeyCode или строка
    if typeof(key) == 'EnumItem' then
        if input.KeyCode == key then
            InstantTP()
        end
    elseif type(key) == 'string' and Enum.KeyCode[key] then
        if input.KeyCode == Enum.KeyCode[key] then
            InstantTP()
        end
    end
end)


local flyEnabled = false
local flySpeed = 30 -- базовая скорость
local flyBoost = 70 -- с Shift
local bodyGyro, bodyVel

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- toggle fly
local function toggleFly()
    flyEnabled = not flyEnabled

    local character = LocalPlayer.Character
    if not character then return end
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")

    if flyEnabled then
        humanoid.WalkSpeed = 0
        humanoid.PlatformStand = true

        bodyGyro = Instance.new("BodyGyro")
        bodyGyro.P = 9e4
        bodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
        bodyGyro.CFrame = humanoidRootPart.CFrame
        bodyGyro.Parent = humanoidRootPart

        bodyVel = Instance.new("BodyVelocity")
        bodyVel.MaxForce = Vector3.new(9e9, 9e9, 9e9)
        bodyVel.Velocity = Vector3.zero
        bodyVel.Parent = humanoidRootPart

        RunService.RenderStepped:Connect(function()
            if not flyEnabled then return end
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end

            local moveDir = Vector3.zero
            local cameraCF = Camera.CFrame
            local speed = flySpeed

            if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                moveDir += cameraCF.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                moveDir -= cameraCF.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                moveDir -= cameraCF.RightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                moveDir += cameraCF.RightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.E) then
                moveDir += cameraCF.UpVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.Q) then
                moveDir -= cameraCF.UpVector
            end

            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                speed = flyBoost
            end

            if moveDir.Magnitude > 0 then
                moveDir = moveDir.Unit * speed
            end

            bodyGyro.CFrame = cameraCF
            bodyVel.Velocity = moveDir
        end)
    else
        if bodyGyro then bodyGyro:Destroy() end
        if bodyVel then bodyVel:Destroy() end

        if humanoid then
            humanoid.PlatformStand = false
            humanoid.WalkSpeed = 16
        end
    end
end

local MovementBox = Tabs.Main:AddLeftGroupbox('Fly')


-- Fly Speed slider
MovementBox:AddSlider('FlySpeed', {
    Text = 'Fly Speed',
    Default = 30,
    Min = 0,
    Max = 200,
    Rounding = 0,
    Compact = false,
    Callback = function(Value)
        flySpeed = Value
    end
})

-- Fly Boost slider (Shift)
MovementBox:AddSlider('FlyBoost', {
    Text = 'Fly Boost (Shift)',
    Default = 70,
    Min = 0,
    Max = 249,
    Rounding = 0,
    Compact = false,
    Callback = function(Value)
        flyBoost = Value
    end
})

-- Fly Keybind (первым идёт)
MovementBox:AddLabel('Fly Key'):AddKeyPicker('FlyKeybind', {
    Default = 'F2',
    SyncToggleState = true,
    Mode = 'Toggle',
    Text = 'Fly',
    NoUI = false,
    Callback = function(Value)
        toggleFly(Value)
    end
})




-- Зацикленное применение силы прыжка
RunService.RenderStepped:Connect(function()
    local char = lp.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and getgenv().JumpPowerValue then
            hum.UseJumpPower = true
            hum.JumpPower = getgenv().JumpPowerValue
        end
    end
end)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- // AntiFling function \\ --
local function EnableAntiFling()
    local Services = setmetatable({}, {
        __index = function(Self, Index)
            local NewService = game.GetService(game, Index)
            if NewService then
                Self[Index] = NewService
            end
            return NewService
        end
    })

    -- функция обработки игрока
    local function PlayerAdded(Player)
        local Detected = false
        local Character;
        local PrimaryPart;

        local function CharacterAdded(NewCharacter)
            Character = NewCharacter
            repeat task.wait()
                PrimaryPart = NewCharacter:FindFirstChild("HumanoidRootPart")
            until PrimaryPart
            Detected = false
        end

        CharacterAdded(Player.Character or Player.CharacterAdded:Wait())
        Player.CharacterAdded:Connect(CharacterAdded)

        Services.RunService.Heartbeat:Connect(function()
            if (Character and Character:IsDescendantOf(workspace)) and (PrimaryPart and PrimaryPart:IsDescendantOf(Character)) then
                if PrimaryPart.AssemblyAngularVelocity.Magnitude > 50 or PrimaryPart.AssemblyLinearVelocity.Magnitude > 100 then
                    Detected = true
                    for _, v in ipairs(Character:GetDescendants()) do
                        if v:IsA("BasePart") then
                            v.CanCollide = false
                            v.AssemblyAngularVelocity = Vector3.zero
                            v.AssemblyLinearVelocity = Vector3.zero
                            v.CustomPhysicalProperties = PhysicalProperties.new(0, 0, 0)
                        end
                    end
                    PrimaryPart.CanCollide = false
                    PrimaryPart.AssemblyAngularVelocity = Vector3.zero
                    PrimaryPart.AssemblyLinearVelocity = Vector3.zero
                    PrimaryPart.CustomPhysicalProperties = PhysicalProperties.new(0, 0, 0)
                end
            end
        end)
    end

    -- обработка игроков
    for _, v in ipairs(Services.Players:GetPlayers()) do
        if v ~= LocalPlayer then
            PlayerAdded(v)
        end
    end
    Services.Players.PlayerAdded:Connect(PlayerAdded)

    -- защита самого игрока
    local LastPosition = nil
    Services.RunService.Heartbeat:Connect(function()
        pcall(function()
            local PrimaryPart = LocalPlayer.Character and LocalPlayer.Character.PrimaryPart
            if not PrimaryPart then return end

            if PrimaryPart.AssemblyLinearVelocity.Magnitude > 250 or PrimaryPart.AssemblyAngularVelocity.Magnitude > 250 then
                PrimaryPart.AssemblyAngularVelocity = Vector3.zero
                PrimaryPart.AssemblyLinearVelocity = Vector3.zero
                if LastPosition then
                    PrimaryPart.CFrame = LastPosition
                end
            elseif PrimaryPart.AssemblyLinearVelocity.Magnitude < 50 or PrimaryPart.AssemblyAngularVelocity.Magnitude > 50 then
                LastPosition = PrimaryPart.CFrame
            end
        end)
    end)
end

-- // Linoria UI Button \\ --
local MiscBox = Tabs.Main:AddRightGroupbox('Misc')

MiscBox:AddButton('Enable AntiFling', function()
    EnableAntiFling()
end)

MiscBox:AddButton('Instant proximity prompt', function()
    game:GetService("ProximityPromptService").PromptButtonHoldBegan:Connect(function(prompt) prompt.HoldDuration = 0 end)
end)

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- вспомогательная функция
local function getRoot(char)
    return char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso"))
end

-- состояние
local walkflinging = false

-- отключаем коллизию у всех частей
local function disableAllCollisions(char)
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end
end

-- оставляем коллизию только на HRP
local function hrpOnlyCollide(char)
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = (part.Name == "HumanoidRootPart")
        end
    end
end

local function startWalkFling()
    if walkflinging then return end
    walkflinging = true

    local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildWhichIsA("Humanoid")
    if humanoid then
        humanoid.Died:Connect(function()
            walkflinging = false
            hrpOnlyCollide(LocalPlayer.Character)
        end)
    end

    -- при включении антифлинга: отключаем ВСЁ
    disableAllCollisions(LocalPlayer.Character)

    task.spawn(function()
        local movel = 0.1
        while walkflinging do
            RunService.Heartbeat:Wait()
            local character = LocalPlayer.Character
            local root = getRoot(character)

            if character then
                disableAllCollisions(character) -- поддерживаем полное отключение
            end

            if not (character and character.Parent and root and root.Parent) then
                continue
            end

            local vel = root.Velocity
            root.Velocity = vel * 10000 + Vector3.new(0, 10000, 0)

            RunService.RenderStepped:Wait()
            if character and root then
                root.Velocity = vel
            end

            RunService.Stepped:Wait()
            if character and root then
                root.Velocity = vel + Vector3.new(0, movel, 0)
                movel = -movel
            end
        end
    end)
end

local function stopWalkFling()
    walkflinging = false
    hrpOnlyCollide(LocalPlayer.Character) -- при выключении: коллизия только на HRP
end

MiscBox:AddToggle("WalkFlingToggle", {
    Text = "Enable WalkFling",
    Default = false,
    Tooltip = "Включить/выключить WalkFling",
    Callback = function(Value)
        if Value then
            startWalkFling()
        else
            stopWalkFling()
        end
    end
})
local LocalPlayerBox = Tabs.Main:AddRightGroupbox('LocalPlayer')

LocalPlayerBox:AddButton('Unlock camera', function()
    Players.LocalPlayer.CameraMode = Enum.CameraMode.Classic
    game.Players.LocalPlayer.CameraMaxZoomDistance = 99999
end)

LocalPlayerBox:AddButton('Camfix', function()
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local Player = Players.LocalPlayer

RunService.RenderStepped:Connect(function()
    if Camera.CameraSubject ~= Player.Character and Player.Character then
        local humanoid = Player.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            Camera.CameraSubject = humanoid
        end
    end
    if Camera.CameraType ~= Enum.CameraType.Custom then
        Camera.CameraType = Enum.CameraType.Custom
    end
end)
end)

LocalPlayerBox:AddSlider('Fov Changer', {
    Text = 'Fov',
    Default = 70,
    Min = 10,
    Max = 120,
    Rounding = 0,
    Compact = false,
    Callback = function(Value)
    workspace.Camera.FieldOfView = Value
    end
})

--// Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local rootPart, humanoid = nil, nil

--// BunnyHop Vars
local bunnyHopEnabled = false
local jumped = false
local rotationMode = "Forward"
local bhopSpeed = 50 -- дефолт

--// FakeLag Vars
local fakeLagEnabled = false
local lagChance = 0.6
local freezeTime = 0.2
local skipTime = 0.1

--// Character Handler
local function setupChar(char)
    rootPart = char:WaitForChild("HumanoidRootPart")
    humanoid = char:WaitForChild("Humanoid")
    humanoid.AutoRotate = true
end

player.CharacterAdded:Connect(setupChar)
if player.Character then setupChar(player.Character) end

--// Input Handling
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.Space then
        jumped = true
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.Space then
        jumped = false
    end
end)

--// Camera Directions
local function getCameraDirs()
    local camCF = workspace.CurrentCamera.CFrame
    local forward = Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z).Unit
    local right = Vector3.new(camCF.RightVector.X, 0, camCF.RightVector.Z).Unit
    return forward, right
end

--// FakeLag Function
local function applyFakeLag()
    if not humanoid or not fakeLagEnabled then return end
    if math.random() < lagChance then
        local animator = humanoid:FindFirstChildOfClass("Animator")
        if animator then
            for _, track in pairs(animator:GetPlayingAnimationTracks()) do
                track:AdjustSpeed(0)
            end
            task.wait(freezeTime)
            for _, track in pairs(animator:GetPlayingAnimationTracks()) do
                track:AdjustSpeed(3)
            end
            task.wait(skipTime)
            for _, track in pairs(animator:GetPlayingAnimationTracks()) do
                track:AdjustSpeed(1)
            end
        end
    end
end

--// Main Loop
RunService.RenderStepped:Connect(function(dt)
    if not rootPart or not humanoid then return end

    -- FakeLag check
    if fakeLagEnabled then
        applyFakeLag()
    end

    -- BunnyHop check
    if not bunnyHopEnabled then
        humanoid.AutoRotate = true
        return
    end

    local state = humanoid:GetState()
    local onGround = (state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.RunningNoPhysics)

    if onGround then
        humanoid.AutoRotate = true
        return
    end

    if jumped then
        humanoid.AutoRotate = false

        local forward, right = getCameraDirs()
        local move = Vector3.new()

        if UserInputService:IsKeyDown(Enum.KeyCode.W) then move += forward end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then move -= forward end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then move -= right end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then move += right end
        if move.Magnitude == 0 then move = forward end

        rootPart.AssemblyLinearVelocity = move.Unit * bhopSpeed + Vector3.new(0, rootPart.AssemblyLinearVelocity.Y, 0)

        if rotationMode == "Spin" then
            rootPart.CFrame = rootPart.CFrame * CFrame.Angles(0, math.rad(10), 0)

        elseif rotationMode == "180" then
            local lookAt = rootPart.Position - forward
            rootPart.CFrame = CFrame.new(rootPart.Position, Vector3.new(lookAt.X, rootPart.Position.Y, lookAt.Z))

        elseif rotationMode == "Forward" then
            rootPart.CFrame = CFrame.new(rootPart.Position, rootPart.Position + forward)
        end
    else
        humanoid.AutoRotate = true
    end
end)

-- UI Elements
LocalPlayerBox:AddToggle('FakeLagEnabled', {
    Text = 'Fake Lag',
    Default = false,
    Callback = function(Value)
        fakeLagEnabled = Value
    end
})

LocalPlayerBox:AddToggle('BunnyHopEnabled', {
    Text = 'Bunny Hop',
    Default = false,
    Callback = function(Value)
        bunnyHopEnabled = Value
    end
})

LocalPlayerBox:AddSlider('BhopSpeed', {
    Text = 'Bhop Speed',
    Default = 50,
    Min = 10,
    Max = 200,
    Rounding = 0,
    Compact = false,
    Callback = function(Value)
        bhopSpeed = Value
    end
})

LocalPlayerBox:AddDropdown('RotationMode', {
    Values = { 'Spin', '180', 'Forward' },
    Default = 3,
    Multi = false,
    Text = 'Rotation Mode',
    Callback = function(Value)
        rotationMode = Value
    end
})

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local ESPenabled = false

-- Получаем HRP
local function getRoot(char)
    return char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso"))
end

-- Создание ESP над головой
local function createNameESP(plr)
    task.spawn(function()
        if not plr.Character or plr == LocalPlayer then return end
        repeat task.wait() until plr.Character:FindFirstChildOfClass("Humanoid") and getRoot(plr.Character)

        -- Удалим старый, если был
        local old = CoreGui:FindFirstChild(plr.Name.."_NameESP")
        if old then old:Destroy() end

        -- BillboardGui
        local holder = Instance.new("BillboardGui")
        holder.Name = plr.Name.."_NameESP"
        holder.Adornee = getRoot(plr.Character)
        holder.Size = UDim2.new(0,200,0,50)
        holder.StudsOffset = Vector3.new(0,3,0)
        holder.AlwaysOnTop = true
        holder.Parent = CoreGui

        -- TextLabel
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1,0,1,0)
        label.BackgroundTransparency = 1
        label.TextColor3 = Color3.new(1,1,1)
        label.TextStrokeTransparency = 0
        label.Font = Enum.Font.SourceSansBold
        label.TextScaled = true
        label.Parent = holder

        -- обновление текста
        task.spawn(function()
            while holder.Parent and ESPenabled and plr.Character and plr.Character:FindFirstChildOfClass("Humanoid") do
                local hum = plr.Character:FindFirstChildOfClass("Humanoid")
                local root = getRoot(plr.Character)
                if hum and root then
                    local distance = (Camera.CFrame.Position - root.Position).Magnitude
                    label.Text = string.format("%s | HP: %d | %.0f studs", plr.Name, hum.Health, distance)
                    if plr.TeamColor then
                        label.TextColor3 = plr.TeamColor.Color
                    end
                end
                task.wait(0.2)
            end
        end)
    end)
end

-- Включение ESP
local function enableESP()
    ESPenabled = true
    for _,plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            createNameESP(plr)
        end
    end
    Players.PlayerAdded:Connect(function(plr)
        if ESPenabled then createNameESP(plr) end
    end)
end

-- Выключение ESP
local function disableESP()
    ESPenabled = false
    for _,v in pairs(CoreGui:GetChildren()) do
        if v.Name:match("_NameESP") then
            v:Destroy()
        end
    end
end

-- Удаление при выходе
Players.PlayerRemoving:Connect(function(plr)
    local f = CoreGui:FindFirstChild(plr.Name.."_NameESP")
    if f then f:Destroy() end
end)

-- === Linoria Toggle ===
local esps = Tabs.Vis:AddLeftGroupbox("Esp")

esps:AddToggle("NameESPToggle", {
    Text = "Enable ESP",
    Default = false,
    Tooltip = "Show name, health and distance above players",
    Callback = function(Value)
        if Value then
            enableESP()
        else
            disableESP()
        end
    end
})


local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

-- Настройки
local espTransparency = 0.4
local ESPenabled = false

-- Получение HRP
local function getRoot(char)
    return char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso"))
end

-- Главная функция ESP
local function createESP(plr)
    task.spawn(function()
        for _, v in pairs(CoreGui:GetChildren()) do
            if v.Name == plr.Name.."_ESP" then
                v:Destroy()
            end
        end
        task.wait()

        if plr.Character and plr ~= LocalPlayer and not CoreGui:FindFirstChild(plr.Name.."_ESP") then
            local ESPholder = Instance.new("Folder")
            ESPholder.Name = plr.Name.."_ESP"
            ESPholder.Parent = CoreGui

            repeat task.wait(1) until plr.Character and getRoot(plr.Character) and plr.Character:FindFirstChildOfClass("Humanoid")

            for _, n in pairs(plr.Character:GetChildren()) do
                if n:IsA("BasePart") then
                    local box = Instance.new("BoxHandleAdornment")
                    box.Name = plr.Name
                    box.Parent = ESPholder
                    box.Adornee = n
                    box.AlwaysOnTop = true
                    box.ZIndex = 10
                    box.Size = n.Size
                    box.Transparency = espTransparency
                    box.Color3 = plr.TeamColor.Color
                end
            end

            local addedFunc, teamChange, removedConn

            addedFunc = plr.CharacterAdded:Connect(function()
                if ESPenabled then
                    ESPholder:Destroy()
                    teamChange:Disconnect()
                    repeat task.wait(1) until getRoot(plr.Character) and plr.Character:FindFirstChildOfClass("Humanoid")
                    createESP(plr)
                    addedFunc:Disconnect()
                else
                    teamChange:Disconnect()
                    addedFunc:Disconnect()
                end
            end)

            teamChange = plr:GetPropertyChangedSignal("TeamColor"):Connect(function()
                if ESPenabled then
                    ESPholder:Destroy()
                    addedFunc:Disconnect()
                    repeat task.wait(1) until getRoot(plr.Character) and plr.Character:FindFirstChildOfClass("Humanoid")
                    createESP(plr)
                    teamChange:Disconnect()
                else
                    teamChange:Disconnect()
                end
            end)

            removedConn = ESPholder.AncestryChanged:Connect(function()
                teamChange:Disconnect()
                addedFunc:Disconnect()
                removedConn:Disconnect()
            end)
        end
    end)
end

-- Включение ESP
local function enableESP()
    ESPenabled = true
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            createESP(plr)
        end
    end
    Players.PlayerAdded:Connect(function(plr)
        if ESPenabled then
            createESP(plr)
        end
    end)
end

-- Выключение ESP
local function disableESP()
    ESPenabled = false
    for _, v in pairs(CoreGui:GetChildren()) do
        if v.Name:match("_ESP") then
            v:Destroy()
        end
    end
end

-- Обновление прозрачности
local function updateESPTransparency()
    for _, folder in pairs(CoreGui:GetChildren()) do
        if folder.Name:match("_ESP") then
            for _, box in pairs(folder:GetChildren()) do
                if box:IsA("BoxHandleAdornment") then
                    box.Transparency = espTransparency
                end
            end
        end
    end
end

-- === Linoria Toggles/Sliders ===
esps:AddToggle("ESPToggle", {
    Text = "Enable Chams",
    Default = false,
    Tooltip = "Enable or disable Chams",
    Callback = function(Value)
        if Value then
            enableESP()
        else
            disableESP()
        end
    end
})

esps:AddSlider("ESPTransparencySlider", {
    Text = "Chams Transparency",
    Default = espTransparency,
    Min = 0,
    Max = 1,
    Step = 0.05,
    Rounding = 2,
    Callback = function(Value)
        espTransparency = Value
        updateESPTransparency()
    end
})

-- Очистка при выходе игрока
Players.PlayerRemoving:Connect(function(player)
    if Toggles.ESPToggle.Value then
        for _, v in pairs(CoreGui:GetChildren()) do
            if v.Name == player.Name.."_ESP" then
                v:Destroy()
            end
        end
    end
end)


local esps = Tabs.Vis:AddRightGroupbox('LocalPlayer')

local Player = game:GetService("Players").LocalPlayer
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local camera = workspace.CurrentCamera
local debugEnabled = false
local cameraSpeed = 50  -- Увеличенная базовая скорость
local fastSpeedMultiplier = 3
local slowSpeedMultiplier = 0.3
local mouseSensitivity = 0.5  -- Чувствительность мыши

-- Сохраняем оригинальные настройки камеры
local originalCameraType
local originalCameraSubject
local originalFieldOfView = 70

-- Настройки управления (можно изменить)
local moveKeys = {
    forward = Enum.KeyCode.W,
    backward = Enum.KeyCode.S,
    left = Enum.KeyCode.A,
    right = Enum.KeyCode.D,
    up = Enum.KeyCode.Space,
    down = Enum.KeyCode.LeftControl
}

-- Переменные для вращения камеры
local yaw = 0
local pitch = 0

-- Функция для включения debug камеры
local function enableDebugCamera()
    if debugEnabled then return end
    debugEnabled = true
    
    -- Сохраняем текущие настройки камеры
    originalCameraType = camera.CameraType
    originalCameraSubject = camera.CameraSubject
    originalFieldOfView = camera.FieldOfView
    
    -- Устанавливаем камеру в ручной режим
    camera.CameraType = Enum.CameraType.Scriptable
    camera.CameraSubject = nil
    
    -- Инициализируем углы вращения
    local look = camera.CFrame.LookVector
    yaw = math.atan2(look.X, look.Z)
    pitch = math.asin(look.Y)
    
    -- Останавливаем персонажа, если он существует
    if Player.Character and Player.Character:FindFirstChild("Humanoid") then
          humanoid.PlatformStand = True
    end
    
    -- Скрываем интерфейс для лучшего обзора
    if Player:FindFirstChild("PlayerGui") then
        Player.PlayerGui:SetTopbarTransparency(1)
    end
    
    -- Захватываем мышь для плавного вращения
    UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
end

-- Функция для выключения debug камеры
local function disableDebugCamera()
    if not debugEnabled then return end
    debugEnabled = false
    
    -- Восстанавливаем оригинальные настройки камеры
    camera.CameraType = originalCameraType or Enum.CameraType.Custom
    camera.CameraSubject = originalCameraSubject or Player.Character and Player.Character:FindFirstChild("Humanoid")
    camera.FieldOfView = originalFieldOfView or 70
    
    -- Восстанавливаем скорость персонажа, если он существует
    if Player.Character and Player.Character:FindFirstChild("Humanoid") then
        humanoid.PlatformStand = False
    end
    
    -- Восстанавливаем интерфейс
    if Player:FindFirstChild("PlayerGui") then
        Player.PlayerGui:SetTopbarTransparency(0)
    end
    
    -- Возвращаем нормальное поведение мыши
    UserInputService.MouseBehavior = Enum.MouseBehavior.Default
end

-- Функция для переключения debug камеры
local function toggleDebugCamera()
    if debugEnabled then
        disableDebugCamera()
    else
        enableDebugCamera()
    end
end

-- Fly Keybind (первым идёт)
esps:AddLabel('Debug Camera Toggle'):AddKeyPicker('DebugCamera', {
    Default = 'F1',
    SyncToggleState = true,
    Mode = 'Toggle',
    Text = 'Debug camera',
    NoUI = false,
    Callback = function(knopka)
        toggleDebugCamera()
    end
})

-- Основной цикл движения камеры
RunService.RenderStepped:Connect(function(deltaTime)
    if not debugEnabled then return end
    
    -- Определяем текущую скорость
    local currentSpeed = cameraSpeed
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) then
        currentSpeed = currentSpeed * slowSpeedMultiplier
    elseif UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
        currentSpeed = currentSpeed * fastSpeedMultiplier
    end
    
    -- Обработка вращения камеры мышью
    local mouseDelta = UserInputService:GetMouseDelta()
    yaw = yaw - mouseDelta.X * 0.01 * mouseSensitivity
    pitch = math.clamp(pitch - mouseDelta.Y * 0.01 * mouseSensitivity, -math.pi/2 + 0.1, math.pi/2 - 0.1)
    
    -- Создаем новую ориентацию камеры
    local newCFrame = CFrame.new(camera.CFrame.Position) * 
                     CFrame.fromOrientation(pitch, yaw, 0)
    
    -- Движение камеры
    local moveVector = Vector3.new(0, 0, 0)
    
    if UserInputService:IsKeyDown(moveKeys.forward) then
        moveVector = moveVector + newCFrame.LookVector
    end
    if UserInputService:IsKeyDown(moveKeys.backward) then
        moveVector = moveVector - newCFrame.LookVector
    end
    if UserInputService:IsKeyDown(moveKeys.left) then
        moveVector = moveVector - newCFrame.RightVector
    end
    if UserInputService:IsKeyDown(moveKeys.right) then
        moveVector = moveVector + newCFrame.RightVector
    end
    if UserInputService:IsKeyDown(moveKeys.up) then
        moveVector = moveVector + Vector3.new(0, 1, 0)
    end
    if UserInputService:IsKeyDown(moveKeys.down) then
        moveVector = moveVector - Vector3.new(0, 1, 0)
    end
    
    -- Применяем движение
    if moveVector.Magnitude > 0 then
        moveVector = moveVector.Unit * currentSpeed * deltaTime
        newCFrame = newCFrame + moveVector
    end
    
    -- Обновляем позицию и поворот камеры
    camera.CFrame = newCFrame
    
    -- Изменение FOV колесиком мыши
    local mouseWheel = UserInputService:GetMouseWheel()
    if mouseWheel ~= 0 then
        camera.FieldOfView = math.clamp(camera.FieldOfView - mouseWheel * 2, 5, 120)
    end
end)

-- Автоматическое отключение debug-камеры при смерти
Player.CharacterAdded:Connect(function(character)
    character:WaitForChild("Humanoid").Died:Connect(function()
        disableDebugCamera()
    end)
end)

local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer
local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")

-- ===== Настройки/состояние =====
local originalMaterials = {}
local originalFace = nil
local originalHRPTransparency
local forceFieldEnabled = false

-- Имя атрибутов для сохранения между смертями
local ATTR_COLOR = "SavedColor"
local ATTR_FORCEFIELD = "SavedForceField"

-- Цвет по умолчанию
local currentColor = Color3.fromRGB(255, 255, 255)

-- Набор имён частей, к которым МОЖНО применять материал (R6 + R15)
local LIMB_NAMES = {
	-- Общие
	Head = true,

	-- R6
	["Torso"] = true,
	["Left Arm"] = true,
	["Right Arm"] = true,
	["Left Leg"] = true,
	["Right Leg"] = true,

	-- R15 — торс
	["UpperTorso"] = true,
	["LowerTorso"] = true,

	-- R15 — руки
	["LeftUpperArm"] = true,
	["LeftLowerArm"] = true,
	["LeftHand"] = true,
	["RightUpperArm"] = true,
	["RightLowerArm"] = true,
	["RightHand"] = true,

	-- R15 — ноги
	["LeftUpperLeg"] = true,
	["LeftLowerLeg"] = true,
	["LeftFoot"] = true,
	["RightUpperLeg"] = true,
	["RightLowerLeg"] = true,
	["RightFoot"] = true,
}

local function isCharacterLimb(part: Instance)
	return part:IsA("BasePart") and LIMB_NAMES[part.Name] == true
end

-- ===== Сохранение оригинальных данных =====
local function saveOriginalAssets()
	originalMaterials = {}

	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			originalMaterials[part] = {
				Material = part.Material,
				Transparency = part.Transparency,
				Color = part.Color
			}
			if part.Name == "HumanoidRootPart" then
				originalHRPTransparency = part.Transparency
			end
		end
	end

	-- Сохраняем лицо
	local head = character:FindFirstChild("Head")
	if head then
		for _, decal in ipairs(head:GetChildren()) do
			if decal:IsA("Decal") and decal.Name == "face" then
				originalFace = decal:Clone()
				break
			end
		end
	end
end

-- ===== Применение ForceField только к конечностям/торсу/голове =====
local function applyForceField()
	for part, _ in pairs(originalMaterials) do
		if isCharacterLimb(part) then
			part.Material = Enum.Material.ForceField
			part.Color = currentColor
			part.Transparency = 0
		elseif part:IsA("BasePart") and part.Name == "HumanoidRootPart" then
			part.Transparency = 1 -- скрываем HRP
		end
	end

	-- НЕ трогаем аксессуары материалом (по твоей просьбе),
	-- но если хочешь, можно раскомментировать изменение цвета аксессуаров:
	-- for _, accessory in ipairs(character:GetChildren()) do
	-- 	if accessory:IsA("Accessory") then
	-- 		local handle = accessory:FindFirstChild("Handle")
	-- 		if handle then
	-- 			handle.Color = currentColor
	-- 		end
	-- 	end
	-- end

	-- Удаляем лицо
	local head = character:FindFirstChild("Head")
	if head then
		for _, decal in ipairs(head:GetChildren()) do
			if decal:IsA("Decal") and decal.Name == "face" then
				decal:Destroy()
			end
		end
	end
end

-- ===== Восстановление оригинальных материалов =====
local function restoreOriginalAssets()
	for part, data in pairs(originalMaterials) do
		if part:IsA("BasePart") then
			part.Material = data.Material
			part.Color = data.Color
			part.Transparency = data.Transparency
		end
	end

	-- Восстановить HRP
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp and originalHRPTransparency ~= nil then
		hrp.Transparency = originalHRPTransparency
	end

	-- Восстановить лицо
	local head = character:FindFirstChild("Head")
	if head and originalFace then
		for _, decal in ipairs(head:GetChildren()) do
			if decal:IsA("Decal") and decal.Name == "face" then
				decal:Destroy()
			end
		end
		originalFace:Clone().Parent = head
	end
end

-- ===== Обновление цвета (работает и с ForceField, и без) =====
local function updateColor(newColor: Color3)
	currentColor = newColor

	-- красим все части персонажа (включая конечности); аксессуары — по желанию
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Color = currentColor
		end
	end

	-- (опционально) красить аксессуары:
	-- for _, accessory in ipairs(character:GetChildren()) do
	-- 	if accessory:IsA("Accessory") then
	-- 		local handle = accessory:FindFirstChild("Handle")
	-- 		if handle then
	-- 			handle.Color = currentColor
	-- 		end
	-- 	end
	-- end

	-- сохраняем цвет в атрибут игрока (чтобы переживал смерть)
	if localPlayer then
		localPlayer:SetAttribute(ATTR_COLOR, currentColor)
	end
end

-- ===== Инициализация сохранённых настроек игрока =====
local function loadSavedSettings()
	-- Цвет
	local savedColor = localPlayer:GetAttribute(ATTR_COLOR)
	if typeof(savedColor) == "Color3" then
		currentColor = savedColor
	else
		localPlayer:SetAttribute(ATTR_COLOR, currentColor)
	end

	-- Состояние ForceField
	local savedFF = localPlayer:GetAttribute(ATTR_FORCEFIELD)
	if typeof(savedFF) == "boolean" then
		forceFieldEnabled = savedFF
	else
		localPlayer:SetAttribute(ATTR_FORCEFIELD, forceFieldEnabled)
	end
end

-- ===== Обработчик спауна/респауна персонажа =====
local function onCharacterAdded(newCharacter)
	character = newCharacter
	humanoid = character:WaitForChild("Humanoid")
	character:WaitForChild("HumanoidRootPart")

	-- загрузить сохранённые настройки (цвет/FF) и применить
	loadSavedSettings()

	-- Сохранить оригиналы
	saveOriginalAssets()

	-- Применить материал/цвет согласно текущим настройкам
	if forceFieldEnabled then
		applyForceField()
	else
		restoreOriginalAssets()
	end

	-- Цвет должен применяться всегда (включая когда ForceField включён)
	updateColor(currentColor)

	-- На смерть ничего особого делать не нужно — CharacterAdded сработает при респавне
end

-- ===== Первичный запуск =====
loadSavedSettings()
saveOriginalAssets()

-- Подписки
localPlayer.CharacterAdded:Connect(onCharacterAdded)

-- ===== UI =====
-- ВАЖНО: предполагается, что Tab уже создан твоей UI-библиотекой выше по коду.

esps:AddToggle('ForceFieldMaterial', {
    Text = 'ForceField Material',
    Default = false,
    Callback = function(Value)
        forceFieldEnabled = Value
		localPlayer:SetAttribute(ATTR_FORCEFIELD, forceFieldEnabled)
		if Value then
			applyForceField()
		else
			restoreOriginalAssets()
		end
		-- Цвет должен остаться/обновиться в любом случае
		updateColor(currentColor)
    end
})

esps:AddLabel('Player Color'):AddColorPicker('ColorPicker', {
    Default = Color3.new(0, 1, 0), 
    Title = 'Color', 
    Transparency = 0, 
    Callback = function(Value)
    		-- Сохраняем и применяем цвет; он переживёт смерть
		updateColor(Value)

		-- Если ForceField включён, убеждаемся, что материалные части окрашены в новый цвет
		if forceFieldEnabled then
			applyForceField() -- пройдёмся по конечностям, чтобы точно обновить цвет ForceField
		end
    end
})

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local lp = Players.LocalPlayer
local phantom = nil
local phantomConn = nil
local animConn = nil
local history = {}
local phantomEnabled = false -- чтобы понимать, включен ли тоггл

-- Удаление фантома
local function removePhantom()
    if phantom then
        phantom:Destroy()
        phantom = nil
    end
    if phantomConn then phantomConn:Disconnect() phantomConn = nil end
    if animConn then animConn:Disconnect() animConn = nil end
    history = {}
end

-- Создание фантома
local function spawnPhantom()
    removePhantom()

    local char = lp.Character or lp.CharacterAdded:Wait()
    local root = char:WaitForChild("HumanoidRootPart")
    local hum = char:WaitForChild("Humanoid")

    -- Клонируем
    local oldArchivable = char.Archivable
    char.Archivable = true
    local clone = char:Clone()
    char.Archivable = oldArchivable

    if not clone then return end

    -- Чистим аксессуары, одежду, face
    for _, inst in ipairs(clone:GetDescendants()) do
        if inst:IsA("Accessory") 
        or inst:IsA("Hat") 
        or inst:IsA("Shirt") 
        or inst:IsA("Pants") 
        or inst:IsA("ShirtGraphic") 
        or inst:IsA("BodyColors") then
            inst:Destroy()
        elseif inst:IsA("Decal") and inst.Name == "face" then
            inst:Destroy()
        elseif inst:IsA("MeshPart") or inst:IsA("Part") then
            inst.Transparency = 0.7
            inst.Color = Color3.new(1, 1, 1)
            inst.CanCollide = false
            inst.Massless = true
            if inst:IsA("MeshPart") then
                inst.TextureID = ""
                inst.Material = Enum.Material.SmoothPlastic
            end
            if inst.Name == "HumanoidRootPart" then
                inst.Transparency = 1 -- скрываем HRP
            end
        end
    end

    phantom = clone
    phantom.Name = "Phantom"
    phantom.Parent = workspace

    local phHum = phantom:FindFirstChildOfClass("Humanoid")
    local phAnimator = phHum and phHum:FindFirstChild("Animator")
    local animator = hum:FindFirstChild("Animator")

    if phHum then
        phHum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    end

    -- задержка (эффект пинга)
    history = {}
    local delayFrames = 15
    phantomConn = RunService.Heartbeat:Connect(function()
        if not phantom or not root.Parent then return end
        table.insert(history, root.CFrame)
        if #history > delayFrames then
            local oldCFrame = table.remove(history, 1)
            phantom:PivotTo(oldCFrame)
        end
    end)

    -- повтор анимаций
    if animator and phAnimator then
        animConn = animator.AnimationPlayed:Connect(function(track)
            for _, t in ipairs(phAnimator:GetPlayingAnimationTracks()) do
                t:Stop()
            end
            local newTrack = phAnimator:LoadAnimation(track.Animation)
            newTrack:Play()
            newTrack.TimePosition = track.TimePosition
            newTrack.Speed = track.Speed
        end)
    end
end

esps:AddToggle('Phantom', {
    Text = 'Phantom Toggle',
    Default = false,
    Callback = function(Value)
      phantomEnabled = Value
      if Value then
          spawnPhantom()
      else
          removePhantom()
      end
    end
})

-- Автопереспавн фантома после смерти / респавна игрока
lp.CharacterAdded:Connect(function(char)
    char:WaitForChild("Humanoid").Died:Connect(function()
        removePhantom()
    end)
    if phantomEnabled then
        task.wait(1) -- подождать пока у игрока всё прогрузится
        spawnPhantom()
    end
end)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

local coneColor = Color3.fromRGB(255, 0, 137) -- Стартовый цвет
local conePart = nil
local rainbowEnabled = false -- флаг для радужного режима
local rainbowConnection = nil -- хранит подключение цикла радужного цвета

-- Функция для создания конуса
local function createCone(character)
    if not character or not character:FindFirstChild("Head") then return end

    -- Удаляем старый конус
    if conePart and conePart.Parent then
        conePart:Destroy()
    end

    local head = character.Head

    -- Конус
    conePart = Instance.new("Part")
    conePart.Name = "ChinaHat"
    conePart.Size = Vector3.new(1, 1, 1)
    conePart.Anchored = false
    conePart.CanCollide = false
    conePart.Transparency = 0.3
    conePart.Color = coneColor

    local mesh = Instance.new("SpecialMesh", conePart)
    mesh.MeshType = Enum.MeshType.FileMesh
    mesh.MeshId = "rbxassetid://1033714"
    mesh.Scale = Vector3.new(1.7, 1.1, 1.7)

    local weld = Instance.new("Weld")
    weld.Part0 = head
    weld.Part1 = conePart
    weld.C0 = CFrame.new(0, 0.9, 0)

    conePart.Parent = character
    weld.Parent = conePart

    return conePart
end

-- Обновление цвета
local function updateConeColor(color)
    if conePart then
        conePart.Color = color
    end
end

-- Радужный цикл
local function startRainbow()
    if rainbowConnection then rainbowConnection:Disconnect() end
    rainbowConnection = RunService.RenderStepped:Connect(function()
        local t = tick() % 5 / 5 -- плавный цикл 0-1
        local color = Color3.fromHSV(t, 1, 1)
        updateConeColor(color)
    end)
end

local function stopRainbow()
    if rainbowConnection then
        rainbowConnection:Disconnect()
        rainbowConnection = nil
    end
    updateConeColor(coneColor)
end

-- Проверяем конус
local function checkCone()
    if not player.Character then return end
    local hatExists = player.Character:FindFirstChild("ChinaHat") or false
    if not hatExists then
        createCone(player.Character)
    end
    -- Восстанавливаем радужный режим если был включен
    if rainbowEnabled then
        startRainbow()
    else
        updateConeColor(coneColor)
    end
end

-- Респавн
player.CharacterAdded:Connect(function(character)
    createCone(character)
    if rainbowEnabled then
        startRainbow()
    else
        updateConeColor(coneColor)
    end

    while character and character:IsDescendantOf(game) do
        checkCone()
        task.wait(1)
    end
end)

-- Если уже есть персонаж
if player.Character then
    createCone(player.Character)
end

esps:AddLabel('China hat'):AddColorPicker('ColorPicker', {
    Default = Color3.new(0, 1, 0), 
    Title = 'China hat color', 
    Transparency = 0, 
    Callback = function(color)
        coneColor = color
        if not rainbowEnabled then
            updateConeColor(coneColor)
        end
    end
})

esps:AddToggle('Rainbow chinahat', {
    Text = 'Rainbow chinahat',
    Default = false,
    Callback = function(Value)
        rainbowEnabled = Value
        if Value then
            startRainbow()
        else
            stopRainbow()
        end
    end
})

local esps = Tabs.Vis:AddLeftGroupbox('Visual')

esps:AddToggle('Fullbrightt', {
    Text = 'Fullbright',
    Default = false,
    Callback = function(state)
        if state then
        _G.LightingEnabled = true

local Lighting = game:GetService("Lighting")

if _G.LightingEnabled then
  
    Lighting.Ambient = Color3.new(1, 1, 1)
    Lighting.Brightness = 2
    Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
    Lighting.FogEnd = 1e10

   
    Lighting:GetPropertyChangedSignal("Ambient"):Connect(function()
        if _G.LightingEnabled then
            Lighting.Ambient = Color3.new(1, 1, 1)
        end
    end)

    Lighting:GetPropertyChangedSignal("Brightness"):Connect(function()
        if _G.LightingEnabled then
            Lighting.Brightness = 2
        end
    end)

    Lighting:GetPropertyChangedSignal("OutdoorAmbient"):Connect(function()
        if _G.LightingEnabled then
            Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
        end
    end)

    Lighting:GetPropertyChangedSignal("FogEnd"):Connect(function()
        if _G.LightingEnabled then
            Lighting.FogEnd = 1e10
        end
    end)
end

    else
        _G.LightingEnabled = false

local Lighting = game:GetService("Lighting")

-- Устанавливаем чуть более светлый нейтральный свет
Lighting.Ambient = Color3.new(0.7, 0.7, 0.7) -- Легкий серый оттенок
Lighting.Brightness = 1 -- Стандартная яркость
Lighting.OutdoorAmbient = Color3.new(0.7, 0.7, 0.7) -- Тот же светлый серый
Lighting.FogEnd = 100000 -- Ограничение на дальность тумана

    end
    end
})

esps:AddButton('Remove Fog', function()
    game.Lighting.FogEnd = 10000
    game.Lighting.FogStart = 0
end)

local skk = Tabs.sk:AddLeftGroupbox('Sky')

local SkyBoxes = {
    ["Night"] = {
        Bk = "http://www.roblox.com/asset/?id=48020371",
        Dn = "http://www.roblox.com/asset/?id=48020144",
        Ft = "http://www.roblox.com/asset/?id=48020234",
        Lf = "http://www.roblox.com/asset/?id=48020211",
        Rt = "http://www.roblox.com/asset/?id=48020254",
        Up = "http://www.roblox.com/asset/?id=48020383",
    },
    ["Pink"] = {
        Bk = "http://www.roblox.com/asset/?id=271042516",
        Dn = "http://www.roblox.com/asset/?id=271077243",
        Ft = "http://www.roblox.com/asset/?id=271042556",
        Lf = "http://www.roblox.com/asset/?id=271042310",
        Rt = "http://www.roblox.com/asset/?id=271042467",
        Up = "http://www.roblox.com/asset/?id=271077958",
    },
    ["Moon"] = {
        Bk = "rbxassetid://159454299",
        Dn = "rbxassetid://159454296",
        Ft = "rbxassetid://159454293",
        Lf = "rbxassetid://159454286",
        Rt = "rbxassetid://159454300",
        Up = "rbxassetid://159454288",
    },
    ["Black"] = {
        Bk = "http://www.roblox.com/asset/?ID=2013298",
        Dn = "http://www.roblox.com/asset/?ID=2013298",
        Ft = "http://www.roblox.com/asset/?ID=2013298",
        Lf = "http://www.roblox.com/asset/?ID=2013298",
        Rt = "http://www.roblox.com/asset/?ID=2013298",
        Up = "http://www.roblox.com/asset/?ID=2013298",
    }
}

local function ApplySky(data)
    if not data then return end -- защита от nil

    for _, v in pairs(game.Lighting:GetChildren()) do
        if v:IsA("Sky") then
            v:Destroy()
        end
    end

    local sky = Instance.new("Sky")
    sky.Name = "ColorfulSky"
    sky.SkyboxBk = data.Bk
    sky.SkyboxDn = data.Dn
    sky.SkyboxFt = data.Ft
    sky.SkyboxLf = data.Lf
    sky.SkyboxRt = data.Rt
    sky.SkyboxUp = data.Up
    sky.SunAngularSize = 21
    sky.SunTextureId = ""
    sky.MoonTextureId = ""
    sky.Parent = game.Lighting
end

skk:AddDropdown("SkySelector", {
    Values = {"Night", "Pink", "Moon", "Black"},
    Default = 1,
    Multi = false,
    Text = "Skybox",

    Callback = function(Value)
        ApplySky(SkyBoxes[Value])
    end
})

-- сразу Night ставим
ApplySky(SkyBoxes["Night"])

local skk = Tabs.sk:AddRightGroupbox('Sky Settings')

local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")

local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")

-- Настройки дня и ночи
local daySettings = {
    ClockTime = 14,
    Ambient = Color3.fromRGB(178, 178, 178),
}

local nightSettings = {
    ClockTime = 0,
    Ambient = Color3.fromRGB(50, 50, 50),
}

local isDay = true

-- Функция переключения дня и ночи
local function toggleDayNight()
    isDay = not isDay
    
    if isDay then
        for property, value in pairs(daySettings) do
            Lighting[property] = value
        end
    else
        for property, value in pairs(nightSettings) do
            Lighting[property] = value
        end
    end
end

skk:AddToggle('Day/Night', {
    Text = 'Day/Night',
    Default = false,
    Callback = function(Value)
    toggleDayNight()
    end
})

Library:SetWatermarkVisibility(true)

local servee = Tabs.serve:AddLeftGroupbox('Server')

-- Сервисы
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local MarketplaceService = game:GetService("MarketplaceService")
local TeleportService = game:GetService("TeleportService")

servee:AddButton('Rejoin', function()
       local ok, err = pcall(function()
           TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
       end)
       if not ok then
           warn("Rejoin failed:", err)
       end
end)

local UU = Tabs.U:AddLeftGroupbox('Server')

local StarterGui = game:GetService("StarterGui")

UU:AddToggle("Health", {
    Text = "Hide Health",
    Default = false,
    Callback = function(Value)
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, not Value)
        -- если Value = true → спрятать, если false → показать
    end
})

UU:AddToggle("PlayerList", {
    Text = "Hide PlayerList",
    Default = false,
    Callback = function(Value)
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, not Value)
        -- если Value = true → спрятать, если false → показать
    end
})

UU:AddToggle("Backpack", {
    Text = "Hide Backpack",
    Default = false,
    Callback = function(Value)
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, not Value)
        -- если Value = true → спрятать, если false → показать
    end
})

UU:AddToggle("Chat", {
    Text = "Hide Chat",
    Default = false,
    Callback = function(Value)
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, not Value)
        -- если Value = true → спрятать, если false → показать
    end
})

UU:AddToggle("EmotesMenu", {
    Text = "Hide EmotesMenu",
    Default = false,
    Callback = function(Value)
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu, not Value)
        -- если Value = true → спрятать, если false → показать
    end
})

UU:AddToggle("All", {
    Text = "Hide All Core UI",
    Default = false,
    Callback = function(Value)
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, not Value)
        -- если Value = true → спрятать, если false → показать
    end
})

local FrameTimer = tick()
local FrameCounter = 0;
local FPS = 165;

local WatermarkConnection = game:GetService('RunService').RenderStepped:Connect(function()
    FrameCounter += 1;

    if (tick() - FrameTimer) >= 1 then
        FPS = FrameCounter;
        FrameTimer = tick();
        FrameCounter = 0;
    end;

    Library:SetWatermark(('gamesense.lua | %s fps | %s ms'):format(
        math.floor(FPS),
        math.floor(game:GetService('Stats').Network.ServerStatsItem['Data Ping']:GetValue())
    ));
end);

Library.KeybindFrame.Visible = true;
Library:OnUnload(function()
    WatermarkConnection:Disconnect()

    print('Unloaded!')
    Library.Unloaded = true
end)

local MenuGroup = Tabs['UI Settings']:AddLeftGroupbox('Menu')

MenuGroup:AddButton('Unload', function() Library:Unload() end)
MenuGroup:AddLabel('Menu bind'):AddKeyPicker('MenuKeybind', { Default = 'End', NoUI = true, Text = 'Menu keybind' })

Library.ToggleKeybind = Options.MenuKeybind -- Allows you to have a custom keybind for the menu

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ 'MenuKeybind' })
ThemeManager:SetFolder('MyScriptHub')
SaveManager:SetFolder('MyScriptHub/specific-game')
SaveManager:BuildConfigSection(Tabs['UI Settings'])
ThemeManager:ApplyToTab(Tabs['UI Settings'])
SaveManager:LoadAutoloadConfig()