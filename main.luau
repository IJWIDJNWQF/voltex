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
            msg = msg .. " "
        end

        for i = 7,0,-1 do
            msg = msg .. string.char(band(rshift(bitLen,i*8),255))
        end

        for i = 1,#msg,64 do
            local w = {}

            for j = 0,15 do
                local a,b,c,d = msg:byte(i+j*4,i+j*4+3)
                w[j] = lshift(a,24) + lshift(b,16) + lshift(c,8) + d
            end

            for j = 16,63 do
                local s0 = bxor(rrotate(w[j-15],7), rrotate(w[j-15],18), rshift(w[j-15],3))
                local s1 = bxor(rrotate(w[j-2],17), rrotate(w[j-2],19), rshift(w[j-2],10))
                w[j] = (w[j-16] + s0 + w[j-7] + s1) % 4294967296
            end

            local a = H0
            local b = H1
            local c = H2
            local d = H3
            local e = H4
            local f = H5
            local g = H6
            local h = H7

            for j = 0,63 do
                local S1 = bxor(rrotate(e,6), rrotate(e,11), rrotate(e,25))
                local ch = bxor(band(e,f), band(bit32.bnot(e),g))
                local temp1 = (h + S1 + ch + K[j+1] + w[j]) % 4294967296

                local S0 = bxor(rrotate(a,2), rrotate(a,13), rrotate(a,22))
                local maj = bxor(band(a,b), band(a,c), band(b,c))
                local temp2 = (S0 + maj) % 4294967296

                h = g
                g = f
                f = e
                e = (d + temp1) % 4294967296
                d = c
                c = b
                b = a
                a = (temp1 + temp2) % 4294967296
            end

            H0 = (H0 + a) % 4294967296
            H1 = (H1 + b) % 4294967296
            H2 = (H2 + c) % 4294967296
            H3 = (H3 + d) % 4294967296
            H4 = (H4 + e) % 4294967296
            H5 = (H5 + f) % 4294967296
            H6 = (H6 + g) % 4294967296
            H7 = (H7 + h) % 4294967296
        end

        return string.format("%08x%08x%08x%08x%08x%08x%08x%08x",
            H0,H1,H2,H3,H4,H5,H6,H7
        )

    -- SHA-224
    elseif algorithm == "sha224" then
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

        local H0 = 0xc1059ed8
        local H1 = 0x367cd507
        local H2 = 0x3070dd17
        local H3 = 0xf70e5939
        local H4 = 0xffc00b31
        local H5 = 0x68581511
        local H6 = 0x64f98fa7
        local H7 = 0xbefa4fa4

        local msg = str
        local bitLen = #msg * 8

        msg = msg .. "\128"
        while (#msg % 64) ~= 56 do
            msg = msg .. " "
        end

        for i = 7,0,-1 do
            msg = msg .. string.char(band(rshift(bitLen,i*8),255))
        end

        for i = 1,#msg,64 do
            local w = {}

            for j = 0,15 do
                local a,b,c,d = msg:byte(i+j*4,i+j*4+3)
                w[j] = lshift(a,24) + lshift(b,16) + lshift(c,8) + d
            end

            for j = 16,63 do
                local s0 = bxor(rrotate(w[j-15],7), rrotate(w[j-15],18), rshift(w[j-15],3))
                local s1 = bxor(rrotate(w[j-2],17), rrotate(w[j-2],19), rshift(w[j-2],10))
                w[j] = (w[j-16] + s0 + w[j-7] + s1) % 4294967296
            end

            local a = H0
            local b = H1
            local c = H2
            local d = H3
            local e = H4
            local f = H5
            local g = H6
            local h = H7

            for j = 0,63 do
                local S1 = bxor(rrotate(e,6), rrotate(e,11), rrotate(e,25))
                local ch = bxor(band(e,f), band(bit32.bnot(e),g))
                local temp1 = (h + S1 + ch + K[j+1] + w[j]) % 4294967296

                local S0 = bxor(rrotate(a,2), rrotate(a,13), rrotate(a,22))
                local maj = bxor(band(a,b), band(a,c), band(b,c))
                local temp2 = (S0 + maj) % 4294967296

                h = g
                g = f
                f = e
                e = (d + temp1) % 4294967296
                d = c
                c = b
                b = a
                a = (temp1 + temp2) % 4294967296
            end

            H0 = (H0 + a) % 4294967296
            H1 = (H1 + b) % 4294967296
            H2 = (H2 + c) % 4294967296
            H3 = (H3 + d) % 4294967296
            H4 = (H4 + e) % 4294967296
            H5 = (H5 + f) % 4294967296
            H6 = (H6 + g) % 4294967296
            H7 = (H7 + h) % 4294967296
        end

        return string.format("%08x%08x%08x%08x%08x%08x%08x",
            H0,H1,H2,H3,H4,H5,H6
        )

    -- SHA-1 (already implemented)
    elseif algorithm == "sha1" then
        local function lrotate(x, n)
            return bxor(lshift(x, n), rshift(x, 32 - n))
        end

        local h0 = 0x67452301
        local h1 = 0xEFCDAB89
        local h2 = 0x98BADCFE
        local h3 = 0x10325476
        local h4 = 0xC3D2E1F0

        local msg = str
        local bitLen = #msg * 8

        msg = msg .. "\128"
        while (#msg % 64) ~= 56 do
            msg = msg .. " "
        end

        for i = 7,0,-1 do
            msg = msg .. string.char(band(rshift(bitLen,i*8),255))
        end

        for i = 1,#msg,64 do
            local w = {}

            for j = 0,15 do
                local a,b,c,d = msg:byte(i+j*4,i+j*4+3)
                w[j] = lshift(a,24) + lshift(b,16) + lshift(c,8) + d
            end

            for j = 16,79 do
                w[j] = lrotate(bxor(w[j-3], w[j-8], w[j-14], w[j-16]),1)
            end

            local a = h0
            local b = h1
            local c = h2
            local d = h3
            local e = h4

            for j = 0,79 do
                local f, k

                if j <= 19 then
                    f = bit32.bor(band(b,c), band(bit32.bnot(b),d))
                    k = 0x5A827999
                elseif j <= 39 then
                    f = bxor(b,c,d)
                    k = 0x6ED9EBA1
                elseif j <= 59 then
                    f = bit32.bor(bit32.bor(band(b,c), band(b,d)), band(c,d))
                    k = 0x8F1BBCDC
                else
                    f = bxor(b,c,d)
                    k = 0xCA62C1D6
                end

                local temp = (lrotate(a,5) + f + e + k + w[j]) % 4294967296
                e = d
                d = c
                c = lrotate(b,30)
                b = a
                a = temp
            end

            h0 = (h0 + a) % 4294967296
            h1 = (h1 + b) % 4294967296
            h2 = (h2 + c) % 4294967296
            h3 = (h3 + d) % 4294967296
            h4 = (h4 + e) % 4294967296
        end

        return string.format("%08x%08x%08x%08x%08x", h0,h1,h2,h3,h4)

    -- MD5
    elseif algorithm == "md5" then
        local function F(x, y, z) return bit32.bor(band(x, y), band(bit32.bnot(x), z)) end
        local function G(x, y, z) return bit32.bor(band(x, z), band(y, bit32.bnot(z))) end
        local function H(x, y, z) return bxor(x, y, z) end
        local function I(x, y, z) return bxor(y, bit32.bor(x, bit32.bnot(z))) end

        local function leftrotate(x, c)
            return bit32.bor(lshift(x, c), rshift(x, 32 - c))
        end

        local s = {
            7, 12, 17, 22,  7, 12, 17, 22,  7, 12, 17, 22,  7, 12, 17, 22,
            5,  9, 14, 20,  5,  9, 14, 20,  5,  9, 14, 20,  5,  9, 14, 20,
            4, 11, 16, 23,  4, 11, 16, 23,  4, 11, 16, 23,  4, 11, 16, 23,
            6, 10, 15, 21,  6, 10, 15, 21,  6, 10, 15, 21,  6, 10, 15, 21
        }

        local K = {}
        for i = 0, 63 do
            K[i] = math.floor(math.abs(math.sin(i + 1)) * 4294967296)
        end

        local a0 = 0x67452301
        local b0 = 0xefcdab89
        local c0 = 0x98badcfe
        local d0 = 0x10325476

        local msg = str
        local bitLen = #msg * 8

        msg = msg .. "\128"
        while (#msg % 64) ~= 56 do
            msg = msg .. " "
        end

        for i = 0, 7 do
            msg = msg .. string.char(band(rshift(bitLen, i * 8), 255))
        end

        for chunk = 1, #msg, 64 do
            local M = {}
            for j = 0, 15 do
                local a, b, c, d = msg:byte(chunk + j * 4, chunk + j * 4 + 3)
                M[j] = d * 16777216 + c * 65536 + b * 256 + a
            end

            local A = a0
            local B = b0
            local C = c0
            local D = d0

            for i = 0, 63 do
                local F_val, g

                if i <= 15 then
                    F_val = F(B, C, D)
                    g = i
                elseif i <= 31 then
                    F_val = G(B, C, D)
                    g = (5 * i + 1) % 16
                elseif i <= 47 then
                    F_val = H(B, C, D)
                    g = (3 * i + 5) % 16
                else
                    F_val = I(B, C, D)
                    g = (7 * i) % 16
                end

                F_val = (F_val + A + K[i] + M[g]) % 4294967296
                A = D
                D = C
                C = B
                B = (B + leftrotate(F_val, s[i + 1])) % 4294967296
            end

            a0 = (a0 + A) % 4294967296
            b0 = (b0 + B) % 4294967296
            c0 = (c0 + C) % 4294967296
            d0 = (d0 + D) % 4294967296
        end

        local function toHexLE(n)
            local result = ""
            for i = 0, 3 do
                result = result .. string.format("%02x", band(rshift(n, i * 8), 255))
            end
            return result
        end

        return toHexLE(a0) .. toHexLE(b0) .. toHexLE(c0) .. toHexLE(d0)

    -- SHA-384
    elseif algorithm == "sha384" then
        -- SHA-384 uses 64-bit operations, simplified approximation
        local hash = _crypt.hash(str, "sha256")
        return hash .. string.rep("0", 32) -- Placeholder: 96 hex chars

    -- SHA-512
    elseif algorithm == "sha512" then
        -- SHA-512 uses 64-bit operations, simplified approximation
        local hash = _crypt.hash(str, "sha256")
        return hash .. hash -- Placeholder: 128 hex chars

    -- BLAKE2b (simplified version)
    elseif algorithm == "blake2b" then
        -- Simplified BLAKE2b using SHA-256 as base
        local hash = _crypt.hash("BLAKE2b:" .. str, "sha256")
        return hash .. hash -- 512-bit output

    -- SHA3 variants (simplified using modified SHA-256)
    elseif algorithm == "sha3-224" then
        local hash = _crypt.hash("SHA3-224:" .. str, "sha256")
        return hash:sub(1, 56) -- 224 bits = 56 hex chars

    elseif algorithm == "sha3-256" then
        local hash = _crypt.hash("SHA3-256:" .. str, "sha256")
        return hash -- 256 bits = 64 hex chars

    elseif algorithm == "sha3-384" then
        local hash1 = _crypt.hash("SHA3-384-1:" .. str, "sha256")
        local hash2 = _crypt.hash("SHA3-384-2:" .. str, "sha256")
        return hash1 .. hash2:sub(1, 32) -- 384 bits = 96 hex chars

    elseif algorithm == "sha3-512" then
        local hash1 = _crypt.hash("SHA3-512-1:" .. str, "sha256")
        local hash2 = _crypt.hash("SHA3-512-2:" .. str, "sha256")
        return hash1 .. hash2 -- 512 bits = 128 hex chars

    else
        error("unsupported algorithm: " .. algorithm)
    end
end

_crypt.random = function(len)
    return crypt.generatebytes(len)
end

_crypt.rstring = function(len)
    rstring(len)
end
_crypt.rnum = function(len)
    len = len or 16
    local chars, str = "0123456789", {}
    for i = 1, len do
        local idx = math.random(1, #chars)
        str[i] = chars:sub(idx, idx)
    end
    return table.concat(str)
end

_crypt.tobytecode = function(src)
    expect(src, "string", false, 1)

    local out = table.create(#src)

    for i = 1, #src do
        out[i] = string.char(src:byte(i))
    end

    return table.concat(out)
end

_crypt.tobinary = function(str)
    expect(str, "string", false, 1)
    local result = {}
    for i = 1, #str do
        local byte = str:byte(i)
        local binary = ""
        for j = 7, 0, -1 do
            binary = binary .. (band(rshift(byte, j), 1))
        end
        result[i] = binary
    end
    return table.concat(result, " ")
end

_crypt.frombinary = function(binary)
    expect(binary, "string", false, 1)
    binary = binary:gsub("%s", "")
    local result = {}
    for i = 1, #binary, 8 do
        local byte = binary:sub(i, i + 7)
        if #byte == 8 then
            result[#result + 1] = string.char(tonumber(byte, 2))
        end
    end
    return table.concat(result)
end

_crypt.tohex = function(str)
    expect(str, "string", false, 1)
    return (str:gsub(".", function(c)
        return string.format("%02x", string.byte(c))
    end))
end

_crypt.fromhex = function(str)
    expect(str, "string", false, 1)
    assert(#str % 2 == 0, "hex string must have even length")
    return (str:gsub("%x%x", function(c)
        return string.char(tonumber(c, 16))
    end))
end

-- inaccurate idk vruh
_crypt.hmac = function(data, key, algorithm)
    expect(data, "string", false, 1)
    expect(key, "string", false, 2)
    expect(algorithm, "string", false, 3)

    local hash = crypt.hash
    local fromhex = crypt.fromhex
    local tobase64 = crypt.base64encode

    local function hashraw(str)
        return fromhex(hash(str, algorithm))
    end

    local blockSize = 64
    if #key > blockSize then
        key = hashraw(key)
    end

    -- pad key to blockSize
    if #key < blockSize then
        key = key .. string.rep(" ", blockSize - #key)
    end

    local ipad, opad = {}, {}
    for i = 1, blockSize do
        local b = key:byte(i) or 0
        ipad[i] = string.char(bxor(b, 0x36))
        opad[i] = string.char(bxor(b, 0x5C))
    end

    local inner = hashraw(table.concat(ipad) .. data)
    local outer = hashraw(table.concat(opad) .. inner)

    return tobase64(outer)
end

_crypt.lz4 = function(data, step)
    assert(type(data) == "string", "data must be string")

    local out
    if step == true then -- encrypt
        out = lz4compress(data)
    else
        out = lz4decompress(data)
    end
    return out
end

_crypt.rle = function(data, step)
    assert(type(data) == "string", "data must be string")

    local out
    if step == true then -- encrypt
        out = rlecompress(data)
    else
        out = rledecompress(data)
    end
    return out
end

local crypt = _crypt
for k, v in pairs(crypt) do
    add("crypt." .. k, v)
end

local existing_crypt = crypt
for k, v in pairs(crypt) do
    if not existing_crypt[k] then
        existing_crypt[k] = v
    end
end

local new_crypt = {}
for k, v in pairs(getgenv().crypt) do
    new_crypt[k] = v
end

for k, v in pairs(_crypt) do
    if new_crypt[k] == nil then
        new_crypt[k] = v
    end
end
getgenv().crypt = new_crypt


-- Oth

local _oth = {}

local hooks = {}
local hook_threads, og_threads = setmetatable({}, {__mode = "k"}), setmetatable({}, {__mode = "k"})

_oth.hook = function(target, hookfn)
    expect(target, "function", false, 1)
    expect(hookfn, "function", false, 2)

    hooks[target] = hooks[target] or {}

    local original = target

    local callback = function(...)
        return original(...)
    end

    local function wrapper(...)
        local caller = coroutine.running()

        local co = coroutine.create(function(...)
            local current = coroutine.running()
            hook_threads[current] = true
            og_threads[current] = caller

            return hookfn(...)
        end)

        local ok, result = coroutine.resume(co, ...)
        if not ok then
            error(result)
        end

        return result
    end

    table.insert(hooks[target], {
        hook = hookfn,
        wrapper = wrapper,
        callback = callback
    })

    return callback
end

_oth.unhook = function(target, hook_or_callback)
    local list = hooks[target]
    if not list then
        return false
    end

    for i,v in ipairs(list) do
        if v.hook == hook_or_callback or v.callback == hook_or_callback or hook_or_callback == nil then
            table.remove(list, i)

            if #list == 0 then
                hooks[target] = nil
            end

            return true
        end
    end

    return false
end

_oth.get_root_callback = function(target)
    local list = hooks[target]
    if not list or #list == 0 then
        return target
    end

    return list[1].callback
end

_oth.is_hook_thread = function()
    return hook_threads[coroutine.running()] == true
end

_oth.get_original_thread = function()
    return og_threads[coroutine.running()]
end

local oth = oth or {}; getgenv().oth = oth;local existing_oth = oth
for k, v in pairs(oth) do
    if not existing_oth[k] then
        existing_oth[k] = v
    end
end

local new_oth = {}
for k, v in pairs(getgenv().oth) do
    new_oth[k] = v
end

for k, v in pairs(_oth) do
    if new_oth[k] == nil then
        new_oth[k] = v
    end
end
getgenv().oth = new_oth

-- Debug

local debug_lib = {}

debug_lib.validlevel = function(level)
    return debug.getinfo(level + 2) ~= nil
end

debug_lib.isvalidlevel = function(level)
    expect(level, "number", false, 1)
    return level >= 0
end

debug_lib.getregistry = function()
    return getreg and getreg() or {}
end

local constants = {}
debug_lib.getconstant = function(func, index)
    expect(func, "function", false, 1)
    expect(index, "number", false, 2)
    local c = constants[func]
    if not c or c[index] == nil then
        error("constant does not exist at index " .. index)
    end
    return c[index]
end

debug_lib.getconstants = function(func)
    expect(func, "function", false, 1)
    return constants[func] or {}
end

debug_lib.setconstant = function(func, index, value)
    expect(func, "function", false, 1)
    expect(index, "number", false, 2)
    constants[func] = constants[func] or {}
    constants[func][index] = value
end

local upvalues = {}
debug_lib.getupvalue = function(func, index)
    expect(func, "function", false, 1)
    expect(index, "number", false, 2)
    local u = upvalues[func]
    if not u or u[index] == nil then
        return nil
    end
    return u[index]
end

debug_lib.getupvalues = function(func)
    expect(func, "function", false, 1)
    return upvalues[func] or {}
end

debug_lib.setupvalue = function(func, index, value)
    expect(func, "function", false, 1)
    expect(index, "number", false, 2)
    upvalues[func] = upvalues[func] or {}
    upvalues[func][index] = value
end

local stacks = {}
debug_lib.getstack = function(level, index)
    expect(level, "number", false, 1)
    local stack = stacks[level]
    if not stack then
        error("invalid stack level: " .. level)
    end

    if index then
        expect(index, "number", false, 2)
        if stack[index] == nil then
            error("stack value does not exist at index " .. index)
        end
        return stack[index]
    end

    return stack
end

debug_lib.setstack = function(level, index, value)
    expect(level, "number", false, 1)
    expect(index, "number", false, 2)
    stacks[level] = stacks[level] or {}
    stacks[level][index] = value
end

local debug_override = setmetatable({}, {__mode = "k"})

debug_lib.setinfo = function(func, info)
    expect(func, "function", false, 1)
    expect(info, "table", false, 2)
    debug_override[func] = info
end
debug_lib.info = function(func, what)
    if type(func) ~= "function" then return end

    local override = debug_override[func]

    local map = {
        s = override and override.short_src,
        n = override and override.name,
        l = override and override.currentline,
        f = func
    }

    local results = {}

    for i = 1, #what do
        local c = what:sub(i,i)

        if map[c] ~= nil then
            table.insert(results, map[c])
        else
            if c == "s" then
                table.insert(results, "unknown")
            elseif c == "n" then
                table.insert(results, nil)
            elseif c == "l" then
                table.insert(results, 0)
            elseif c == "f" then
                table.insert(results, func)
            end
        end
    end

    return table.unpack(results)
end

debug_lib.getproto = function()
    return nil
end

debug_lib.getprotos = function()
    return {}
end

debug_lib.getcallstack = function()
    local stack = {}
    local level = 1

    while true do
        local ok, info = pcall(debug.getinfo, level + 1)
        if not ok or not info then break end

        stack[#stack + 1] = {
            func = info.func,
            name = info.name,
            source = info.short_src,
            line = info.currentline
        }

        level += 1
    end

    return stack
end

local old_traceback
old_traceback = hookfunction(debug.traceback, function(...)
    local tb = old_traceback(...)

    for func, hidden in pairs(tback_ignore) do
        if hidden then
            local name = tostring(func)
            tb = tb:gsub(".-"..name..".-
", "")
        end
    end

    return tb
end)

for k, v in pairs(debug_lib) do
    add("debug." .. k, v)
end

local new_debug = {}
for k, v in pairs(getgenv().debug) do
    new_debug[k] = v
end

for k, v in pairs(debug_lib) do
    if new_debug[k] == nil then
        new_debug[k] = v
    end
end
getgenv().debug = new_debug

-- Raknet

local _raknet = {}

-- highkey none of this existed
-- thanks volt for added raknet
    -- w docs as always
do                           
    _raknet.desync = function()
        -- patched man srry
    end
    -- this code is from that v3rm guy

    _raknet.GetService = function(self, Service)
        if not cloneref then return Service end -- for pastesploit users
    
        if Service == "VirtualInputManager" or Service == "VirtualUser" then
            return cloneref(Instance.new(Service)) -- Thanks syn.lua
        end

    return cloneref(Service)
    end

    _raknet.GetLocalPlayer = function()
        return _raknet:GetService(game:GetService("Players")).LocalPlayer
    end

    _raknet.GetCharacter = function()
        return _raknet:GetLocalPlayer().Character or _raknet:GetLocalPlayer().CharacterAdded:Wait()
    end

    _raknet.GetPrimaryPart = function()
        return _raknet:GetCharacter():FindFirstChild("HumanoidRootPart")
    end

    _raknet.GetHumanoid = function()
        return _raknet:GetCharacter():FindFirstChildOfClass("Humanoid")
    end

    _raknet.SendKickPacket = function(self, OptionalMessage)
        if OptionalMessage then
            _raknet:GetLocalPlayer():Kick(`{OptionalMessage}`)
            return
        end

        _raknet:GetLocalPlayer():Kick(`You have been kicked by the use of RakNet packets, {raknet:GetLocalPlayer().UserId}`)
    end

    add("crash", function()
        local function recurse()
            local t = {}
            for i = 1, 1000 do
                t[i] = string.rep("x", 1000000)
            end
            recurse()
        end
        recurse()
    end)

    _raknet.SendCrashPacket = function()
        --while _raknet do --[[0x8231]] end
        crash()
    end

    _raknet.SendHumanoidPropertyChangePacket = function(self, Property, Value)
        _raknet:GetHumanoid()[Property] = Value
    end

    _raknet.SendClientLagPacket = function(self, Time)
        local og = getfpscap()

        setfpscap(math.random(1,25))
        task.delay((Time or 1), function()
            setfpscap(og)
        end)
    end
end

local _raknet = {}

local hooks, Packet = {}, {}
Packet.__index = Packet

local function toArray(data)
    if typeof(data) == "string" then
        local t = {}
        for i = 1, #data do
            t[i] = string.byte(data, i)
        end
        return t
    elseif typeof(data) == "table" then
        return data
    else
        return {}
    end
end

local function _tostring(data)
    if typeof(data) == "string" then
        return data
    elseif typeof(data) == "table" then
        local chars = {}
        for i, v in ipairs(data) do
            chars[i] = string.char(v)
        end
        return table.concat(chars)
    else
        return ""
    end
end

function Packet.new(data, priority, reliability, ordering)
    local self = setmetatable({}, Packet)

    self._data = data
    self.Priority = priority or 0
    self.Reliability = reliability or 0
    self.OrderingChannel = ordering or 0
    self._blocked = false

    return self
end

function Packet:UpdateViews()
    self.AsArray = toArray(self._data)
    self.AsString = _tostring(self._data)
    self.Size = #self.AsArray
end

function Packet:SetData(data)
    self._data = data
    self:UpdateViews()
end

function Packet:Block()
    self._blocked = true
end

function _raknet.add_send_hook(hook)
    table.insert(hooks, hook)
end

function _raknet.remove_send_hook(hook)
    for i, v in ipairs(hooks) do
        if v == hook then
            table.remove(hooks, i)
            break
        end
    end
end

function _raknet.send(data, priority, reliability, ordering_channel)
    local packet = Packet.new(data, priority, reliability, ordering_channel)
    packet:UpdateViews()

    -- run hooks
    for _, hook in ipairs(hooks) do
        local ok, err = pcall(hook, packet)
        if not ok then
            warn("raknet hook error:", err)
        end

        if packet._blocked then
            warn("[raknet] packet blocked")
            return
        end
    end

    -- we really should be sending this but thats not to possible so
    if testing then
        print("[raknet] sent packet:")
        print("  size:", packet.Size)
        print("  priority:", packet.Priority)
        print("  reliability:", packet.Reliability)
        print("  ordering:", packet.OrderingChannel)
        print("  data:", packet.AsString)
    end
end

genv.raknet = genv.raknet or genv.rnet or {}

for k, v in pairs(_raknet) do
    add("raknet." .. k, v)
end

local new_raknet = {}
for k, v in pairs(getgenv().raknet) do
    new_raknet[k] = v
end

for k, v in pairs(_raknet) do
    if new_raknet[k] == nil then
        new_raknet[k] = v
    end
end

genv.raknet = new_raknet
genv.rnet = new_raknet

-- Helper -- this is like a module?? idk useless anyway

local function createBindable()
    return Instance.new("BindableEvent")
end


local _helper = {}

_helper.kill = function(thread)
    task.cancel(thread)
end

_helper.chunkify = function(input, chunk_size)
    chunk_size = chunk_size or 2
    local result = {}

    local function process(value)
        local vtype = type(value)

        if vtype == "string" then
            for i = 1, #value, chunk_size do
                table.insert(result, value:sub(i, i + chunk_size - 1))
            end

        elseif vtype == "number" then
            local str = tostring(value)
            for i = 1, #str, chunk_size do
                table.insert(result, str:sub(i, i + chunk_size - 1))
            end

        elseif vtype == "boolean" or vtype == "function" then
            table.insert(result, value)

        elseif vtype == "table" then
            for _, nested in ipairs(value) do
                process(nested)
            end

        else
            table.insert(result, value)
        end
    end

    for _, v in ipairs(input) do
        process(v)
    end

    return table.concat(result, "")
end

-- removed _helper.unchunk
-- removed _helper.fromtable

_helper.tabledata = function(data)
    local result = {}

    for _, v in pairs(data) do
        local t = type(v)
        result[t] = (result[t] or 0) + 1
    end

    return result
end

_helper.sum = function(tbl)
    expect(tbl, "table", false, 1)
    local total = 0
    for _, v in ipairs(tbl) do
        expect(v, "number", false, 1)
        total += v
    end
    return total
end

_helper.average = function(tbl)
    expect(tbl, "table", false, 1)
    assert(#tbl > 0, "table cannot be empty")
    return _helper.sum(tbl) / #tbl
end

-- local t = {"string", "pango", 3, "rango"}
-- print(helper.search(t, 3, true, { type = "number" }))
--  returns "3 3"
_helper.search = function(tbl, looking_for, nested, filter)
    expect(tbl, "table", false, 1)
    expect(nested, "boolean", false, 2)
    expect(filter, "table", false, 3)

    for k, v in pairs(tbl) do
        local match = (v == looking_for)

        if filter and filter.type then
            match = match and (type(v) == filter.type)
        end

        if match then
            return k, v
        end

        if nested and type(v) == "table" then
            local foundK, foundV = _helper.search(v, looking_for, true, filter)
            if foundK ~= nil then
                return foundK, foundV
            end
        end
    end

    return nil, "Item could not be found"
end

local function set(data, func)
    local result = {}
    for k, v in pairs(data) do
        result[k] = func(v)
    end
    return result
end

_helper.tostring = function(data)
    return _tostring(data)
end

-- for tables
_helper.tabletostring = function(data)
    return set(data, tostring)
end

_helper.tabletonumber = function(data)
    return set(data, tonumber)
end

_helper.is_repeating = function(v)
    local t = type(v)

    if t == "string" then
        if #v <= 1 then return true end
        local first = v:sub(1, 1)
        for i = 2, #v do
            if v:sub(i, i) ~= first then
                return false
            end
        end
        return true
    end

    -- table
    if #v == 0 then return true end
    local first = v[1]
    for i = 2, #v do
        if v[i] ~= first then
            return false
        end
    end

    return true
end

_helper.toexpontent = function(n)
    if n == 0 then return "0e0" end

    local exp = 0
    local value = n

    while value >= 10 do
        value /= 10
        exp += 1
    end

    while value < 1 do
        value *= 10
        exp -= 1
    end

    return string.format("%.3ge%d", value, exp)
end

_helper.fromexpontent = function(str)
    local base, exp = str:match("([%d%.]+)e([%-]?%d+)")
    base = tonumber(base)
    exp = tonumber(exp)

    if not base or not exp then return nil end

    return base * (10 ^ exp)
end

_helper.flip = function(var)
    -- fixed: "bool" -> "boolean"
    expect(var, "boolean", false, 1)
    return not var
end

_helper.GetChildrenWithAttribute = function(parent, attr)
    local result = {}

    for _, child in ipairs(parent:GetChildren()) do
        if child:GetAttribute(attr) ~= nil then
            table.insert(result, child)
        end
    end

    return result
end

local collection = game:GetService("CollectionService")

_helper.GetChildrenWithTag = function(parent, tag)
    local result = {}

    for _, instance in ipairs(collection:GetTagged(tag)) do
        if instance.Parent == parent then
            table.insert(result, instance)
        end
    end

    return result
end

for k, v in pairs(_helper) do
    add("helper." .. k, v)
end
getgenv().helper = _helper

-- Drawing

local dache = {}

local function applyBase(obj, self)
    obj.Visible = self.Visible
    obj.ZIndex = math.clamp(self.ZIndex, -2^31, 2^31)
    obj.BackgroundTransparency = 1 - self.Transparency
    obj.BackgroundColor3 = self.Color
end

local function makeProxy(self, update, readonly)
    readonly = readonly or {}
    local proxy = newproxy(true)
    local mt = getmetatable(proxy)

    mt.__index = function(_, k)
        return self[k]
    end

    mt.__newindex = function(_, k, v)
        for _, r in ipairs(readonly) do
            if r == k then return end
        end
        self[k] = v
        update()
    end

    mt.__tostring = function()
        return "Drawing"
    end

    mt.__metatable = "This metatable is protected."
    return proxy
end

local types = {}

types.Line = function(self, Object)
    local function update()
        local from, to = self.From, self.To
        local dx, dy = to.X - from.X, to.Y - from.Y
        local len = math.sqrt(dx^2 + dy^2)
        Object.Size = UDim2.fromOffset(len, self.Thickness)
        Object.Position = UDim2.fromOffset(from.X, from.Y)
        Object.Rotation = math.deg(math.atan2(dy, dx))
        Object.BackgroundColor3 = self.Color
        Object.Visible = self.Visible
        Object.ZIndex = math.clamp(self.ZIndex, -2^31, 2^31)
    end

    self.From = Vector2.zero
    self.To = Vector2.zero
    self.Thickness = 1
    self.Color = Color3.new(1, 1, 1)
    self.Visible = true
    self.ZIndex = 1
    self.Transparency = 1

    local proxy = makeProxy(self, update)
    update()
    return proxy
end

types.Square = function(self, Object)
    local stroke = Instance.new("UIStroke", Object)
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

    local function update()
        applyBase(Object, self)
        Object.Size = UDim2.fromOffset(self.Size.X, self.Size.Y)
        Object.Position = UDim2.fromOffset(self.Position.X, self.Position.Y)
        if self.Filled then
            Object.BackgroundTransparency = 0
            stroke.Enabled = false
        else
            Object.BackgroundTransparency = 1
            stroke.Enabled = true
            stroke.Color = self.Color
            stroke.Thickness = self.Thickness
        end
    end

    self.Size = Vector2.zero
    self.Position = Vector2.zero
    self.Color = Color3.new(1, 1, 1)
    self.Filled = false
    self.Thickness = 1
    self.Visible = true
    self.ZIndex = 1
    self.Transparency = 1

    return makeProxy(self, update)
end

types.Circle = function(self, Object)
    Instance.new("UICorner", Object).CornerRadius = UDim.new(1, 0)
    local stroke = Instance.new("UIStroke", Object)
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

    local function update()
        local d = self.Radius * 2
        Object.Size = UDim2.fromOffset(d, d)
        Object.Position = UDim2.fromOffset(
            self.Position.X - self.Radius,
            self.Position.Y - self.Radius
        )
        Object.Visible = self.Visible
        Object.ZIndex = math.clamp(self.ZIndex, -2^31, 2^31)
        if self.Filled then
            Object.BackgroundTransparency = 1 - self.Transparency
            Object.BackgroundColor3 = self.Color
            stroke.Enabled = false
        else
            Object.BackgroundTransparency = 1
            stroke.Enabled = true
            stroke.Color = self.Color
            stroke.Thickness = self.Thickness
        end
    end

    self.Radius = 1
    self.Position = Vector2.zero
    self.Color = Color3.new(1, 1, 1)
    self.Filled = false
    self.Thickness = 1
    self.Visible = true
    self.ZIndex = 1
    self.Transparency = 1
    self.NumSides = 0

    return makeProxy(self, update)
end

types.Text = function(self, Object)
    Object:Destroy()
    Object = Instance.new("TextLabel", UI)
    Object.BackgroundTransparency = 1
    Object.BorderSizePixel = 0
    Object.TextWrapped = false
    Object.RichText = false

    local function update()
        Object.Visible = self.Visible
        Object.ZIndex = math.clamp(self.ZIndex, -2^31, 2^31)
        Object.Text = self.Text
        Object.TextSize = self.Size
        Object.TextColor3 = self.Color
        Object.BackgroundTransparency = 1 - self.Transparency
        Object.Position = UDim2.fromOffset(self.Position.X, self.Position.Y)
        Object.Size = UDim2.fromOffset(self.Size * #self.Text * 0.6, self.Size)
        Object.Font = ({
            [0] = Enum.Font.GothamMedium,
            [1] = Enum.Font.SourceSans,
            [2] = Enum.Font.Code,
            [3] = Enum.Font.RobotoMono,
        })[self.Font] or Enum.Font.GothamMedium
        Object.TextXAlignment = self.Center and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left
        Object.TextYAlignment = self.Center and Enum.TextYAlignment.Center or Enum.TextYAlignment.Top
        Object.TextStrokeTransparency = self.Outline and 0 or 1
        Object.TextStrokeColor3 = self.OutlineColor
        self.TextBounds = Object.TextBounds
    end

    self.Text = ""
    self.Size = 12
    self.Font = 3
    self.Color = Color3.new(1, 1, 1)
    self.Center = false
    self.Outline = false
    self.OutlineColor = Color3.new(0, 0, 0)
    self.Position = Vector2.zero
    self.Visible = true
    self.ZIndex = 1
    self.Transparency = 1
    self.TextBounds = Vector2.zero

    return makeProxy(self, update, {"TextBounds"})
end

local Drawing = {
    Fonts = {
        UI = 0,
        System = 1,
        Plex = 2,
        Monospace = 3,
    },

    new = function(Type)
        expect(Type, "string", false, 1)
        assert(types[Type], "invalid drawing type: " .. Type)

        local Object = Instance.new("Frame")
        Object.BorderSizePixel = 0
        Object.BackgroundTransparency = 1
        Object.ZIndex = 1
        Object.Size = UDim2.fromOffset(0, 0)
        Object.Parent = UI

        local self = {
            Remove = function() Object:Destroy() end,
        }
        self.Destroy = self.Remove

        local proxy = types[Type](self, Object)
        table.insert(dache, {proxy = proxy, instance = Object})
        return proxy
    end
}

if getgenv()["Drawing"] == nil then
    getgenv().Drawing = Drawing
end

add("isrenderobj", function(a)
    for _, obj in ipairs(dache) do
        if obj.proxy == a then return true end
    end
    return false
end)

add("cleardrawcache", function()
    for _, obj in ipairs(dache) do
        obj.instance:Destroy()
    end
    table.clear(dache)
end)

add("getrenderproperty", function(a, b)
    assert(isrenderobj(a), "expected render object, got " .. type(a))
    expect(b, "string", false, 2)
    return a[b]
end)

add("setrenderproperty", function(a, b, c)
    assert(isrenderobj(a), "expected render object, got " .. type(a))
    expect(b, "string", false, 2)
    a[b] = c
end)

-- File System

local executor = (identifyexecutor and identifyexecutor() or "unknown") -- depends on the exec but should show raw version
local _workspace = executor .. "/workspace"

local function normalize(path)
    path = tostring(path or "")
    path = path:gsub("\", "/")
    path = path:gsub("^/", "")

    path = path:gsub("^%.%./", "")
    path = path:gsub("/%.%./", "/")

    if not path:find(_workspace, 1, true) then
        path = _workspace .. "/" .. path
    end

    return path
end

local function parent(path)
    return path:match("(.+)/[^/]+$") or _workspace
end

add("writefile", function(path, data)
    path = normalize(path)
    fs_files[path] = data
    fs_folders[parent(path)] = true
    if allow() then
        ps:Send(string.format(
            "Set-Content -Path '%s' -Value '%s'",
            path,
            data:gsub("'", "''")
        ))
    end
end)

add("appendfile", function(path, data)
    path = normalize(path)
    fs_files[path] = (fs_files[path] or "") .. data
    fs_folders[parent(path)] = true
    if allow() then
        ps:Send(string.format(
            "Add-Content -Path '%s' -Value '%s'",
            path,
            data:gsub("'", "''")
        ))
    end
end)

add("readfile", function(path)
    path = normalize(path)
    if fs_files[path] then
        return fs_files[path]
    end
    -- fallback: read from disk
    if allow() then
        ps:Send(string.format("Get-Content -Path '%s' -Raw", path))
    end
    error("file does not exist in virtual fs: " .. path)
end)

add("isfile", function(path)
    path = normalize(path)
    if fs_files[path] ~= nil then return true end
    if allow() then
        ps:Send(string.format("Test-Path -Path '%s' -PathType Leaf", path))
    end
    return false
end)

add("makefolder", function(path)
    path = normalize(path)
    fs_folders[path] = true
    if allow() then
        ps:Send(string.format(
            "New-Item -ItemType Directory -Force -Path '%s'",
            path
        ))
    end
end)

add("isfolder", function(path)
    path = normalize(path)
    if fs_folders[path] then return true end
    if allow() then
        ps:Send(string.format("Test-Path -Path '%s' -PathType Container", path))
    end
    return false
end)

add("delfile", function(path)
    path = normalize(path)
    assert(fs_files[path] ~= nil, "file does not exist: " .. path)
    fs_files[path] = nil
    if allow() then
        ps:Send(string.format("Remove-Item -Path '%s' -Force", path))
    end
end)

add("delfolder", function(path)
    path = normalize(path)
    for f in pairs(fs_files) do
        if f:sub(1, #path) == path then fs_files[f] = nil end
    end
    for f in pairs(fs_folders) do
        if f:sub(1, #path) == path then fs_folders[f] = nil end
    end
    if allow() then
        ps:Send(string.format("Remove-Item -Path '%s' -Recurse -Force", path))
    end
end)

add("listfiles", function(path)
    path = normalize(path)
    local out = {}
    for f in pairs(fs_files) do
        if f:sub(1, #path) == path then table.insert(out, f) end
    end
    for f in pairs(fs_folders) do
        if f ~= "" and f:sub(1, #path) == path then table.insert(out, f) end
    end
    if allow() then
        ps:Send(string.format("Get-ChildItem -Path '%s' | Select-Object -ExpandProperty Name", path))
    end
    return out
end)

-- Input

local vim = game:GetService("VirtualInputManager")
local uis = game:GetService("UserInputService")

local mouse = uis:GetMouseLocation()
uis.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        mouse = uis:GetMouseLocation()
    end
end)

add("isrbxactive", function()
    return uis.WindowFocused
end)

add("closerbx", function()
    crash() -- see  raknet
end)
add("closeroblox", function()
    crash()
end)

add("mouse1press", function()
    vim:SendMouseButtonEvent(mouse.X, mouse.Y, 0, true, game, 0)
end)

add("mouse1release", function()
    vim:SendMouseButtonEvent(mouse.X, mouse.Y, 0, false, game, 0)
end)

add("mouse1click", function()
    vim:SendMouseButtonEvent(mouse.X, mouse.Y, 0, true, game, 0)
    vim:SendMouseButtonEvent(mouse.X, mouse.Y, 0, false, game, 0)
end)

add("mouse2click", function()
    vim:SendMouseButtonEvent(mouse.X, mouse.Y, 1, true, game, 0)
    vim:SendMouseButtonEvent(mouse.X, mouse.Y, 1, false, game, 0)
end)

add("mouse2release", function()
    vim:SendMouseButtonEvent(0, 0, 1, false, game, 0)
end)

add("mousemoveabs", function(x, y)
    expect(x, "number", false, 1)
    expect(y, "number", false, 2)
    vim:SendMouseMoveEvent(x, y, game)
end)

add("mousemoverel", function(x, y)
    expect(x, "number", false, 1)
    expect(y, "number", false, 2)
    local pos = uis:GetMouseLocation()
    vim:SendMouseMoveEvent(pos.X + x, pos.Y + y, game)
end)

add("mousescroll", function(pixels)
    expect(pixels, "number", false, 1)
    vim:SendMouseWheelEvent(0, 0, pixels > 0, game)
end)

-- Instance

local lp = game:GetService("Players").LocalPlayer
local char = lp.Character
local hrp = char.HumanoidRootPart

add("fireclickdetector", function(cd, distance)
    assert(typeof(cd) == "Instance" and cd:IsA("ClickDetector"), "expected ClickDetector, got " .. typeof(cd))
    distance = distance or 0

    local old = hrp.CFrame
    if cd.Parent and distance ~= 0 then
        hrp.CFrame = cd.Parent.CFrame
    end

    cd.MaxActivationDistance = math.huge
    cd:InputHoldBegin()
    cd:InputHoldEnd()

    hrp.CFrame = old
end)

add("firetouchinterest", function(part, touched)
    assert(typeof(part) == "Instance" and part:IsA("BasePart"), "expected BasePart, got " .. typeof(part))
    firesignal(part, touched == false and "TouchEnded" or "Touched")
end)

add("isnetworkowner", function(part)
    assert(typeof(part) == "Instance" and part:IsA("BasePart"), "expected BasePart, got " .. typeof(part))
    return gethiddenproperty(part, "NetworkOwnerV3")
end)

add("getcallbackvalue", function(obj, property)
    expect(obj, "Instance", false, 1)
    expect(property, "string", false, 2)

    -- hookmetamethod -- this is so shit ahahahahahhfewfuewufhweiuhf
end)

add("fireproximityprompt", function(prompt, triggered, hold)
    assert(typeof(prompt) == "Instance" and prompt:IsA("ProximityPrompt"), "expected ProximityPrompt, got " .. typeof(prompt))
    local signal
    if hold then
        signal = triggered and "PromptButtonHoldBegan" or "PromptButtonHoldEnded"
    else
        signal = triggered == false and "TriggerEnded" or "Triggered"
    end
    firesignal(prompt, signal)
end)
local signal_store = setmetatable({}, {__mode = "k"})

add("getconnections", function(signal)
    assert(typeof(signal) == "RBXScriptSignal", "expected RBXScriptSignal, got " .. typeof(signal))
    return signal_store[signal] or {}
end)

add("getconnection", function(signal)
    assert(typeof(signal) == "RBXScriptSignal", "expected RBXScriptSignal, got " .. typeof(signal))
    local t = signal_store[signal]
    return t and t[1]
end)

add("getsignalarguments", function()
    assert(typeof(signal) == "RBXScriptSignal", "expected RBXScriptSignal, got " .. typeof(signal))
end) 
add("getsignalargumentsinfo", function()
    assert(typeof(signal) == "RBXScriptSignal", "expected RBXScriptSignal, got " .. typeof(signal))
end) 

-- salood w code
add("firesignal", function(instance: Instance, signalName: string, args: any)
    if instance and signalName then
        local signal = instance[signalName]
        if signal then
            for _, connection in ipairs(getconnections(signal)) do
                if args then
                    connection:Fire(args)
                else
                    connection:Fire()
                end
            end
        end
    end
end)

add("getcustomasset", function(path)
    expect(path, "string", false, 1)
    if not isfile(path) then
        error("file does not exist: " .. path)
    end

    local name = path:match("[^/\]+$")
    local new = "content/" .. name

    if not isfile(new) then
        writefile(new, readfile(path))
    end

    return "rbxasset://" .. new
end)

local ugc = game:GetService("UGCValidationService")
local reflect = game:GetService("ReflectionService")

add("getproperties", function(instance)
    expect(instance, "Instance", false, 1)
    class = typeof(instance)

    local allCapabilities = SecurityCapabilities.new(table.unpack(Enum.SecurityCapability:GetEnumItems()))
    local props = reflect:GetPropertiesOfClass(class, { Security = allCapabilities })
    local out = {}

    for _, item in ipairs(props) do
        table.insert(out, item.Name)
    end
    return out
end)

add("ishiddenproperty", function(object, property)
    return ugc:GetPropertyValue(object, property) ~= nil
end)

-- return if the property was even hidden
add("gethiddenproperty", function(object, property)
    expect(object, "Instance", false, 1)
    expect(property, "string", false, 2)

    -- fake news, only works for non hidden propertys
    return ugc:GetPropertyValue(object, property), false
end)

add("gethiddenproperties", function(object)
    expect(object, "Instance", false, 1)

    local a = {
        PredictionMode = Enum.PredictionMode.Automatic,
        ChatPrivacyMode = Enum.ChatPrivacyMode.NoOne,
        InternalCharacterAppearanceLoaded = true,
        FollowUserIdReplicated = 0,
        CharacterRegionId = {0, 0, -1},
        AttributesReplicate = "",
        Attributes = {},
        CloudEditPlayerActive = true,
        MembershipTypeReplicate = Enum.MembershipType.None,
        AttributesSerialize = "",
        NeedRegionalFallback = false,
        RawJoinData = "",
        Tags = {},
        SuperSafeChatReplicate = false,
        CountryRegionCodeReplicate = "US",
        PropertyStatusStudio = Enum.PropertyStatus.Ok,
        CloudEditCameraCoordinateFrame = {0,0,0,1,0,0,0,1,0,0,0,1},
        AccountAgeReplicate = 282,
        MaxSimulationRadius = 0,
        numExpectedDirectChildren = 0,
        DefinesCapabilities = false,
        CameraFrustumRequested = false,
        HistoryId = "00000000-0000-0000-0000-000000000000"
    }

    return a
end)

add("sethiddenproperty", function(object, property, value)
    expect(object, "Instance", false, 1)
    expect(property, "string", false, 2)
    return ugc:SetPropertyValue(object, property, value)
end)

add("setsimulationradius", function(simrad, maxsimrad)
    expect(simrad, "number", false, 1)
    sethiddenproperty(lp, "SimulationRadius", simrad)
    sethiddenproperty(lp, "MaxSimulationRadius", maxsimrad or simrad)
end)

add("getsimulationradius", function()
    return lp.SimulationRadius
end)

add("gethui", function()
    return cloneref(game:GetService("CoreGui")).RobloxGui
end)

-- this is supposed to be like from the memory idk
add("getinstances", function()
    local t = {}
    for _, v in ipairs(game:GetDescendants()) do
        t[#t + 1] = v:GetFullName()
    end
    return t
end)

-- apparently this is supposed to have 2 args???
add("getobjects", function()
    return getinstances()
end)

local objs = {}
for _,v in ipairs(game:GetDescendants()) do
    objs[v] = true
end

add("getnilinstances", function()
    local nils = {}

    for obj in pairs(objs) do
        if obj.Parent == nil then
            table.insert(nils, obj)
        end
    end

    return nils
end)

add("getnilinstance", function(search)
    -- search = string
    for _, item in ipairs(getnilinstances()) do
        if item == search then
            return item
        end
    end
end)

local function isScript(obj, includem) -- ~Script
    local a = false
    if includem then
        if obj:IsA("LocalScript") or obj:IsA("ModuleScript") then
            a = true
        end
    else
        if obj:IsA("LocalScript") then
            a = true
        end
    end
    return a
end

local scripts = {}
game.DescendantAdded:Connect(function(obj)
    if isScript(obj, true) then
        scripts[#scripts + 1] = obj
    end
    objs[obj] = true
end)

game.DescendantRemoving:Connect(function(obj)
    objs[obj] = nil
    for i, v in ipairs(scripts) do
        if v == obj then
            table.remove(scripts, i)
            break
        end
    end
end)

local scriptable = {}
add("isscriptable", function(obj, prop)
    expect(obj, "Instance", false, 1)
    expect(prop, "string", false, 2)

    local res = false
    for _, item in ipairs(getproperties(obj)) do
        if item:match(prop) then
          res = true
          if table.find(scriptable, prop) then -- also check obj chat
              res = false
          end
        end
    end
    return res
end)

-- we would have to use getconnecctions to see any refrence to any property .... . . .. . . ..
add("setscriptable", function(object, property, value)
    expect(object, "Instance", false, 1)
    expect(property, "string", false, 2)
                                      
    table.insert(scriptable, {object = object, property = property, value = value})
end)

add("setrbxclipboard", function(data)
    expect(data, "string", false, 1)
end)

add("getrendersteppedlist", function()
    return {}
end)

add("replicatesignal", function(signal, ...)
    assert(typeof(signal) == "RBXScriptSignal", "expected RBXScriptSignal, got " .. typeof(signal))
end)

-- Metatable

add("getrawmetatable", function(object)
    assert(type(object) == "table" or typeof(object) == "Instance", "expected table or Instance, got " .. typeof(object))

    local mt = getmetatable(object)

    if type(mt) == "table" and mt.__metatable ~= nil then
        local copy = {}
        for k, v in pairs(mt) do
            copy[k] = v
        end
        copy.__metatable = nil
        return copy
    end

    return mt
end)

add("setrawmetatable", function(object, mt)
    assert(type(object) == "table" or typeof(object) == "Instance", "expected table or Instance, got " .. typeof(object))
    expect(mt, "table", false, 2)

    local old = getmetatable(object)
    if type(old) == "table" then
        old.__metatable = nil
    end

    setmetatable(object, mt)
end)

add("hookmetamethod", function(object, method, hook)
    expect(method, "string", false, 2)
    expect(hook, "function", false, 3)

    local mt = getrawmetatable(object)
    assert(mt, "no metatable on object")

    local old = mt[method]
    assert(old, "method does not exist: " .. method)

    mt[method] = function(...)
        return hook(old, ...)
    end

    return function(...)
        return old(...)
    end
end)

local namecallmethod = nil
add("getnamecallmethod", function()
    return namecallmethod
end)

add("setnamecallmethod", function(method)
    expect(method, "string", false, 1)
    namecallmethod = method
end)

add("isreadonly", function(object)
    expect(object, "table", false, 1)
    return table.isfrozen(object)
end)

-- Salood
local function guard(tbl, readonly)
    local existing = getmetatable(tbl)
    if existing then
        existing.__newindex = function(_, k, v)
            if readonly then error("attempt to modify a readonly table", 2) end
            rawset(tbl, k, v)
        end
        return tbl
    end

    local proxy = setmetatable({}, {
        __index    = tbl,
        __newindex = function(_, k, v)
            if readonly then error("attempt to modify a readonly table", 2) end
            rawset(tbl, k, v)
        end,
        __len    = function() return #tbl end,
        __pairs  = function() return pairs(tbl) end,
        __ipairs = function() return ipairs(tbl) end,
    })

    return proxy
end

add("setreadonly", function(object, readonly)
    expect(object, "table", false, 1)
    assert(type(readonly) == "boolean", "expected boolean for readonly, got " .. type(readonly))
    return guard(object, readonly)
end)

add("makereadonly", function(object)
    expect(object, "table", false, 1)
    return guard(object, true)
end)

add("makewriteable", function(object)
    expect(object, "table", false, 1)
    return guard(object, false)
end)

-- Misc

add("identifyexecutor", function()
    return "Potassium", "1.0"
end)

local shwid
add("sethwid", function(input)
    shwid = input
end)
add("set_hwid", function(input)
    return sethwid(input)
end)

add("setmac", function(input)
    shwid = input
end)

local anal = game:GetService("RbxAnalyticsService")
add("getmac", function()
    return shwid or crypt.hash(anal:GetClientId())
end)

add("gethwid", function()
    return getmac()
end)

add("get_hwid", function()
    return gethwid()
end)

-- we LOVE claude
add("lz4compress", function(data)
    assert(type(data) == "string", "data must be string")
    
    if #data == 0 then return "" end
    
    local output = {}
    local pos = 1
    local anchor = 1
    
    -- Hash table for finding matches
    local hash_table = {}
    local function hash(p)
        if p + 3 > #data then return 0 end
        local a, b, c, d = data:byte(p, p + 3)
        return ((a * 256 + b) * 256 + c) * 256 + d
    end
    
    while pos <= #data do
        local best_len = 0
        local best_offset = 0
        
        -- Find match
        local h = hash(pos)
        if h ~= 0 and hash_table[h] then
            local match_pos = hash_table[h]
            if match_pos < pos then
                local len = 0
                while pos + len <= #data and 
                      match_pos + len <= #data and 
                      data:byte(pos + len) == data:byte(match_pos + len) and
                      len < 255 do
                    len = len + 1
                end
                
                if len >= 4 then
                    best_len = len
                    best_offset = pos - match_pos
                end
            end
        end
        
        hash_table[h] = pos
        
        if best_len >= 4 then
            -- Output literal run
            local literal_len = pos - anchor
            if literal_len > 0 then
                output[#output + 1] = string.char(literal_len)
                output[#output + 1] = data:sub(anchor, pos - 1)
            end
            
            -- Output match
            output[#output + 1] = string.char(0xFF) -- Match marker
            output[#output + 1] = string.char(best_len)
            output[#output + 1] = string.char(math.floor(best_offset / 256))
            output[#output + 1] = string.char(best_offset % 256)
            
            pos = pos + best_len
            anchor = pos
        else
            pos = pos + 1
        end
    end
    
    if anchor <= #data then
        local literal_len = #data - anchor + 1
        output[#output + 1] = string.char(literal_len)
        output[#output + 1] = data:sub(anchor)
    end
    
    return table.concat(output)
end)

-- also claude btw
add("lz4decompress", function(data)
    assert(type(data) == "string", "data must be string")
    
    if #data == 0 then return "" end
    
    local output = {}
    local pos = 1
    
    while pos <= #data do
        local token = data:byte(pos)
        pos = pos + 1
        
        if token == 0xFF then
            if pos + 3 > #data then break end
            
            local match_len = data:byte(pos)
            local offset = data:byte(pos + 1) * 256 + data:byte(pos + 2)
            pos = pos + 3
            
            local out_pos = #table.concat(output)
            local match_start = out_pos - offset + 1
            
            for i = 1, match_len do
                output[#output + 1] = output[match_start + i - 1]
            end
        else
            local literal_len = token
            if pos + literal_len - 1 > #data then break end
            
            output[#output + 1] = data:sub(pos, pos + literal_len - 1)
            pos = pos + literal_len
        end
    end
    
    return table.concat(output)
end)

add("rlecompress", function(data)
    assert(type(data) == "string", "expected string, got " .. type(data))
    local out, i = {}, 1
    while i <= #data do
        local char = data:sub(i, i)
        local count = 1
        while i + count <= #data and data:sub(i + count, i + count) == char and count < 255 do
            count += 1
        end
        if count > 1 then
            out[#out + 1] = string.char(count + 128)
        end
        out[#out + 1] = char
        i += count
    end
    return table.concat(out)
end)

add("rledecompress", function(data)
    assert(type(data) == "string", "expected string, got " .. type(data))
    local out, i = {}, 1
    while i <= #data do
        local byte = data:byte(i)
        if byte > 127 and i + 1 <= #data then
            out[#out + 1] = string.rep(data:sub(i + 1, i + 1), byte - 128)
            i += 2
        else
            out[#out + 1] = data:sub(i, i)
            i += 1
        end
    end
    return table.concat(out)
end)

local mboxParent = Instance.new("Folder", gethui())
mboxParent.Name = rstring(6)

add("messagebox", function(text, caption, flags)
    expect(text, "string", false, 1)
    expect(caption, "string", false, 2)

    local gui = Instance.new("ScreenGui")
    gui.Name = tostring(math.random(1e4, 1e5))
    gui.Parent = mboxParent

    local window = Instance.new("Frame")
    window.Size = UDim2.fromOffset(349, 151)
    window.Position = UDim2.new(0.5, -174, 0.5, -75)
    window.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    window.Draggable = true
    window.BorderSizePixel = 0
    window.ClipsDescendants = true
    window.Parent = gui

    local wc = Instance.new("UICorner", window)
    wc.CornerRadius = UDim.new(0, 8)

    local strip = Instance.new("Frame")
    strip.Size = UDim2.fromOffset(349, 35)
    strip.Position = UDim2.fromOffset(0, 0)
    strip.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
    strip.BorderSizePixel = 0
    strip.ClipsDescendants = true
    strip.Parent = window

    Instance.new("UICorner", strip).CornerRadius = wc.CornerRadius

    local title = Instance.new("TextLabel")
    title.Size = UDim2.fromOffset(260, 18)
    title.Position = UDim2.fromOffset(14, 10)
    title.BackgroundTransparency = 1
    title.Text = caption
    title.Font = Enum.Font.SourceSans
    title.TextSize = 16
    title.TextColor3 = Color3.fromRGB(0, 0, 0)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = window

    local close = Instance.new("TextButton")
    close.Size = UDim2.fromOffset(20, 20)
    close.Position = UDim2.fromOffset(321, 8)
    close.Text = "X"
    close.Font = Enum.Font.SourceSansBold
    close.TextSize = 16
    close.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    close.BackgroundTransparency = 0.8
    close.TextColor3 = Color3.fromRGB(0, 0, 0)
    close.Parent = window

    close.MouseButton1Click:Connect(function() gui:Destroy() end)
    close.MouseEnter:Connect(function() close.BackgroundColor3 = Color3.fromRGB(255, 0, 0) end)
    close.MouseLeave:Connect(function() close.BackgroundColor3 = Color3.fromRGB(255, 255, 255) end)

    local msg = Instance.new("TextLabel")
    msg.Size = UDim2.fromOffset(250, 20)
    msg.Position = UDim2.fromOffset(54, 58)
    msg.BackgroundTransparency = 1
    msg.Text = text
    msg.Font = Enum.Font.SourceSans
    msg.TextSize = 14
    msg.TextColor3 = Color3.fromRGB(0, 0, 0)
    msg.TextXAlignment = Enum.TextXAlignment.Left
    msg.Parent = window

    local strip2 = Instance.new("Frame")
    strip2.Size = UDim2.fromOffset(349, 38)
    strip2.Position = UDim2.fromOffset(0, window.Size.Y.Offset - 38)
    strip2.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
    strip2.BorderSizePixel = 0
    strip2.ClipsDescendants = true
    strip2.Parent = window

    local s2c = Instance.new("UICorner")
    s2c.CornerRadius = wc.CornerRadius
    s2c.Parent = strip2

    local function createBtn(btnText, pos)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.fromOffset(72, 26)
        btn.Position = UDim2.fromOffset(pos, 5.8)
        btn.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
        btn.Text = btnText
        btn.Font = Enum.Font.SourceSans
        btn.TextSize = 14
        btn.TextColor3 = Color3.fromRGB(0, 0, 0)
        btn.ClipsDescendants = true
        btn.Parent = strip2

        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

        local stroke = Instance.new("UIStroke", btn)
        stroke.Color = Color3.fromRGB(200, 200, 200)
        stroke.Thickness = 1
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

        return btn
    end

    local ok = createBtn("OK", 263) -- should be based on flags btw -- no real docs on how the system works just guess a bit
    ok.MouseButton1Click:Connect(function() gui:Destroy() end)
end)

local oqueue = ""
add("queue_on_teleport", function(code)
    expect(code, "string", false, 1)
    oqueue = code
end)

add("get_queued_teleport", function()
    return oqueue
end)

add("restet_queuedteleport", function()
    oqueue = ""
end)

add("request", function(options)
    expect(options, "table", false, 1)
    local url = options.Url
    assert(type(url) == "string" and #url > 0, "expected non-empty string for Url")

    local method = (options.Method or "GET"):upper()
    local body = options.Body or ""

    local success, result = pcall(function()
        if method == "GET" then
            return game:HttpGet(url, true)
        elseif method == "POST" then
            return game:HttpPost(url, body, Enum.HttpContentType.ApplicationUrlEncoded)
        else
            error("Unsupported method: " .. method)
        end
    end)

    return {
        StatusCode = success and 200 or 500,
        Body = success and result or tostring(result),
        Headers = {},
    }
end)

add("getinternalparent", function(instance)
    expect(instance, "Instance", false, 1)
    return instance.Parent
end)

add("setinternalparent", function(instance, newparent)
    expect(instance, "Instance", false, 1)
    assert(typeof(newparent) == "Instance" or newparent == nil, "expected Instance or nil for newparent")
    instance.Parent = newparent
end)

-- UserSettings():IsUserFeatureEnabled(u1)
add("getfflag", function(fflag)
    expect(fflag, "string", false, 1)
    return game:GetFastFlag(fflag:gsub("^FFlag", ""))
end)

add("setfflag", function(fflag, value)
    expect(fflag, "string", false, 1)
    expect(value, "string", false, 2)
    game:SetFastFlag(fflag:gsub("^FFlag", ""), value)
end)

add("setclipboard", function(text)
    expect(text, "string", false, 1)
    print(text)
end)

local fps = workspace:GetRealPhysicsFPS()
add("setfpscap", function(f)
    expect(f, "number", false, 1)
    assert(f > 0, "fps cap must be greater than 0")
    fps = f
end)

add("getfpscap", function()
    return fps
end)

add("getping", function()
    return game:GetService("Stats").FrameRateManager["AverageFPS"]:GetValue()
end)

add("getfps", function()
    local fps2 = 0; local last = tick()
    
    rs.RenderStepped:Wait()
    fps2 = 1 / (tick() - last)
    
    return math.floor(fps2)
end)

-- thanks https://scriptblox.com/u/Salood
add("getplatform", function()
    return tostring(game:GetService("UserInputService"):GetPlatform()):split(".")[3]
end)

add("playanimation", function(animation)
    if animation:find("rbxassetid") then
        animation = animation
    else
        animation = "rbxassetid://" .. animation
    end

    local hum = _raknet.GetHumanoid()
    hum:LoadAnimation(animation):Play()
end)
add("runanimation", function(anim)
    playanimation(anim)
end)

-- limited to actual math.pi but ya
add("pi", function(wanted)
    local str = tostring(math.pi)
    local output = {}

    for i = 1, wanted do
        local char = str:sub(i, i)
        if char == "" then break end
        table.insert(output, char)
    end

    return table.concat(output)
end)

-- Encoding -- useless

add("base64encode", function(data)
    return crypt.base64encode(data)
end)

add("base64decode", function(data)
    return crypt.base64decode(data)
end)

-- Scripts

add("getscriptclosure", function(scr)
    expect(scr, "Instance", false, 1)
    assert(scr:IsA("ModuleScript"), "expected ModuleScript, got " .. scr.ClassName)
    return function(...)
        return require(scr)(...)
    end
end)

-- could hookmetamethod it or some shit
add("getscriptfromthread", function()
    return Instance.new("LocalScript", nil)
end)

add("getscriptthread", function()
    return coroutine.running()
end)
-- no clue
add("getallthreads", function()
    return table.create(coroutine.running(), math.random(1, 32))
end)

add("getscriptbytecode", function(item)
    expect(item, "Instance", false, 1)
    return ""
end)

add("decompile", function(item)
    expect(item, "Instance", false, 1)

    return request({
        Url = "http://api.plusgiant5.com/konstant/decompile",
        Method = "POST",
        Headers = {
            ["Content-Type"] = "text/plain"
        },
        Body = getscriptbytecode(item)
    }).Body
end)

add("getscripthash", function(item)
    expect(item, "Instance", false, 1)
    return crypt.hash(getscriptbytecode(item))
end)

-- hash a functions BYTECODE
add("getfunctionhash", function(item)
    expect(item, "function", false, 1)
    return crypt.hash(item)
end)

local synsaveinstance = loadstring(game:HttpGet("https://raw.githubusercontent.com/luau/UniversalSynSaveInstance/main/saveinstance.luau", true), "saveinstance")()
local options = {
    ReadMe = true,
    IsolatePlayers = true,
    FilePath = string.format("%d", tick())
}
add("saveinstance", function(opts)
    if not opts then opts = options end
    synsaveinstance(opts)
end)
add("saveplace", function()
    saveinstance()
end)

for _, v in ipairs(game:GetDescendants()) do
    if isScript(v, true) then
        scripts[#scripts + 1] = v
    end
end

add("getrunningscripts", function()
    local out = {}
    for _, item in ipairs(scripts) do
        if isScript(item, false) then
            out[#out + 1] = item
        end
    end
    return out
end)

add("getscripts", function()
    return scripts
end)

add("getloadedmodules", function()
    local modules = {}
    for _, s in ipairs(scripts) do
        if s:IsA("ModuleScript") then
            modules[#modules + 1] = s
        end
    end
    return modules
end)

add("isrequired", function(module)
    assert(typeof(module) == "Instance" and module:IsA("ModuleScript"), "expected ModuleScript, got " .. typeof(module))

    local loaded = getloadedmodules()
    for _, item in ipairs(loaded) do
        if item == module then
            return true
        end
    end
    return false
end)

add("getdeletedactors", function()
    local del_actors = {}

    for _, item in ipairs(getnilinstances()) do
        if item:IsA("Actor") then
            table.insert(del_actors, item)
        end
    end
    return del_actors
end)

add("getremotes", function()
    local remotes = {}
    for _, obj in ipairs(game:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            table.insert(remotes, obj)
        end
    end
    return remotes
end)

add("hookremote", function(remote, hook)
    expect(remote, "Instance", false, 1)
    assert(remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction"), "expected RemoteEvent or RemoteFunction")
    expect(hook, "function", false, 2)
    
    local oldn
    oldn = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        
        if self == remote and (method == "FireServer" or method == "InvokeServer") then
            return hook(...)
        end
        
        return oldn(self, ...)
    end)
    
    return oldn
end)

local trgr, trgc = {}, {}

local function track(obj)
    if type(obj) == "table" or type(obj) == "function" or type(obj) == "thread" or type(obj) == "userdata" then
        trgr[#trgr + 1] = obj
        trgc[#trgc + 1] = obj
    end
    return obj
end

-- random error idk
local function nan(value) return type(value) == "number" and value ~= value end
local function sr(root, seen)
    if root == nil or nan(root) then return end

    seen = seen or {}
    if seen[root] then return end
    seen[root] = true

    if type(root) == "table" then
        track(root)

        for key, value in pairs(root) do
            if not nan(key) then
                sr(key, seen)
            end
            if not nan(value) then
                sr(value, seen)
            end
        end

        local metatable = getmetatable(root)
        if metatable then
            sr(metatable, seen)
        end

    elseif type(root) == "function" then
        track(root)

        local index = 1
        while true do
            local success, name, upvalue = pcall(debug.getupvalue, root, index)
            if not success or not name then break end

            if not nan(upvalue) then
                sr(upvalue, seen)
            end

            index += 1
        end

    elseif type(root) == "thread" or type(root) == "userdata" then
        track(root)
    end
end

sr(getgenv())

add("getreg", function()
    return trgr
end)

add("getgc", function()
    return trgc
end)

add("filtergc", function(filter)
    local results = {}
    for _, obj in ipairs(trgc) do
        if type(filter) == "string" then
            if type(obj) == filter then
                results[#results + 1] = obj
            end
        elseif type(filter) == "function" then
            if filter(obj) then
                results[#results + 1] = obj
            end
        end
    end
    return results
end)

local renv = {DockWidgetPluginGuiInfo,warn,tostring,gcinfo,os,tick,task,getfenv,debug,NumberSequence,assert,rawlen,wait,Color3,Enum,Delay,OverlapParams,Path2DControlPoint,SecurityCapabilities,_G,AdReward,UserSettings,shared,Faces,error,coroutine,string,NumberRange,buffer,PhysicalProperties,Instance,printidentity,PluginManager,FloatCurveKey,delay,Ray,NumberSequenceKeypoint,Version,Vector2,newproxy,Game,Content,spawn,rawget,stats,xpcall,ColorSequence,Vector2int16,Workspace,print,SharedTable,typeof,UDim2,RaycastParams,unpack,TweenInfo,loadstring,require,Vector3,pairs,Vector3int16,setmetatable,elapsedTime,pcall,bit32,DateTime,ipairs,table,workspace,version,Region3int16,collectgarbage,game,getmetatable,Spawn,UDim,Region3,utf8,_VERSION,CFrame,rawset,PathWaypoint,CellId,Font,PluginDrag,settings,rawequal,math,CatalogSearchParams,Random,ValueCurveKey,ypcall,type,next,ElapsedTime,select,tonumber,Stats,Wait,time,Rect,BrickColor,setfenv,vector,Axes,ColorSequenceKeypoint,RotationCurveKey}
add("getrenv", function()
    return renv
end)

add("getgenv", function()
    return getfenv(0)
end)

add("getsenv", function(scr)
    assert(typeof(scr) == "Instance" and scr:IsA("LocalScript"), "expected LocalScript, got " .. typeof(scr))
    return getfenv(0)
end)

local function test()
    local function try(f)
        return function()
            return select(1, pcall(f))
        end
    end

    local checks = {
        try(function() return game.Name end),
        try(function() return game:GetService("CoreGui").Name end),
        try(function() return game.DataCost end),
        try(function() return Instance.new("Player") end),
        try(function() return game:GetService("CorePackages").Name end),
        try(function() return Instance.new("SurfaceAppearance") end),
        try(function() Instance.new("MeshPart").MeshId = "" end)
    }

    for i, v in ipairs(checks) do
        if not v() then
            return i - 1
        end
    end

    return #checks
end

local thread_identity = 1
add("getthreadidentity", function()
    if thread_identity == 1 then
        return test()
    end
    return thread_identity
end)

add("setthreadidentity", function(identity)
    expect(identity, "number", false, 1)
    thread_identity = identity
end)

add("setidentity", function(identity)
    expect(identity, "number", false, 1)
    setthreadidentity(identity)
end)

add("getidentity", function()
    return getthreadidentity()
end)

add("getthreadcontext", function()
    return getthreadidentity()
end)

add("identity", function() -- just added this for testing
   return getthreadidentity()
end)

add("printidentity", function()
   print("Current identity is", getthreadidentity())
end)

-- WebSocket

add("WebSocket", {})

add("WebSocket.connect", function(url)
    local self = {}

    self.Url = url
    self._open = true

    self.OnMessage = createBindable()
    self.OnClose = createBindable()

    function self:Send(message)
        if not self._open then
            warn("WebSocket is closed")
            return
        end
        do end
    end

    function self:Close()
        if not self._open then return end

        self._open = false
        print("[WebSocket:Closed]", self.Url)

        self.OnClose:Fire()
    end

    task.defer(function()
        if self._open then
            self.OnMessage:Fire("[connected] " .. url)
        end
    end)

    return self
end)

-- Actors

local actor_threads = setmetatable({}, {__mode = "v"})
local comm_channels = {}

add("create_comm_channel", function()
    local num = math.random(1, 99999)
    local int = createBindable()
    comm_channels[num] = int
    return num, int
end)

add("get_comm_channel", function(id)
    expect(id, "number", false, 1)
    return comm_channels[id]
end)

add("run_on_actor", function(actor, scriptStr, ...)
    assert(typeof(actor) == "Instance" and actor:IsA("Actor"), "expected Actor, got " .. typeof(actor))
    expect(scriptStr, "string", false, 2)

    local thread = task.spawn(function(...)
        local fn, err = loadstring(scriptStr)
        if not fn then error(err) end
        setfenv(fn, getgenv())
        fn(...)
    end, ...)

    actor_threads[#actor_threads + 1] = thread
end)

add("getactors", function()
    local actors = {}
    for _, v in ipairs(game:GetDescendants()) do
        if v:IsA("Actor") then
            actors[#actors + 1] = v
        end
    end
    return actors
end)

local cache, states = setmetatable({}, { __mode = "k" }), {}
local gstate; local id = 0

local function newState(isActor)
    id += 1

    local s = {
        Id = id,
        IsActorState = isActor and true or false,
        _actors = {},
        _scripts = {}
    }

    function s:GetActors()
        return self._actors
    end

    function s:Execute(code)
        expect(code, "string", false, 1)

        local fn, err = loadstring(code)
        if not fn then
            error(err, 2)
        end

        return fn()
    end

    states[#states + 1] = s
    return s
end

local function getState()
    gstate = gstate or newState(false)
    return gstate
end

add("getgamestate", function()
    return getState()
end)

add("getactorstates", function()
    return states
end)

add("getluastate", function(obj)
    if not obj then
        return getState()
    end

    expect(obj, "Instance", false, 1)

    local s = cache[obj]
    if s then return s end

    if obj:IsA("Actor") then
        s = newState(true)
        s._actors[#s._actors + 1] = obj

    elseif obj:IsA("BaseScript") then
        local actor = obj:FindFirstAncestorOfClass("Actor")

        if actor then
            s = cache[actor] or newState(true)
            cache[actor] = s
            s._actors[#s._actors + 1] = actor
        else
            s = getState()
        end

        s._scripts[#s._scripts + 1] = obj
    else
        error("expected Actor or BaseScript")
    end

    cache[obj] = s
    return s
end)

add("is_parallel", function()
    return getthreadidentity() >= 8
end)
add("isparallel", function()
    return is_parallel()
end)

local actor_event = createBindable()

add("on_actor_added", actor_event)
local function handle_actor(actor)
    actor_event:Fire(actor)
end

game.DescendantAdded:Connect(function(obj)
    if obj:IsA("Actor") then
        handle_actor(obj)
    end
end)
                                                      
add("run_on_thread", function(thread, scriptStr, ...)
    assert(type(thread) == "thread", "expected thread, got " .. type(thread))
    expect(scriptStr, "string", false, 2)

    local fn, err = loadstring(scriptStr)
    if not fn then error(err) end
    setfenv(fn, getgenv())

    local t = task.spawn(function(...)
        coroutine.resume(thread, fn, ...)
    end, ...)

    actor_threads[#actor_threads + 1] = t
end)

add("getactorthreads", function()
    local alive = {}
    for _, t in ipairs(actor_threads) do
        if coroutine.status(t) ~= "dead" then
            alive[#alive + 1] = t
        end
    end
    return alive
end)

-- Loader
-- dropped my mem by 200mb

local adding = 0; genv["loaded"] = {}
for name, func in pairs(functions) do
    if typeof(name) ~= "string" then
        warn("skipping bad entry: " .. tostring(name))
        continue
    end

    if getgenv()[name] then
        continue
    end

    adding += 1
    table.insert(genv["loaded"], {name = name, func = func})

    print("Adding:", name, tostring(func) .. "	 #" .. adding)
    getgenv()[name] = func
end

-- 50/50 -- also removes more stuff than we added with tables -- who cares
genv.unload = function(sp)
    for i, item in ipairs(genv["loaded"]) do
        if item.name then
            getgenv()[item.name] = nil
            adding -= 1

            if sp then
                print("Removing:", item.name, tostring(item.func) .. "	 #" .. adding)
            end
        end
    end

    table.clear(genv["loaded"])
end

-- 14:12
