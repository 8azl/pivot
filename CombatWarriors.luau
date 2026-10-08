if type(getgenv().PivotUnload) == "function" then
	pcall(getgenv().PivotUnload)
end
getgenv().PivotUnload = nil
if type(getgenv().KaliUnload) == "function" then
	pcall(getgenv().KaliUnload)
end
getgenv().KaliUnload = nil
if type(getgenv().Anka) == "table" then
	local alive = false
	if gethui then
		for _, gui in gethui():GetChildren() do
			if gui:IsA("ScreenGui") and gui:FindFirstChild("Main") then
				alive = true
				break
			end
		end
	end
	if not alive then getgenv().Anka = nil end
end
local WHITE = Color3.new(1, 1, 1)
local cloneref = cloneref or function(instance) return instance end
local Players = cloneref(game:GetService("Players"))
local RunService = cloneref(game:GetService("RunService"))
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local UserInputService = cloneref(game:GetService("UserInputService"))
local AnimationClipProvider = cloneref(game:GetService("AnimationClipProvider"))
local CollectionService = cloneref(game:GetService("CollectionService"))
local LocalPlayer = Players.LocalPlayer
local Pivot = {
	Running = true,
	Connections = {},
	Binds = {},
	Loops = {},
	Guis = {},
}
local Kali = Pivot
function Kali.track(connection)
table.insert(Kali.Connections, connection)
return connection
end
function Kali.bind(key, connection)
local old = Kali.Binds[key]
if old then old:Disconnect() end
Kali.Binds[key] = connection
end
function Kali.loop(key, interval, step)
if Kali.Loops[key] then return end
Kali.Loops[key] = true
task.spawn(function()
while Kali.Running and Kali.Loops[key] do
local ok, keep = pcall(step)
if ok and keep == false then break end
task.wait(interval)
end
Kali.Loops[key] = nil
end)
end
local Settings = {
AutoParry = false,
ParryDistance = 15,
ParryChance = 100,
ParryDelay = 0,
TargetedOnly = false,
AutoAttack = false,
AttackRange = 9,
AttackFacing = true,
SkipParrying = true,
ParrySafety = 100,
WhitelistFriends = true,
KillAura = false,
MeleeSilentAim = false,
AuraRange = 14,
HitboxExpander = false,
HitboxSize = 8,
ShowHitbox = true,
AutoGloryKill = false,
GloryRange = 6,
AutoShove = false,
InfiniteStamina = false,
InfiniteOxygen = false,
NoFallDamage = false,
NoKnockback = false,
AntiRagdoll = false,
AutoSelfRevive = false,
FastRespawn = false,
InstaUse = false,
AntiMod = false,
NoJumpCooldown = false,
NoDashCooldown = false,
SpeedBoost = false,
SpeedAmount = 8,
Fly = false,
FlySpeed = 40,
HighJump = false,
JumpBoost = 20,
GunSilentAim = false,
ThrowableAim = false,
GunFov = 150,
ShowFov = false,
GunMaxDistance = 400,
GunPart = "Head",
GunPrediction = true,
GunVisibleCheck = true,
NoRecoil = false,
NoSpread = false,
AutoReload = false,
Esp = false,
EspChams = true,
EspName = true,
EspDistance = true,
EspHealth = true,
EspWeapon = true,
EspState = true,
EspBox = false,
EspTracer = false,
EspHealthBar = false,
EspMaxDistance = 1000,
EspColor = Color3.fromRGB(255, 80, 80),
EspFriendColor = Color3.fromRGB(90, 220, 120),
}
local PARRY_COLOR = Color3.fromRGB(255, 210, 70)
local CHAMS_LIMIT = 28
local AURA_COOLDOWN_MARGIN = 1.10
local MELEE_SERVER_REACH = 14
local stores = { own = nil, byPlayer = nil, searched = 0 }
local function findStores()
if stores.own and stores.byPlayer then return end
if not filtergc or os.clock() - stores.searched < 10 then return end
stores.searched = os.clock()
if not stores.own then
for _, store in filtergc("table", { Keys = { "_state", "_reducer" } }) or {} do
local state = rawget(store, "_state")
if type(state) == "table" and rawget(state, "parryClient") then
stores.own = store
break
end
end
end
for _, player in Players:GetPlayers() do
if player ~= LocalPlayer then
for _, map in filtergc("table", { Keys = { player } }) or {} do
local store = rawget(map, player)
local state = type(store) == "table" and rawget(store, "_state")
if type(state) == "table" and rawget(state, "parry") then
stores.byPlayer = map
break
end
end
if stores.byPlayer then break end
end
end
end
local function ownState()
findStores()
return stores.own and rawget(stores.own, "_state")
end
local function stateOf(player)
findStores()
local store = stores.byPlayer and rawget(stores.byPlayer, player)
return type(store) == "table" and rawget(store, "_state") or nil
end
local friends = {}
local function cacheFriend(player)
if player == LocalPlayer or friends[player] ~= nil then return end
friends[player] = false
task.spawn(function()
local ok, isFriend = pcall(player.IsFriendsWith, player, LocalPlayer.UserId)
friends[player] = ok and isFriend or false
end)
end
for _, player in Players:GetPlayers() do cacheFriend(player) end
Kali.track(Players.PlayerAdded:Connect(cacheFriend))
Kali.track(Players.PlayerRemoving:Connect(function(player)
friends[player] = nil
end))
local function excluded(player)
if Settings.WhitelistFriends and friends[player] then return true end
local team = LocalPlayer.Team
return team ~= nil and player.Team == team
end
local function typing()
return UserInputService:GetFocusedTextBox() ~= nil
end
local trampoline
local function gameCall(fn, ...)
if not setstackhidden or type(fn) ~= "function" then return false end
if not (trampoline and trampoline.Parent) then
trampoline = nil
local loaders = ReplicatedStorage:FindFirstChild("ModuleLoadingExecutors")
for _, loader in loaders and loaders:GetChildren() or {} do
local bindable = loader:FindFirstChild("Bindable")
if bindable and bindable:IsA("BindableFunction") then
trampoline = bindable
break
end
end
if not trampoline then return false end
end
local args = table.pack(...)
local runner = function()
task.spawn(fn, table.unpack(args, 1, args.n))
end
setstackhidden(runner, true)
return pcall(trampoline.Invoke, trampoline, runner)
end
local weapons = setmetatable({}, { __mode = "k" })
local function weaponObject(tool, marker)
local cache = weapons[tool]
if cache and (cache.obj or os.clock() - cache.searched < 0.5) then return cache.obj end
cache = { searched = os.clock() }
weapons[tool] = cache
if not filtergc then return nil end
for _, candidate in filtergc("table", { Keys = { "tool", "_itemConfig", marker } }) or {} do
if rawget(candidate, "tool") == tool then
cache.obj = candidate
break
end
end
return cache.obj
end
local function equippedMelee()
local character = LocalPlayer.Character
local tool = character and character:FindFirstChildOfClass("Tool")
return tool and tool:FindFirstChild("Hitboxes") and weaponObject(tool, "meleeHitboxes")
end
local function mobileButton(state, id)
local buttons = state and state.mobileButtonsClient and state.mobileButtonsClient.buttons
local button = buttons and buttons[id]
return button and button.onClick
end
local slashAnimations
local function slashSet()
if slashAnimations then return slashAnimations end
slashAnimations = {}
local shared = ReplicatedStorage:FindFirstChild("Shared")
local assets = shared and shared:FindFirstChild("Assets")
local melee = assets and assets:FindFirstChild("Melee")
local stomp = melee and melee:FindFirstChild("Stomp")
local function add(animation)
if typeof(animation) == "Instance" and animation:IsA("Animation") and not (stomp and animation:IsDescendantOf(stomp)) then
local id = animation.AnimationId:match("%d+")
if id then slashAnimations[id] = true end
end
end
for _, animation in melee and melee:GetDescendants() or {} do
if animation.Name:sub(1, 5) == "Slash" then add(animation) end
end
for _, config in filtergc and filtergc("table", { Keys = { "slashMetadata" } }) or {} do
if type(config.slashMetadata) == "table" then
for _, slash in config.slashMetadata do
if type(slash) == "table" then add(slash.animation) end
end
end
end
return slashAnimations
end
local function targetsMe(attacker, attackerRoot, myDistance)
for _, player in Players:GetPlayers() do
if player ~= LocalPlayer and player ~= attacker then
local character = player.Character
local root = character and character:FindFirstChild("HumanoidRootPart")
local humanoid = character and character:FindFirstChildOfClass("Humanoid")
if root and humanoid and humanoid.Health > 0 and (root.Position - attackerRoot.Position).Magnitude + 2 < myDistance then
return false
end
end
end
return true
end
local parryGeneration = 0
local function onSwing(player, character, track, swing)
local animation = track.Animation
local id = animation and animation.AnimationId:match("%d+")
if not (id and slashSet()[id]) or excluded(player) then return end
local own = LocalPlayer.Character
if Settings.ParryDelay > 0 then
task.wait(Settings.ParryDelay / 1000)
end
if not (Kali.Running and Settings.AutoParry and swing.active
and swing.generation == parryGeneration and track.IsPlaying
and Kali.Binds[swing.stopKey] == swing.stopConnection
and LocalPlayer.Character == own and player.Character == character) or excluded(player) then return end
local root = own and own:FindFirstChild("HumanoidRootPart")
local enemyRoot = character:FindFirstChild("HumanoidRootPart")
local humanoid = own and own:FindFirstChildOfClass("Humanoid")
local enemyHumanoid = character:FindFirstChildOfClass("Humanoid")
local obj = equippedMelee()
if not (root and enemyRoot and humanoid and enemyHumanoid and obj)
or humanoid.Health <= 0 or enemyHumanoid.Health <= 0 then return end
local offset = root.Position - enemyRoot.Position
if offset.Magnitude > Settings.ParryDistance then return end
if Settings.TargetedOnly and not targetsMe(player, enemyRoot, offset.Magnitude) then return end
if math.random(1, 100) > Settings.ParryChance then return end
gameCall(obj.parry, obj)
end
local function waitForHitWindow(player, character, track)
if not (Kali.Running and Settings.AutoParry and track.IsPlaying and player.Character == character) then return end
local animation = track.Animation
local id = animation and animation.AnimationId:match("%d+")
if not (id and slashSet()[id]) or excluded(player) then return end
local key = "parryHit" .. player.UserId
local stopKey = "parryStop" .. player.UserId
local endKey = "parryEnd" .. player.UserId
local swing = {
active = false,
generation = parryGeneration,
stopKey = stopKey,
}
swing.stopConnection = track.Stopped:Connect(function()
swing.active = false
if Kali.Binds[stopKey] ~= swing.stopConnection then return end
Kali.bind(key, nil)
Kali.bind(endKey, nil)
Kali.bind(stopKey, nil)
end)
Kali.bind(stopKey, swing.stopConnection)
Kali.bind(endKey, track:GetMarkerReachedSignal("stopHitDetection"):Connect(function()
swing.active = false
if Kali.Binds[stopKey] ~= swing.stopConnection then return end
Kali.bind(endKey, nil)
end))
Kali.bind(key, track:GetMarkerReachedSignal("startHitDetection"):Connect(function()
if Kali.Binds[stopKey] ~= swing.stopConnection or swing.generation ~= parryGeneration
or not (Kali.Running and Settings.AutoParry and track.IsPlaying) then return end
Kali.bind(key, nil)
swing.active = true
pcall(onSwing, player, character, track, swing)
end))
end
local swingWatch = {}
local function watchCharacter(player, character)
Kali.bind("parryEnd" .. player.UserId, nil)
Kali.bind("parryHit" .. player.UserId, nil)
Kali.bind("parryStop" .. player.UserId, nil)
local old = swingWatch[player]
if old then old:Disconnect() end
swingWatch[player] = nil
if not character then return end
local generation = parryGeneration
task.spawn(function()
local humanoid = character:WaitForChild("Humanoid", 10)
local animator = humanoid and humanoid:WaitForChild("Animator", 10)
if not (animator and Kali.Running and Settings.AutoParry and generation == parryGeneration and player.Character == character) then return end
swingWatch[player] = animator.AnimationPlayed:Connect(function(track)
if generation ~= parryGeneration then return end
pcall(waitForHitWindow, player, character, track)
end)
end)
end
local function refreshAutoParry()
parryGeneration += 1
for player in swingWatch do
watchCharacter(player, nil)
end
if not (Kali.Running and Settings.AutoParry) then
Kali.bind("parryAdded", nil)
Kali.bind("parryRemoving", nil)
for _, player in Players:GetPlayers() do Kali.bind("parryChar" .. player.UserId, nil) end
return
end
slashSet()
local function follow(player)
if player == LocalPlayer then return end
Kali.bind("parryChar" .. player.UserId, player.CharacterAdded:Connect(function(character)
watchCharacter(player, character)
end))
watchCharacter(player, player.Character)
end
for _, player in Players:GetPlayers() do follow(player) end
Kali.bind("parryAdded", Players.PlayerAdded:Connect(follow))
Kali.bind("parryRemoving", Players.PlayerRemoving:Connect(function(player)
watchCharacter(player, nil)
Kali.bind("parryChar" .. player.UserId, nil)
end))
end
local parryWatch = {}
local antiParryEnabled = false
local autoSwing = { obj = nil, character = nil, root = nil, baseline = 0, pendingAt = 0 }
local function parryUnsafe(player, character, state)
if not Settings.SkipParrying then return false end
local entry = parryWatch[player]
if entry and entry.character ~= character then entry = nil end
local parry = state and state.parry
local known = parry and type(parry.isParrying) == "boolean"
local active = known and parry.isParrying
local shield = entry and entry.shield
local shieldActive = if shield and shield.Parent == character then shield:GetAttribute("Toggle") else nil
if entry and known then
if entry.stateActive and not active then entry.endedAt = os.clock() end
entry.stateActive = active == true
end
if active or shieldActive == true then return true end
if not known and type(shieldActive) ~= "boolean" then return true end
return entry ~= nil and os.clock() - entry.endedAt < Settings.ParrySafety / 1000
end
local function watchParryCharacter(player, character)
local id = player.UserId
Kali.bind("antiParryChild" .. id, nil)
Kali.bind("antiParryShield" .. id, nil)
parryWatch[player] = nil
if not character then return end
local entry = { character = character, endedAt = -math.huge, stateActive = false }
parryWatch[player] = entry
local function childAdded(child)
if child.Name == "HumanoidRootPart" then entry.root = child end
if child:IsA("Humanoid") then entry.humanoid = child end
if child:GetAttribute("ParryShieldId") then
entry.shield = child
entry.shieldActive = child:GetAttribute("Toggle") == true
Kali.bind("antiParryShield" .. id, child:GetAttributeChangedSignal("Toggle"):Connect(function()
local active = child:GetAttribute("Toggle") == true
if entry.shieldActive and not active then entry.endedAt = os.clock() end
entry.shieldActive = active
end))
end
end
for _, child in character:GetChildren() do childAdded(child) end
Kali.bind("antiParryChild" .. id, character.ChildAdded:Connect(childAdded))
end
local function parryThreat(root, obj)
if not Settings.SkipParrying then return false end
local reach = Settings.AttackRange
for hitbox in obj.meleeHitboxes do
reach = math.max(reach, (hitbox.Position - root.Position).Magnitude + hitbox.Size.Magnitude * 0.5 + 3)
end
reach = math.min(reach, MELEE_SERVER_REACH)
for player, entry in parryWatch do
local enemyRoot, humanoid = entry.root, entry.humanoid
if enemyRoot and enemyRoot.Parent == entry.character and humanoid and humanoid.Parent == entry.character and humanoid.Health > 0
and player.Character == entry.character and not excluded(player) then
local offset = enemyRoot.Position - root.Position
local closing = offset + (enemyRoot.AssemblyLinearVelocity - root.AssemblyLinearVelocity) * (Settings.ParrySafety / 1000)
if math.min(offset.Magnitude, closing.Magnitude) <= reach
and parryUnsafe(player, entry.character, stateOf(player)) then return true end
end
end
return false
end
local function autoSwingStep()
local obj, character = autoSwing.obj, autoSwing.character
if not obj then return end
if not (Kali.Running and Settings.AutoAttack and Settings.SkipParrying)
or LocalPlayer.Character ~= character or obj.tool.Parent ~= character then
autoSwing.obj = nil
return
end
if obj._lastSlashTick == autoSwing.baseline then
if os.clock() - autoSwing.pendingAt > 0.25 then autoSwing.obj = nil end
return
end
local track = obj._prevSlashAnimation
if not (track and track.IsPlaying) then autoSwing.obj = nil; return end
local root = autoSwing.root
if root and parryThreat(root, obj) then
track:Stop(0)
gameCall(obj.stopHitboxes, obj, obj.meleeHitboxes)
autoSwing.obj = nil
end
end
local function refreshAntiParry()
local enabled = Kali.Running and Settings.SkipParrying
and (Settings.AutoAttack or Settings.KillAura or Settings.MeleeSilentAim or Settings.HitboxExpander)
Kali.bind("antiParrySwing", nil)
if enabled and Settings.AutoAttack then
Kali.bind("antiParrySwing", RunService.PreSimulation:Connect(function() pcall(autoSwingStep) end))
else
autoSwing.obj = nil
end
if enabled == antiParryEnabled then return end
antiParryEnabled = enabled
if not enabled then
Kali.bind("antiParryAdded", nil)
Kali.bind("antiParryRemoving", nil)
for _, player in Players:GetPlayers() do
Kali.bind("antiParryChar" .. player.UserId, nil)
watchParryCharacter(player, nil)
end
return
end
local function follow(player)
if player == LocalPlayer then return end
Kali.bind("antiParryChar" .. player.UserId, player.CharacterAdded:Connect(function(character)
watchParryCharacter(player, character)
end))
watchParryCharacter(player, player.Character)
end
for _, player in Players:GetPlayers() do follow(player) end
Kali.bind("antiParryAdded", Players.PlayerAdded:Connect(follow))
Kali.bind("antiParryRemoving", Players.PlayerRemoving:Connect(function(player)
Kali.bind("antiParryChar" .. player.UserId, nil)
watchParryCharacter(player, nil)
end))
end
local function busy(player, character)
if character:FindFirstChildOfClass("ForceField") then return true end
local state = stateOf(player)
if parryUnsafe(player, character, state) then return true end
if not state then return false end
if state.down and state.down.isDowned then return true end
if state.gk and state.gk.isBeingGked then return true end
return state.spawn ~= nil and state.spawn.isIn == false
end
local function attackStep()
if not Settings.AutoAttack then return false end
if Settings.KillAura then return end
local own = LocalPlayer.Character
local root = own and own:FindFirstChild("HumanoidRootPart")
local humanoid = own and own:FindFirstChildOfClass("Humanoid")
local obj = equippedMelee()
if not (root and humanoid and humanoid.Health > 0 and obj) then return end
if obj._cooldownProgressVO and obj._cooldownProgressVO.Value < 1 then return end
local state = ownState()
if state and ((state.down and state.down.isDowned) or (state.parryClient and state.parryClient.isParrying)) then return end
if parryThreat(root, obj) then return end
for _, player in Players:GetPlayers() do
if player ~= LocalPlayer and not excluded(player) then
local character = player.Character
local enemyRoot = character and character:FindFirstChild("HumanoidRootPart")
local enemyHumanoid = character and character:FindFirstChildOfClass("Humanoid")
if enemyRoot and enemyHumanoid and enemyHumanoid.Health > 0 then
local offset = enemyRoot.Position - root.Position
if offset.Magnitude <= Settings.AttackRange
and (not Settings.AttackFacing or root.CFrame.LookVector:Dot(offset.Unit) >= 0.3)
and not busy(player, character) then
local baseline = obj._lastSlashTick
if gameCall(obj.slash, obj) then
autoSwing.obj = obj
autoSwing.character = own
autoSwing.root = root
autoSwing.baseline = baseline
autoSwing.pendingAt = os.clock()
end
return
end
end
end
end
end
local function gloryPrompt(root)
for _, child in root:GetChildren() do
if child:IsA("ProximityPrompt") and child:GetAttribute("PromptId") == "gloryKill" then return child end
end
return nil
end
local auraTargets = {}
local function collectTargets(root, range)
table.clear(auraTargets)
for _, player in Players:GetPlayers() do
if player ~= LocalPlayer and not excluded(player) then
local character = player.Character
local torso = character and character:FindFirstChild("Torso")
local humanoid = character and character:FindFirstChildOfClass("Humanoid")
if torso and humanoid and humanoid.Health > 0 and (torso.Position - root.Position).Magnitude <= range and not busy(player, character) then
local enemyRoot = Settings.AutoGloryKill and character:FindFirstChild("HumanoidRootPart")
local prompt = enemyRoot and gloryPrompt(enemyRoot)
if not (prompt and prompt.Enabled) then
table.insert(auraTargets, torso)
end
end
end
end
table.sort(auraTargets, function(a, b)
return (a.Position - root.Position).Magnitude < (b.Position - root.Position).Magnitude
end)
return auraTargets
end
local aimedSlashTick
local function meleeAimStep()
if not Settings.MeleeSilentAim then return false end
local character = LocalPlayer.Character
local root = character and character:FindFirstChild("HumanoidRootPart")
local obj = equippedMelee()
if not (root and obj) then return end
local slashTick = obj._lastSlashTick
if slashTick == aimedSlashTick or tick() - (slashTick or 0) >= 0.6 or (obj._slashHitDetectionStage or 0) < 1 then return end
local part = collectTargets(root, Settings.AuraRange)[1]
local hitbox = next(obj.meleeHitboxes)
if not (part and hitbox) then return end
aimedSlashTick = slashTick
gameCall(obj.onSlashRayHit, obj, hitbox, part, {
Position = part.Position,
Normal = (hitbox.Position - part.Position).Unit,
}, hitbox.Position, part.Position)
end
local function expanderStep()
if not Settings.HitboxExpander then return false end
local character = LocalPlayer.Character
local root = character and character:FindFirstChild("HumanoidRootPart")
local obj = equippedMelee()
if not (root and obj) or tick() - (obj._lastSlashTick or 0) >= 0.6 or (obj._slashHitDetectionStage or 0) < 1 then return end
local reach = Settings.HitboxSize * 0.5
for hitbox, caster in obj.meleeHitboxes do
if caster.HitboxActive then
local half = hitbox.Size * 0.5
for _, torso in collectTargets(root, MELEE_SERVER_REACH) do
local humanoid = torso.Parent:FindFirstChildOfClass("Humanoid")
local hit = obj._humanoidsAlreadyHit[humanoid]
local blade = hitbox.CFrame * hitbox.CFrame:PointToObjectSpace(torso.Position):Max(-half):Min(half)
if not (hit and hit.amountOfTimesHit > 0) and (blade - torso.Position).Magnitude <= reach then
gameCall(obj.onSlashRayHit, obj, hitbox, torso, {
Position = torso.Position,
Normal = (blade - torso.Position).Unit,
}, hitbox.Position, torso.Position)
end
end
end
end
end
local network
local slashWindows = setmetatable({}, { __mode = "k" })
local function hitDelay(obj, index)
local windows = slashWindows[obj]
if windows then return windows[index] end
windows = {}
slashWindows[obj] = windows
task.spawn(function()
for slash, meta in obj._itemConfig.slashMetadata do
local track = obj.animations.slashes[slash]
local ok, clip = pcall(AnimationClipProvider.GetAnimationClipAsync, AnimationClipProvider, track.Animation.AnimationId)
local marker
for _, keyframe in ok and clip and clip:GetKeyframes() or {} do
for _, mark in keyframe:GetMarkers() do
if mark.Name == "startHitDetection" then marker = math.min(marker or math.huge, keyframe.Time) end
end
end
if marker then
local speed = if meta.duration then track.Length / meta.duration else meta.speed or 1
windows[slash] = (meta.buildupDuration or marker / speed) + 0.03
end
end
end)
return nil
end
local function canSwing(obj, state)
if obj._itemConfig.isPermEquipped or (obj._equipProgressVO and obj._equipProgressVO.Value < 1) then return false end
if not state then return true end
return state.meleeClient ~= nil and state.meleeClient.canMeleeFromCount
and not (state.stunClient and state.stunClient.isStunned)
and not (state.down and state.down.isDowned)
and not (state.parry and state.parry.isParrying)
and not (state.ragdollClient and state.ragdollClient.isRagdolled)
and not (state.gk and state.gk.isBeingGked)
and not (state.freeze and state.freeze.isFrozen)
and not (state.charge and state.charge.isBeingCharged)
end
local aura = { swingAt = 0, slash = 0, missed = false, generation = 0 }
local function auraHit(obj, swingAt, generation, character)
if not (Kali.Running and Settings.KillAura) or aura.generation ~= generation or aura.swingAt ~= swingAt
or LocalPlayer.Character ~= character or obj.tool.Parent ~= character or equippedMelee() ~= obj then return end
local humanoid = character:FindFirstChildOfClass("Humanoid")
if not (humanoid and humanoid.Health > 0 and canSwing(obj, ownState())) then return end
local root = character and character:FindFirstChild("HumanoidRootPart")
local hitbox = next(obj.meleeHitboxes)
local targets = root and hitbox and Settings.KillAura and collectTargets(root, Settings.AuraRange) or {}
local hits = 0
for _, torso in targets do
if not (Kali.Running and Settings.KillAura) or aura.generation ~= generation or aura.swingAt ~= swingAt
or LocalPlayer.Character ~= character or obj.tool.Parent ~= character or equippedMelee() ~= obj
or humanoid.Health <= 0 or not canSwing(obj, ownState()) then break end
local player = Players:GetPlayerFromCharacter(torso.Parent)
if not player or busy(player, torso.Parent) then continue end
local position = torso.Position
local direction = (position - hitbox.Position).Unit
if gameCall(network.FireServer, network, "MeleeDamage", obj.tool, torso, hitbox, position,
torso.CFrame:ToObjectSpace(CFrame.new(position)), root.CFrame.LookVector, direction, -direction, tick() - swingAt)
then hits += 1 end
end
if aura.generation ~= generation or aura.swingAt ~= swingAt then return end
aura.missed = hits == 0
obj._lastSwingWasAHit = not aura.missed
end
local function auraStep()
if not Settings.KillAura then return false end
local character = LocalPlayer.Character
local root = character and character:FindFirstChild("HumanoidRootPart")
local humanoid = character and character:FindFirstChildOfClass("Humanoid")
local obj = equippedMelee()
if not (root and humanoid and humanoid.Health > 0 and obj) then return end
local config = obj._itemConfig
local cooldown = config.cooldown
if type(cooldown) ~= "number" then return end
if aura.missed and type(config.cooldownPunish) == "number" then cooldown *= config.cooldownPunish end
if tick() - math.max(aura.swingAt, obj._lastSlashTick or 0) < cooldown * AURA_COOLDOWN_MARGIN then return end
if not canSwing(obj, ownState()) or #collectTargets(root, Settings.AuraRange) == 0 then return end
network = network or filtergc and (filtergc("table", { Keys = { "FireServer", "BindEvents", "InvokeServer" } }) or {})[1]
local slash = aura.slash % #obj._itemConfig.slashMetadata + 1
local delay = hitDelay(obj, slash)
if not (network and delay) then return end
local swingAt = tick()
if not gameCall(network.FireServer, network, "MeleeSwing", obj.tool, slash) then return end
aura.slash = slash
aura.swingAt = swingAt
aura.missed = false
local timer = obj._cooldownProgressTimer
if timer then gameCall(timer.setValue, timer, 0) end
local generation = aura.generation
task.delay(delay, function() pcall(auraHit, obj, swingAt, generation, character) end)
end
local gloryAt = 0
local function gloryStep()
if not Settings.AutoGloryKill then return false end
local character = LocalPlayer.Character
local root = character and character:FindFirstChild("HumanoidRootPart")
local tool = character and character:FindFirstChildOfClass("Tool")
if not (root and tool) or os.clock() - gloryAt < 1 then return end
local obj = weaponObject(tool, if tool:FindFirstChild("Hitboxes") then "meleeHitboxes" else "_clientAmmoVO")
if not (obj and obj._itemConfig and obj._itemConfig.gkConfig) then return end
local state = ownState()
if state and ((state.down and state.down.isDowned) or (state.gk and state.gk.isGking)) then return end
for _, player in Players:GetPlayers() do
if player ~= LocalPlayer and not excluded(player) then
local enemy = player.Character
local enemyRoot = enemy and enemy:FindFirstChild("HumanoidRootPart")
local prompt = enemyRoot and gloryPrompt(enemyRoot)
if prompt and prompt.Enabled and (enemyRoot.Position - root.Position).Magnitude <= Settings.GloryRange then
gloryAt = os.clock()
gameCall(obj.gloryKill, obj, enemy)
return
end
end
end
end
local shoveAt = 0
local function shoveStep()
if not Settings.AutoShove then return false end
local character = LocalPlayer.Character
local root = character and character:FindFirstChild("HumanoidRootPart")
local stomp = character and character:FindFirstChild("Stomp")
if not (root and stomp) or os.clock() - shoveAt < 0.8 then return end
local obj = weaponObject(stomp, "meleeHitboxes")
if not obj then return end
for _, player in Players:GetPlayers() do
if player ~= LocalPlayer and not excluded(player) then
local enemyRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
local state = enemyRoot and stateOf(player)
if state and state.parry and state.parry.isParried then
local offset = root.CFrame:PointToObjectSpace(enemyRoot.Position)
if offset.Z < 0 and offset.Z > -7 and math.abs(offset.X) <= 3.5 then
shoveAt = os.clock()
gameCall(obj.slash, obj)
return
end
end
end
end
end
local staminas = { list = {}, air = nil, searched = 0 }
local function findStaminas()
if not filtergc or os.clock() - staminas.searched < 3 then return end
staminas.searched = os.clock()
staminas.list = filtergc("table", { Keys = { "_stamina", "_maxStamina", "_isEmpty" } }) or {}
if not staminas.air then
local getter = filtergc("function", { Name = "getAirStamina", IgnoreExecutor = true }, true)
local ok, air = pcall(debug.getupvalue, getter, 1)
staminas.air = ok and type(air) == "table" and air or nil
end
end
local function pinStamina(stamina)
local maximum = rawget(stamina, "_maxStamina")
if type(maximum) == "number" and rawget(stamina, "_stamina") ~= maximum then
stamina._stamina = maximum
stamina._isEmpty = false
end
end
local function staminaStep()
if not (Settings.InfiniteStamina or Settings.InfiniteOxygen) then return false end
findStaminas()
for _, stamina in staminas.list do
local isAir = stamina == staminas.air
if (isAir and Settings.InfiniteOxygen) or (not isAir and Settings.InfiniteStamina) then
pinStamina(stamina)
end
end
end
local fallPinned = false
local function fallStep()
local state = ownState()
local fall = state and state.fallDamageClient
if not Settings.NoFallDamage then
if fallPinned and fall then fall.disableNextCount = 0 end
fallPinned = false
return false
end
if fall and fall.disableNextCount < 1 then
fall.disableNextCount = 1
fallPinned = true
end
end
local muted = {}
local function setMuted(eventName, state)
if state then
if muted[eventName] or not filtergc then return end
for _, handler in filtergc("table", { KeyValuePairs = { Name = eventName } }) or {} do
local callbacks = rawget(handler, "Callbacks")
if type(callbacks) == "table" and #callbacks > 0 then
muted[eventName] = { handler = callbacks, saved = table.clone(callbacks) }
table.clear(callbacks)
return
end
end
else
local entry = muted[eventName]
if not entry then return end
muted[eventName] = nil
for _, callback in entry.saved do table.insert(entry.handler, callback) end
end
end
local KNOCKBACK_EVENTS = { "KnockbackCharacterPart", "KnockbackCharacterPartAngular", "ImpulseCharacterPart", "ImpulseCharacterPartAngular" }
local function refreshMutes()
for _, eventName in KNOCKBACK_EVENTS do
setMuted(eventName, Kali.Running and Settings.NoKnockback)
end
setMuted("ToggleRagdoll", Kali.Running and Settings.AntiRagdoll)
end
local reviveAt = 0
local function reviveStep()
if not (Settings.AutoSelfRevive or Settings.FastRespawn) then return false end
local state = ownState()
if not (state and state.health) or os.clock() - reviveAt < 1 then return end
local onClick
if state.health.current > 0 then
local puck = state.puckReviveClient
if Settings.AutoSelfRevive and state.down and state.down.isDowned
and not (state.gk and state.gk.isBeingGked)
and not (state.selfReviveClient and state.selfReviveClient.isDoing)
and not (puck and puck.canRevive and not puck.isInCooldown) then
onClick = mobileButton(state, "selfRevive")
end
elseif Settings.FastRespawn and not (state.mainMenuClient and state.mainMenuClient.isIn)
and not (state.fastRespawnClient and state.fastRespawnClient.isDoing) then
onClick = mobileButton(state, "fastRespawn")
end
if onClick then
reviveAt = os.clock()
gameCall(onClick)
end
end
local promptDurations = {}
local function instaPrompt(prompt)
if prompt:IsA("ProximityPrompt") and prompt.HoldDuration > 0 then
promptDurations[prompt] = prompt.HoldDuration
prompt.HoldDuration = 0
end
end
local function refreshInstaUse()
if Kali.Running and Settings.InstaUse then
for _, descendant in workspace:GetDescendants() do instaPrompt(descendant) end
Kali.bind("instaUse", workspace.DescendantAdded:Connect(instaPrompt))
else
Kali.bind("instaUse", nil)
for prompt, duration in promptDurations do
if prompt.Parent then prompt.HoldDuration = duration end
end
table.clear(promptDurations)
end
end
local jumpPinned = false
local dashTimerGetter
local dashFinishedFor
local function movementStep()
local state = ownState()
local jump = state and state.jumpClient
if Settings.NoJumpCooldown then
if jump and not jump.canMultiJumpFromCount then
jump.canMultiJumpFromCount = true
jumpPinned = true
end
elseif jumpPinned then
if jump then jump.canMultiJumpFromCount = false end
jumpPinned = false
end
if Settings.NoDashCooldown and filtergc then
dashTimerGetter = dashTimerGetter or filtergc("function", { Name = "onResetDashCooldown", IgnoreExecutor = true }, true)
local ok, timer = pcall(debug.getupvalue, dashTimerGetter, 1)
if ok and type(timer) == "table" and timer ~= dashFinishedFor
and not rawget(timer, "_hasBeenCalled") and not rawget(timer, "_canceled") then
dashFinishedFor = timer
gameCall(timer.finish, timer)
end
end
if not (Settings.NoJumpCooldown or Settings.NoDashCooldown) and not jumpPinned then return false end
end
local function motionStep(dt)
local character = LocalPlayer.Character
local root = character and character:FindFirstChild("HumanoidRootPart")
local humanoid = character and character:FindFirstChildOfClass("Humanoid")
if not (root and humanoid and humanoid.Health > 0) or typing() then return end
if Settings.Fly then
local camera = workspace.CurrentCamera
local look = camera and camera.CFrame or root.CFrame
local direction = humanoid.MoveDirection
local flat = Vector3.new(look.LookVector.X, 0, look.LookVector.Z)
local move = Vector3.zero
if direction.Magnitude > 0 and flat.Magnitude > 0 then
move = look.LookVector * direction:Dot(flat.Unit) + look.RightVector * direction:Dot(look.RightVector)
end
if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.yAxis end
if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then move -= Vector3.yAxis end
root.AssemblyLinearVelocity = Vector3.zero
local step = Vector3.new(0, workspace.Gravity * dt * dt, 0)
if move.Magnitude > 0 then
step += move.Unit * Settings.FlySpeed * dt
end
root.CFrame += step
return
end
if Settings.SpeedBoost and humanoid.MoveDirection.Magnitude > 0 then
root.CFrame += humanoid.MoveDirection * Settings.SpeedAmount * dt
end
end
local function onJumpState(_, new)
if Settings.HighJump and new == Enum.HumanoidStateType.Jumping then
local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
if root then
local velocity = root.AssemblyLinearVelocity
root.AssemblyLinearVelocity = Vector3.new(velocity.X, velocity.Y + Settings.JumpBoost, velocity.Z)
end
end
end
local function refreshMotion()
local motion = Kali.Running and (Settings.SpeedBoost or Settings.Fly)
if motion and not Kali.Binds.motion then
Kali.bind("motion", RunService.Heartbeat:Connect(function(dt)
pcall(motionStep, dt)
end))
elseif not motion then
Kali.bind("motion", nil)
end
local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
if Kali.Running and Settings.HighJump and humanoid then
Kali.bind("highJump", humanoid.StateChanged:Connect(onJumpState))
Kali.bind("highJumpChar", LocalPlayer.CharacterAdded:Connect(function(character)
local fresh = character:WaitForChild("Humanoid", 10)
if fresh and Settings.HighJump then Kali.bind("highJump", fresh.StateChanged:Connect(onJumpState)) end
end))
else
Kali.bind("highJump", nil)
Kali.bind("highJumpChar", nil)
end
end
local GUN_MODS = { NoRecoil = { "recoilAmount" }, NoSpread = { "minSpread", "maxSpread" } }
local moddedConfigs = {}
local function applyGunMods(config)
for setting, fields in GUN_MODS do
if Settings[setting] then
for _, field in fields do
local value = config[field]
if type(value) == "number" and value ~= 0 then
local saved = moddedConfigs[config]
if not saved then
saved = {}
moddedConfigs[config] = saved
end
saved[field] = value
config[field] = 0
end
end
end
end
end
local function restoreGunMods()
for config, fields in moddedConfigs do
for field, value in fields do config[field] = value end
end
table.clear(moddedConfigs)
end
local function aimTool()
local character = LocalPlayer.Character
local tool = character and character:FindFirstChildOfClass("Tool")
if not tool or tool:FindFirstChild("Hitboxes") then return nil, nil end
if tool:FindFirstChild("ClientAmmo") then return weaponObject(tool, "_clientAmmoVO"), "gun" end
local obj = weaponObject(tool, "sounds")
if obj and obj.getAimSolution then return obj, "throwable" end
return nil, nil
end
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true
local ignoreList, ignoreAt = {}, 0
local function refreshIgnoreList()
local character = LocalPlayer.Character
if os.clock() - ignoreAt < 5 and ignoreList[#ignoreList] == character then return end
ignoreAt = os.clock()
ignoreList = CollectionService:GetTagged("RANGED_CASTER_IGNORE_LIST")
table.insert(ignoreList, character)
rayParams.FilterDescendantsInstances = ignoreList
end
local function cursorHit(origin, direction)
local result = workspace:Raycast(origin, direction * 1000, rayParams)
if result then return result.Position, result.Instance end
return origin + direction * 1000, nil
end
local crosshairGetter
local function crosshairOffset()
if crosshairGetter == nil then
crosshairGetter = filtergc and filtergc("function", { Name = "getCrosshairOffset", IgnoreExecutor = true }, true) or false
end
if not crosshairGetter then return Vector2.zero end
local ok, offset = pcall(debug.getupvalue, crosshairGetter, 1)
return ok and typeof(offset) == "Vector2" and offset or Vector2.zero
end
local sightParams = RaycastParams.new()
sightParams.FilterType = Enum.RaycastFilterType.Exclude
local function visible(origin, part, character)
sightParams.FilterDescendantsInstances = { LocalPlayer.Character, workspace:FindFirstChild("EffectsJunk") }
local hit = workspace:Raycast(origin, part.Position - origin, sightParams)
return hit == nil or hit.Instance:IsDescendantOf(character)
end
local function cursorPoint(camera)
local input = UserInputService:GetLastInputType()
if input == Enum.UserInputType.Touch or input == Enum.UserInputType.Gamepad1 then
return camera.ViewportSize * 0.5
end
return UserInputService:GetMouseLocation()
end
local function gunTarget(camera, cursor, fov, expand)
local origin = camera.CFrame.Position
local aim = expand and camera:ViewportPointToRay(cursor.X, cursor.Y).Direction
local best, bestGap
for _, player in Players:GetPlayers() do
if player ~= LocalPlayer and not excluded(player) then
local character = player.Character
local part = character and (character:FindFirstChild(Settings.GunPart) or character:FindFirstChild("HumanoidRootPart"))
local humanoid = character and character:FindFirstChildOfClass("Humanoid")
if part and humanoid and humanoid.Health > 0 and not character:FindFirstChildOfClass("ForceField")
and (part.Position - origin).Magnitude <= Settings.GunMaxDistance then
local screen, onScreen = camera:WorldToViewportPoint(part.Position)
if onScreen then
local gap = (Vector2.new(screen.X, screen.Y) - cursor).Magnitude
local offset = part.Position - origin
local inside = fov and gap <= Settings.GunFov
or aim and (offset - aim * offset:Dot(aim)).Magnitude <= Settings.HitboxSize * 0.5
if inside and (not bestGap or gap < bestGap)
and (not Settings.GunVisibleCheck or visible(origin, part, character)) then
best, bestGap = part, gap
end
end
end
end
end
return best
end
local function leadPoint(part, origin, config)
local point = part.Position
local speed = config and config.speed
if not Settings.GunPrediction or type(speed) ~= "number" or speed <= 0 then return point end
local velocity = part.AssemblyLinearVelocity
local gravity = typeof(config.gravity) == "Vector3" and config.gravity or Vector3.zero
for _ = 1, 3 do
local flight = (point - origin).Magnitude / speed
point = part.Position + velocity * flight - gravity * (0.5 * flight * flight)
end
return point
end
local function rayOntoLine(origin, from, line)
local offset = from - origin
local reach = line:Dot(offset)
local far = from + line * (math.sqrt(reach * reach - offset:Dot(offset) + 1e6) - reach)
local landing = workspace:Raycast(from, far - from, rayParams)
local goal = landing and landing.Position or far
local ray = (goal - origin).Unit
return ray, goal
end
local function gunRay(origin, obj, part)
local muzzle = obj.handle and obj.handle:FindFirstChild("FirePoint")
local from = muzzle and muzzle.WorldPosition or origin
local point = leadPoint(part, from, obj._itemConfig)
local direct = (point - origin).Unit
local hitPosition, hitPart = cursorHit(origin, direct)
if hitPart and hitPart:IsDescendantOf(part.Parent) and (hitPosition - point).Magnitude < 2 then return direct end
local ray, goal = rayOntoLine(origin, point, (point - from).Unit)
local reached, reachedPart = cursorHit(origin, ray)
if (reached - goal).Magnitude < 1 or (reachedPart and reachedPart:IsDescendantOf(part.Parent)) then return ray end
return direct
end
local THROW_ANGLES = 20
local function throwMiss(origin, head, direction, target)
local ray, goal = rayOntoLine(origin, head, direction)
if (cursorHit(origin, ray) - goal).Magnitude > 1 then return nil, 0, ray end
local speed = math.clamp((1 + ray.Y) * 125, 0, 200)
local start = head + direction * 3
local flat = Vector2.new(direction.X, direction.Z).Magnitude * speed
if flat < 1 then return nil, 0, ray end
local flight = Vector2.new(target.X - start.X, target.Z - start.Z).Magnitude / flat
return start.Y + direction.Y * speed * flight - 0.5 * workspace.Gravity * flight * flight - target.Y, flight, ray
end
local function throwRoot(origin, head, flat, target, low, high, lowMiss)
for _ = 1, 9 do
local middle = (low + high) * 0.5
local miss = throwMiss(origin, head, flat * math.cos(middle) + Vector3.yAxis * math.sin(middle), target)
if not miss then return nil end
if (miss < 0) == (lowMiss < 0) then low, lowMiss = middle, miss else high = middle end
end
local angle = (low + high) * 0.5
local direction = flat * math.cos(angle) + Vector3.yAxis * math.sin(angle)
local miss, flight, ray = throwMiss(origin, head, direction, target)
if not miss or math.abs(miss) > 2 then return nil end
return ray, flight, direction
end
local flightParams = RaycastParams.new()
flightParams.FilterType = Enum.RaycastFilterType.Exclude
flightParams.CollisionGroup = "throwables"
flightParams.RespectCanCollide = true
flightParams.IgnoreWater = true
local function throwClear(head, direction, ray, flight, target)
flightParams.FilterDescendantsInstances = { LocalPlayer.Character, workspace:FindFirstChild("EffectsJunk") }
local start = head + direction * 3
local velocity = direction * math.clamp((1 + ray.Y) * 125, 0, 200)
local previous = start
for step = 1, 6 do
local t = flight * step / 6
local point = start + velocity * t - Vector3.new(0, 0.5 * workspace.Gravity * t * t, 0)
local hit = workspace:Raycast(previous, point - previous, flightParams)
if hit and (hit.Position - target).Magnitude > 3 then return false end
previous = point
end
return true
end
local function throwRay(origin, head, target)
local flat = Vector3.new(target.X - head.X, 0, target.Z - head.Z)
if flat.Magnitude < 1 then return nil, 0 end
flat = flat.Unit
local fallbackRay, fallbackFlight
local previous, previousMiss
for step = 0, THROW_ANGLES do
local angle = -1 + step * 2.5 / THROW_ANGLES
local miss = throwMiss(origin, head, flat * math.cos(angle) + Vector3.yAxis * math.sin(angle), target)
if miss and previousMiss and (miss < 0) ~= (previousMiss < 0) then
local ray, flight, direction = throwRoot(origin, head, flat, target, previous, angle, previousMiss)
if ray then
if throwClear(head, direction, ray, flight, target) then return ray, flight end
fallbackRay, fallbackFlight = fallbackRay or ray, fallbackFlight or flight
end
end
if miss then previous, previousMiss = angle, miss end
end
return fallbackRay, fallbackFlight or 0
end
local function throwableRay(origin, part)
local head = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Head")
local root = part.Parent:FindFirstChild("HumanoidRootPart")
if not (head and root) then return nil end
local feet = root.Position - Vector3.new(0, 2.5, 0)
local ray, flight = throwRay(origin, head.Position, feet)
if ray and Settings.GunPrediction then
local velocity = root.AssemblyLinearVelocity
ray = throwRay(origin, head.Position, feet + Vector3.new(velocity.X, 0, velocity.Z) * flight) or ray
end
return ray
end
local aimRestore
local reloadAt = 0
local throwSolved = { at = 0, ray = nil }
local fovRing
local function aimPreAnimation()
local obj, kind = aimTool()
if not obj then return end
if kind == "gun" then
applyGunMods(obj._itemConfig)
if Settings.AutoReload and obj._clientAmmoVO.Value <= 0 and not obj._isReloading and os.clock() - reloadAt > 1 then
reloadAt = os.clock()
gameCall(obj.reload, obj)
end
end
local camera = workspace.CurrentCamera
if not camera or aimRestore then return end
if kind == "gun" and not (Settings.GunSilentAim or Settings.HitboxExpander) then return end
if kind == "throwable" and not (Settings.ThrowableAim and (obj.holdingActivation or obj.throwingThrowable)) then return end
local cursor = cursorPoint(camera)
if kind == "gun" then cursor += crosshairOffset() end
local part = if kind == "gun"
then gunTarget(camera, cursor, Settings.GunSilentAim, Settings.HitboxExpander)
else gunTarget(camera, cursor, true, false)
if not part then return end
refreshIgnoreList()
local origin = camera.CFrame.Position
local ray
if kind == "gun" then
ray = gunRay(origin, obj, part)
else
if obj.throwingThrowable or os.clock() - throwSolved.at > 0.1 then
throwSolved.at = os.clock()
throwSolved.ray = throwableRay(origin, part)
end
ray = throwSolved.ray
end
if not ray then return end
aimRestore = camera.CFrame
camera.CFrame = CFrame.fromRotationBetweenVectors(camera:ViewportPointToRay(cursor.X, cursor.Y).Direction, ray) * aimRestore.Rotation + aimRestore.Position
end
local function gunRenderFirst()
if aimRestore then
local camera = workspace.CurrentCamera
if camera then camera.CFrame = aimRestore end
aimRestore = nil
end
if fovRing then
local camera = workspace.CurrentCamera
fovRing.Visible = camera ~= nil and Settings.ShowFov and (Settings.GunSilentAim or Settings.ThrowableAim)
if fovRing.Visible then
local cursor = cursorPoint(camera)
fovRing.Position = UDim2.fromOffset(cursor.X, cursor.Y)
fovRing.Size = UDim2.fromOffset(Settings.GunFov * 2, Settings.GunFov * 2)
end
end
end
local gunBound = false
local function refreshGun()
local wanted = Kali.Running and (Settings.GunSilentAim or Settings.HitboxExpander or Settings.ThrowableAim or Settings.NoSpread or Settings.NoRecoil or Settings.AutoReload or Settings.ShowFov)
restoreGunMods()
if wanted and not gunBound then
gunBound = true
Kali.bind("gunPre", RunService.PreAnimation:Connect(function()
pcall(aimPreAnimation)
end))
RunService:BindToRenderStep("KaliFirst", 0, function()
pcall(gunRenderFirst)
end)
elseif not wanted and gunBound then
gunBound = false
Kali.bind("gunPre", nil)
pcall(RunService.UnbindFromRenderStep, RunService, "KaliFirst")
pcall(gunRenderFirst)
end
end
local STAFF_RANK = 52
local UGC_RANK = 90
local function checkStaff(player)
if not Settings.AntiMod or player == LocalPlayer or game.CreatorType ~= Enum.CreatorType.Group then return end
task.spawn(function()
local ok, rank = pcall(player.GetRankInGroup, player, game.CreatorId)
if not (ok and rank >= STAFF_RANK and rank ~= UGC_RANK and Settings.AntiMod and Kali.Running) then return end
local _, role = pcall(player.GetRoleInGroup, player, game.CreatorId)
LocalPlayer:Kick("Staff joined: " .. player.Name .. " (" .. tostring(role) .. ")")
end)
end
local function refreshAntiMod()
if Kali.Running and Settings.AntiMod then
for _, player in Players:GetPlayers() do checkStaff(player) end
Kali.bind("antiMod", Players.PlayerAdded:Connect(checkStaff))
else
Kali.bind("antiMod", nil)
end
end
local overlay
local espEntries = {}
local chamsQueue = {}
local function ensureOverlay()
if overlay and overlay.Parent then return overlay end
local hui = gethui and gethui()
if not hui then return nil end
overlay = Instance.new("ScreenGui")
overlay.Name = "Overlay"
overlay.ResetOnSpawn = false
overlay.IgnoreGuiInset = true
overlay.Parent = hui
table.insert(Kali.Guis, overlay)
return overlay
end
local function espRemove(player)
local entry = espEntries[player]
if not entry then return end
espEntries[player] = nil
entry.billboard:Destroy()
entry.box:Destroy()
entry.tracer:Destroy()
entry.bar:Destroy()
if entry.highlight then entry.highlight:Destroy() end
end
local function newFrame(props)
local frame = Instance.new("Frame")
frame.BorderSizePixel = 0
frame.Visible = false
for key, value in props do frame[key] = value end
frame.Parent = overlay
return frame
end
local function espAdd(player, character)
local head = character:FindFirstChild("Head")
if not (head and ensureOverlay()) then return nil end
local billboard = Instance.new("BillboardGui")
billboard.AlwaysOnTop = true
billboard.Size = UDim2.fromOffset(200, 44)
billboard.ExtentsOffsetWorldSpace = Vector3.yAxis
billboard.StudsOffsetWorldSpace = Vector3.new(0, 1.5, 0)
billboard.Adornee = head
local label = Instance.new("TextLabel")
label.BackgroundTransparency = 1
label.Size = UDim2.fromScale(1, 1)
label.Font = Enum.Font.GothamBold
label.TextSize = 13
label.TextStrokeTransparency = 0.4
label.TextYAlignment = Enum.TextYAlignment.Bottom
label.Parent = billboard
billboard.Parent = overlay
local box = newFrame({ BackgroundTransparency = 1 })
local stroke = Instance.new("UIStroke")
stroke.Thickness = 1
stroke.Parent = box
local tracer = newFrame({ AnchorPoint = Vector2.new(0, 0.5) })
local bar = newFrame({ BackgroundColor3 = Color3.new(), BackgroundTransparency = 0.35 })
local fill = Instance.new("Frame")
fill.BorderSizePixel = 0
fill.AnchorPoint = Vector2.new(0, 1)
fill.Position = UDim2.fromScale(0, 1)
fill.Parent = bar
local entry = {
character = character, head = head, billboard = billboard, label = label, distance = 0,
box = box, stroke = stroke, tracer = tracer, bar = bar, fill = fill,
}
espEntries[player] = entry
return entry
end
local HEALTHY = Color3.fromRGB(90, 220, 120)
local HURT = Color3.fromRGB(255, 70, 70)
local function espDraw()
local camera = workspace.CurrentCamera
if not camera then return end
local viewport = camera.ViewportSize
local from = Vector2.new(viewport.X * 0.5, viewport.Y)
for _, entry in espEntries do
local character = entry.character
local root = character:FindFirstChild("HumanoidRootPart")
local humanoid = character:FindFirstChildOfClass("Humanoid")
local top, onScreen = camera:WorldToViewportPoint(entry.head.Position + Vector3.new(0, 0.8, 0))
local shown = onScreen and root ~= nil and humanoid ~= nil and entry.billboard.Enabled
local bottom = shown and camera:WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0))
local height = shown and math.abs(bottom.Y - top.Y) or 0
local width = height * 0.55
local left = shown and (top.X - width * 0.5) or 0
local color = entry.label.TextColor3
entry.box.Visible = shown and Settings.EspBox
if entry.box.Visible then
entry.box.Position = UDim2.fromOffset(left, top.Y)
entry.box.Size = UDim2.fromOffset(width, height)
entry.stroke.Color = color
end
entry.tracer.Visible = shown and Settings.EspTracer
if entry.tracer.Visible then
local reach = Vector2.new(bottom.X, bottom.Y) - from
entry.tracer.Position = UDim2.fromOffset(from.X, from.Y)
entry.tracer.Size = UDim2.fromOffset(reach.Magnitude, 1)
entry.tracer.Rotation = math.deg(math.atan2(reach.Y, reach.X))
entry.tracer.BackgroundColor3 = color
end
entry.bar.Visible = shown and Settings.EspHealthBar
if entry.bar.Visible then
local alpha = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
entry.bar.Position = UDim2.fromOffset(left - 5, top.Y)
entry.bar.Size = UDim2.fromOffset(3, height)
entry.fill.Size = UDim2.fromScale(1, alpha)
entry.fill.BackgroundColor3 = HURT:Lerp(HEALTHY, alpha)
end
end
end
local function refreshEspDraw()
if Kali.Running and Settings.Esp and (Settings.EspBox or Settings.EspTracer or Settings.EspHealthBar) then
if not Kali.Binds.espDraw then
Kali.bind("espDraw", RunService.RenderStepped:Connect(function()
pcall(espDraw)
end))
end
else
Kali.bind("espDraw", nil)
for _, entry in espEntries do
entry.box.Visible = false
entry.tracer.Visible = false
entry.bar.Visible = false
end
end
end
local function applyChams(entry, color)
if Settings.EspChams and not entry.highlight then
local highlight = Instance.new("Highlight")
highlight.Enabled = false
highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
highlight.FillTransparency = 0.6
highlight.OutlineTransparency = 0.1
highlight.Adornee = entry.character
highlight.Parent = overlay
entry.highlight = highlight
elseif not Settings.EspChams and entry.highlight then
entry.highlight:Destroy()
entry.highlight = nil
end
if entry.highlight then
entry.highlight.FillColor = color
entry.highlight.OutlineColor = color
end
end
local function espText(player, character, humanoid, distance)
local lines = {}
if Settings.EspName then table.insert(lines, player.DisplayName) end
local detail = {}
if Settings.EspHealth then table.insert(detail, math.floor(humanoid.Health) .. " HP") end
if Settings.EspDistance then table.insert(detail, math.floor(distance) .. "m") end
if Settings.EspWeapon then
local tool = character:FindFirstChildOfClass("Tool")
if tool then table.insert(detail, tool.Name) end
end
if #detail > 0 then table.insert(lines, table.concat(detail, " · ")) end
local parrying = false
if Settings.EspState then
local state = stateOf(player)
if state then
if state.down and state.down.isDowned then
table.insert(lines, "DOWNED")
elseif state.parry and state.parry.isParrying then
table.insert(lines, "PARRYING")
parrying = true
end
end
end
return table.concat(lines, "\n"), parrying
end
local function espStep()
if not Settings.Esp then
for player in espEntries do espRemove(player) end
return false
end
local camera = workspace.CurrentCamera
local origin = camera and camera.CFrame.Position or Vector3.zero
table.clear(chamsQueue)
for _, player in Players:GetPlayers() do
if player ~= LocalPlayer then
local character = player.Character
local humanoid = character and character:FindFirstChildOfClass("Humanoid")
local entry = espEntries[player]
if entry and (entry.character ~= character or not entry.head.Parent) then
espRemove(player)
entry = nil
end
if humanoid and humanoid.Health > 0 then
entry = entry or espAdd(player, character)
if entry then
entry.distance = (entry.head.Position - origin).Magnitude
local visible = entry.distance <= Settings.EspMaxDistance
entry.billboard.Enabled = visible
if visible then
local text, parrying = espText(player, character, humanoid, entry.distance)
local color = if parrying then PARRY_COLOR elseif friends[player] then Settings.EspFriendColor else Settings.EspColor
entry.label.Text = text
entry.label.TextColor3 = color
applyChams(entry, color)
if entry.highlight then table.insert(chamsQueue, entry) end
elseif entry.highlight then
entry.highlight.Enabled = false
end
end
elseif entry then
espRemove(player)
end
end
end
for player in espEntries do
if not player.Parent then espRemove(player) end
end
table.sort(chamsQueue, function(a, b) return a.distance < b.distance end)
for index, entry in chamsQueue do
entry.highlight.Enabled = index <= CHAMS_LIMIT
end
end
local hitboxViews = {}
local function hitboxViewStep()
local shown = Settings.HitboxExpander and Settings.ShowHitbox and ensureOverlay()
for _, player in Players:GetPlayers() do
local character = shown and player ~= LocalPlayer and not excluded(player) and player.Character
local torso = character and character:FindFirstChild("Torso")
local humanoid = character and character:FindFirstChildOfClass("Humanoid")
local view = hitboxViews[player]
if torso and humanoid and humanoid.Health > 0 then
if not view then
view = Instance.new("SphereHandleAdornment")
view.Transparency = 0.75
view.Parent = shown
hitboxViews[player] = view
end
view.Adornee = torso
view.Radius = Settings.HitboxSize * 0.5
view.Color3 = Settings.EspColor
elseif view then
view:Destroy()
hitboxViews[player] = nil
end
end
for player, view in hitboxViews do
if not player.Parent then
view:Destroy()
hitboxViews[player] = nil
end
end
if not shown then return false end
end
local function set_thread_identity_safe(identity)
	local exec_setidentity = setthreadidentity or set_thread_identity or setidentity or set_thread_context
	if type(exec_setidentity) == "function" then
		pcall(exec_setidentity, identity)
	end
end

set_thread_identity_safe(8)

local Library
local okLib, resLib = pcall(function()
	if isfile and isfile("ui.luau") then
		return loadstring(readfile("ui.luau"))()
	end
	return nil
end)
if okLib and type(resLib) == "table" then
	Library = resLib
else
	Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/ktrodev/uis/refs/heads/main/BOII"))()
end

local Window = Library.new()
Pivot.Window = Window

local function ensureGuiParent(gui)
	if not gui then return end
	local success = false
	if gethui then
		local ok, res = pcall(gethui)
		if ok and res then
			pcall(function() gui.Parent = res end)
			if gui.Parent == res then success = true end
		end
	end
	if not success then
		pcall(function()
			local cg = game:GetService("CoreGui")
			if cg then
				gui.Parent = cg
				if gui.Parent == cg then success = true end
			end
		end)
	end
	if not success then
		pcall(function()
			local pgui = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
			if pgui then gui.Parent = pgui end
		end)
	end
	pcall(function() gui.Enabled = true end)
end

if Window and Window._ui then
	ensureGuiParent(Window._ui)
	table.insert(Pivot.Guis, Window._ui)
end
if Window and Window._toggle_gui then
	ensureGuiParent(Window._toggle_gui)
	table.insert(Pivot.Guis, Window._toggle_gui)
end

pcall(function() Library:set_toggle_keybind(Enum.KeyCode.RightControl) end)
pcall(function() Window:set_toggle_keybind(Enum.KeyCode.RightControl) end)

Library.SendNotification({
	title = "Pivot",
	text = "Loaded Combat Warriors successfully!",
	duration = 5
})

local MainTab = Window:create_tab("main", "rbxassetid://107819132007001")
local VisualsTab = Window:create_tab("visuals", "rbxassetid://10723415205")
local SettingsTab = Window:create_tab("settings", "rbxassetid://10734950309")

-- MAIN TAB
do
	local parry = MainTab:create_module({
		title = "Auto Parry",
		description = "Automated parry defense against incoming attacks",
		flag = "AutoParryModule",
		section = "left",
		callback = function(state) end
	})

	parry:create_checkbox({
		title = "Auto Parry",
		flag = "AutoParryToggle",
		default = Settings.AutoParry,
		callback = function(state)
			Settings.AutoParry = state
			refreshAutoParry()
		end
	})

	parry:create_slider({
		title = "Parry Distance",
		flag = "ParryDistanceSlider",
		minimum_value = 5,
		maximum_value = 30,
		value = Settings.ParryDistance,
		round_number = true,
		callback = function(studs)
			Settings.ParryDistance = studs
		end
	})

	parry:create_slider({
		title = "Parry Chance",
		flag = "ParryChanceSlider",
		minimum_value = 1,
		maximum_value = 100,
		value = Settings.ParryChance,
		round_number = true,
		callback = function(percent)
			Settings.ParryChance = percent
		end
	})

	parry:create_slider({
		title = "Reaction Delay (ms)",
		flag = "ReactionDelaySlider",
		minimum_value = 0,
		maximum_value = 300,
		value = Settings.ParryDelay,
		round_number = true,
		callback = function(ms)
			Settings.ParryDelay = ms
		end
	})

	parry:create_checkbox({
		title = "Targeted Only",
		flag = "TargetedOnlyToggle",
		default = Settings.TargetedOnly,
		callback = function(state)
			Settings.TargetedOnly = state
		end
	})

	local combat = MainTab:create_module({
		title = "Combat",
		description = "Offensive assists, aura and hitbox expansion",
		flag = "CombatModule",
		section = "right",
		callback = function(state) end
	})

	combat:create_checkbox({
		title = "Auto Attack",
		flag = "AutoAttackToggle",
		default = Settings.AutoAttack,
		callback = function(state)
			Settings.AutoAttack = state
			refreshAntiParry()
			if state then Kali.loop("attack", 0.12, attackStep) end
		end
	})

	combat:create_slider({
		title = "Attack Range",
		flag = "AttackRangeSlider",
		minimum_value = 4,
		maximum_value = 15,
		value = Settings.AttackRange,
		round_number = true,
		callback = function(studs)
			Settings.AttackRange = studs
		end
	})

	combat:create_checkbox({
		title = "Face Check",
		flag = "FaceCheckToggle",
		default = Settings.AttackFacing,
		callback = function(state)
			Settings.AttackFacing = state
		end
	})

	combat:create_checkbox({
		title = "Anti Parry",
		flag = "AntiParryToggle",
		default = Settings.SkipParrying,
		callback = function(state)
			Settings.SkipParrying = state
			refreshAntiParry()
		end
	})

	combat:create_slider({
		title = "Parry Safety (ms)",
		flag = "ParrySafetySlider",
		minimum_value = 0,
		maximum_value = 300,
		value = Settings.ParrySafety,
		round_number = true,
		callback = function(ms)
			Settings.ParrySafety = ms
		end
	})

	combat:create_divider()

	combat:create_checkbox({
		title = "Kill Aura",
		flag = "KillAuraToggle",
		default = Settings.KillAura,
		callback = function(state)
			Settings.KillAura = state
			aura.generation += 1
			refreshAntiParry()
			if state then Kali.loop("aura", 0.05, auraStep) end
		end
	})

	combat:create_checkbox({
		title = "Melee Silent Aim",
		flag = "MeleeSilentAimToggle",
		default = Settings.MeleeSilentAim,
		callback = function(state)
			Settings.MeleeSilentAim = state
			refreshAntiParry()
			if state then Kali.loop("meleeAim", 0.05, meleeAimStep) end
		end
	})

	combat:create_slider({
		title = "Aura Range",
		flag = "AuraRangeSlider",
		minimum_value = 5,
		maximum_value = 20,
		value = Settings.AuraRange,
		round_number = true,
		callback = function(studs)
			Settings.AuraRange = studs
		end
	})

	combat:create_divider()

	combat:create_checkbox({
		title = "Hitbox Expander",
		flag = "HitboxExpanderToggle",
		default = Settings.HitboxExpander,
		callback = function(state)
			Settings.HitboxExpander = state
			refreshAntiParry()
			if state then
				Kali.loop("expander", 0.05, expanderStep)
				Kali.loop("hitboxView", 0.2, hitboxViewStep)
			end
			refreshGun()
		end
	})

	combat:create_slider({
		title = "Hitbox Size",
		flag = "HitboxSizeSlider",
		minimum_value = 2,
		maximum_value = 40,
		value = Settings.HitboxSize,
		round_number = true,
		callback = function(studs)
			Settings.HitboxSize = studs
		end
	})

	combat:create_checkbox({
		title = "Show Hitbox",
		flag = "ShowHitboxToggle",
		default = Settings.ShowHitbox,
		callback = function(state)
			Settings.ShowHitbox = state
			if state then Kali.loop("hitboxView", 0.2, hitboxViewStep) end
		end
	})

	combat:create_divider()

	combat:create_checkbox({
		title = "Auto Glory Kill",
		flag = "AutoGloryKillToggle",
		default = Settings.AutoGloryKill,
		callback = function(state)
			Settings.AutoGloryKill = state
			if state then Kali.loop("glory", 0.15, gloryStep) end
		end
	})

	combat:create_slider({
		title = "Glory Kill Range",
		flag = "GloryKillRangeSlider",
		minimum_value = 6,
		maximum_value = 10,
		value = Settings.GloryRange,
		round_number = true,
		callback = function(studs)
			Settings.GloryRange = studs
		end
	})

	combat:create_checkbox({
		title = "Auto Shove",
		flag = "AutoShoveToggle",
		default = Settings.AutoShove,
		callback = function(state)
			Settings.AutoShove = state
			if state then Kali.loop("shove", 0.1, shoveStep) end
		end
	})

	combat:create_divider()

	combat:create_checkbox({
		title = "Whitelist Friends",
		flag = "WhitelistFriendsToggle",
		default = Settings.WhitelistFriends,
		callback = function(state)
			Settings.WhitelistFriends = state
		end
	})

	local movement = MainTab:create_module({
		title = "Movement",
		description = "Stamina, flight, speed and cooldown removers",
		flag = "MovementModule",
		section = "left",
		callback = function(state) end
	})

	movement:create_checkbox({
		title = "Infinite Stamina",
		flag = "InfiniteStaminaToggle",
		default = Settings.InfiniteStamina,
		callback = function(state)
			Settings.InfiniteStamina = state
			if state then Kali.loop("stamina", 0.05, staminaStep) end
		end
	})

	movement:create_checkbox({
		title = "Infinite Oxygen",
		flag = "InfiniteOxygenToggle",
		default = Settings.InfiniteOxygen,
		callback = function(state)
			Settings.InfiniteOxygen = state
			if state then Kali.loop("stamina", 0.05, staminaStep) end
		end
	})

	movement:create_checkbox({
		title = "No Fall Damage",
		flag = "NoFallDamageToggle",
		default = Settings.NoFallDamage,
		callback = function(state)
			Settings.NoFallDamage = state
			if state then Kali.loop("fall", 0.25, fallStep) else fallStep() end
		end
	})

	movement:create_checkbox({
		title = "No Knockback",
		flag = "NoKnockbackToggle",
		default = Settings.NoKnockback,
		callback = function(state)
			Settings.NoKnockback = state
			refreshMutes()
		end
	})

	movement:create_checkbox({
		title = "Anti Ragdoll",
		flag = "AntiRagdollToggle",
		default = Settings.AntiRagdoll,
		callback = function(state)
			Settings.AntiRagdoll = state
			refreshMutes()
		end
	})

	movement:create_checkbox({
		title = "No Jump Cooldown",
		flag = "NoJumpCooldownToggle",
		default = Settings.NoJumpCooldown,
		callback = function(state)
			Settings.NoJumpCooldown = state
			Kali.loop("movement", 0.1, movementStep)
		end
	})

	movement:create_checkbox({
		title = "No Dash Cooldown",
		flag = "NoDashCooldownToggle",
		default = Settings.NoDashCooldown,
		callback = function(state)
			Settings.NoDashCooldown = state
			Kali.loop("movement", 0.1, movementStep)
		end
	})

	movement:create_divider()

	movement:create_checkbox({
		title = "CFrame Walkspeed",
		flag = "SpeedBoostToggle",
		default = Settings.SpeedBoost,
		callback = function(state)
			Settings.SpeedBoost = state
			refreshMotion()
		end
	})

	movement:create_slider({
		title = "Extra Speed",
		flag = "ExtraSpeedSlider",
		minimum_value = 1,
		maximum_value = 40,
		value = Settings.SpeedAmount,
		round_number = true,
		callback = function(speed)
			Settings.SpeedAmount = speed
		end
	})

	movement:create_checkbox({
		title = "Fly",
		flag = "FlyToggle",
		default = Settings.Fly,
		callback = function(state)
			Settings.Fly = state
			refreshMotion()
		end
	})

	movement:create_slider({
		title = "Fly Speed",
		flag = "FlySpeedSlider",
		minimum_value = 10,
		maximum_value = 120,
		value = Settings.FlySpeed,
		round_number = true,
		callback = function(speed)
			Settings.FlySpeed = speed
		end
	})

	movement:create_checkbox({
		title = "High Jump",
		flag = "HighJumpToggle",
		default = Settings.HighJump,
		callback = function(state)
			Settings.HighJump = state
			refreshMotion()
		end
	})

	movement:create_slider({
		title = "Jump Boost",
		flag = "JumpBoostSlider",
		minimum_value = 5,
		maximum_value = 80,
		value = Settings.JumpBoost,
		round_number = true,
		callback = function(power)
			Settings.JumpBoost = power
		end
	})

	local gun = MainTab:create_module({
		title = "Gun & Ranged",
		description = "Silent aim, projectile prediction & recoil removal",
		flag = "GunRangedModule",
		section = "left",
		callback = function(state) end
	})

	gun:create_checkbox({
		title = "Silent Aim",
		flag = "GunSilentAimToggle",
		default = Settings.GunSilentAim,
		callback = function(state)
			Settings.GunSilentAim = state
			refreshGun()
		end
	})

	gun:create_checkbox({
		title = "Throwable Aim",
		flag = "ThrowableAimToggle",
		default = Settings.ThrowableAim,
		callback = function(state)
			Settings.ThrowableAim = state
			refreshGun()
		end
	})

	gun:create_slider({
		title = "FOV",
		flag = "GunFovSlider",
		minimum_value = 30,
		maximum_value = 600,
		value = Settings.GunFov,
		round_number = true,
		callback = function(radius)
			Settings.GunFov = radius
		end
	})

	gun:create_checkbox({
		title = "Show FOV Circle",
		flag = "ShowFovCircleToggle",
		default = Settings.ShowFov,
		callback = function(state)
			Settings.ShowFov = state
			if state and not fovRing and ensureOverlay() then
				fovRing = Instance.new("Frame")
				fovRing.BackgroundTransparency = 1
				fovRing.AnchorPoint = Vector2.new(0.5, 0.5)
				fovRing.Visible = false
				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(1, 0)
				corner.Parent = fovRing
				local stroke = Instance.new("UIStroke")
				stroke.Color = WHITE
				stroke.Transparency = 0.4
				stroke.Parent = fovRing
				fovRing.Parent = overlay
			end
			refreshGun()
		end
	})

	gun:create_slider({
		title = "Max Distance",
		flag = "GunMaxDistSlider",
		minimum_value = 50,
		maximum_value = 1500,
		value = Settings.GunMaxDistance,
		round_number = true,
		callback = function(studs)
			Settings.GunMaxDistance = studs
		end
	})

	gun:create_dropdown({
		title = "Body Part",
		flag = "GunBodyPartDropdown",
		options = { "Head", "Torso", "HumanoidRootPart" },
		maximum_options = 1,
		value = Settings.GunPart,
		callback = function(part)
			Settings.GunPart = part
		end
	})

	gun:create_checkbox({
		title = "Use Prediction",
		flag = "GunPredictionToggle",
		default = Settings.GunPrediction,
		callback = function(state)
			Settings.GunPrediction = state
		end
	})

	gun:create_checkbox({
		title = "Visible Check",
		flag = "GunVisibleCheckToggle",
		default = Settings.GunVisibleCheck,
		callback = function(state)
			Settings.GunVisibleCheck = state
		end
	})

	gun:create_divider()

	gun:create_checkbox({
		title = "No Recoil",
		flag = "GunNoRecoilToggle",
		default = Settings.NoRecoil,
		callback = function(state)
			Settings.NoRecoil = state
			refreshGun()
		end
	})

	gun:create_checkbox({
		title = "No Spread",
		flag = "GunNoSpreadToggle",
		default = Settings.NoSpread,
		callback = function(state)
			Settings.NoSpread = state
			refreshGun()
		end
	})

	gun:create_checkbox({
		title = "Auto Reload",
		flag = "GunAutoReloadToggle",
		default = Settings.AutoReload,
		callback = function(state)
			Settings.AutoReload = state
			refreshGun()
		end
	})

	local utility = MainTab:create_module({
		title = "Utility",
		description = "Revive, respawn and moderation bypasses",
		flag = "UtilityModule",
		section = "right",
		callback = function(state) end
	})

	utility:create_checkbox({
		title = "Auto Self Revive",
		flag = "AutoSelfReviveToggle",
		default = Settings.AutoSelfRevive,
		callback = function(state)
			Settings.AutoSelfRevive = state
			if state then Kali.loop("revive", 0.2, reviveStep) end
		end
	})

	utility:create_checkbox({
		title = "Fast Respawn",
		flag = "FastRespawnToggle",
		default = Settings.FastRespawn,
		callback = function(state)
			Settings.FastRespawn = state
			if state then Kali.loop("revive", 0.2, reviveStep) end
		end
	})

	utility:create_checkbox({
		title = "Insta Use",
		flag = "InstaUseToggle",
		default = Settings.InstaUse,
		callback = function(state)
			Settings.InstaUse = state
			refreshInstaUse()
		end
	})

	utility:create_checkbox({
		title = "Anti Mod",
		flag = "AntiModToggle",
		default = Settings.AntiMod,
		callback = function(state)
			Settings.AntiMod = state
			refreshAntiMod()
		end
	})
end

-- VISUALS TAB
do
	local esp = VisualsTab:create_module({
		title = "Player ESP",
		description = "Player visual tracking, boxes, health and status",
		flag = "PlayerEspModule",
		section = "left",
		callback = function(state) end
	})

	esp:create_checkbox({
		title = "ESP",
		flag = "EspToggle",
		default = Settings.Esp,
		callback = function(state)
			Settings.Esp = state
			if state then Kali.loop("esp", 0.15, espStep) end
			refreshEspDraw()
		end
	})

	esp:create_checkbox({
		title = "Boxes",
		flag = "EspBoxToggle",
		default = Settings.EspBox,
		callback = function(state)
			Settings.EspBox = state
			refreshEspDraw()
		end
	})

	esp:create_checkbox({
		title = "Tracers",
		flag = "EspTracerToggle",
		default = Settings.EspTracer,
		callback = function(state)
			Settings.EspTracer = state
			refreshEspDraw()
		end
	})

	esp:create_checkbox({
		title = "Health Bar",
		flag = "EspHealthBarToggle",
		default = Settings.EspHealthBar,
		callback = function(state)
			Settings.EspHealthBar = state
			refreshEspDraw()
		end
	})

	esp:create_checkbox({
		title = "Chams",
		flag = "EspChamsToggle",
		default = Settings.EspChams,
		callback = function(state)
			Settings.EspChams = state
		end
	})

	esp:create_checkbox({
		title = "Name",
		flag = "EspNameToggle",
		default = Settings.EspName,
		callback = function(state)
			Settings.EspName = state
		end
	})

	esp:create_checkbox({
		title = "Health",
		flag = "EspHealthToggle",
		default = Settings.EspHealth,
		callback = function(state)
			Settings.EspHealth = state
		end
	})

	esp:create_checkbox({
		title = "Distance",
		flag = "EspDistanceToggle",
		default = Settings.EspDistance,
		callback = function(state)
			Settings.EspDistance = state
		end
	})

	esp:create_checkbox({
		title = "Weapon",
		flag = "EspWeaponToggle",
		default = Settings.EspWeapon,
		callback = function(state)
			Settings.EspWeapon = state
		end
	})

	esp:create_checkbox({
		title = "Parry / Downed",
		flag = "EspStateToggle",
		default = Settings.EspState,
		callback = function(state)
			Settings.EspState = state
		end
	})

	local espSettings = VisualsTab:create_module({
		title = "ESP Settings",
		description = "Rendering distances and limits",
		flag = "EspSettingsModule",
		section = "right",
		callback = function(state) end
	})

	espSettings:create_slider({
		title = "ESP Distance",
		flag = "EspMaxDistanceSlider",
		minimum_value = 50,
		maximum_value = 2000,
		value = Settings.EspMaxDistance,
		round_number = true,
		callback = function(studs)
			Settings.EspMaxDistance = studs
		end
	})
end

-- SETTINGS TAB
do
	local settingsModule = SettingsTab:create_module({
		title = "Interface",
		description = "Script controls and runtime management",
		flag = "InterfaceModule",
		section = "left",
		callback = function(state) end
	})

	settingsModule:create_paragraph({
		title = "Menu Keybind",
		text = "Press Right Control to toggle the interface."
	})

	settingsModule:create_button({
		title = "Unload Script",
		callback = function()
			if type(getgenv().PivotUnload) == "function" then
				getgenv().PivotUnload()
			end
		end
	})
end

local function unload()
	Pivot.Running = false
	for key, value in Settings do
		if type(value) == "boolean" then Settings[key] = false end
	end
	table.clear(Pivot.Loops)
	aura.generation += 1
	pcall(refreshAntiParry)
	pcall(refreshAutoParry)
	pcall(fallStep)
	pcall(reviveStep)
	pcall(refreshMutes)
	pcall(refreshInstaUse)
	pcall(refreshGun)
	pcall(refreshAntiMod)
	pcall(movementStep)
	pcall(refreshEspDraw)
	pcall(refreshMotion)
	for _, connection in Pivot.Binds do
		pcall(function() connection:Disconnect() end)
	end
	table.clear(Pivot.Binds)
	for _, connection in Pivot.Connections do
		pcall(function() connection:Disconnect() end)
	end
	table.clear(Pivot.Connections)
	for player in espEntries do
		pcall(espRemove, player)
	end
	pcall(function()
		if Window and Window.destroy then
			Window:destroy()
		elseif Window and Window._ui then
			Window._ui:Destroy()
		end
		if Window and Window._toggle_gui then
			Window._toggle_gui:Destroy()
		end
	end)
	for _, gui in Pivot.Guis do
		pcall(function() gui:Destroy() end)
	end
	table.clear(Pivot.Guis)
	getgenv().PivotUnload = nil
	getgenv().KaliUnload = nil
	getgenv().Anka = nil
end

getgenv().PivotUnload = unload
getgenv().KaliUnload = unload