-- init
if not game:IsLoaded() then 
    game.Loaded:Wait()
end

if not syn or not protectgui then
    getgenv().protectgui = function() end
end

local SilentAimSettings = {
    Enabled = false,
    
    ClassName = "Universal Silent Aim - Averiias, Stefanuk12, xaxa",
    ToggleKey = "RightAlt",
    
    TeamCheck = false,
    VisibleCheck = false, 
    TargetPart = "HumanoidRootPart",
    SilentAimMethod = "Raycast",
    
    FOVRadius = 130,
    FOVVisible = false,
    ShowSilentAimTarget = false, 
    
    MouseHitPrediction = false,
    MouseHitPredictionAmount = 0.165,
    HitChance = 100
}

-- variables
getgenv().SilentAimSettings = Settings
local MainFileName = "UniversalSilentAim"
local SelectedFile, FileToSave = "", ""

local Camera = workspace.CurrentCamera
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local GetChildren = game.GetChildren
local GetPlayers = Players.GetPlayers
local WorldToScreen = Camera.WorldToScreenPoint
local WorldToViewportPoint = Camera.WorldToViewportPoint
local GetPartsObscuringTarget = Camera.GetPartsObscuringTarget
local FindFirstChild = game.FindFirstChild
local RenderStepped = RunService.RenderStepped
local GuiInset = GuiService.GetGuiInset
local GetMouseLocation = UserInputService.GetMouseLocation

local resume = coroutine.resume 
local create = coroutine.create

local ValidTargetParts = {"Head", "HumanoidRootPart"}
local PredictionAmount = 0.165

local mouse_box = Drawing.new("Square")
mouse_box.Visible = true 
mouse_box.ZIndex = 999 
mouse_box.Color = Color3.fromRGB(54, 57, 241)
mouse_box.Thickness = 20 
mouse_box.Size = Vector2.new(20, 20)
mouse_box.Filled = true 

local fov_circle = Drawing.new("Circle")
fov_circle.Thickness = 1
fov_circle.NumSides = 100
fov_circle.Radius = 180
fov_circle.Filled = false
fov_circle.Visible = false
fov_circle.ZIndex = 999
fov_circle.Transparency = 1
fov_circle.Color = Color3.fromRGB(54, 57, 241)

local ExpectedArguments = {
    FindPartOnRayWithIgnoreList = {
        ArgCountRequired = 3,
        Args = {
            "Instance", "Ray", "table", "boolean", "boolean"
        }
    },
    FindPartOnRayWithWhitelist = {
        ArgCountRequired = 3,
        Args = {
            "Instance", "Ray", "table", "boolean"
        }
    },
    FindPartOnRay = {
        ArgCountRequired = 2,
        Args = {
            "Instance", "Ray", "Instance", "boolean", "boolean"
        }
    },
    Raycast = {
        ArgCountRequired = 3,
        Args = {
            "Instance", "Vector3", "Vector3", "RaycastParams"
        }
    }
}

function CalculateChance(Percentage)
    -- // Floor the percentage
    Percentage = math.floor(Percentage)

    -- // Get the chance
    local chance = math.floor(Random.new().NextNumber(Random.new(), 0, 1) * 100) / 100

    -- // Return
    return chance <= Percentage / 100
end


--[[file handling]] do 
    if not isfolder(MainFileName) then 
        makefolder(MainFileName);
    end
    
    if not isfolder(string.format("%s/%s", MainFileName, tostring(game.PlaceId))) then 
        makefolder(string.format("%s/%s", MainFileName, tostring(game.PlaceId)))
    end
end

local Files = listfiles(string.format("%s/%s", "UniversalSilentAim", tostring(game.PlaceId)))

-- functions
local function GetFiles() -- credits to the linoria lib for this function, listfiles returns the files full path and its annoying
	local out = {}
	for i = 1, #Files do
		local file = Files[i]
		if file:sub(-4) == '.lua' then
			-- i hate this but it has to be done ...

			local pos = file:find('.lua', 1, true)
			local start = pos

			local char = file:sub(pos, pos)
			while char ~= '/' and char ~= '\\' and char ~= '' do
				pos = pos - 1
				char = file:sub(pos, pos)
			end

			if char == '/' or char == '\\' then
				table.insert(out, file:sub(pos + 1, start - 1))
			end
		end
	end
	
	return out
end

local function UpdateFile(FileName)
    assert(FileName or FileName == "string", "oopsies");
    writefile(string.format("%s/%s/%s.lua", MainFileName, tostring(game.PlaceId), FileName), HttpService:JSONEncode(SilentAimSettings))
end

local function LoadFile(FileName)
    assert(FileName or FileName == "string", "oopsies");
    
    local File = string.format("%s/%s/%s.lua", MainFileName, tostring(game.PlaceId), FileName)
    local ConfigData = HttpService:JSONDecode(readfile(File))
    for Index, Value in next, ConfigData do
        SilentAimSettings[Index] = Value
    end
end

local function getPositionOnScreen(Vector)
    local Vec3, OnScreen = WorldToScreen(Camera, Vector)
    return Vector2.new(Vec3.X, Vec3.Y), OnScreen
end

local function ValidateArguments(Args, RayMethod)
    local Matches = 0
    if #Args < RayMethod.ArgCountRequired then
        return false
    end
    for Pos, Argument in next, Args do
        if typeof(Argument) == RayMethod.Args[Pos] then
            Matches = Matches + 1
        end
    end
    return Matches >= RayMethod.ArgCountRequired
end

local function getDirection(Origin, Position)
    return (Position - Origin).Unit * 1000
end

local function getMousePosition()
    return GetMouseLocation(UserInputService)
end

local function IsPlayerVisible(Player)
    local PlayerCharacter = Player.Character
    local LocalPlayerCharacter = LocalPlayer.Character
    
    if not (PlayerCharacter or LocalPlayerCharacter) then return end 
    
    local PlayerRoot = FindFirstChild(PlayerCharacter, Options.TargetPart.Value) or FindFirstChild(PlayerCharacter, "HumanoidRootPart")
    
    if not PlayerRoot then return end 
    
    local CastPoints, IgnoreList = {PlayerRoot.Position, LocalPlayerCharacter, PlayerCharacter}, {LocalPlayerCharacter, PlayerCharacter}
    local ObscuringObjects = #GetPartsObscuringTarget(Camera, CastPoints, IgnoreList)
    
    return ((ObscuringObjects == 0 and true) or (ObscuringObjects > 0 and false))
end

local function getClosestPlayer()
    if not Options.TargetPart.Value then return end
    local Closest
    local DistanceToMouse
    for _, Player in next, GetPlayers(Players) do
        if Player == LocalPlayer then continue end
        if Toggles.TeamCheck.Value and Player.Team == LocalPlayer.Team then continue end

        local Character = Player.Character
        if not Character then continue end
        
        if Toggles.VisibleCheck.Value and not IsPlayerVisible(Player) then continue end

        local HumanoidRootPart = FindFirstChild(Character, "HumanoidRootPart")
        local Humanoid = FindFirstChild(Character, "Humanoid")
        if not HumanoidRootPart or not Humanoid or Humanoid and Humanoid.Health <= 0 then continue end

        local ScreenPosition, OnScreen = getPositionOnScreen(HumanoidRootPart.Position)
        if not OnScreen then continue end

        local Distance = (getMousePosition() - ScreenPosition).Magnitude
        if Distance <= (DistanceToMouse or Options.Radius.Value or 2000) then
            Closest = ((Options.TargetPart.Value == "Random" and Character[ValidTargetParts[math.random(1, #ValidTargetParts)]]) or Character[Options.TargetPart.Value])
            DistanceToMouse = Distance
        end
    end
    return Closest
end

local repo = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'

local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local SaveManager = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()

local Window = Library:CreateWindow({Title = 'skeet.lua', Center = true, AutoShow = true, TabPadding = 8, MenuFadeTime = 0})
local GeneralTab = Window:AddTab("Combat")
local MainBOX = GeneralTab:AddLeftTabbox("Main") do
    local Main = MainBOX:AddTab("Main")
    
    Main:AddToggle("aim_Enabled", {Text = "Enabled"}):AddKeyPicker("aim_Enabled_KeyPicker", {Default = "RightAlt", SyncToggleState = true, Mode = "Toggle", Text = "Enabled", NoUI = false});
    Options.aim_Enabled_KeyPicker:OnClick(function()
        SilentAimSettings.Enabled = not SilentAimSettings.Enabled
        
        Toggles.aim_Enabled.Value = SilentAimSettings.Enabled
        Toggles.aim_Enabled:SetValue(SilentAimSettings.Enabled)
        
        mouse_box.Visible = SilentAimSettings.Enabled
    end)
    
    Main:AddToggle("TeamCheck", {Text = "Team Check", Default = SilentAimSettings.TeamCheck}):OnChanged(function()
        SilentAimSettings.TeamCheck = Toggles.TeamCheck.Value
    end)
    Main:AddToggle("VisibleCheck", {Text = "Visible Check", Default = SilentAimSettings.VisibleCheck}):OnChanged(function()
        SilentAimSettings.VisibleCheck = Toggles.VisibleCheck.Value
    end)
    Main:AddDropdown("TargetPart", {AllowNull = true, Text = "Target Part", Default = SilentAimSettings.TargetPart, Values = {"Head", "HumanoidRootPart", "Random"}}):OnChanged(function()
        SilentAimSettings.TargetPart = Options.TargetPart.Value
    end)
    Main:AddDropdown("Method", {AllowNull = true, Text = "Silent Aim Method", Default = SilentAimSettings.SilentAimMethod, Values = {
        "Raycast","FindPartOnRay",
        "FindPartOnRayWithWhitelist",
        "FindPartOnRayWithIgnoreList",
        "Mouse.Hit/Target"
    }}):OnChanged(function() 
        SilentAimSettings.SilentAimMethod = Options.Method.Value 
    end)
    Main:AddSlider('HitChance', {
        Text = 'Hit chance',
        Default = 100,
        Min = 0,
        Max = 100,
        Rounding = 1,
    
        Compact = false,
    })
    Options.HitChance:OnChanged(function()
        SilentAimSettings.HitChance = Options.HitChance.Value
    end)
end

local MiscellaneousBOX = GeneralTab:AddLeftTabbox("Miscellaneous")
local FieldOfViewBOX = GeneralTab:AddLeftTabbox("Field Of View") do
    local Main = FieldOfViewBOX:AddTab("Visuals")
    
    Main:AddToggle("Visible", {Text = "Show FOV Circle"}):AddColorPicker("Color", {Default = Color3.fromRGB(54, 57, 241)}):OnChanged(function()
        fov_circle.Visible = Toggles.Visible.Value
        SilentAimSettings.FOVVisible = Toggles.Visible.Value
    end)
    Main:AddSlider("Radius", {Text = "FOV Circle Radius", Min = 0, Max = 360, Default = 130, Rounding = 0}):OnChanged(function()
        fov_circle.Radius = Options.Radius.Value
        SilentAimSettings.FOVRadius = Options.Radius.Value
    end)
    Main:AddToggle("MousePosition", {Text = "Show Silent Aim Target"}):AddColorPicker("MouseVisualizeColor", {Default = Color3.fromRGB(54, 57, 241)}):OnChanged(function()
        mouse_box.Visible = Toggles.MousePosition.Value 
        SilentAimSettings.ShowSilentAimTarget = Toggles.MousePosition.Value 
    end)
    local PredictionTab = MiscellaneousBOX:AddTab("Prediction")
    PredictionTab:AddToggle("Prediction", {Text = "Mouse.Hit/Target Prediction"}):OnChanged(function()
        SilentAimSettings.MouseHitPrediction = Toggles.Prediction.Value
    end)
    PredictionTab:AddSlider("Amount", {Text = "Prediction Amount", Min = 0.165, Max = 1, Default = 0.165, Rounding = 3}):OnChanged(function()
        PredictionAmount = Options.Amount.Value
        SilentAimSettings.MouseHitPredictionAmount = Options.Amount.Value
    end)
end

resume(create(function()
    RenderStepped:Connect(function()
        if Toggles.MousePosition.Value and Toggles.aim_Enabled.Value then
            if getClosestPlayer() then 
                local Root = getClosestPlayer().Parent.PrimaryPart or getClosestPlayer()
                local RootToViewportPoint, IsOnScreen = WorldToViewportPoint(Camera, Root.Position);
                -- using PrimaryPart instead because if your Target Part is "Random" it will flicker the square between the Target's Head and HumanoidRootPart (its annoying)
                
                mouse_box.Visible = IsOnScreen
                mouse_box.Position = Vector2.new(RootToViewportPoint.X, RootToViewportPoint.Y)
            else 
                mouse_box.Visible = false 
                mouse_box.Position = Vector2.new()
            end
        end
        
        if Toggles.Visible.Value then 
            fov_circle.Visible = Toggles.Visible.Value
            fov_circle.Color = Options.Color.Value
            fov_circle.Position = getMousePosition()
        end
    end)
end))

-- hooks
local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(...)
    local Method = getnamecallmethod()
    local Arguments = {...}
    local self = Arguments[1]
    local chance = CalculateChance(SilentAimSettings.HitChance)
    if Toggles.aim_Enabled.Value and self == workspace and not checkcaller() and chance == true then
        if Method == "FindPartOnRayWithIgnoreList" and Options.Method.Value == Method then
            if ValidateArguments(Arguments, ExpectedArguments.FindPartOnRayWithIgnoreList) then
                local A_Ray = Arguments[2]

                local HitPart = getClosestPlayer()
                if HitPart then
                    local Origin = A_Ray.Origin
                    local Direction = getDirection(Origin, HitPart.Position)
                    Arguments[2] = Ray.new(Origin, Direction)

                    return oldNamecall(unpack(Arguments))
                end
            end
        elseif Method == "FindPartOnRayWithWhitelist" and Options.Method.Value == Method then
            if ValidateArguments(Arguments, ExpectedArguments.FindPartOnRayWithWhitelist) then
                local A_Ray = Arguments[2]

                local HitPart = getClosestPlayer()
                if HitPart then
                    local Origin = A_Ray.Origin
                    local Direction = getDirection(Origin, HitPart.Position)
                    Arguments[2] = Ray.new(Origin, Direction)

                    return oldNamecall(unpack(Arguments))
                end
            end
        elseif (Method == "FindPartOnRay" or Method == "findPartOnRay") and Options.Method.Value:lower() == Method:lower() then
            if ValidateArguments(Arguments, ExpectedArguments.FindPartOnRay) then
                local A_Ray = Arguments[2]

                local HitPart = getClosestPlayer()
                if HitPart then
                    local Origin = A_Ray.Origin
                    local Direction = getDirection(Origin, HitPart.Position)
                    Arguments[2] = Ray.new(Origin, Direction)

                    return oldNamecall(unpack(Arguments))
                end
            end
        elseif Method == "Raycast" and Options.Method.Value == Method then
            if ValidateArguments(Arguments, ExpectedArguments.Raycast) then
                local A_Origin = Arguments[2]

                local HitPart = getClosestPlayer()
                if HitPart then
                    Arguments[3] = getDirection(A_Origin, HitPart.Position)

                    return oldNamecall(unpack(Arguments))
                end
            end
        end
    end
    return oldNamecall(...)
end))

local oldIndex = nil 
oldIndex = hookmetamethod(game, "__index", newcclosure(function(self, Index)
    if self == Mouse and not checkcaller() and Toggles.aim_Enabled.Value and Options.Method.Value == "Mouse.Hit/Target" and getClosestPlayer() then
        local HitPart = getClosestPlayer()
         
        if Index == "Target" or Index == "target" then 
            return HitPart
        elseif Index == "Hit" or Index == "hit" then 
            return ((Toggles.Prediction.Value and (HitPart.CFrame + (HitPart.Velocity * PredictionAmount))) or (not Toggles.Prediction.Value and HitPart.CFrame))
        elseif Index == "X" or Index == "x" then 
            return self.X 
        elseif Index == "Y" or Index == "y" then 
            return self.Y 
        elseif Index == "UnitRay" then 
            return Ray.new(self.Origin, (self.Hit - self.Origin).Unit)
        end
    end

    return oldIndex(self, Index)
end))

local VisualsBox = Window:AddTab("Visuals")
local PlayersBOX = VisualsBox:AddLeftTabbox("Players")
do
    local Players = PlayersBOX:AddTab("Players")
end

local OtherTab   = Window:AddTab("Other")

-- таббокс слева (обычно без названия при создании)
local LeftTabbox = OtherTab:AddLeftTabbox()

-- сам таб внутри таббокса
local SelfTab = LeftTabbox:AddTab("Self")

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
SelfTab:AddToggle('FakeLagEnabled', {
    Text = 'Fake Lag',
    Default = false,
    Callback = function(Value)
        fakeLagEnabled = Value
    end
})

SelfTab:AddToggle('BunnyHopEnabled', {
    Text = 'Bunny Hop',
    Default = false,
    Callback = function(Value)
        bunnyHopEnabled = Value
    end
})

SelfTab:AddSlider('BhopSpeed', {
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

SelfTab:AddDropdown('RotationMode', {
    Values = { 'Spin', '180', 'Forward' },
    Default = 3,
    Multi = false,
    Text = 'Rotation Mode',
    Callback = function(Value)
        rotationMode = Value
    end
})

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

-- Fly Speed slider
SelfTab:AddSlider('FlySpeed', {
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
SelfTab:AddSlider('FlyBoost', {
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
SelfTab:AddLabel('Fly Key'):AddKeyPicker('FlyKeybind', {
    Default = 'F2',
    SyncToggleState = true,
    Mode = 'Toggle',
    Text = 'Fly',
    NoUI = false,
    Callback = function(Value)
        toggleFly(Value)
    end
})

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

SelfTab:AddSlider('WalkTPSpeed', {
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

-- таббокс слева (обычно без названия при создании)
local RightTabbox = OtherTab:AddRightTabbox()

-- сам таб внутри таббокса
local OtherBox = RightTabbox:AddTab("Other")

OtherBox:AddButton('Remove fog', function()
    game.Lighting.FogEnd = 10000
    game.Lighting.FogStart = 0
end)

OtherBox:AddSlider('ssss', {
    Text = 'Brightness',
    Default = 3,
    Min = 0,
    Max = 10,
    Rounding = 1, -- в Linoria округление задаётся целым числом знаков после запятой
    Suffix = '', -- у Brightness нет процентов, лучше оставить пустым
    Callback = function(Value)
        game:GetService("Lighting").Brightness = Value
    end
})


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

OtherBox:AddDropdown("SkySelector", {
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

OtherBox:AddToggle('HideTerrainDecor', {
    Text = 'Hide grass',
    Default = false,
    Tooltip = 'nothink',
    Callback = function(on)
        local ok, err = pcall(function()
            workspace.Terrain.Decoration = not (not on)
        end)
        if not ok then
            warn("[Linoria] Не удалось изменить Terrain.Decoration: ", err)
        end
    end
})

-- Сохраним дефолтные значения, чтобы было куда возвращать
local L = game:GetService("Lighting")
local Defaults = {
    Ambient = L.Ambient,
    OutdoorAmbient = L.OutdoorAmbient
}

-- Тумблер + цвет
OtherBox:AddToggle('AmbientToggle', { Text = 'Ambient override', Default = false })
    :AddColorPicker('AmbientColor', { Default = Color3.fromRGB(54, 57, 241) })

-- Реакция на ВКЛ/ВЫКЛ тумблера
Toggles.AmbientToggle:OnChanged(function()
    if Toggles.AmbientToggle.Value then
        local c = Options.AmbientColor.Value
        L.Ambient = c
        L.OutdoorAmbient = c
    else
        L.Ambient = Defaults.Ambient
        L.OutdoorAmbient = Defaults.OutdoorAmbient
    end
end)

-- Если меняем цвет — применяем его, но только когда тумблер включён
Options.AmbientColor:OnChanged(function()
    if Toggles.AmbientToggle.Value then
        local c = Options.AmbientColor.Value
        L.Ambient = c
        L.OutdoorAmbient = c
    end
end)

OtherBox:AddButton('Unlock camera', function()
    local Players = game:GetService("Players")
    local player = Players.LocalPlayer

    -- Set maximum zoom distance to a large number
    player.CameraMaxZoomDistance = 9999

    -- Set camera mode to Classic
    player.CameraMode = Enum.CameraMode.Classic
end)

local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera

local fovValue = 70 -- начальное значение FOV

-- Слайдер для изменения FOV
OtherBox:AddSlider('FovSlider', {
    Text = 'Fov',
    Default = fovValue,
    Min = 10,
    Max = 120,
    Rounding = 0,
    Compact = false,
    Callback = function(Value)
        fovValue = Value
    end
})

-- Loop для обновления FOV каждый кадр
RunService.RenderStepped:Connect(function()
    if Camera then
        Camera.FieldOfView = fovValue
    end
end)


-- LocalScript в StarterPlayerScripts

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- ====== Состояние
local currentTool: Tool? = nil
local renderConn: RBXScriptConnection? = nil
local equipConns = {}
local baseGrip = CFrame.new()

local offsetPos = Vector3.new(0, 0, 0)
local offsetRot = Vector3.new(0, 0, 0)
local onlyFirstPerson = true -- toggle state

-- Получаем смещение в виде CFrame
local function getOffsetCFrame()
	return CFrame.new(offsetPos) * CFrame.Angles(
		math.rad(offsetRot.X), 
		math.rad(offsetRot.Y), 
		math.rad(offsetRot.Z)
	)
end

-- Останавливаем рендер
local function stopRender()
	if renderConn then
		renderConn:Disconnect()
		renderConn = nil
	end
end

-- Рендерим инструмент каждый кадр
local function startRender()
	stopRender()
	renderConn = RunService.RenderStepped:Connect(function()
		if currentTool and currentTool.Parent == LocalPlayer.Character then
			if onlyFirstPerson then
				local head = LocalPlayer.Character:FindFirstChild("Head")
				if head then
					local dist = (Camera.CFrame.Position - head.Position).Magnitude
					if dist < 0.6 then
						currentTool.Grip = baseGrip * getOffsetCFrame()
					else
						currentTool.Grip = baseGrip
					end
				end
			else
				currentTool.Grip = baseGrip * getOffsetCFrame()
			end
		end
	end)
end

-- Когда инструмент снимается
local function onUnequipped()
	if currentTool then
		currentTool.Grip = baseGrip
	end
	stopRender()
	currentTool = nil
end

-- Когда инструмент экипируется
local function onEquipped(tool: Tool)
	currentTool = tool
	baseGrip = tool.Grip
	startRender()
end

-- Подписка на инструмент
local function attachTool(tool: Instance)
	if not tool:IsA("Tool") then return end
	-- Только один раз подписываемся на Equipped и Unequipped
	if not equipConns[tool] then
		equipConns[tool] = {}
		equipConns[tool].Equipped = tool.Equipped:Connect(function() onEquipped(tool) end)
		equipConns[tool].Unequipped = tool.Unequipped:Connect(onUnequipped)
	end
	if tool.Parent == LocalPlayer.Character then
		onEquipped(tool)
	end
end

-- Обрабатываем все инструменты у персонажа и в рюкзаке
local function hookAllTools()
	local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	for _, t in ipairs(LocalPlayer.Backpack:GetChildren()) do
		attachTool(t)
	end
	LocalPlayer.Backpack.ChildAdded:Connect(attachTool)
	char.ChildAdded:Connect(attachTool)
end

-- Инициализация
hookAllTools()

-- Повторная инициализация после смерти
LocalPlayer.CharacterAdded:Connect(function(char)
	wait(0.1) -- дождаться появления частей
	hookAllTools()
end)

-- Toggle смещения
OtherBox:AddToggle('HideTerrainDeco', {
	Text = 'LeftHand',
	Default = false,
	Tooltip = 'in firstperson',
	Callback = function(on)
		offsetPos = Vector3.new(on and 3 or 0, offsetPos.Y, offsetPos.Z)
		if currentTool then
			currentTool.Grip = baseGrip * getOffsetCFrame()
		end
	end
})

local Tabs = {
    ['UI Settings'] = Window:AddTab('UI Settings'),
}

local MenuGroup = Tabs['UI Settings']:AddLeftGroupbox('Menu')

MenuGroup:AddButton('Unload', function() Library:Unload() end)
MenuGroup:AddButton('Rejoin', function()
    -- Сервисы
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local MarketplaceService = game:GetService("MarketplaceService")
local TeleportService = game:GetService("TeleportService")

       local ok, err = pcall(function()
           TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
       end)
       if not ok then
           warn("Rejoin failed:", err)
       end
end)
MenuGroup:AddLabel('Menu bind'):AddKeyPicker('MenuKeybind', { Default = 'End', NoUI = true, Text = 'Menu keybind' })

Library.ToggleKeybind = Options.MenuKeybind

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ 'MenuKeybind' })
ThemeManager:SetFolder('MyScriptHub')
SaveManager:SetFolder('MyScriptHub/specific-game')
SaveManager:BuildConfigSection(Tabs['UI Settings'])
ThemeManager:ApplyToTab(Tabs['UI Settings'])
SaveManager:LoadAutoloadConfig()
