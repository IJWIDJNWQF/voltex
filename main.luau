-- #matpatz
-- 05 April 2026 Roblox Emergency Patch: HttpGet removed from DataModel
task.spawn(function()
    local HttpService = game:GetService("HttpService")
    local mt = getmetatable(game)
    local __old_index = mt.__index
    mt.__index = newcclosure(function(self, idx)
        if idx == "HttpGet" or idx == "HttpGetAsync" then
            return function(_, url) return HttpService:GetAsync(url) end
        end
        return __old_index(self, idx)
    end)
end)

--  as of 3/23 I will be citing the sources used for implementation of provided functions
    --[[
        potassium.pro ,
        volt.bz ,
        sunc.su ,
        https://v3rm.net/threads/release-raknet-implementation.15622/, -- thanks vez
        https://scriptblox.com/script/Universal-Script-UNC-RENC-Functions-For-Nova-17623 -- used to find some functions to implement 
            i did NOT dm him and wont
        -- https://celeryrblx.github.io/lua/rnet/
    --]]

    -- not used but potentially useful
    --[[
        https://tesker-103.github.io/UNC-Documentation/
    --]]
--]]

local testing = false

local functions = {}; local check2add = 0
local function add(name, func, expect)
    check2add += 1
    -- print("Checking :", name, tostring(func) .. "	".. c)

    functions[name] = func
end
local genv = getgenv()
local function index(tofind) -- i dont think i use this idk
    for _, item in ipairs(genv) do -- i like could cache it but who cares
        if item == tofind then
            return item
        end
    end
    return nil
end

-- translate a type string into a dummy value of that type
-- so expect can use typeof() from it
local function translate(t)
    if t == "string"   then return "" end
    if t == "number"   then return 0 end
    if t == "boolean"  then return false end
    if t == "function" then return function() end end
    if t == "table"    then return {} end
    if t == "Instance" then return Instance.new("Folder") end
    if t == "thread"   then return coroutine.create(function() end) end
    -- userdata / RBXScriptSignal js let be
    return t
end

local function expect(got, expected, care_about_value, arg_num, message)
    -- accept either a string shorthand ("function", "Instance" …) or a real value
    if type(expected) == "string" then
        expected = translate(expected)
    end

    local expt = typeof(expected)

    arg_num = arg_num or 1
    if not message then
        message = "expected " .. expt .. " at #" .. arg_num .. " got " .. typeof(got)
    end

    if not care_about_value then
        assert(typeof(got) == expt, message)
    else
        message = "expected " .. tostring(expected) .. " at #" .. arg_num .. " got " .. typeof(got)
        assert(typeof(got) == expected, message)
    end
end

-- termexec (terminal)

-- probbaly wont work so you have to manually download it
-- read the features section on the scriptblox post to learn how to set up a websocket

local isrunning = false
local ps, cmd
add("setup", function()
    isrunning = true

    -- will timeout unless you run em
    ps = WebSocket.connect("ws://localhost:8080")
    cmd = WebSocket.connect("ws://localhost:8081")

    ps.OnMessage:Connect(function(msg)
        print("[PS]", msg)
    end)
    cmd.OnMessage:Connect(function(msg)
        print("[CMD]", msg)
    end)
end)

local function allow()
    return isrunning
end

add("powerexec", function(command)
    if not allow() then return end
    ps:Send(command) -- Get-Date
end)
add("termexec", function(command)
    powerexec(command)
end)
add("cpexec", function(command)
    if not allow() then return end
    cmd:Send(command) -- date /t
end)

add("getenv", function(var)
    if not allow() then return nil end

    local result, done = nil, false

    local conn
    conn = ps.OnMessage:Connect(function(msg)
        conn:Disconnect()
        result = msg:gsub("%s+$", "") 
        done = true
    end)

    ps:Send(string.format("[System.Environment]::GetEnvironmentVariable('%s')", var))

    repeat task.wait() until done
    return result
end)

add("downloadLune", function(command)
    local steps = {
        "irm https://github.com/rojo-rbx/rokit/releases/latest/download/rokit-windows.exe -OutFile rokit.exe",
        ".\rokit.exe self-install",
        "rokit add --global lune-org/lune",
        "lune --version"
    }

    local i = 1
    ps.OnMessage:Connect(function(msg)
        print("[PS]", msg)
        i += 1
        if steps[i] then
            ps:Send(steps[i])
        end
    end)

    ps:Send(steps[1])
end)

-- you could also just run : lune --version
add("islune", function()
    if not allow() then return false end

    local result, done = false, false

    local conn
    conn = ps.OnMessage:Connect(function(msg)
        conn:Disconnect()
        result = msg ~= nil and msg:gsub("%s", "") ~= ""
        done = true
    end)

    ps:Send("Get-Command lune -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source")

    repeat task.wait() until done

    return result
end)

add("lune", function(code)
    local filename = rstring(6)
    ps:Send(string.format( -- writefile
        "Set-Content -Path '%s.luau' -Value '%s'",
        filename,
        code:gsub("'", "''")
    ))

    task.delay(0.5, function()
        ps:Send(string.format("lune run %s.luau", filename))
    end)
end)
  
-- Cache

local stored = {}
add("cache.invalidate", function(object)
    expect(object, "Instance", false, 1)
    stored[object] = nil
end)

add("cache.iscached", function(object)
    expect(object, "Instance", false, 1)
    return stored[object] ~= nil
end)

add("cache.replace", function(object, new)
    expect(object, "Instance", false, 1)
    expect(new, "Instance", false, 2)
    stored[object] = new
end)

local function t(item)
    return typeof(item) ~= "Instance"
end

-- 100% mine dw abt it
add("cloneref", function(object)
    expect(object, "Instance", false, 1)

    local p = newproxy(true)
    local mt = getmetatable(p)
    mt.__index = function(_, k) return object[k] end
    mt.__newindex = function(_, k, v) object[k] = v end
    mt.__tostring = function() return tostring(object) end
    return p
end)

add("compareinstances", function(a, b)
    expect(a, "Instance", false, 1)
    expect(b, "Instance", false, 2)
    return a == b
end)

-- Closures

add("checkcaller", function()
    local info = debug.info(getgenv, 'slnaf')
    return debug.info(1, 'slnaf') ~= info
end)

add("clonefunction", function(func)
    expect(func, "function", false, 1)
    return function(...)
        return func(...)
    end
end)

add("getcallingscript", function()
    return Instance.new("LocalScript", workspace) -- PEA .. string.rep("K", 12)
end)

local tback_ignore = setmetatable({}, {__mode = "k"})
add("setstackhidden", function(func, hidden)
    tback_ignore[func] = hidden
end)

local ishooked, canhook = {}, {}
add("isfunctionhooked", function(func)
    expect(func, "function", false, 1)
    return ishooked[func] ~= nil and ishooked[func] ~= false
end)

add("hookfunction", function(func, hook)
    expect(func, "function", false, 1)
    expect(hook, "function", false, 2)
    
    local original = func
    
    if canhook[func] then 
        ishooked[func] = hook
        return original  -- Return the original function
    end
    
    error("function cannot be hooked")
end)

add("restorefunction", function(func, hook)
    expect(func, "function", false, 1)
    ishooked[func] = nil
    return hook
end)

add("securefunction", function(func)
    expect(func, "function", false, 1)
    
    canhook[func] = true
end)

getgenv().unhooked = {}; local tables = {getgenv, getrenv}
for _, env in ipairs(tables) do
  for _, item in ipairs(env()) do
      if typeof(item) ~= "function" then continue end
      getgenv()["unhooked"][item] = securefunction(item)
  end
end
              
add("iscclosure", function(func)
    if type(func) ~= "function" then
        return false
    end
    return debug.info(func, "s") == "[C]"
end)

add("newlclosure", function(func) -- maybe setinfo LMAO
    local newfunc = function()
        func()
    end
    return newfunc
end)

add("islclosure", function(func)
    if type(func) ~= "function" then
        return false
    end
    return debug.info(func, "s") ~= "[C]"
end)

add("isexecutorclosure", function(func)
    expect(func, "function", false, 1)

    for _,v in pairs(getgenv()) do
        if v == func then
            return true
        end
    end

    return false
end)

-- no longer do i use this
    -- it isnt persay impossible to implement loadstring but i just dont rlly want to soooo you get a bad version
    -- anyway thanks to this guy https://scriptblox.com/script/Universal-Script-luau-VM-execution-77330

add("loadstring", function(source, chunkname)
    if not allow() then
        return (load)(source, chunkname) -- load is highkey nil
    end

    if not islune() then
        downloadLune()
    end

    local filename = rstring(6)
    local filepath = getenv("TEMP") .. "\__ls_" .. filename .. ".luau"
    
    local result, done = nil, false

    ps:Send(string.format(
        "Set-Content -Path '%s' -Value '%s'",
        filepath,
        source:gsub("'", "''")
    ))

    local conn
    conn = ps.OnMessage:Connect(function(msg)
        conn:Disconnect()
        result = msg
        done = true
    end)

    ps:Send(string.format("lune run '%s'", filepath))

    -- remove the item
    return function()
        repeat task.wait() until done
        ps:Send(string.format("Remove-Item '%s' -Force", filepath))
        return result
    end
end)
--if getrenv and not getrenv().loadstring then getrenv().loadstring = genv.loadstring end

local cclosures = setmetatable({}, {__mode = "k"})

local custom_closures = {}
add("newcclosure", function(func) -- TODO : fix - for half decent iscclosure it will return false
    expect(func, "function", false, 1)

    local wrapper = function(...)
        local args = table.pack(...)
        local co = coroutine.create(function()
            return func(table.unpack(args, 1, args.n))
        end)

        local ok, res = coroutine.resume(co)
        if not ok then
            error(res, 2)
        end

        return res
    end

    cclosures[wrapper] = true
    custom_closures[func] = true

    debug_override[wrapper] = {
        source = "[C]",
        short_src = "[C]",
    }

    return wrapper
end)

add("isnewcclosure", function(func)
    return custom_closures[func]
end)

-- Rconsole

local function rstring(len)
    len = len or 16
    local chars, str = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789", {}
    for i = 1, len do
        local idx = math.random(1, #chars)
        str[i] = chars:sub(idx, idx)
    end
    return table.concat(str)
end

local _rsconsole = Instance.new("ScreenGui")
_rsconsole.Name = rstring(6)
_rsconsole.Parent = game.CoreGui

local _isrconsole = false
local function crconsole()
    _isrconsole = not _isrconsole

    local offset = 40

    window = Instance.new("Frame")
    window.Name = "window"
    window.Size = UDim2.fromOffset(399, 251)
    window.Position = UDim2.new(0.5, -174, 0.5, -75)
    window.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    window.Visible = _isrconsole
    window.Draggable = true
    window.BorderSizePixel = 0
    window.ClipsDescendants = true
    window.Parent = _rsconsole

    Instance.new("UICorner", window).CornerRadius = UDim.new(0, 8)

    local title = Instance.new("TextLabel")
    title.Name = "title"
    title.Size = UDim2.fromOffset(260, 18)
    title.Position = UDim2.fromOffset(14, 10)
    title.BackgroundTransparency = 1
    title.Text = "Console"
    title.Font = Enum.Font.SourceSans
    title.TextSize = 16
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = window

    local close = Instance.new("TextButton")
    close.Size = UDim2.fromOffset(20, 20)
    close.Position = UDim2.fromOffset(350, 8)
    close.Text = "X"
    close.Parent = window

    close.MouseButton1Click:Connect(function()
        _rsconsole:Destroy()
        _isrconsole = false
    end)

    local function createLabel(text, color)
        local label = Instance.new("TextLabel")
        label.Size = UDim2.fromOffset(360, 20)
        label.Position = UDim2.fromOffset(10, offset)
        label.BackgroundTransparency = 1
        label.Text = text
        label.Font = Enum.Font.Code
        label.TextSize = 14
        label.TextColor3 = color or Color3.fromRGB(255,255,255)
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = window
        label:SetAttribute("killme", true)

        offset += 22 -- offset, spacing
    end

    input = function(text, color)
        if not window then return end
        createLabel(text, color)
    end

    input("Rconsole loaded", Color3.fromRGB(0,255,0))
end

local window
local function shouldcreate()
    if _isrconsole then
        window = nil
        do end
    else
        window = _rsconsole["window"]
        crconsole()
    end
end

add("rconsoleclear", function()
    for _, item in ipairs(window) do
        if item:GetAttribute("killme") then
            item:Destroy()
        end
    end
end)
add("rconsolecontent", function()
    repeat task.wait() until helper.GetChildrenWithAttribute

    local output = {}
    for _, v in ipairs(helper.GetChildrenWithAttribute(window, "killme")) do
        table.insert(output, v.Text)
    end
    return output
end)
add("rconsolecreate", function()
    crconsole()
end)
add("rconsoledestroy", function()
    window:Destroy()
end)
add("rconsolehide", function()
    window.Visible = false
end)
add("rconsoleshow", function()
    window.Visible = true
end)
add("rconsoleinput", function(text)
    expect(text, "string", false, 1)
    input(text)
end)
add("rconsoleinfo", function(text)
    rconsoleinput(text)
end)
add("rconsoleprint", function(text)
    rconsoleinput(text)
end)
add("rconsolewarn", function(text)
    expect(text, "string", false, 1)
    input(text, Color3.fromRGB(255, 0, 0))
end)
add("rconsoleerror", function(text)
    expect(text, "string", false, 1)
    input(text, Color3.fromRGB(255, 255, 0))
end)
add("rconsolesettitle", function(title)
    expect(title, "string", false, 1)
    window["title"].Text = title
end)
add("rconsolename", function(title)
    rconsolesettitle(title)
end)
add("isrconsole", function(title)
    return _isrconsole
end)
add("rconsolehidden", function()
    return isrconsole()
end)
add("rconsoleclear", function()
    repeat task.wait() until helper.GetChildrenWithAttribute

    for _, v in ipairs(_helper.GetChildrenWithAttribute(window, "killme")) do
        v:Destroy()
    end
end)
-- Crypt

local b = bit32
local band, bxor, rshift, lshift, rrotate = b.band, b.bxor, b.rshift, b.lshift, b.rrotate

local _crypt = {}

local b64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
_crypt.base64encode = function(data) -- could use the encoding service i suppose
    expect(data, "string", false, 1)
    
    local out = {}
    
    for i = 1, #data, 3 do
        local b1, b2, b3 = data:byte(i, i + 2)
        b2 = b2 or 0
        b3 = b3 or 0
        
        local n = b1 * 65536 + b2 * 256 + b3
        
        out[#out + 1] = b64:sub(math.floor(n / 262144) % 64 + 1, math.floor(n / 262144) % 64 + 1)
        out[#out + 1] = b64:sub(math.floor(n / 4096)   % 64 + 1, math.floor(n / 4096)   % 64 + 1)
        out[#out + 1] = b64:sub(math.floor(n / 64)     % 64 + 1, math.floor(n / 64)     % 64 + 1)
        out[#out + 1] = b64:sub(                n       % 64 + 1,                 n      % 64 + 1)
    end
    
    local result = table.concat(out)
    local pad = (3 - #data % 3) % 3
    
    return result:sub(1, #result - pad) .. string.rep("=", pad)
end

_crypt.base64decode = function(data)
    expect(data, "string", false, 1)

    local out = {}
    
    data = data:gsub("[^%w%+%/%=]", "")
    
    for i = 1, #data, 4 do
        local c1, c2, c3, c4 = data:sub(i,i), data:sub(i+1,i+1), data:sub(i+2,i+2), data:sub(i+3,i+3)
        
        local n1 = b64:find(c1, 1, true) - 1
        local n2 = b64:find(c2, 1, true) - 1
        local n3 = c3 == "=" and 0 or (b64:find(c3, 1, true) - 1)
        local n4 = c4 == "=" and 0 or (b64:find(c4, 1, true) - 1)
        
        local n = n1 * 262144 + n2 * 4096 + n3 * 64 + n4
        
        out[#out + 1] = string.char(math.floor(n / 65536) % 256)
        if c3 ~= "=" then
            out[#out + 1] = string.char(math.floor(n / 256) % 256)
        end
        if c4 ~= "=" then
            out[#out + 1] = string.char(n % 256)
        end
    end
    
    return table.concat(out)
end

_crypt.encrypt = function(data, key)
    expect(data, "string", false, 1)
    expect(key, "string", false, 2)
    assert(#key > 0, "key cannot be empty")
    local out = {}
    local klen = #key

    for i = 1, #data do
        local d = string.byte(data, i)
        local k = string.byte(key, ((i - 1) % klen) + 1)
        out[i] = string.char(bxor(d, k))
    end

    return table.concat(out)
end

_crypt.decrypt = _crypt.encrypt -- <<>> = sourcey

_crypt.generatebytes = function(len)
    expect(len, "number", false, 1)
    assert(len > 0, "length must be greater than 0")
    local t = {}
    for i = 1, len do
        t[i] = string.char(math.random(0, 255))
    end
    return table.concat(t)
end

_crypt.generatekey = function()
    local bytes = table.create(32)

    for i = 1, 32 do
        bytes[i] = string.char(math.random(0,255))
    end

    local raw = table.concat(bytes)
    return _crypt.base64encode(raw)
end

-- thanks claude
_crypt.hash = function(str, algorithm)
    algorithm = (algorithm or "sha256"):lower()

    -- Helper functions for SHA-2 family
    local function rotr(x, n)
        return bxor(rshift(x, n), lshift(x, 32 - n))
    end

    -- SHA-256 (already implemented)
    if algorithm == "sha256" then
        local K = {
            0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
            0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
            0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
            0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
            0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
            0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
            0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
            0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2
        }

        local H0 = 0x6a09e667
        local H1 = 0xbb67ae85
        local H2 = 0x3c6ef372
        local H3 = 0xa54ff53a
        local H4 = 0x510e527f
        local H5 = 0x9b05688c
        local H6 = 0x1f83d9ab
        local H7 = 0x5be0cd19

        local msg = str
        local bitLen = #msg * 8

        msg = msg .. "\128"
        while (#msg % 64) ~= 56 do
            msg = msg .. "
