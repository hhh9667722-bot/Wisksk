-- kick �고쉶 (湲곕낯 �쒓났 肄붾뱶)
for k, v in pairs(getgc(true)) do
	if pcall(function()
			return rawget(v, "indexInstance")
		end) and type(rawget(v, "indexInstance")) == "table" and (rawget(v, "indexInstance"))[1] == "kick" then
		setreadonly(v, false)
		v.tvk = {
			"kick",
			function()
				return game.Workspace:WaitForChild("")
			end
		}
	end
end

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

-- 蹂��� �ㅼ젙
local fovRadius = 100
local fovCircle = nil
local SilentAimRS = nil
local remote_key = {}
local CurrentTarget = nil
local processing = false
local savedTeamName = nil
local AimAssistStrength = 0.6

local AdminUserIds = {}

-- �좏떥由ы떚 �⑥닔��
local function isAdmin(player) return AdminUserIds[player.UserId] == true end
local function getSafeGuiParent() return CoreGui or LocalPlayer:FindFirstChildOfClass("PlayerGui") end

local function removeExistingAimbotGuis()
	local parent = getSafeGuiParent()
	if parent then
		local oldGui = parent:FindFirstChild("MobileAimbotUI")
		if oldGui then oldGui:Destroy() end
	end
	if fovCircle then fovCircle:Destroy() fovCircle = nil end
end

local function applyESP(char)
	if not char then return end
	local h = char:FindFirstChild("TargetHighlight")
	if not h then
		h = Instance.new("Highlight")
		h.Name = "TargetHighlight"
		h.FillColor = Color3.fromRGB(255, 0, 0)
		h.OutlineColor = Color3.fromRGB(255, 255, 255)
		h.FillTransparency = 0.5
		h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		h.Parent = char
	end
end

local function removeESP(char)
	if char and char:FindFirstChild("TargetHighlight") then
		char.TargetHighlight:Destroy()
	end
end

local function removeAllESP()
	for _, p in pairs(Players:GetPlayers()) do
		if p.Character then removeESP(p.Character) end
	end
end

local function isVisible(targetPart)
	local origin = Camera.CFrame.Position
	local destination = targetPart.Position
	local direction = destination - origin
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {LocalPlayer.Character, Camera}
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	local result = workspace:Raycast(origin, direction, raycastParams)
	if result then
		return result.Instance:IsDescendantOf(targetPart.Parent)
	end
	return true
end

local function ReplaceChar(pos, str, r) return str:sub(1, pos-1) .. r .. str:sub(pos+1) end

local function GetPlayerUserId(Player)
	local user_id = Player.UserId
	if #tostring(user_id) ~= 9 then user_id = math.abs(user_id * 100000000) end
	return user_id
end

local function NextRemoteKey(Player)
	local user_id = GetPlayerUserId(Player)
	local key = remote_key[user_id]
	if not key then return nil end
	local a = key:sub(4,4)
	local p = string.byte(key:sub(1,1))
	local s = (tonumber(a) or 0) * 2
	if s > 9 then s = 1 end
	local n = key:gsub(a, tostring(s))
	local h = p + 4 - s
	if h > 90 then h = 65 end
	local n1 = ReplaceChar(1, n, string.char(h))
	remote_key[user_id] = n1
	return n1
end

local function isTargetValid(targetPlayer)
	if not targetPlayer or targetPlayer == LocalPlayer then return false end
	local char = targetPlayer.Character
	if not char or not char.Parent then return false end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return false end
	return true
end

local function getTool()
	local character = LocalPlayer.Character
	if character then
		local info = character:FindFirstChild("Info", true)
		if info and info.Parent then return info.Parent end
	end
	return nil
end

local function ByPassKey(k, targetPlayer)
	if not k or not isTargetValid(targetPlayer) then return end
	local tool = getTool()
	local damage = 9999
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local remotes = assets and assets:FindFirstChild("Misc") and assets.Misc:FindFirstChild("CWS_Directory") and assets.Misc.CWS_Directory:FindFirstChild("remotes")
	local damageRemote = remotes and remotes:FindFirstChild("Damage")

	if damageRemote then
		damageRemote:FireServer({
			["damage"] = damage,
			["k"] = k,
			["hit_name"] = "Head",
			["target"] = targetPlayer.Character.Humanoid,
			["velocity"] = Vector3.new(0, 0, 0),
			["tool"] = tool,
			["auth"] = false
		})
	end
end

local function applyTeam(teamName)
	local team = Teams:FindFirstChild(teamName)
	if team then
		LocalPlayer.Team = team
		LocalPlayer.TeamColor = team.TeamColor
		savedTeamName = teamName
		return true
	end
	return false
end

-- UI �앹꽦
local Window = Fluent:CreateWindow({
	Title = "Cave Army",
	SubTitle = "By JHK (Integrated)",
	TabWidth = 160,
	Size = UDim2.fromOffset(500, 420),
})

local Tab = Window:AddTab({ Title = "Main", Icon = "user" })
local Misc = Window:AddTab({ Title = "Misc", Icon = "plus-circle" })
local Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })

-- Main �뱀뀡
local Section = Tab:AddSection("Silent Aim")
local KillAllSection = Tab:AddSection("Kill All")
local TeamSection = Tab:AddSection("��")

Section:AddSlider("Fov", { Title = "Fov", Default = 100, Min = 50, Max = 200, Rounding = 1, Callback = function(v) fovRadius = v end })
local SilentAim = Section:AddToggle("SilentAim", { Title = "SilentAim", Default = false })
local ShowTargetPlayer = Section:AddToggle("ShowTargetPlayer", { Title = "ShowTargetPlayer", Default = false })
Section:AddSlider("AimStrength", { Title = "�먯엫 蹂댁젙 媛뺣룄 (%)", Default = 60, Min = 10, Max = 100, Rounding = 0, Callback = function(v) AimAssistStrength = math.clamp(v / 100, 0, 1) end })

Section:AddButton({
	Title = "臾댄븳珥앹븣",
	Description = "珥앹쓣 �ㅼ� �딆� �곹깭�먯꽌 �ㅽ뻾�섏꽭��.",
	Callback = function()
		task.spawn(function()
			while task.wait(1) do
				for _, v in pairs(LocalPlayer.Backpack:GetDescendants()) do
					if v:IsA("Tool") and v:FindFirstChild("Info") then v:SetAttribute("ammo", 999999) end
				end
			end
		end)
	end
})

-- Kill All 湲곕뒫
KillAllSection:AddButton({
	Title = "Kill All",
	Callback = function()
		if processing then return end
		local userid = GetPlayerUserId(LocalPlayer)
		-- (�먭꺽 �� �띾뱷 濡쒖쭅 �앸왂/湲곗〈 濡쒖쭅 �좎�)
		task.spawn(function()
			processing = true
			for _ = 1, 5 do
				for _, p in pairs(Players:GetPlayers()) do
					if isTargetValid(p) then ByPassKey(NextRemoteKey(LocalPlayer), p) end
				end
				task.wait()
			end
			processing = false
		end)
	end
})

-- Misc �뱀뀡 (�꾩씠�� �덉랬 �ы븿)
local MiscItemSection = Misc:AddSection("�꾩씠�� 愿�由�")

MiscItemSection:AddButton({
    Title = "紐⑤뱺 臾닿린/�꾩씠�� �꾨웾 �덉랬",
    Description = "留듭뿉 �⑥뼱吏� 紐⑤뱺 �꾩씠�쒖쓣 媛�諛⑹쑝濡� 媛��몄샃�덈떎.",
    Callback = function()
        local count = 0
        for _, obj in pairs(workspace:GetDescendants()) do
            if obj:IsA("Tool") then
                obj.Parent = LocalPlayer.Backpack
                count = count + 1
            elseif obj:IsA("TouchTransmitter") and obj.Parent:IsA("Part") and obj.Parent.Parent:IsA("Tool") then
                -- �곗튂�댁빞 癒뱀뼱吏��� �� ����
                firetouchinterest(LocalPlayer.Character.HumanoidRootPart, obj.Parent, 0)
                firetouchinterest(LocalPlayer.Character.HumanoidRootPart, obj.Parent, 1)
                count = count + 1
            end
        end
        Fluent:Notify({Title = "�꾩씠�� �덉랬", Content = count .. "媛쒖쓽 �꾩씠�쒖쓣 �띾뱷�덉뒿�덈떎.", Duration = 3})
    end
})

Misc:AddButton({ Title = "Infinite Yield", Callback = function() loadstring(game:HttpGet("https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"))() end })

-- 臾댁쟻 紐⑤뱶 諛� 湲고� 湲곕뒫 (湲곗〈 肄붾뱶 �좎�)
local GodModeToggle = Misc:AddToggle("GodMode", { Title = "�뚯뒪�몄슜 臾댁쟻 紐⑤뱶", Default = false })
-- (GodMode 愿��� 濡쒖쭅 �앸왂/湲곗〈 濡쒖쭅 �좎�)

-- 硫뷀��뚯씠釉� �꾪궧 (Silent Aim)
local mt = getrawmetatable(game)
local old = mt.__index
setreadonly(mt, false)
mt.__index = newcclosure(function(self, key)
	if not checkcaller() and self:IsA("Mouse") and key == "Hit" and SilentAim.Value and CurrentTarget then
		return CFrame.new(CurrentTarget.Position)
	end
	return old(self, key)
end)
setreadonly(mt, true)

-- 留덈Т由�
SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
InterfaceManager:BuildInterfaceSection(Settings)
SaveManager:BuildConfigSection(Settings)
SaveManager:LoadAutoloadConfig()
Window:SelectTab(1)
Fluent:Notify({Title = "Cave Army", Content = "�듯빀 �ㅽ겕由쏀듃 濡쒕뱶 �꾨즺", Duration = 5})
