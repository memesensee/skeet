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
    HitChance = 100,

    Autoshot = false,
    AutoshotDelay = 50
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

local Window = Library:CreateWindow({Title = 'chinozec.lol', Center = true, AutoShow = true, TabPadding = 8, MenuFadeTime = 0})
local GeneralTab = Window:AddTab("Combat")
local MainBOX = GeneralTab:AddLeftTabbox("Main") do
    local Main = MainBOX:AddTab("Main")
    
    Main:AddToggle("aim_Enabled", {Text = "Enabled"}):AddKeyPicker("aim_Enabled_KeyPicker", {Default = "RightAlt", SyncToggleState = true, Mode = "Toggle", Text = "Enabled", NoUI = false});
    Options.aim_Enabled_KeyPicker:OnClick(function()
    SilentAimSettings.Enabled = not SilentAimSettings.Enabled
    
    Toggles.aim_Enabled.Value = SilentAimSettings.Enabled
    Toggles.aim_Enabled:SetValue(SilentAimSettings.Enabled)
    
    mouse_box.Visible = SilentAimSettings.Enabled

    Library:Notify(SilentAimSettings.Enabled and 'Enable aim' or 'Disable aim')
end)

    Main:AddToggle("Autoshot", {Text = "Autoshot", Default = SilentAimSettings.Autoshot}):OnChanged(function()
        SilentAimSettings.Autoshot = Toggles.Autoshot.Value
    end)

    Main:AddSlider("AutoshotDelay", {Text = "Autoshot Delay (ms)", Min = 0, Max = 1000, Default = SilentAimSettings.AutoshotDelay, Rounding = 0}):OnChanged(function()
        SilentAimSettings.AutoshotDelay = Options.AutoshotDelay.Value
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
    local Main = FieldOfViewBOX:AddTab("")
    
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

local autoshotConnection
local lastShot = 0

Toggles.Autoshot:OnChanged(function()
    if Toggles.Autoshot.Value then
        autoshotConnection = RunService.Heartbeat:Connect(function()
            if not Toggles.aim_Enabled.Value then return end
            local Closest = getClosestPlayer()
            if Closest and tick() - lastShot >= (SilentAimSettings.AutoshotDelay / 1000 + 0.01) then
                mouse1press()
                task.wait(0.01)  -- Время "hold" клика, можно увеличить до 0.05 если не работает
                mouse1release()
                lastShot = tick()
            end
        end)
    else
        if autoshotConnection then
            autoshotConnection:Disconnect()
            autoshotConnection = nil
        end
    end
end)

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

-- Переменные для хранения состояния
local ESPEnabled = false
local ChamsEnabled = false
local BoxEnabled = false
local MaxDistance = 1000
local Highlights = {}
local Billboards = {}
local Boxes = {}
local ESPPosition = Vector3.new(0, 3, 0) -- По умолчанию над головой
local ShowNick = true
local ShowHP = true
local ShowDistance = true
local ShowItem = true
local NickColor = Color3.fromRGB(255, 255, 255)
local HPColor = Color3.fromRGB(255, 255, 255)
local DistanceColor = Color3.fromRGB(255, 255, 255)
local ItemColor = Color3.fromRGB(255, 255, 255)
local BoxColor = Color3.fromRGB(255, 255, 255)

-- Службы
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- Функция для получения предмета в руках
local function GetHoldingItem(character)
    if character then
        local tool = character:FindFirstChildOfClass("Tool")
        return tool and tool.Name or "None"
    end
    return "None"
end

-- Функция для создания Chams
local function CreateChams(player)
    if player ~= LocalPlayer and player.Character then
        local highlight = Instance.new("Highlight")
        highlight.Adornee = player.Character
        highlight.FillColor = Color3.fromRGB(255, 255, 255) -- Дефолт белый
        highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
        highlight.FillTransparency = 0.5
        highlight.OutlineTransparency = 0
        highlight.Parent = player.Character
        Highlights[player] = highlight
    end
end

-- Функция для удаления Chams
local function RemoveChams(player)
    if Highlights[player] then
        Highlights[player]:Destroy()
        Highlights[player] = nil
    end
end

-- Функция для создания BillboardGui с информацией
local function CreateESP(player)
    if player ~= LocalPlayer and player.Character then
        local billboard = Instance.new("BillboardGui")
        billboard.Name = "ESP_Label"
        local head = player.Character:FindFirstChild("Head") or player.Character:FindFirstChild("HumanoidRootPart")
        if not head then return end
        billboard.Adornee = head
        billboard.Size = UDim2.new(0, 200, 0, 100)
        billboard.StudsOffset = ESPPosition
        billboard.AlwaysOnTop = true
        billboard.Enabled = false

        local textLabel = Instance.new("TextLabel")
        textLabel.Size = UDim2.new(1, 0, 1, 0)
        textLabel.BackgroundTransparency = 1
        textLabel.TextStrokeTransparency = 0
        textLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        textLabel.TextSize = 14
        textLabel.Font = Enum.Font.SourceSans
        textLabel.TextYAlignment = Enum.TextYAlignment.Top
        textLabel.Parent = billboard
        billboard.Parent = player.Character

        -- Обновление информации в реальном времени
        local connection
        connection = RunService.RenderStepped:Connect(function()
            if not player.Character or not player.Character:FindFirstChild("Humanoid") or not Billboards[player] then
                if connection then connection:Disconnect() end
                return
            end
            local humanoid = player.Character.Humanoid
            local head = player.Character:FindFirstChild("Head")
            if not head then
                billboard.Enabled = false
                return
            end
            local distance = LocalPlayer:DistanceFromCharacter(head.Position)
            if distance > MaxDistance then
                billboard.Enabled = false
                return
            end
            billboard.Enabled = true
            local health = math.floor(humanoid.Health)
            local maxHealth = humanoid.MaxHealth
            local healthPercent = math.floor((health / maxHealth) * 100)
            local item = GetHoldingItem(player.Character)

            local textParts = {}
            if ShowNick then
                table.insert(textParts, string.format("<font color='rgb(%d,%d,%d)'>%s</font>", NickColor.R*255, NickColor.G*255, NickColor.B*255, player.Name))
            end
            if ShowHP then
                table.insert(textParts, string.format("<font color='rgb(%d,%d,%d)'>[%d%%]</font>", HPColor.R*255, HPColor.G*255, HPColor.B*255, healthPercent))
            end
            if ShowDistance then
                table.insert(textParts, string.format("<font color='rgb(%d,%d,%d)'>%.1f</font>", DistanceColor.R*255, DistanceColor.G*255, DistanceColor.B*255, distance))
            end
            if ShowItem then
                table.insert(textParts, string.format("<font color='rgb(%d,%d,%d)'>%s</font>", ItemColor.R*255, ItemColor.G*255, ItemColor.B*255, item))
            end

            textLabel.Text = table.concat(textParts, "\n")
            textLabel.RichText = true
        end)

        Billboards[player] = { Billboard = billboard, TextLabel = textLabel, Connection = connection }
    end
end

-- Функция для удаления ESP
local function RemoveESP(player)
    if Billboards[player] then
        if Billboards[player].Connection then Billboards[player].Connection:Disconnect() end
        Billboards[player].Billboard:Destroy()
        Billboards[player] = nil
    end
end

-- Функция для создания Box ESP
local function CreateBox(player)
    if player ~= LocalPlayer then
        if Boxes[player] then
            Boxes[player]:Remove()
            Boxes[player] = nil
        end
        local box = Drawing.new("Square")
        box.Visible = false
        box.Color = BoxColor
        box.Thickness = 1
        box.Transparency = 1
        box.Filled = false
        Boxes[player] = box
    end
end

-- Функция для удаления Box ESP
local function RemoveBox(player)
    if Boxes[player] then
        Boxes[player]:Remove()
        Boxes[player] = nil
    end
end

-- Функция для получения 2D bounding box
local function get2DBBox(character)
    local camera = workspace.CurrentCamera
    if not character or not character:FindFirstChild("HumanoidRootPart") then return nil end
    local cf, size = character:GetBoundingBox()
    local x, y, z = size.X / 2, size.Y / 2, size.Z / 2
    local corners = {
        Vector3.new(x, y, z),
        Vector3.new(x, y, -z),
        Vector3.new(x, -y, z),
        Vector3.new(x, -y, -z),
        Vector3.new(-x, y, z),
        Vector3.new(-x, y, -z),
        Vector3.new(-x, -y, z),
        Vector3.new(-x, -y, -z),
    }
    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
    local onScreen = false
    for _, offset in ipairs(corners) do
        local point = cf * offset
        local vec, vis = camera:WorldToViewportPoint(point)
        if vis then
            onScreen = true
            minX = math.min(minX, vec.X)
            minY = math.min(minY, vec.Y)
            maxX = math.max(maxX, vec.X)
            maxY = math.max(maxY, vec.Y)
        end
    end
    if not onScreen then return nil end
    return Vector2.new(minX, minY), Vector2.new(maxX - minX, maxY - minY)
end

-- Функция для обновления Box ESP
local boxConnection
local function updateBoxes()
    local camera = workspace.CurrentCamera
    for player, box in pairs(Boxes) do
        if player.Character and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0 then
            local head = player.Character:FindFirstChild("Head")
            if head then
                local distance = LocalPlayer:DistanceFromCharacter(head.Position)
                if distance > MaxDistance then
                    box.Visible = false
                    continue
                end
                local pos, size = get2DBBox(player.Character)
                if pos then
                    box.Position = pos
                    box.Size = size
                    box.Color = BoxColor
                    box.Visible = true
                else
                    box.Visible = false
                end
            else
                box.Visible = false
            end
        else
            box.Visible = false
        end
    end
end

-- Функция для обновления всех ESP
local function UpdateAllESP()
    for _, player in ipairs(Players:GetPlayers()) do
        if ESPEnabled and player ~= LocalPlayer and player.Character then
            CreateESP(player)
        else
            RemoveESP(player)
        end
        if ChamsEnabled and player ~= LocalPlayer and player.Character then
            CreateChams(player)
        else
            RemoveChams(player)
        end
        if BoxEnabled and player ~= LocalPlayer and player.Character then
            CreateBox(player)
        else
            RemoveBox(player)
        end
    end
end

local visuals = Window:AddTab("Visuals")

-- Левый Tabbox
local LeftTabbox = visuals:AddLeftTabbox()

-- Добавляем Tab в левый Tabbox
local LeftGroupBox = LeftTabbox:AddTab("ESP")

-- Переключатель для ESP
LeftGroupBox:AddToggle('ESP_Toggle', {
    Text = 'Enable ESP (Info Over Player)',
    Default = false,
    Tooltip = 'Toggles info display over players',
})

Toggles.ESP_Toggle:OnChanged(function()
    ESPEnabled = Toggles.ESP_Toggle.Value
    UpdateAllESP()
end)

-- Переключатель для Chams
LeftGroupBox:AddToggle('Chams_Toggle', {
    Text = 'Enable Chams (Highlight)',
    Default = false,
    Tooltip = 'Toggles player highlighting through walls',
})

Toggles.Chams_Toggle:OnChanged(function()
    ChamsEnabled = Toggles.Chams_Toggle.Value
    UpdateAllESP()
end)

-- Слайдер для прозрачности Chams
LeftGroupBox:AddSlider('Chams_Transparency', {
    Text = 'Chams Transparency',
    Default = 0.5,
    Min = 0,
    Max = 1,
    Rounding = 2,
    Tooltip = 'Adjust transparency of Chams highlights',
})

Options.Chams_Transparency:OnChanged(function()
    for _, highlight in pairs(Highlights) do
        highlight.FillTransparency = Options.Chams_Transparency.Value
    end
end)

-- ColorPicker для цвета Chams (прикреплен к Label)
LeftGroupBox:AddLabel('Chams Color'):AddColorPicker('Chams_Color', {
    Default = Color3.fromRGB(255, 255, 255),
    Callback = function(value)
        for _, highlight in pairs(Highlights) do
            highlight.FillColor = value
        end
    end,
    Tooltip = 'Select color for Chams highlights'
})

-- Переключатель для Box ESP с ColorPicker
LeftGroupBox:AddToggle('Box_Toggle', {
    Text = 'Enable Box ESP',
    Default = false,
    Tooltip = 'Toggles box around players',
})

Toggles.Box_Toggle:OnChanged(function()
    BoxEnabled = Toggles.Box_Toggle.Value
    if BoxEnabled then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                CreateBox(player)
            end
        end
        if not boxConnection then
            boxConnection = RunService.RenderStepped:Connect(updateBoxes)
        end
    else
        if boxConnection then
            boxConnection:Disconnect()
            boxConnection = nil
        end
        for player in pairs(Boxes) do
            RemoveBox(player)
        end
    end
end)

Toggles.Box_Toggle:AddColorPicker('Box_Color', {
    Default = Color3.fromRGB(255, 255, 255),
    Callback = function(value)
        BoxColor = value
    end,
    Tooltip = 'Select color for box ESP'
})

-- Правый Tabbox
local RightTabbox = visuals:AddRightTabbox()

-- Добавляем Tab в правый Tabbox
local ESPGroupBox = RightTabbox:AddTab("ESP Settings")

-- Слайдер для максимальной дистанции ESP
ESPGroupBox:AddSlider('Max_Distance', {
    Text = 'Max ESP Distance',
    Default = 1000,
    Min = 0,
    Max = 9999,
    Rounding = 0,
    Tooltip = 'Maximum distance to show ESP',
})

Options.Max_Distance:OnChanged(function()
    MaxDistance = Options.Max_Distance.Value
end)

-- Dropdown для позиции ESP
ESPGroupBox:AddDropdown('ESP_Position', {
    Text = 'ESP Position',
    Default = 'Above Head',
    Values = {'Above Head', 'Below Feet', 'On Torso'},
    Tooltip = 'Select position for ESP info',
})

Options.ESP_Position:OnChanged(function()
    if Options.ESP_Position.Value == 'Above Head' then
        ESPPosition = Vector3.new(0, 3, 0)
    elseif Options.ESP_Position.Value == 'Below Feet' then
        ESPPosition = Vector3.new(0, -3, 0)
    elseif Options.ESP_Position.Value == 'On Torso' then
        ESPPosition = Vector3.new(0, 0, 0)
    end
    -- Обновить позиции для существующих ESP
    for player, data in pairs(Billboards) do
        if data.Billboard then
            data.Billboard.StudsOffset = ESPPosition
        end
    end
end)

-- Переключатель для Nick с ColorPicker
ESPGroupBox:AddToggle('Show_Nick', {
    Text = 'Show Nick',
    Default = true,
    Tooltip = 'Toggle player name display',
})

Toggles.Show_Nick:OnChanged(function()
    ShowNick = Toggles.Show_Nick.Value
end)

Toggles.Show_Nick:AddColorPicker('Nick_Color', {
    Default = Color3.fromRGB(255, 255, 255),
    Callback = function(value)
        NickColor = value
    end,
    Tooltip = 'Select color for player name'
})

-- Переключатель для HP с ColorPicker
ESPGroupBox:AddToggle('Show_HP', {
    Text = 'Show HP',
    Default = true,
    Tooltip = 'Toggle health display',
})

Toggles.Show_HP:OnChanged(function()
    ShowHP = Toggles.Show_HP.Value
end)

Toggles.Show_HP:AddColorPicker('HP_Color', {
    Default = Color3.fromRGB(255, 255, 255),
    Callback = function(value)
        HPColor = value
    end,
    Tooltip = 'Select color for health'
})

-- Переключатель для Distance с ColorPicker
ESPGroupBox:AddToggle('Show_Distance', {
    Text = 'Show Distance',
    Default = true,
    Tooltip = 'Toggle distance display',
})

Toggles.Show_Distance:OnChanged(function()
    ShowDistance = Toggles.Show_Distance.Value
end)

Toggles.Show_Distance:AddColorPicker('Distance_Color', {
    Default = Color3.fromRGB(255, 255, 255),
    Callback = function(value)
        DistanceColor = value
    end,
    Tooltip = 'Select color for distance'
})

-- Переключатель для Item с ColorPicker
ESPGroupBox:AddToggle('Show_Item', {
    Text = 'Show Item',
    Default = true,
    Tooltip = 'Toggle item display',
})

Toggles.Show_Item:OnChanged(function()
    ShowItem = Toggles.Show_Item.Value
end)

Toggles.Show_Item:AddColorPicker('Item_Color', {
    Default = Color3.fromRGB(255, 255, 255),
    Callback = function(value)
        ItemColor = value
    end,
    Tooltip = 'Select color for item'
})

-- Функция для подписки на CharacterAdded
local function ConnectCharacter(player)
    player.CharacterAdded:Connect(function(char)
        -- Делаем задержку, чтобы персонаж успел полностью загрузиться
        wait(0.1)
        if ESPEnabled then
            CreateESP(player)
        end
        if ChamsEnabled then
            CreateChams(player)
        end
        if BoxEnabled then
            CreateBox(player)
        end
    end)
end

-- Подписываемся на всех существующих игроков
for _, player in ipairs(Players:GetPlayers()) do
    ConnectCharacter(player)
    -- Если у игрока уже есть персонаж
    if player.Character then
        if ESPEnabled then CreateESP(player) end
        if ChamsEnabled then CreateChams(player) end
        if BoxEnabled then CreateBox(player) end
    end
end

-- Подписка на новых игроков
Players.PlayerAdded:Connect(function(player)
    ConnectCharacter(player)
end)

-- Обработка ухода игроков
Players.PlayerRemoving:Connect(function(player)
    RemoveESP(player)
    RemoveChams(player)
    RemoveBox(player)
end)

-- Правый Tabbox
local RightTabbbox = visuals:AddLeftTabbox()

-- Добавляем Tab в правый Tabbox
local Localplayerr = RightTabbbox:AddTab("LocalPlayer")

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local coneColor = Color3.fromRGB(255, 0, 137) -- Начальный цвет
local conePart = nil -- Хранит текущий конус
local enabled = false -- Флаг для включения/выключения
local rainbowEnabled = false -- Флаг для радужного режима
local rainbowSpeed = 0.5 -- Скорость изменения цвета

-- Функция для создания конуса
local function createCone(character)
    if not enabled or not character or not character:FindFirstChild("Head") then return end

    -- Удаляем старый конус, если он есть
    if conePart and conePart.Parent then
        conePart:Destroy()
    end

    local head = character.Head

    -- Создаём конус
    conePart = Instance.new("Part")
    conePart.Name = "ChinaHat"
    conePart.Size = Vector3.new(1, 1, 1)
    conePart.Color = coneColor
    conePart.Transparency = 0.3
    conePart.Anchored = false
    conePart.CanCollide = false

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

-- Проверяем наличие конуса и обновляем цвет
local function checkCone()
    if not enabled or not player.Character then 
        if conePart and conePart.Parent then
            conePart:Destroy()
        end
        return 
    end
    
    local hatExists = player.Character:FindFirstChild("ChinaHat")
    if not hatExists then
        createCone(player.Character)
    else
        -- обновляем цвет
        hatExists.Color = coneColor
    end
end

-- Автоматическое пересоздание при респавне
player.CharacterAdded:Connect(function(character)
    createCone(character)
    
    -- Проверяем конус каждую секунду (на случай удаления)
    while character and character:IsDescendantOf(game) do
        checkCone()
        task.wait(1)
    end
end)

-- Если персонаж уже есть при запуске скрипта
if player.Character then
    createCone(player.Character)
end

-- Радужный режим (цикл цветов)
spawn(function()
    while true do
        if rainbowEnabled and enabled then
            local hue = tick() * rainbowSpeed % 1
            coneColor = Color3.fromHSV(hue, 1, 1)
            checkCone()
        end
        task.wait(0.05)
    end
end)

-- UI Elements
Localplayerr:AddToggle('EnableChinaHat', {
    Text = 'Enable China Hat',
    Default = false,
    Callback = function(value)
        enabled = value
        checkCone()
    end
})

Localplayerr:AddLabel('Hat Color'):AddColorPicker('HatColor', {
    Default = Color3.fromRGB(255, 255, 255),
    Callback = function(color)
        if not rainbowEnabled then
            coneColor = color
            checkCone()
        end
    end
})

Localplayerr:AddToggle('RainbowMode', {
    Text = 'Rainbow Mode',
    Default = false,
    Callback = function(value)
        rainbowEnabled = value
        if not rainbowEnabled then
            checkCone()
        end
    end
})

-- Variables
local playerEnabled = false
local toolEnabled = false
local toolMat = "Plastic"
local toolCol = Color3.fromRGB(255, 0, 0)
local playerCol = Color3.fromRGB(255, 255, 255)

-- All available Roblox materials, including ForceField
local Materials = {
    "Plastic", "SmoothPlastic", "Neon", "Glass", "Wood", "WoodPlanks", "Marble",
    "Slate", "Concrete", "Granite", "Metal", "DiamondPlate", "Foil", "CorrodedMetal",
    "Brick", "Pebble", "Sand", "Fabric", "Ice", "ForceField"
}

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()

-- =========================
-- Functions for player (with ForceField material)
-- =========================
function applyPlayer()
    if not Character then return end

    -- Change material and color of all player parts
    for _, part in pairs(Character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Material = Enum.Material.ForceField
            part.Color = playerCol
        end
    end
end

function resetPlayer()
    if not Character then return end

    -- Reset to default material and color
    for _, part in pairs(Character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Material = Enum.Material.Plastic
            part.Color = Color3.fromRGB(255, 255, 255)
        end
    end
end

-- Handle character respawn
LocalPlayer.CharacterAdded:Connect(function(newChar)
    Character = newChar
    if playerEnabled then
        applyPlayer()
    end
end)

-- =========================
-- Functions for tools
-- =========================
function applyTool(tool)
    if not tool:IsA("Tool") then return end
    for _, part in pairs(tool:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Material = Enum.Material[toolMat]
            part.Color = toolCol
        end
    end
end

function resetTool(tool)
    if not tool:IsA("Tool") then return end
    for _, part in pairs(tool:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Material = Enum.Material.Plastic
            part.Color = Color3.fromRGB(255, 255, 255)
        end
    end
end

function applyAllTools()
    -- Apply to tools in Backpack
    for _, tool in pairs(LocalPlayer.Backpack:GetChildren()) do
        applyTool(tool)
    end
    -- Apply to equipped tool in Character (held item)
    for _, tool in pairs(Character:GetChildren()) do
        applyTool(tool)
    end
end

function resetTools()
    -- Reset tools in Backpack
    for _, tool in pairs(LocalPlayer.Backpack:GetChildren()) do
        resetTool(tool)
    end
    -- Reset equipped tool in Character
    for _, tool in pairs(Character:GetChildren()) do
        resetTool(tool)
    end
end

-- Handle new tools added to Backpack
LocalPlayer.Backpack.ChildAdded:Connect(function(child)
    if toolEnabled then
        applyTool(child)
    end
end)

-- Handle tools equipped (added to Character, i.e., held)
Character.ChildAdded:Connect(function(child)
    if toolEnabled and child:IsA("Tool") then
        applyTool(child)
    end
end)

-- =========================
-- UI Elements (replace "Library" with your actual UI library variable, e.g., "Localplayerr" if that's it – looks like a typo in original)
-- =========================

-- ForceField on player
Localplayerr:AddToggle("ForceFieldPlayer", {
    Text = "ForceField on Player",
    Default = false,
    Callback = function(Value)
        playerEnabled = Value
        if Value then
            applyPlayer()
        else
            resetPlayer()
        end
    end
})

Localplayerr:AddLabel('Player Color'):AddColorPicker('PlayerColor', {
    Default = playerCol,
    Callback = function(Color)
        playerCol = Color
        if playerEnabled then
            applyPlayer()
        end
    end
})

-- Toggle for tools
Localplayerr:AddToggle("ToolMaterial", {
    Text = "Tool Material",
    Default = false,
    Callback = function(Value)
        toolEnabled = Value
        if Value then
            applyAllTools()
        else
            resetTools()
        end
    end
})

-- Dropdown for material selection (now includes ForceField)
Localplayerr:AddDropdown("ToolMaterialSelect", {
    Values = Materials,
    Default = toolMat,
    Multi = false,
    Text = "Tool Materials",
    Callback = function(Option)
        toolMat = Option
        if toolEnabled then
            applyAllTools()
        end
    end
})

Localplayerr:AddLabel('Tool Color'):AddColorPicker('ToolColor', {
    Default = toolCol,
    Callback = function(Color)
        toolCol = Color
        if toolEnabled then
            applyAllTools()
        end
    end
})
-- Правый Tabbox
local RightTabbbbox = visuals:AddRightTabbox()

-- Добавляем Tab в правый Tabbox
local Localplayerrr = RightTabbbbox:AddTab("Crosshair")

local player = game.Players.LocalPlayer
local mouse = player:GetMouse()
local runService = game:GetService("RunService")

-- Create ScreenGui
local gui = Instance.new("ScreenGui", player:WaitForChild("PlayerGui"))
gui.ResetOnSpawn = false
gui.Name = "CrosshairGui"

-- Function to create a line
local function createLine(parent, rotation)
    local line = Instance.new("Frame")
    line.Size = UDim2.new(0, 15, 0, 3) -- короче (было 30, стало 15)
    line.AnchorPoint = Vector2.new(0.5, 0.5)
    line.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    line.BorderSizePixel = 1
    line.BorderColor3 = Color3.fromRGB(0, 0, 0)
    line.Rotation = rotation
    line.Parent = parent
    return line
end

-- Crosshair container
local crosshair = Instance.new("Frame")
crosshair.Size = UDim2.new(0, 150, 0, 150) -- увеличил контейнер для отдалённых линий
crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
crosshair.BackgroundTransparency = 1
crosshair.Parent = gui

-- Gap (расстояние от центра)
local gap = 100

-- Create 4 crosshair lines
local top = createLine(crosshair, 90)
top.Position = UDim2.new(0.5, 0, 0, gap)

local bottom = createLine(crosshair, 90)
bottom.Position = UDim2.new(0.5, 0, 1, -gap)

local left = createLine(crosshair, 0)
left.Position = UDim2.new(0, gap, 0.5, 0)

local right = createLine(crosshair, 0)
right.Position = UDim2.new(1, -gap, 0.5, 0)

-- Text label
local textLabel = Instance.new("TextLabel")
textLabel.Size = UDim2.new(0, 150, 0, 35)
textLabel.AnchorPoint = Vector2.new(0.5, 0) -- теперь позиционируется от верха текста
textLabel.BackgroundTransparency = 1
textLabel.Font = Enum.Font.GothamBold
textLabel.TextSize = 22
textLabel.RichText = true
textLabel.Text = '<font color="rgb(255,0,0)">chinozec</font><font color="rgb(255,255,255)">.lol</font>'
textLabel.TextStrokeTransparency = 0
textLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
textLabel.Position = UDim2.new(0.5, 0, 1, 100) -- ниже кроссхэйра (смещение на 100px)
textLabel.Parent = gui

-- Animation parameters
local rotationSpeed = 65 -- крутится быстрее (раньше было 0.5)
local textOffset = Vector2.new(0, 40) -- текст теперь ниже центра и дальше от линий
local angle = 0
local blinkAlpha = 1
local blinkSpeed = 2
local isEnabled = false

-- Dynamic VIP color (starts as default red)
local vipColor = Color3.fromRGB(255, 0, 0)

-- Add elements to the groupbox
Localplayerrr:AddToggle("CrosshairEnabled", {
    Text = "Enable Crosshair",
    Default = false,
    Callback = function(value)
        isEnabled = value
        crosshair.Visible = value
        textLabel.Visible = value
    end
})

-- Add color picker via a chained label (this is the key fix)
Localplayerrr:AddLabel("Crosshair Color"):AddColorPicker("CrosshairColor", {
    Default = Color3.fromRGB(255, 0, 0),
    Callback = function(color)
        top.BackgroundColor3 = color
        bottom.BackgroundColor3 = color
        left.BackgroundColor3 = color
        right.BackgroundColor3 = color
        vipColor = color  -- Update the dynamic VIP color
    end
})

-- Animation loop
runService.RenderStepped:Connect(function(dt)
    if not isEnabled then return end

    angle = angle + rotationSpeed * dt
    crosshair.Rotation = angle % 360

    local mousePos = Vector2.new(mouse.X, mouse.Y)
    crosshair.Position = UDim2.new(0, mousePos.X, 0, mousePos.Y)

    local target = UDim2.new(0, mousePos.X + textOffset.X, 0, mousePos.Y + textOffset.Y)
    textLabel.Position = textLabel.Position:Lerp(target, 0.1)

    blinkAlpha = blinkAlpha + blinkSpeed * dt
    local vipTransparency = (math.sin(blinkAlpha) + 1) / 2 * 0.7

    -- Use dynamic VIP color with transparency (this fixes the hardcoded color issue)
    local r, g, b = math.floor(vipColor.R * 255), math.floor(vipColor.G * 255), math.floor(vipColor.B * 255)
    textLabel.Text = string.format('<font color="rgb(%d,%d,%d)" transparency="%f">chinozec</font><font color="rgb(255,255,255)">.lol</font>', r, g, b, vipTransparency)
end)

-- Сервисы
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

-- Создание прицела
local player = game.Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local crosshairGui = Instance.new("ScreenGui")
crosshairGui.Name = "HotlineCrosshair"
crosshairGui.Parent = playerGui
crosshairGui.ResetOnSpawn = false
crosshairGui.IgnoreGuiInset = true

-- Настройки прицела
local lineLength = 8       -- длина штриха
local lineThickness = 2    -- толщина
local innerDist = 0        -- минимальное расстояние между линиями
local outerDist = 16       -- максимальное расстояние при пульсе
local pulseSpeed = 0.3     -- скорость пульсации (сек)

-- Создание линий
local lines = {}
for _, name in ipairs({"Top", "Bottom", "Left", "Right"}) do
    local line = Instance.new("Frame")
    line.Name = name
    line.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    line.BorderSizePixel = 0
    line.Parent = crosshairGui
    lines[name] = line
end

-- Переменные
local crosshairEnabled = false
local crosshairColor = Color3.fromRGB(255, 255, 255)
local currentDist = outerDist
local pulseConnection
local followConnection

-- Обновление цвета
local function updateColor()
    for _, line in pairs(lines) do
        line.BackgroundColor3 = crosshairColor
    end
end

-- Обновление позиций
local function updatePositions(mousePos, dist)
    lines.Top.Size = UDim2.new(0, lineThickness, 0, lineLength)
    lines.Top.Position = UDim2.new(0, mousePos.X - lineThickness/2, 0, mousePos.Y - dist - lineLength)

    lines.Bottom.Size = UDim2.new(0, lineThickness, 0, lineLength)
    lines.Bottom.Position = UDim2.new(0, mousePos.X - lineThickness/2, 0, mousePos.Y + dist)

    lines.Left.Size = UDim2.new(0, lineLength, 0, lineThickness)
    lines.Left.Position = UDim2.new(0, mousePos.X - dist - lineLength, 0, mousePos.Y - lineThickness/2)

    lines.Right.Size = UDim2.new(0, lineLength, 0, lineThickness)
    lines.Right.Position = UDim2.new(0, mousePos.X + dist, 0, mousePos.Y - lineThickness/2)
end

-- Пульсация
local function startPulse()
    if pulseConnection then return end
    pulseConnection = task.spawn(function()
        while crosshairEnabled do
            local goalDist = (currentDist == outerDist) and innerDist or outerDist
            local startDist = currentDist
            local startTime = tick()

            while tick() - startTime < pulseSpeed and crosshairEnabled do
                local alpha = (tick() - startTime) / pulseSpeed
                local eased = TweenService:GetValue(alpha, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
                currentDist = startDist + (goalDist - startDist) * eased
                task.wait()
            end
            currentDist = goalDist
        end
        pulseConnection = nil
    end)
end

-- Следование за мышью
local function startFollow()
    if followConnection then return end
    followConnection = RunService.RenderStepped:Connect(function()
        if crosshairEnabled then
            local mousePos = UserInputService:GetMouseLocation()
            updatePositions(mousePos, currentDist)
        end
    end)
end

Localplayerrr:AddToggle("Crosshair Enabled", {
    Text = "Hotline Miami Crosshair",
    Default = false,
    Callback = function(value)
        crosshairEnabled = value
        crosshairGui.Enabled = value
        if value then
            currentDist = outerDist
            updateColor()
            startPulse()
            startFollow()
            UserInputService.MouseIconEnabled = false
        else
            pulseConnection = nil
            UserInputService.MouseIconEnabled = true
        end
    end
})

Localplayerrr:AddLabel("HMC color"):AddColorPicker("Hotline Miami Color", {
    Default = Color3.fromRGB(255, 0, 0),
    Callback = function(color)
        crosshairColor = color
        updateColor()
    end
})

-- Инициализация
crosshairGui.Enabled = false
UserInputService.MouseIconEnabled = true

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

local RunService = game:GetService("RunService")
local player = game.Players.LocalPlayer

local hrp, humanoid
local connection -- для хранения RenderStepped

-- Функция включения/выключения Fake AA
local function setFakeAA(enabled)
	if enabled then
		if player.Character then
			humanoid = player.Character:FindFirstChildOfClass("Humanoid")
			hrp = player.Character:FindFirstChild("HumanoidRootPart")
			if humanoid and hrp then
				humanoid.AutoRotate = false
				-- Подключаем RenderStepped
				connection = RunService.RenderStepped:Connect(function()
					local moveDir = humanoid.MoveDirection
					if moveDir.Magnitude > 0.01 then
						local opposite = -moveDir.Unit
						opposite = Vector3.new(opposite.X, 0, opposite.Z)
						if opposite.Magnitude > 0.001 then
							hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + opposite)
						end
					end
				end)
			end
		end
	else
		-- Отключаем Fake AA
		if connection then
			connection:Disconnect()
			connection = nil
		end
		if humanoid then
			humanoid.AutoRotate = true
		end
	end
end

-- Linoria Toggle
SelfTab:AddToggle('FakeLagEnabled', {
	Text = 'Fake aa', 
	Default = false,
	Callback = function(Value)
		setFakeAA(Value)
	end
})

-- Подписка на смену персонажа (чтобы работало при respawn)
player.CharacterAdded:Connect(function(char)
	humanoid = char:WaitForChild("Humanoid")
	hrp = char:WaitForChild("HumanoidRootPart")
end)


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
local flyConnection

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- disable fly
local function disableFly()
    if flyConnection then
        flyConnection:Disconnect()
        flyConnection = nil
    end
    if bodyGyro then
        bodyGyro:Destroy()
        bodyGyro = nil
    end
    if bodyVel then
        bodyVel:Destroy()
        bodyVel = nil
    end

    local character = LocalPlayer.Character
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.PlatformStand = false
            humanoid.WalkSpeed = 16
        end
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
            end
        end
    end
end

-- toggle fly
local function toggleFly(enabled)
    if enabled == flyEnabled then return end
    flyEnabled = enabled

    if not enabled then
        disableFly()
        return
    end

    local character = LocalPlayer.Character
    if not character then return end
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    humanoid.WalkSpeed = 0
    humanoid.PlatformStand = true

    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end

    bodyGyro = Instance.new("BodyGyro")
    bodyGyro.P = 9e4
    bodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    bodyGyro.CFrame = humanoidRootPart.CFrame
    bodyGyro.Parent = humanoidRootPart

    bodyVel = Instance.new("BodyVelocity")
    bodyVel.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    bodyVel.Velocity = Vector3.zero
    bodyVel.Parent = humanoidRootPart

    flyConnection = RunService.RenderStepped:Connect(function()
        if not flyEnabled then return end

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
end

-- Handle respawn
LocalPlayer.CharacterAdded:Connect(function(newChar)
    if flyEnabled then
        task.wait(0.1)
        toggleFly(false)
        toggleFly(true)
    end
end)

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
    Max = 250,
    Rounding = 0,
    Compact = false,
    Callback = function(Value)
        flyBoost = Value
    end
})

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
    ["Green"] = {
        Bk = "rbxassetid://11941775243",
        Dn = "rbxassetid://11941774975",
        Ft = "rbxassetid://11941774655",
        Lf = "rbxassetid://11941774369",
        Rt = "rbxassetid://11941774042",
        Up = "rbxassetid://11941773718",
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
    Values = {"Night", "Green", "Pink", "Moon", "Black"},
    Default = 5,
    Multi = false,
    Text = "Skybox",

    Callback = function(Value)
        ApplySky(SkyBoxes[Value])
    end
})

-- сразу Night ставим
ApplySky(SkyBoxes["Black"])

local grassFlags = {
    "FIntFRMMinGrassDistance",
    "FIntFRMMaxGrassDistance",
    "FIntRenderGrassDetailStrands",
    "FIntRenderGrassHeightScaler"
}

local originalValues = {}

OtherBox:AddToggle('HideTerrainDecor', {
    Text = 'Hide grass',
    Default = false,
    Tooltip = 'nothing',
    Callback = function(on)
        local ok, err = pcall(function()
            if not next(originalValues) then
                -- Store originals on first toggle
                for _, flag in ipairs(grassFlags) do
                    originalValues[flag] = getfflag(flag)
                end
            end

            if on then
                -- Hide: Set all to 0
                for _, flag in ipairs(grassFlags) do
                    setfflag(flag, 0)
                end
            else
                -- Show: Restore originals
                for flag, value in pairs(originalValues) do
                    setfflag(flag, value)
                end
            end
        end)
        if not ok then
            warn("[Linoria] Failed to toggle grass visibility: ", err)
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

-- Предполагается, что Linoria уже инициализирована:
-- local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/Library.lua"))()

local player = game.Players.LocalPlayer
local camera = workspace.CurrentCamera

OtherBox:AddToggle('InvisiCamEnabled', {
    Text = 'Enable InvisiCam',
    Default = false,
    Tooltip = 'Makes walls transparent when blocking view',
    Callback = function(value)
        if value then
            player.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Invisicam
            player.DevComputerCameraOcclusionMode = Enum.DevCameraOcclusionMode.Invisicam
            player.DevTouchCameraOcclusionMode = Enum.DevCameraOcclusionMode.Invisicam
        else
            player.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Zoom
            player.DevComputerCameraOcclusionMode = Enum.DevCameraOcclusionMode.Zoom
            player.DevTouchCameraOcclusionMode = Enum.DevCameraOcclusionMode.Zoom
        end
    end
})

local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera

local fovValue = 70 -- начальное значение FOV

-- Слайдер для изменения FOV
OtherBox:AddSlider('FovSlider', {
    Text = 'Fov',
    Default = fovValue,
    Min = 10,
    Max = 120,
    Rounding = 1,
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

OtherBox:AddButton('Instant Proximity Prompt', function()
    game:GetService("ProximityPromptService").PromptButtonHoldBegan:Connect(function(prompt) 
        prompt.HoldDuration = 0 
    end)
end)

-- // Сервисы
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")
-- // Настройки
local settings = {
    ChatPosition = "Up"
}
-- // Debounce для предотвращения спама
local lastUpdateTime = 0
local DEBOUNCE_TIME = 0.1  -- 100ms задержка

local ChatPosDropdown = OtherBox:AddDropdown('ChatPosition', {
    Values = {'Up', 'Center', 'Down'},
    Default = 'Up',
    Multi = false,
    Text = 'Chat Position',
})

-- // Функция установки позиции (обновлённая для read-only Position)
local function SetChatPosition(position)
    local currentTime = tick()
    if currentTime - lastUpdateTime < DEBOUNCE_TIME then
        return
    end
    lastUpdateTime = currentTime

    local success = pcall(function()
        local config = TextChatService:WaitForChild("ChatWindowConfiguration", 5)  -- Ждём config (timeout 5s)
        if config then
            -- Новый чат: Только alignments (Position read-only!)
            config.HorizontalAlignment = Enum.HorizontalAlignment.Left
            if position == "Up" then
                config.VerticalAlignment = Enum.VerticalAlignment.Top
            elseif position == "Center" then
                config.VerticalAlignment = Enum.VerticalAlignment.Center
            else  -- Down
                config.VerticalAlignment = Enum.VerticalAlignment.Bottom
            end
        else
            -- Legacy чат: Точные координаты
            local viewport = workspace.CurrentCamera.ViewportSize
            local chatHeight = 250
            local yOffset = 0
            local xOffset = 10
            if position == "Up" then
                yOffset = 10
            elseif position == "Center" then
                yOffset = (viewport.Y / 2) - (chatHeight / 2)
            else
                yOffset = viewport.Y - chatHeight - 20
            end
            local pos = UDim2.new(0, xOffset, 0, yOffset)
            StarterGui:SetCore("ChatWindowPosition", pos)
        end
    end)
    if not success then
        warn("[Chat Position] Ошибка при смене позиции. Проверь, включён ли TextChatService в игре.")
    end
end

-- // Изменение при выборе в dropdown
ChatPosDropdown:OnChanged(function(val)
    settings.ChatPosition = val
    SetChatPosition(val)
end)

-- // Обработка ресайза экрана (только для legacy, alignments auto-адаптируются)
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
    if workspace.CurrentCamera then
        -- Проверяем, legacy ли (если config не найден)
        local config = TextChatService:FindFirstChildOfClass("ChatWindowConfiguration")
        if not config then
            SetChatPosition(settings.ChatPosition)
        end
    end
end)

-- // Изначальная установка с задержкой (чат может грузиться медленно)
task.wait(2)  -- Ждём 2 секунды
SetChatPosition(settings.ChatPosition)

OtherBox:AddButton('Chat history enable', function()
    game:GetService("TextChatService").ChatWindowConfiguration.Enabled = true
end)

local Tabs = {
    ['UI Settings'] = Window:AddTab('UI Settings'),
}

local MenuGroup = Tabs['UI Settings']:AddLeftGroupbox('Menu')

        Library.KeybindFrame.Visible = true;

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
