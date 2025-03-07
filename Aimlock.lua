local p = game.Players.LocalPlayer
local m = p:GetMouse()
local aimEnabled = false
local targetPlayer = nil
local fovRadius = 150
local aimSmoothness = 0.15  -- Quicker but subtle transitions
local maxDist = 800
local shakeAmount = 0.05  -- Slight shake to simulate human error
local reactionTime = 0.05  -- Human-like reaction time
local lastReactionTime = 0  -- Time of last aim lock reaction
local deadzoneRadius = 5  -- Smaller deadzone for more aggressive targeting
local leadPredictionFactor = 0.6  -- Aggressive lead prediction
local screenCenter = Vector2.new(m.X, m.Y)  -- Starting position of the mouse

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local camera = game.Workspace.CurrentCamera

-- Function to predict target's movement based on velocity and acceleration
local function predictPosition(character)
    local root = character:FindFirstChild("HumanoidRootPart")
    if root then
        local velocity = root.Velocity
        local acceleration = root.AssemblyLinearVelocity
        return root.Position + velocity * leadPredictionFactor + acceleration * 0.1  -- Adding acceleration
    else
        return character.Head.Position
    end
end

-- Check if the target player is visible to the camera
local function isVisibleToCamera(character)
    local head = character:FindFirstChild("Head")
    if head then
        local screenPos, onScreen = camera:WorldToScreenPoint(head.Position)
        return onScreen  -- Returns true if the player’s head is visible on screen
    end
    return false
end

-- Find the nearest player in the field of view
local function findNearestPlayerInFOV()
    local nearest = nil
    local closestDist = math.huge
    for _, v in pairs(game.Players:GetPlayers()) do
        if v ~= p and v.Character and v.Character:FindFirstChild("Head") then
            if isVisibleToCamera(v.Character) then  -- Only consider players that are visible
                local headPos = v.Character.Head.Position
                local screenPos, visible = camera:WorldToScreenPoint(headPos)
                local dist = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
                if dist <= fovRadius and dist < closestDist and (headPos - camera.CFrame.Position).Magnitude <= maxDist then
                    closestDist = dist
                    nearest = v
                end
            end
        end
    end
    return nearest
end

-- Add a shake effect when locked on (to simulate human-like aiming)
local function shakeAim(targetPos)
    local shakeX = math.random() * shakeAmount - (shakeAmount / 2)
    local shakeY = math.random() * shakeAmount - (shakeAmount / 2)
    return targetPos + Vector3.new(shakeX, shakeY, 0)
end

-- Add random offset to the aim to make it seem less accurate
local function addAimOffset(targetPos)
    local offsetX = math.random() * shakeAmount - (shakeAmount / 2)
    local offsetY = math.random() * shakeAmount - (shakeAmount / 2)
    return targetPos + Vector3.new(offsetX, offsetY, 0)
end

-- Introduce a slight delay to mimic reaction time
local function canAimNow()
    return tick() - lastReactionTime > reactionTime
end

-- Lock the mouse to the target when right-click is held
local function lockOnTarget()
    if targetPlayer and targetPlayer.Character then
        -- Check if the target is alive
        local humanoid = targetPlayer.Character:FindFirstChild("Humanoid")
        if humanoid and humanoid.Health <= 0 then
            -- Target is dead, find a new target
            targetPlayer = findNearestPlayerInFOV()
        end

        -- If the target is alive and the aim can be activated
        if targetPlayer and targetPlayer.Character:FindFirstChild("Head") and canAimNow() then
            local targetPos = predictPosition(targetPlayer.Character)
            targetPos = shakeAim(targetPos)  -- Add shake to the target position
            targetPos = addAimOffset(targetPos)  -- Add random offset to simulate human inaccuracy

            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                -- Check for deadzone, if the target is too close, don’t adjust the aim
                local distToTarget = (targetPos - hrp.Position).Magnitude
                if distToTarget > deadzoneRadius then
                    -- Introduce random flick behavior for human-like aiming
                    local flickSpeed = math.random() * 0.1  -- Random flick speed
                    local direction = (targetPos - hrp.Position).unit
                    local newCFrame = CFrame.new(hrp.Position, hrp.Position + direction * Vector3.new(1, 0, 1))
                    hrp.CFrame = hrp.CFrame:Lerp(newCFrame, aimSmoothness + flickSpeed)

                    -- Update the time of the last reaction to simulate the reaction time delay
                    lastReactionTime = tick()
                end
            end
        end
    end
end

-- Run the aimbot when right-click is held
RunService.RenderStepped:Connect(function()
    if aimEnabled and targetPlayer then
        lockOnTarget()
    end
end)

-- Check if the right mouse button is pressed to activate aim
UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        aimEnabled = true
        targetPlayer = findNearestPlayerInFOV()
    end
end)

-- Deactivate aim when right-click is released
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        aimEnabled = false
        targetPlayer = nil
    end
end)
