local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")

local BehaviorTree = require(ServerStorage.BehaviorTrees.EnemyAI)
local EnemyTemplates = require(ReplicatedStorage.Modules.EnemyTemplates)

local Animations = ReplicatedStorage:WaitForChild('Animations')
local Remotes = ReplicatedStorage:FindFirstChild('Remotes')
local Songs = ReplicatedStorage:WaitForChild('Songs')

local PlayerDieEvent = Remotes:FindFirstChild('PlayerDieEvent')
local DefenseRemote = Remotes:FindFirstChild('DefenseRemote')
local ParryRemote = Remotes:FindFirstChild('ParryRemote')
local PromptCheck = Remotes:FindFirstChild('PromptCheck')
local PromptEnd = Remotes:FindFirstChild('PromptEnd')



local Sword = {}
Sword.__index = Sword

function  Sword.new(tool)
	local self = setmetatable({}, Sword)
	self.Tool = tool
	self.AttackCooldown = 1
	self.Damage = 5
	self.CurrentAttackIndex = 1
	self.IsAttacking = false
	self.CanAttack = true
	self.EquippedModel = nil

	self:SetupEvents()

	return self
end

function Sword:SetupEvents()
	if self.Tool.Activated then
		self.Tool.Activated:Connect(function()
			self:Attack()
		end)
	end

	local handle = self.Tool:FindFirstChild("Handle")
	if handle then
		handle.Touched:Connect(function(hit)
			self:OnHit(hit)
		end)
	end

	if self.Tool.Equipped then
		self.Tool.Equipped:Connect(function()
			self:RemoveWeld()
		end)
	end

	if self.Tool.Unequipped then
		self.Tool.Unequipped:Connect(function()
			local character = self.Tool.Parent.Parent.Character 
			if not character then
				print('Not Character Detect!!! Little Donkey')
			end
			self:WeldToCharacter(character)
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


function Sword:WeldToCharacter(character)
	if not Players:GetPlayerFromCharacter(character) then return end

	if self.EquippedModel and self.EquippedModel.Parent == character then
		print('Tool Equipped')
		return
	end

	local torso = character:FindFirstChild("Torso")
	local toolClone = self.Tool.Model and self.Tool.Model:Clone()

	if not toolClone then return end

	toolClone.Parent = character
	local handle = toolClone.PrimaryPart

	if not torso or not handle then return end

	if handle:FindFirstChild("SwordWeld") then
		handle.SwordWeld:Destroy()
	end

	local weld = Instance.new("Weld")
	weld.Name = "SwordWeld"
	weld.Part0 = torso
	weld.Part1 = handle
	weld.C0 = CFrame.new(-1, -1, 0) * CFrame.Angles(0, math.rad(90), math.rad(90))
	weld.Parent = handle

	handle.Anchored = false
	handle.CanCollide = false

	self.EquippedModel = toolClone
end

function Sword:RemoveWeld()
	if not self.EquippedModel then return end

	local handle = self.Tool:FindFirstChild("Handle")
	if handle then
		local weld = handle:FindFirstChild("SwordWeld")
		if weld then
			weld:Destroy()
		end
	end

	self.EquippedModel:Destroy()
	self.EquippedModel = nil
end

function Sword:Attack()
	local character = self.Tool.Parent
	local humanoid = character:FindFirstChild('Humanoid')

	if not self.CanAttack then return end
	self.HitEnemies = {}
	self.HitSomething = false
	self.CanAttack = false
	self.IsAttacking = true

	if humanoid then
		local AnimFolder = ReplicatedStorage:FindFirstChild("Animations").Attacks
		local attackAnims = 4
		local animName = "Att"..self.CurrentAttackIndex
		local animation = AnimFolder:FindFirstChild(animName)

		if animation then
			local track = humanoid:LoadAnimation(animation)
			track:Play()
		end

		self.CurrentAttackIndex += 1
		if self.CurrentAttackIndex > attackAnims then
			self.CurrentAttackIndex = 1
		end
	end

	task.delay(0.4, function()
		if self.HitSomething then
			local SlashsSongs = Songs:WaitForChild('Slashs')
			local SlashsValue = 2
			local SlashName = "Dmg" ..self.CurrentAttackIndex
			local Song = SlashsSongs:FindFirstChild(SlashName)
			if Song then
				Song:Play()
			end
			
			self.CurrentAttackIndex += 1
			if self.CurrentAttackIndex > SlashsValue then
				self.CurrentAttackIndex = 1
			end
			
		else
			local Swings = Songs:WaitForChild('Swings')
			local SwingName = "Swing" ..self.CurrentAttackIndex
			local Song = Swings:FindFirstChild(SwingName)
			if Song then
				Song:Play()
				Song.Volume = 2
			end
		end
	end)

	task.delay(0.5, function()
		self.IsAttacking = false
	end)

	task.delay(self.AttackCooldown, function()
		self.CanAttack = true
	end)

	print("Espada atacou!")
end


if RunService:IsServer() then
	DefenseRemote.OnServerEvent:Connect(function(player, state)
		if player.Character then
			player.Character:SetAttribute('Blocking', state)
		end
	end)

	ParryRemote.OnServerEvent:Connect(function(player, state)
		if player.Character then
			player.Character:SetAttribute('Parrying', state)
		end
	end)
end

function Sword:OnHit(hit)
	if not self.IsAttacking then return end
	if not RunService:IsServer() then return end

	local character = hit:FindFirstAncestorOfClass("Model")
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	local playerFromTool = Players:GetPlayerFromCharacter(self.Tool.Parent)
	local isEnemy = playerFromTool and Players:GetPlayerFromCharacter(character) ~= playerFromTool

	if isEnemy then
		if humanoid.Health - self.Damage <= 0 then
			print('Enemy Died')
			--PlayerDieEvent:FireServer(character)
		end

		if character:GetAttribute('Blocking') == true then
			print('Attacking blocked by', character.Name)
			local Defesa = Songs:WaitForChild('Defesa')
			local EspadaTocou = Defesa:FindFirstChild('EspadaTocou')			
			if EspadaTocou then EspadaTocou:Play() end

			local fx = Instance.new("Part")
			fx.Anchored = true
			fx.CanCollide = false
			fx.BrickColor = BrickColor.new("Bright blue")
			fx.Material = Enum.Material.Neon
			fx.Size = Vector3.new(0.3, 0.3, 0.3)
			fx.CFrame = hit.CFrame
			fx.Parent = workspace
			Debris:AddItem(fx, 0.2)

			return
		end

		if character:GetAttribute("Parrying") == true then
			
			print("Successful parry by", character.Name)
			self:StunOwner()
			return
		end

		print("Hit enemy:", character.Name, 'Damage:', self.Damage)
		humanoid:TakeDamage(self.Damage)
		self.HitSomething = true

		local fx = Instance.new("Part")
		fx.Anchored = true
		fx.CanCollide = false
		fx.BrickColor = BrickColor.Red()
		fx.Material = Enum.Material.Neon
		fx.Size = Vector3.new(0.5, 0.5, 0.5)
		fx.CFrame = hit.CFrame
		fx.Parent = workspace

		Debris:AddItem(fx, 0.2)
	end
	
	humanoid.HealthChanged:Connect(function(newHealth)
		if newHealth <= 30 and not character:GetAttribute('IsDowing') then
			character:SetAttribute('IsDowing', true)
			
			local Finisher = Animations:WaitForChild('Finisher')
			local GoDowing = Finisher:WaitForChild('GoDowing')
			local IdleDowing = Finisher:WaitForChild('IdleDowing')
			
			local track = humanoid:LoadAnimation(GoDowing)
			track:Play()
			
			track.Stopped:Wait()
			
			local IdleTrack = humanoid:LoadAnimation(IdleDowing)
			IdleTrack:Play()
			
			humanoid.WalkSpeed = 0
			humanoid.JumpPower = 0
			
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Finish"
			prompt.ObjectText = "Press N"
			prompt.KeyboardKeyCode = Enum.KeyCode.N
			prompt.RequiresLineOfSight = false
			prompt.MaxActivationDistance = 10
			prompt.Parent = character:FindFirstChild("HumanoidRootPart")
			 
			 local promptActivate = true
			 
			prompt.Triggered:Connect(function(otherPlayer)
				PromptCheck:FireClient(otherPlayer)
				IdleTrack:Stop()
				local promptActivate = false
				self:ExecuteFinisher(otherPlayer, character)
				prompt:Destroy()
			end)
			task.delay(5, function()
				if promptActivate and character:GetAttribute('IsDowing') then
					promptActivate = false
					if prompt and prompt.Parent then
						prompt:Destroy()
					end
					if humanoid then
						humanoid.Health = 0
					end
				end
			end)
		end
	end)
end


function Sword:StunOwner()
	local character = self.Tool.Parent
	local humanoid = character and character:FindFirstChild("Humanoid")
	if humanoid then
		print('STUN APPLIED', character.Name)
		local StunAnim = Animations.Attacks:FindFirstChild('Stun')
		if StunAnim then
			local track = humanoid:LoadAnimation(StunAnim)
			track:Play()
		end
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		task.delay(3, function()
			print('Finished stun')
			humanoid.WalkSpeed = 16
			humanoid.JumpPower = 50
		end)
	end
end


function Sword:ExecuteFinisher(executorPlayer, downedCharacter)
	local executorChar = executorPlayer.Character
	if not executorChar then return end

	local executorHumanoid = executorChar:FindFirstChild("Humanoid")
	local downedHumanoid = downedCharacter:FindFirstChild("Humanoid")

	if not executorHumanoid or not downedHumanoid then return end

	
	executorHumanoid.WalkSpeed = 0
	executorHumanoid.JumpPower = 0
	downedHumanoid.WalkSpeed = 0
	downedHumanoid.JumpPower = 0

	
	local finishFolder = Animations:WaitForChild("FinishAttack")
	local anim1 = finishFolder:FindFirstChild("Finish1Player1")
	local anim2 = finishFolder:FindFirstChild("Finish1Player2")

	local track1 = executorHumanoid:LoadAnimation(anim1)
	local track2 = downedHumanoid:LoadAnimation(anim2)

    local Finishings = Songs:FindFirstChild('Finishings')
	local Abyssal = Finishings:FindFirstChild('abyssal')
	
	local Leviathan = Finishings:FindFirstChild('leviathan')
	track1:Play()
	if track1:Play() then
		Abyssal:Play()
	end
	
	track2:Play()
	
	if track2:Play() then
		print('Put Song')
	end

	
	task.delay(2, function()
		
		downedHumanoid.Health = 0
		executorHumanoid.WalkSpeed = 16
		executorHumanoid.JumpPower = 50
		
		PromptEnd:FireClient(executorPlayer)
	end)
end

enemyClass.__index = enemyClass

-- Constructor
function module.new(enemyType: string)
	local self = setmetatable({}, enemyClass)
	local enemyData = EnemyTemplates[enemyType]
	
	-- Unique ID
	self.id = HttpService:GenerateGUID(false)
	
	-- Stats
	self.health = enemyData.health
	self.speed = enemyData.speed
	self.damage = enemyData.damage
	self.attackRange = enemyData.attackRange
	self.sightRange = enemyData.sightRange
	
	-- Other
	self.model = enemyData.model
	self.attackAnimation = enemyData.attackAnimation -- Optional
	self.behaviorTree = BehaviorTree(self.damage, self.attackRange, self.sightRange, self.attackAnimation)

	module.enemies[self.id] = self
	return self
end

-- Spawn method
function enemyClass:spawn(spawnpoint: Vector3)
	-- Clone the model and set position
	local modelClone = self.model:Clone()
	modelClone.PrimaryPart.CFrame = CFrame.new(spawnpoint)
	modelClone.Parent = enemyFolder

	self.model = modelClone
	
	local humanoid = modelClone:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.MaxHealth = self.health
		humanoid.Health = self.health
		humanoid.WalkSpeed = self.speed
		
		humanoid.Died:Connect(function()
			self:die()
		end)
	end
	local Sword1 = enemyFolder.Sword1
	local SwordClone = Sword1:Clone()
	SwordClone.Parent = modelClone
	local SwordManagerIA = SwordManager.new(SwordClone)
	
	-- Start AI loop
	self:runAI()

	return modelClone
end

-- Run AI
function enemyClass:runAI()
	task.spawn(function()
		while self.model and self.model.Parent do
			self.behaviorTree:Tick(self)
			task.wait(0.2)
		end
		self:destroy()
	end)
end

-- Handle death
function enemyClass:die()
	if self.model then
		local model = self.model
		self.model = nil
		
		task.wait(3) -- Prevents the body from instantly disappearing
		
		model:Destroy()
	end
	
	-- Remove from global enemy list
	module.enemies[self.id] = nil
end

-- Cleanup
function enemyClass:destroy()
	self:die()
end

return Sword
