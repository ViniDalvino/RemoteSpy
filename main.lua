if rs then
    rs.exit()
end

local methods, missing_methods = {
    get_metatable = getrawmetatable or debug.getmetatable or false,
    get_context = getthreadcontext or syn_context_get or false,
    set_readonly = setreadonly or false,
    set_context = setthreadcontext or syn_context_set or false,
    new_cclosure = newcclosure or false,
    hook_function = hookfunction or replaceclosure or false,
    check_caller = checkcaller or false,
    is_readonly = isreadonly or false
}, ""

for name, method in pairs(methods) do
    if not method then
        missing_methods = missing_methods .. name .. ', '
    end
end

assert(
    #missing_methods == 0, 
    ("Your exploit is missing: %s"):format(missing_methods:sub(1, -3))
)

local players = game:GetService("Players")
local client = players.LocalPlayer
local player_scripts = client.PlayerScripts

local gmt = getrawmetatable(game)
local nmc = gmt.__namecall

local import = function(asset)
    if type(asset) == "string" then
        return loadstring(readfile("hydroxide/remotespy/" .. asset .. '.lua'))()
    end
end

local hooks = {}
local remotes = {
    RemoteEvent = Instance.new("RemoteEvent").FireServer,
    RemoteFunction = Instance.new("RemoteFunction").InvokeServer,
    BindableEvent = Instance.new("BindableEvent").Fire,
    BindableFunction = Instance.new("BindableFunction").Invoke
}

getgenv().rs = {}
rs.methods = methods
rs.exit = function()
    gmt.__namecall = hooks.namecall

    for class,original_method in pairs(hooks) do
        local method = remotes[class]

        if method then
            methods.hook_function(method, original_method)
        end
    end

    rs.ui.exit()
end

local ui = import("ui")
local remote = import("objects/remote")

rs.ui = ui
rs.remote = remote

local create_log = Instance.new("BindableFunction")
create_log.OnInvoke = ui.create_log

local hook = function(method, env, instance, ...)
    local returns = table.pack(method(instance, ...))
    
    --local script = rawget(env, "script") 
    if (instance ~= create_log and remotes[instance.ClassName]) then
        local old = methods.get_context()
        methods.set_context(6)

        local object = rs.cache[instance] 

        if not object then
            object = remote.new(instance)
            object.log = create_log.Invoke(create_log, instance)
        end

        ui.update(object, {...}, returns)
        methods.set_context(old)
    end
    
    return unpack(returns)
end

for i,v in pairs(remotes) do
    hooks[i] = methods.hook_function(v, function(instance, ...)
        return hook(hooks[i], getfenv(2), instance, ...)
    end)
end

setreadonly(gmt, false)

hooks.namecall = nmc
gmt.__namecall = function(instance, ...)
    return hook(nmc, getfenv(2), instance, ...)
end