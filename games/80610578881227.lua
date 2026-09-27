--// Zombie Island //--

--[[
Notes

Zombies are stored under workspace.Entities.Enemy

]]--

--[[
WeaponHit == RemoteEvent that stores the entityID for what entity got shot, 

local Event = game:GetService("ReplicatedStorage").Assets.Remote.WeaponRemotes.WeaponHit
Event:FireServer(
    {
        hitPosition = Vector3.new(1.6339111328125, 18.8125, -110.49996185303),
        weaponId = "300004",
        entityId = 65530,
        clientAttackId = 42,
        hitType = "entity",
        nearbyEntities = {
            {
                entityId = 65530,
                distance = 4.024838338887,
                position = Vector3.new(2.0625, 14.8125, -110.625)
            }
        }
    }
)
    
]]--