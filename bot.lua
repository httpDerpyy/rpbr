
--// Variables
local http = require("coro-http")
local JSON = require("json")
local discordia = require("discordia")

--// Bot Settings
local client = discordia.Client()
local token = "Hidden in GitHub"

local lastSave = os.time()

--// Settings
local prefix = "-"
local verified_role = "848948428028772352"

--// Links
local getId = "https://api.roblox.com/users/get-by-username?username="
local checkId = "https://api.roblox.com/users/"
local checkDesc = "https://users.roblox.com/v1/users/"

--// Floats
local prompts = {}
local global_data = {}

local palavras = {
    "pão",
    "chocolate",
    "açucar",
    "arroz",
    "comida",
    "adoro",
    "batata",
    "beterraba",
    "doce",
    "banana",
    "cenoura",
    "abacate",
    "pizza",
    "milkshake",
}

--// Load Saved Data
local saved = io.open("./data.txt", "r")
local content_saved = saved:read("a")

global_data = JSON.parse(content_saved)
saved:close()

if global_data == nil then
    global_data = {}
end

print("Verified Users Data Loaded")

--// Functions
function string:split(delimiter)
    local result = { }
    local from  = 1
    local delim_from, delim_to = string.find( self, delimiter, from  )
    while delim_from do
      table.insert( result, string.sub( self, from , delim_from-1 ) )
      from  = delim_to + 1
      delim_from, delim_to = string.find( self, delimiter, from  )
    end
    table.insert( result, string.sub( self, from  ) )
    return result
end

function GerarCodigo()

    local codigo = ""
    for i = 1,5,1 do
        if i == 1 then
            codigo = codigo .. palavras[math.random(1, #palavras)]
        else
            codigo = codigo .. " " .. palavras[math.random(1, #palavras)]
        end
    end

    return codigo

end

--// Script
client:on("reactionAdd", function(reaction, id)

    local message = reaction.message
    if not message.author.bot then
        return
    end

    if id == "857645022325374976" then
        return
    end
    
    if prompts[id] then
    
    local fases = {
        ["Conferir"] = function()
           
            if reaction.emojiName == "✅" then
                
                local codigo = GerarCodigo()
    
                prompts[id].Fase = "Codigo"
                prompts[id].Codigo = codigo
    
                prompts[id].Mensagem:setContent("<@"..id..">\n🔑 Certo, para finalizar sua verificação siga as instruções do GIF abaixo e coloque seu código no seu perfil do Roblox.\n\n**Assim que inserir o código reaja abaixo para confirmar**\n\n**Código:** `"..codigo.."`\n\nhttps://gyazo.com/8410604384f07646ccf69ea4ee6e2c30")
                prompts[id].Mensagem:clearReactions()

                prompts[id].Mensagem:addReaction("✅")
    
            elseif reaction.emojiName == "❌" then
                
                local msg = prompts[id].Mensagem
                msg:setContent("😅 Que pena! Vamos começar novamente? Digite `"..prefix.."verificar`.")
                prompts[id] = nil
    
            end
        end,
        ["Codigo"] = function()

            prompts[id].Mensagem:clearReactions()

            if reaction.emojiName == "✅" then

                local msg = prompts[id].Mensagem
                msg:setContent("⏰ Vamos verificar se o código foi inserido corretamente...")

                coroutine.wrap(function()

                    local res, data = http.request("GET", checkDesc .. prompts[id].Id)
                    local content = JSON.parse(data)

                    if content.description == prompts[id].Codigo then

                        global_data[id] = {
                            Usuario = prompts[id].Usuario,
                            Id = prompts[id].Id,
                            Perfil = string.format("https://www.roblox.com/users/%s/profile", prompts[id].Id)
                        } 

                        msg:setContent("✌️ Você já está registrado!")
                        prompts[id].Member:setNickname(prompts[id].Usuario)
                        prompts[id].Member:addRole(verified_role)
                        prompts[id] = nil
                    else
                        msg:setContent("😅 Pelo visto você colocou o código de forma errada, vamos começar do zero? Digite `"..prefix.."verificar`.")
                        prompts[id] = nil
                    end

                end)()

            end
        end,
    }

    fases[prompts[id].Fase]()

    end

end)


client:on("messageCreate", function(message)

    if lastSave + 300 < os.time() then
        print("Backup")
        lastSave = os.time()
        local toSave = JSON.stringify(global_data)
        local writeSave = io.open("./data.txt", "w+")
        writeSave:write(toSave)
        print(toSave)
        writeSave:close()
    end

    local content = message.content
    local member = message.member

    if member == nil then
	return
    end

    local id = member.user.id

    if prompts[id] and prompts[id].Inicio + 300 < os.time() then
        message:reply("<@"..id..">\n⏰ Seu tempo expirou! Digite `"..prefix.."verificar` para começar novamente.")
	
        prompts[id] = nil
        return
    end

    local args = content:split(" ")

    --// Prompts
    if prompts[id] then

        local types = {
            ["Usuario"] = function()
                
                local nick = args[1]
                local msg = message:reply("💻 Procurando pelo perfil `" .. nick .. "`...")

                coroutine.wrap(function()
                    
                    local res, data = http.request("GET", getId .. nick)
                    local content = JSON.parse(data)

		    if not content then
			msg:setContent("🤔 Este usuário não existe no Roblox.")
			prompts[id] = nil
			return
		    end

                    if content.Username ~= nil then
                       
                        msg:setContent(string.format("💻 Esse daqui é você?\n\n**Usuário:** %s\n**ID:** %s\n**Perfil:** %s", content.Username, content.Id, "https://www.roblox.com/users/"..content.Id.."/profile"))
                        msg:addReaction("✅")
                        msg:addReaction("❌")

                        prompts[id].Fase = "Conferir"
                        prompts[id].Usuario = nick
                        prompts[id].Id = content.Id
                        prompts[id].Mensagem = msg
                        
                    end


                end)()

            end,
        }

        if types[prompts[id].Fase] then
		types[prompts[id].Fase]()
	end

    end

    local startsWith = string.sub(args[1], 1, 1)
    if not startsWith == prefix then
	return
    end

    args[1] = string.sub(args[1], 2)

    local commands = {
        ["verificar"] = function ()
            
            local msg = message:reply("⏰ Checando banco de dados...")
            if global_data[id] then
                msg:setContent("✌️ Você já está registrado!")
                msg:clearReactions()
                member:setNickname(global_data[id].Usuario)
                member:addRole(verified_role)
                return
            end
            
            msg:setContent("🤔 Não encontramos você no nosso sistema, por favor nos **informe seu usuário do Roblox no chat**.")
            prompts[id] = {
                Fase = "Usuario",
                Usuario = "",
                Id = "0",
                Codigo = "",
                Inicio = os.time(),
                Mensagem = "",
                Member = member,
            }

        end,
        ["reverificar"] = function ()

            local msg = message:reply("⏰ Checando banco de dados...")
            if global_data[id] then
                msg:reply("✋ Seus dados foram apagados, digite `"..prefix.."verificar` para mudar seu registro.")
                global_data[id] = nil
            end

        end,
        ["perfil"] = function()

            local msg = message:reply("⏰ Checando banco de dados...")

	    if not message.mentionedUsers[1] then
		msg:setContent("😅 Por favor, mencione o usuário alvo.")
		return
	    end
			
            local target = message.mentionedUsers[1][1]
	    

            if global_data[target] then
                msg:setContent(string.format("✋ Perfil Encontrado\n\n**Usuário:** `%s`\n**Perfil:** %s", global_data[target].Usuario, global_data[target].Perfil))
            else
                msg:setContent("😅 Este usuário não possui um cadastro.")
            end

        end,
        ["forcesavedata"] = function()

            if id ~= "239205804488523777" then
                return
            end

            local msg = message:reply("⏰ Forçando um salvamento...")

            lastSave = os.time()
            local toSave = JSON.stringify(global_data)
            local writeSave = io.open("./data.txt", "w+")
            writeSave:write(toSave)
            writeSave:close()

            msg:setContent("✋ Salvamento forçado foi um sucesso.")

        end,
        ["forceverify"] = function ()

            if id ~= "239205804488523777" then
                return
            end

            local msg = message:reply("⏰ Criando um perfil forçado...")

            local target_id = args[2]
            local target_username = args[3]
            local target_roblox_id = args[4]
            local target_roblox_profile = args[5]

            global_data[target_id] = {
                Usuario = target_username,
                Id = target_roblox_id,
                Perfil = target_roblox_profile,
            }

            msg:setContent("✋ Perfil forçado criado com sucesso.")

        end,
    }

    if commands[args[1]] then
        commands[args[1]]()
    end

end)

--// Initialize
client:run("Bot " .. token)
client:on("ready", function()
    print("Ready")
end)
