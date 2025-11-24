local ReplicatedStorage = game:GetService('ReplicatedStorage') -- gets the ReplicatedStorage service for shared game data
local Players = game:GetService("Players") -- gets the Players service to manage player objects
local Debris = game:GetService("Debris") -- gets the Debris service to automatically remove objects after a delay
local RunService = game:GetService("RunService") -- gets the RunService to check if code runs on server or client
local ServerStorage = game:GetService("ServerStorage") -- gets the ServerStorage service for server-only data
local HttpService = game:GetService("HttpService") -- gets the HttpService for HTTP requests and JSON operations

local BehaviorTree = require(ServerStorage.BehaviorTrees.EnemyAI) -- requires the enemy AI behavior tree module
local EnemyTemplates = require(ReplicatedStorage.Modules.EnemyTemplates) -- requires the enemy templates module

local Animations = ReplicatedStorage:WaitForChild('Animations') -- waits for and gets the Animations folder
local Remotes = ReplicatedStorage:FindFirstChild('Remotes') -- finds the Remotes folder containing remote events
local Songs = ReplicatedStorage:WaitForChild('Songs') -- waits for and gets the Songs folder for audio

local PlayerDieEvent = Remotes:FindFirstChild('PlayerDieEvent') -- finds the remote event for player death
local DefenseRemote = Remotes:FindFirstChild('DefenseRemote') -- finds the remote event for defense/blocking
local ParryRemote = Remotes:FindFirstChild('ParryRemote') -- finds the remote event for parrying
local PromptCheck = Remotes:FindFirstChild('PromptCheck') -- finds the remote event to check proximity prompts
local PromptEnd = Remotes:FindFirstChild('PromptEnd') -- finds the remote event when prompt finishes



local Sword = {} -- creates an empty table to hold the Sword class
Sword.__index = Sword -- sets the metatable index to enable object-oriented programming

function  Sword.new(tool) -- constructor function to create a new Sword object
	local self = setmetatable({}, Sword) -- creates a new instance with Sword as metatable
	self.Tool = tool -- stores the tool object reference
	self.AttackCooldown = 1 -- sets attack cooldown to 1 second between attacks
	self.Damage = 5 -- sets base damage value to 5 health points
	self.CurrentAttackIndex = 1 -- initializes attack animation index to 1 for combo system
	self.IsAttacking = false -- flag to track if currently performing an attack
	self.CanAttack = true -- flag to track if attack is off cooldown
	self.EquippedModel = nil -- stores reference to the equipped sword model on character

	self:SetupEvents() -- calls function to connect all event listeners

	return self -- returns the newly created Sword instance
end

function Sword:SetupEvents() -- sets up all event connections for the sword tool
	if self.Tool.Activated then -- checks if the Activated event exists on the tool
		self.Tool.Activated:Connect(function() -- connects to the tool activation event (when player clicks)
			self:Attack() -- calls the Attack function when tool is activated
		end)
	end

	local handle = self.Tool:FindFirstChild("Handle") -- finds the Handle part of the tool
	if handle then -- checks if handle exists
		handle.Touched:Connect(function(hit) -- connects to the Touched event when handle hits something
			self:OnHit(hit) -- calls OnHit function with the part that was touched
		end)
	end

	if self.Tool.Equipped then -- checks if the Equipped event exists
		self.Tool.Equipped:Connect(function() -- connects to when player equips the tool
			self:RemoveWeld() -- removes the weld to detach sword from back position
		end)
	end

	if self.Tool.Unequipped then -- checks if the Unequipped event exists
		self.Tool.Unequipped:Connect(function() -- connects to when player unequips the tool
			local character = self.Tool.Parent.Parent.Character -- gets the character model from the player
			if not character then -- checks if character was not found
				print('Not Character Detect!!! Little Donkey') -- prints error message
			end
			self:WeldToCharacter(character) -- welds sword to character's back when unequipped
		end)
	end
end


--[[function Sword:PlaySoundClone(originalSound)
	if originalSound then
		local soundClone = originalSound:Clone()
		soundClone.Parent = workspace
		soundClone.Volume = 1
		soundClone:Play()
		game.Debris:AddItem(soundClone, soundClone.TimeLengh + 0.5)
	end
end]]


function Sword:WeldToCharacter(character) -- welds the sword model to the character's back
	if not Players:GetPlayerFromCharacter(character) then return end -- checks if character belongs to a player, returns if not

	if self.EquippedModel and self.EquippedModel.Parent == character then -- checks if sword is already welded to this character
		print('Tool Equipped') -- prints message that tool is already equipped
		return -- exits function early to avoid duplicate welds
	end

	local torso = character:FindFirstChild("Torso") -- finds the Torso part of the character
	local toolClone = self.Tool.Model and self.Tool.Model:Clone() -- clones the sword model if it exists

	if not toolClone then return end -- exits if no tool model to clone

	toolClone.Parent = character -- parents the cloned tool to the character
	local handle = toolClone.PrimaryPart -- gets the primary part of the cloned tool

	if not torso or not handle then return end -- exits if torso or handle not found

	if handle:FindFirstChild("SwordWeld") then -- checks if a weld already exists
		handle.SwordWeld:Destroy() -- destroys the existing weld to prevent conflicts
	end

	local weld = Instance.new("Weld") -- creates a new Weld instance
	weld.Name = "SwordWeld" -- names the weld for easy identification
	weld.Part0 = torso -- sets the first part of weld to torso
	weld.Part1 = handle -- sets the second part of weld to sword handle
	weld.C0 = CFrame.new(-1, -1, 0) * CFrame.Angles(0, math.rad(90), math.rad(90)) -- positions sword on character's back with rotation
	weld.Parent = handle -- parents the weld to the handle

	handle.Anchored = false -- makes handle movable (not fixed in space)
	handle.CanCollide = false -- prevents handle from colliding with other parts

	self.EquippedModel = toolClone -- stores reference to the equipped model
end

function Sword:RemoveWeld() -- removes the weld and destroys the equipped sword model
	if not self.EquippedModel then return end -- exits if no equipped model exists

	local handle = self.Tool:FindFirstChild("Handle") -- finds the Handle part of the tool
	if handle then -- checks if handle exists
		local weld = handle:FindFirstChild("SwordWeld") -- finds the SwordWeld instance
		if weld then -- checks if weld exists
			weld:Destroy() -- destroys the weld connection
		end
	end

	self.EquippedModel:Destroy() -- destroys the equipped sword model from character
	self.EquippedModel = nil -- sets reference to nil to clear memory
end

function Sword:Attack() -- handles the attack logic and animation
	local character = self.Tool.Parent -- gets the character holding the tool
	local humanoid = character:FindFirstChild('Humanoid') -- finds the Humanoid to control animations

	if not self.CanAttack then return end -- exits if attack is on cooldown
	self.HitEnemies = {} -- initializes empty table to track hit enemies (prevents double hits)
	self.HitSomething = false -- flag to track if the attack connected with anything
	self.CanAttack = false -- sets attack on cooldown
	self.IsAttacking = true -- sets attacking flag to true for hit detection

	if humanoid then -- checks if humanoid exists
		local AnimFolder = ReplicatedStorage:FindFirstChild("Animations").Attacks -- gets the Attacks animation folder
		local attackAnims = 4 -- defines total number of attack animations in combo
		local animName = "Att"..self.CurrentAttackIndex -- constructs animation name like "Att1", "Att2", etc.
		local animation = AnimFolder:FindFirstChild(animName) -- finds the specific attack animation

		if animation then -- checks if animation was found
			local track = humanoid:LoadAnimation(animation) -- loads the animation onto the humanoid
			track:Play() -- plays the attack animation
		end

		self.CurrentAttackIndex += 1 -- increments to next attack in combo sequence
		if self.CurrentAttackIndex > attackAnims then -- checks if combo index exceeded max
			self.CurrentAttackIndex = 1 -- resets combo back to first attack
		end
	end

	task.delay(0.4, function() -- delays execution by 0.4 seconds to sync with animation
		if self.HitSomething then -- checks if the attack hit an enemy
			local SlashsSongs = Songs:WaitForChild('Slashs') -- gets the Slashs sound folder
			local SlashsValue = 2 -- defines total number of slash sound variations
			local SlashName = "Dmg" ..self.CurrentAttackIndex -- constructs slash sound name like "Dmg1", "Dmg2"
			local Song = SlashsSongs:FindFirstChild(SlashName) -- finds the specific slash sound
			if Song then -- checks if sound was found
				Song:Play() -- plays the slash impact sound
			end
			
			self.CurrentAttackIndex += 1 -- increments sound index for variation
			if self.CurrentAttackIndex > SlashsValue then -- checks if index exceeded max sounds
				self.CurrentAttackIndex = 1 -- resets sound index to first variation
			end
			
		else -- if attack missed (didn't hit anything)
			local Swings = Songs:WaitForChild('Swings') -- gets the Swings sound folder for whoosh sounds
			local SwingName = "Swing" ..self.CurrentAttackIndex -- constructs swing sound name
			local Song = Swings:FindFirstChild(SwingName) -- finds the specific swing sound
			if Song then -- checks if sound was found
				Song:Play() -- plays the swing whoosh sound
				Song.Volume = 2 -- sets volume to 2 for audibility
			end
		end
	end)

	task.delay(0.5, function() -- delays execution by 0.5 seconds
		self.IsAttacking = false -- sets attacking flag to false to end hit detection window
	end)

	task.delay(self.AttackCooldown, function() -- delays by attack cooldown duration (1 second)
		self.CanAttack = true -- allows attacking again after cooldown
	end)

	print("Espada atacou!") -- prints "Sword attacked!" in Portuguese for debugging
end


if RunService:IsServer() then -- checks if code is running on the server side
	DefenseRemote.OnServerEvent:Connect(function(player, state) -- connects to defense remote event from client
		if player.Character then -- checks if player has a character
			player.Character:SetAttribute('Blocking', state) -- sets the Blocking attribute to track defense state
		end
	end)

	ParryRemote.OnServerEvent:Connect(function(player, state) -- connects to parry remote event from client
		if player.Character then -- checks if player has a character
			player.Character:SetAttribute('Parrying', state) -- sets the Parrying attribute to track parry state
		end
	end)
end

function Sword:OnHit(hit) -- handles logic when sword touches something
	if not self.IsAttacking then return end -- exits if not currently in attack animation
	if not RunService:IsServer() then return end -- exits if running on client (only server handles damage)

	local character = hit:FindFirstAncestorOfClass("Model") -- finds the character model from the hit part
	if not character then return end -- exits if no character model found

	local humanoid = character:FindFirstChildOfClass("Humanoid") -- finds the Humanoid of the hit character
	if not humanoid or humanoid.Health <= 0 then return end -- exits if no humanoid or already dead

	local playerFromTool = Players:GetPlayerFromCharacter(self.Tool.Parent) -- gets the player wielding the sword
	local isEnemy = playerFromTool and Players:GetPlayerFromCharacter(character) ~= playerFromTool -- checks if hit character is different from attacker

	if isEnemy then -- checks if the hit target is an enemy (not the attacker)
		if humanoid.Health - self.Damage <= 0 then -- checks if damage would kill the enemy
			print('Enemy Died') -- prints death message for debugging
			--PlayerDieEvent:FireServer(character) -- commented out player death event
		end

		if character:GetAttribute('Blocking') == true then -- checks if enemy is blocking
			print('Attacking blocked by', character.Name) -- prints block message with character name
			local Defesa = Songs:WaitForChild('Defesa') -- gets the Defesa (defense) sound folder
			local EspadaTocou = Defesa:FindFirstChild('EspadaTocou') -- finds the sword block sound
			if EspadaTocou then EspadaTocou:Play() end -- plays block sound if it exists

			local fx = Instance.new("Part") -- creates a new Part for visual effect
			fx.Anchored = true -- makes effect stay in place (not affected by physics)
			fx.CanCollide = false -- prevents effect from colliding with other parts
			fx.BrickColor = BrickColor.new("Bright blue") -- sets effect color to bright blue
			fx.Material = Enum.Material.Neon -- sets material to Neon for glowing effect
			fx.Size = Vector3.new(0.3, 0.3, 0.3) -- sets effect size to 0.3x0.3x0.3 studs
			fx.CFrame = hit.CFrame -- positions effect at hit location
			fx.Parent = workspace -- parents effect to workspace to make it visible
			Debris:AddItem(fx, 0.2) -- automatically removes effect after 0.2 seconds

			return -- exits function early since attack was blocked
		end

		if character:GetAttribute("Parrying") == true then -- checks if enemy is parrying (perfect block timing)
			
			print("Successful parry by", character.Name) -- prints parry success message
			self:StunOwner() -- stuns the attacker as punishment for being parried
			return -- exits function early since attack was parried
		end

		print("Hit enemy:", character.Name, 'Damage:', self.Damage) -- prints hit confirmation with damage value
		humanoid:TakeDamage(self.Damage) -- applies damage to the enemy's health
		self.HitSomething = true -- sets flag to true for sound system (slash vs swing)

		local fx = Instance.new("Part") -- creates a new Part for blood/hit effect
		fx.Anchored = true -- makes effect stay in place
		fx.CanCollide = false -- prevents effect from colliding
		fx.BrickColor = BrickColor.Red() -- sets effect color to red for blood
		fx.Material = Enum.Material.Neon -- sets material to Neon for glowing effect
		fx.Size = Vector3.new(0.5, 0.5, 0.5) -- sets effect size to 0.5x0.5x0.5 studs
		fx.CFrame = hit.CFrame -- positions effect at hit location
		fx.Parent = workspace -- parents effect to workspace

		Debris:AddItem(fx, 0.2) -- automatically removes effect after 0.2 seconds
	end
	
	humanoid.HealthChanged:Connect(function(newHealth) -- connects to health change event
		if newHealth <= 30 and not character:GetAttribute('IsDowing') then -- checks if health dropped to 30 or below and not already downed
			character:SetAttribute('IsDowing', true) -- sets IsDowing attribute to prevent retriggering
			
			local Finisher = Animations:WaitForChild('Finisher') -- gets the Finisher animation folder
			local GoDowing = Finisher:WaitForChild('GoDowing') -- gets the animation for falling down
			local IdleDowing = Finisher:WaitForChild('IdleDowing') -- gets the downed idle animation
			
			local track = humanoid:LoadAnimation(GoDowing) -- loads the going down animation
			track:Play() -- plays the falling down animation
			
			track.Stopped:Wait() -- waits for the falling animation to complete
			
			local IdleTrack = humanoid:LoadAnimation(IdleDowing) -- loads the downed idle animation
			IdleTrack:Play() -- plays the downed idle loop
			
			humanoid.WalkSpeed = 0 -- sets walk speed to 0 to prevent movement
			humanoid.JumpPower = 0 -- sets jump power to 0 to prevent jumping
			
			local prompt = Instance.new("ProximityPrompt") -- creates a ProximityPrompt for finisher interaction
			prompt.ActionText = "Finish" -- sets action text displayed on prompt
			prompt.ObjectText = "Press N" -- sets instruction text for the prompt
			prompt.KeyboardKeyCode = Enum.KeyCode.N -- sets keybind to N key
			prompt.RequiresLineOfSight = false -- allows prompt to show through walls
			prompt.MaxActivationDistance = 10 -- sets max distance to 10 studs for activation
			prompt.Parent = character:FindFirstChild("HumanoidRootPart") -- parents prompt to character's root part
			 
			 local promptActivate = true -- flag to track if prompt is still active
			 
			prompt.Triggered:Connect(function(otherPlayer) -- connects to prompt activation event
				PromptCheck:FireClient(otherPlayer) -- notifies client that finisher is starting
				IdleTrack:Stop() -- stops the downed idle animation
				local promptActivate = false -- sets flag to false to prevent timeout kill
				self:ExecuteFinisher(otherPlayer, character) -- executes the finisher move
				prompt:Destroy() -- destroys the prompt after use
			end)
			task.delay(5, function() -- delays execution by 5 seconds for timeout
				if promptActivate and character:GetAttribute('IsDowing') then -- checks if prompt is still active and character still downed
					promptActivate = false -- sets flag to false
					if prompt and prompt.Parent then -- checks if prompt still exists
						prompt:Destroy() -- destroys the prompt after timeout
					end
					if humanoid then -- checks if humanoid still exists
						humanoid.Health = 0 -- kills the character if not finished in time
					end
				end
			end)
		end
	end)
end


function Sword:StunOwner() -- stuns the sword owner when parried
	local character = self.Tool.Parent -- gets the character holding the sword
	local humanoid = character and character:FindFirstChild("Humanoid") -- finds the humanoid if character exists
	if humanoid then -- checks if humanoid was found
		print('STUN APPLIED', character.Name) -- prints stun message with character name
		local StunAnim = Animations.Attacks:FindFirstChild('Stun') -- finds the stun animation
		if StunAnim then -- checks if stun animation exists
			local track = humanoid:LoadAnimation(StunAnim) -- loads the stun animation
			track:Play() -- plays the stun animation
		end
		humanoid.WalkSpeed = 0 -- sets walk speed to 0 to freeze movement
		humanoid.JumpPower = 0 -- sets jump power to 0 to prevent jumping
		task.delay(3, function() -- delays execution by 3 seconds for stun duration
			print('Finished stun') -- prints stun end message
			humanoid.WalkSpeed = 16 -- restores default walk speed
			humanoid.JumpPower = 50 -- restores default jump power
		end)
	end
end


function Sword:ExecuteFinisher(executorPlayer, downedCharacter) -- executes the finisher move on downed enemy
	local executorChar = executorPlayer.Character -- gets the character of the player executing finisher
	if not executorChar then return end -- exits if executor has no character

	local executorHumanoid = executorChar:FindFirstChild("Humanoid") -- finds executor's humanoid
	local downedHumanoid = downedCharacter:FindFirstChild("Humanoid") -- finds downed character's humanoid

	if not executorHumanoid or not downedHumanoid then return end -- exits if either humanoid not found

	
	executorHumanoid.WalkSpeed = 0 -- freezes executor's movement during finisher
	executorHumanoid.JumpPower = 0 -- prevents executor from jumping during finisher
	downedHumanoid.WalkSpeed = 0 -- freezes downed character's movement
	downedHumanoid.JumpPower = 0 -- prevents downed character from jumping

	
	local finishFolder = Animations:WaitForChild("FinishAttack") -- gets the FinishAttack animation folder
	local anim1 = finishFolder:FindFirstChild("Finish1Player1") -- finds executor's finisher animation
	local anim2 = finishFolder:FindFirstChild("Finish1Player2") -- finds victim's finisher animation

	local track1 = executorHumanoid:LoadAnimation(anim1) -- loads executor's animation
	local track2 = downedHumanoid:LoadAnimation(anim2) -- loads victim's animation

    local Finishings = Songs:FindFirstChild('Finishings') -- finds the Finishings sound folder
	local Abyssal = Finishings:FindFirstChild('abyssal') -- finds the abyssal finisher sound
	
	local Leviathan = Finishings:FindFirstChild('leviathan') -- finds the leviathan finisher sound (unused)
	track1:Play() -- plays the executor's finisher animation
	if track1:Play() then -- checks if animation started playing (always true)
		Abyssal:Play() -- plays the abyssal finisher sound effect
	end
	
	track2:Play() -- plays the victim's finisher animation
	
	if track2:Play() then -- checks if animation started playing (always true)
		print('Put Song') -- prints debug message
	end

	
	task.delay(2, function() -- delays execution by 2 seconds for finisher duration
		
		downedHumanoid.Health = 0 -- kills the downed character
		executorHumanoid.WalkSpeed = 16 -- restores executor's walk speed to default
		executorHumanoid.JumpPower = 50 -- restores executor's jump power to default
		
		PromptEnd:FireClient(executorPlayer) -- notifies executor's client that finisher ended
	end)
end

return Sword -- returns the Sword class table for module usage
