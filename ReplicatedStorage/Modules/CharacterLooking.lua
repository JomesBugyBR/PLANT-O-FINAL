local CharacterLooking = {}

function CharacterLooking:isLookingAtAI(character, aiPosition)
    local head = character:FindFirstChild("Head")
    if not head then return false end
    
    local lookDirection = head.CFrame.LookVector
    local directionToAI = (aiPosition - head.Position).unit
    local dotProduct = lookDirection:Dot(directionToAI)
    
    return dotProduct > 0.85 -- Adjust the threshold as needed
end

return CharacterLooking
