if getgenv().UHCore then pcall(function() getgenv().UHCore.StopAll() end) end
getgenv().UHCore=nil
local Players,RS,WS,Lighting,RST=game:GetService("Players"),game:GetService("RunService"),game:GetService("Workspace"),game:GetService("Lighting"),game:GetService("ReplicatedStorage")
local LP,Cam,Conn=Players.LocalPlayer,WS.CurrentCamera,{}
local AttackRemotes,HealRemotes,RepairRemotes,GiftRemotes={},{},{},{}
local CachedGens,CachedPallets,GenCache,CachedGifts,CachedDropZones,CachedCharParts={},{},{},{},{},{}
local LastHeal,LastRepair,LastGenScan,LastPalletScan,LastGiftScan,LastGiftPickup,LastGiftDrop,LastDropZoneScan,SkillHooked,SlowHooked=0,0,0,0,0,0,0,0,false,false
local OrigFog,OrigLight,OrigAtmosphere,OrigBlur={},{},{},{}
local PlayerCache={Killers={},Survivors={},LastUpdate=0}
local StateCache={}
local ChangeOptionRemote=nil
local LastCleanup=0
local FrameSkip=0
local ESPUpdateLock=false
local S={Plr={SP=16,SO=false},Kil={AD=7,AO=false,AB=false,Last=0,CD=4,Can=true},Aim={M=nil,TP="Head",AAO=false,AAD=50,AAS=0.15,Lock=true},ESP={KO=false,SO=false,GO=false,PO=false,GFO=false,FT=0.85,OT=0.5,SD=true},Vis={NF=false,FB=false,CS=12,CG=6,CO=false,CT="Sniper",CD=3,CTH=2},Col={K=Color3.fromRGB(255,80,80),SV=Color3.fromRGB(80,255,80),PL=Color3.fromRGB(255,200,80),GL=Color3.fromRGB(255,0,0),GM=Color3.fromRGB(255,255,0),GH=Color3.fromRGB(0,255,0),CR=Color3.fromRGB(255,255,255),CL=Color3.fromRGB(255,0,0),GF=Color3.fromRGB(255,100,255)},Cam={Mode="Default"},Rep={Gen=false,Heal=false},Gift={GO=false,Range=6}}
local CrosshairTypes,CameraModes,TargetParts={"Sniper","Weapon","Dot"},{"Default","FirstPerson","ThirdPerson"},{"Head","Body","RightArm","LeftArm"}

pcall(function() local opts=RST:FindFirstChild("Remotes") if opts then local o=opts:FindFirstChild("Options") if o then ChangeOptionRemote=o:FindFirstChild("changeoption") end end end)
pcall(function() local R=RST:FindFirstChild("Remotes") if R then local E=R:FindFirstChild("Events") if E then local C=E:FindFirstChild("Christmas") if C then GiftRemotes.Gift=C:FindFirstChild("gift") GiftRemotes.PutDown=C:FindFirstChild("putdown") end end end end)

local function DC(n) if Conn[n] then pcall(function() Conn[n]:Disconnect() end) Conn[n]=nil end end
local function DCAll() for n in pairs(Conn) do DC(n) end end

-- OPTIMIZED: Removed pcall overhead
local function GetChar(p) return p and p.Character end
local function GetHum(c) return c and c:FindFirstChildOfClass("Humanoid") end
local function GetRoot(c) return c and (c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("Torso")) end
local function IsAlive(p) local c=GetChar(p) local h=c and GetHum(c) return h and h.Health>0 end

local function GetPart(c,t) 
    if not c then return nil end 
    if t=="Head" then return c:FindFirstChild("Head") or GetRoot(c)
    elseif t=="Body" then return c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso")
    elseif t=="RightArm" then return c:FindFirstChild("RightHand") or c:FindFirstChild("RightUpperArm") or c:FindFirstChild("Right Arm") or GetRoot(c)
    elseif t=="LeftArm" then return c:FindFirstChild("LeftHand") or c:FindFirstChild("LeftUpperArm") or c:FindFirstChild("Left Arm") or GetRoot(c)
    end
    return GetRoot(c)
end

local function GetRole(p) 
    local c=GetChar(p) 
    if not c then return nil end 
    local r=c:GetAttribute("Role") or c:GetAttribute("PlayerRole") 
    if r then 
        local rs=tostring(r):lower() 
        if rs:find("killer") then return "Killer" elseif rs:find("survivor") then return "Survivor" end 
    end 
    if p.Team then 
        local t=p.Team.Name:lower() 
        if t:find("killer") then return "Killer" elseif t:find("survivor") then return "Survivor" end 
    end 
    return nil 
end

local function GetDist(p) 
    local mr=GetRoot(GetChar(LP)) 
    local tr=GetRoot(GetChar(p)) 
    if mr and tr then return math.floor((mr.Position-tr.Position).Magnitude) end 
    return 0 
end

-- OPTIMIZED: Less frequent update
local function UpdatePlayerCache() 
    if tick()-PlayerCache.LastUpdate<3 then return end 
    PlayerCache.LastUpdate=tick() 
    local newKillers,newSurvivors={},{} 
    for _,p in pairs(Players:GetPlayers()) do 
        if p and p~=LP and p.Parent then 
            local role=GetRole(p) 
            if role=="Killer" then table.insert(newKillers,p) 
            elseif role=="Survivor" or role==nil then table.insert(newSurvivors,p) end 
        end 
    end 
    PlayerCache.Killers=newKillers 
    PlayerCache.Survivors=newSurvivors 
end

local function GetNearestKiller() 
    UpdatePlayerCache() 
    local nearest,nearestDist=nil,999 
    local mr=GetRoot(GetChar(LP)) 
    if not mr then return nil,999 end 
    for _,k in pairs(PlayerCache.Killers) do 
        if k and k.Parent then 
            local kr=GetRoot(GetChar(k)) 
            if kr then 
                local dist=(mr.Position-kr.Position).Magnitude 
                if dist<nearestDist then nearest,nearestDist=k,dist end 
            end 
        end 
    end 
    return nearest,nearestDist 
end

-- OPTIMIZED: Cached attribute names
local BadAttrs={"Knocked","Downed","IsKnocked","IsDowned","isKnocked","isDowned","Down","IsDown","KnockedDown","incapacitated","Incapacitated","Hooked","IsHooked","isHooked","OnHook","Carried","IsCarried","isCarried","BeingCarried","Crouching","IsCrouching","isCrouching","Crouch","IsCrouch"}
local CarryAttrs={"Carrying","IsCarrying","isCarrying","HoldingSurvivor","CarryingSurvivor"}

local function IsPlayerNormal() 
    local c=GetChar(LP) 
    if not c then return false end 
    local h=GetHum(c) 
    if not h or h.Health<=0 then return false end 
    for _,attr in ipairs(BadAttrs) do 
        if c:GetAttribute(attr)==true then return false end 
    end 
    local state=h:GetState() 
    if state==Enum.HumanoidStateType.Physics or state==Enum.HumanoidStateType.PlatformStanding then return false end 
    return true 
end

local function IsCarryingSurvivor() 
    local c=GetChar(LP) 
    if not c then return false end 
    for _,attr in ipairs(CarryAttrs) do 
        if c:GetAttribute(attr)==true then return true end 
    end 
    return false 
end

-- OPTIMIZED: Faster cleanup with less overhead
local function CleanupMemory() 
    if tick()-LastCleanup<20 then return end 
    LastCleanup=tick() 
    local now=tick() 
    for key,data in pairs(StateCache) do 
        if now-data.t>5 then StateCache[key]=nil end 
    end 
    for gen,data in pairs(GenCache) do 
        if now-data.t>20 or not gen or not gen.Parent then GenCache[gen]=nil end 
    end 
end

-- SAFE REMOVE ESP
local function SafeRemovePlayerESP(p) 
    if not p then return end 
    task.defer(function() 
        local c=GetChar(p) 
        if c then 
            local h=c:FindFirstChild("ESP_HL") 
            if h then h:Destroy() end 
            local hd=c:FindFirstChild("Head") 
            if hd then 
                local b=hd:FindFirstChild("ESP_Tag") 
                if b then b:Destroy() end 
            end 
        end 
    end) 
end

-- PLAYER REMOVING HANDLER
local function OnPlayerRemoving(p) 
    if not p then return end 
    task.defer(function() 
        SafeRemovePlayerESP(p) 
        local uid=tostring(p.UserId) 
        StateCache[uid.."_knocked"]=nil 
        StateCache[uid.."_hooked"]=nil 
        StateCache[uid.."_carried"]=nil 
        local newKillers={} 
        for _,k in pairs(PlayerCache.Killers) do 
            if k and k~=p and k.Parent then table.insert(newKillers,k) end 
        end 
        PlayerCache.Killers=newKillers 
        local newSurvivors={} 
        for _,s in pairs(PlayerCache.Survivors) do 
            if s and s~=p and s.Parent then table.insert(newSurvivors,s) end 
        end 
        PlayerCache.Survivors=newSurvivors 
    end) 
end
DC("PlayerRemoving") 
Conn["PlayerRemoving"]=Players.PlayerRemoving:Connect(OnPlayerRemoving)

local Lobby={InGame=false,Running=false,TransitionCD=0}
function Lobby:Check() 
    local c=GetChar(LP) 
    if c then 
        local r=c:GetAttribute("Role") or c:GetAttribute("PlayerRole") 
        if r and (tostring(r):lower():find("killer") or tostring(r):lower():find("survivor")) then return false end 
    end 
    if LP.Team then 
        local t=LP.Team.Name:lower() 
        if t:find("survivor") or t:find("killer") then return false end 
        if t:find("lobby") or t:find("waiting") or t:find("spectator") then return true end 
    end 
    return #CachedGens==0 
end

function Lobby:CleanUp() 
    if tick()-self.TransitionCD<2 then return end 
    self.TransitionCD=tick() 
    task.defer(function() 
        for _,p in pairs(Players:GetPlayers()) do SafeRemovePlayerESP(p) end 
        for _,g in pairs(CachedGens) do if g then local h=g:FindFirstChild("ESP_HL") if h then h:Destroy() end end end 
        for _,pl in pairs(CachedPallets) do if pl then local h=pl:FindFirstChild("ESP_HL") if h then h:Destroy() end end end 
        for _,gf in pairs(CachedGifts) do if gf then local h=gf:FindFirstChild("ESP_HL") if h then h:Destroy() end end end 
        CachedGens,CachedPallets,GenCache,StateCache,CachedGifts,CachedDropZones={},{},{},{},{},{} 
        PlayerCache={Killers={},Survivors={},LastUpdate=0} 
        LastGenScan,LastPalletScan,LastGiftScan,LastDropZoneScan=0,0,0,0 
    end) 
end

function Lobby:Start() 
    if self.Running then return end 
    self.Running=true 
    task.spawn(function() 
        while self.Running do 
            local isLobby=self:Check() 
            local wasInGame=self.InGame 
            self.InGame=not isLobby 
            if wasInGame and not self.InGame then self:CleanUp() end 
            CleanupMemory() 
            task.wait(5) 
        end 
    end) 
end

function Lobby:Stop() self.Running=false end
Lobby:Start()

pcall(function() 
    local R=RST:FindFirstChild("Remotes") 
    if R then 
        local A=R:FindFirstChild("Attacks") 
        if A then 
            AttackRemotes.Basic=A:FindFirstChild("BasicAttack") 
            AttackRemotes.AfterAttack=A:FindFirstChild("AfterAttack") 
            AttackRemotes.Hit=A:FindFirstChild("hit") 
        end 
    end 
    for _,r in pairs(RST:GetDescendants()) do 
        if r:IsA("RemoteEvent") or r:IsA("RemoteFunction") then 
            local n=r.Name:lower() 
            if n:find("heal") or n:find("revive") then table.insert(HealRemotes,r) end 
            if n:find("repair") or n:find("generator") then table.insert(RepairRemotes,r) end 
        end 
    end 
end)

local PS={}
local function GetCachedState(p,stateType,checkFunc) 
    if not p or not p.Parent then return false end 
    local key=tostring(p.UserId).."_"..stateType 
    local cached=StateCache[key] 
    if cached and tick()-cached.t<0.8 then return cached.v end 
    local ok,result=pcall(checkFunc) 
    if not ok then return false end 
    StateCache[key]={v=result,t=tick()} 
    return result 
end

local KnockedAttrs={"Knocked","Downed","IsKnocked","IsDowned","isKnocked","isDowned","Down","IsDown","KnockedDown","incapacitated","Incapacitated"}
local HookedAttrs={"Hooked","IsHooked","isHooked","OnHook","onHook","Sacrificing","BeingSacrificed"}
local CarriedAttrs={"Carried","IsCarried","isCarried","BeingCarried","PickedUp","IsPickedUp","Grabbed","IsGrabbed"}

function PS:Knocked(p) 
    if not p or not p.Parent then return false end 
    return GetCachedState(p,"knocked",function() 
        local c=GetChar(p) 
        if not c then return false end 
        for _,attr in ipairs(KnockedAttrs) do 
            if c:GetAttribute(attr)==true then return true end 
        end 
        local hum=GetHum(c) 
        if hum then 
            local state=hum:GetState() 
            if (state==Enum.HumanoidStateType.Physics or state==Enum.HumanoidStateType.PlatformStanding) and hum.Health<hum.MaxHealth*0.3 then return true end 
        end 
        return false 
    end) 
end

function PS:Hooked(p) 
    if not p or not p.Parent then return false end 
    return GetCachedState(p,"hooked",function() 
        local c=GetChar(p) 
        if not c then return false end 
        for _,attr in ipairs(HookedAttrs) do 
            if c:GetAttribute(attr)==true then return true end 
        end 
        return false 
    end) 
end

function PS:Carried(p) 
    if not p or not p.Parent then return false end 
    return GetCachedState(p,"carried",function() 
        local c=GetChar(p) 
        if not c then return false end 
        for _,attr in ipairs(CarriedAttrs) do 
            if c:GetAttribute(attr)==true then return true end 
        end 
        return false 
    end) 
end

function PS:CanAttack(t) 
    if not t or t==LP or not t.Parent then return false end 
    if not IsAlive(t) then return false end 
    if self:Knocked(t) or self:Hooked(t) or self:Carried(t) then return false end 
    return true 
end

function PS:CanAim(t) 
    if not t or t==LP or not t.Parent then return false end 
    if not IsAlive(t) then return false end 
    if self:Knocked(t) or self:Hooked(t) or self:Carried(t) then return false end 
    return true 
end

function PS:CanAtk() 
    local h=GetHum(GetChar(LP)) 
    if not h or h.Health<=0 then return false end 
    if tick()-S.Kil.Last<S.Kil.CD then return false end 
    if not S.Kil.Can then return false end 
    if IsCarryingSurvivor() then return false end 
    return true 
end

function PS:GetState(p) 
    if not p or not p.Parent then return nil end 
    return {Alive=IsAlive(p),Knocked=self:Knocked(p),Hooked=self:Hooked(p),Carried=self:Carried(p),CanAim=self:CanAim(p)} 
end

-- OPTIMIZED: Longer scan intervals
local function ScanGens() 
    if tick()-LastGenScan<45 then return CachedGens end 
    if Lobby:Check() then CachedGens={} return CachedGens end 
    LastGenScan=tick() 
    local newGens={} 
    local mapFolder=WS:FindFirstChild("Map") or WS 
    for _,o in pairs(mapFolder:GetDescendants()) do 
        local n=o.Name:lower() 
        if (n=="generator" or n:find("generator") or n=="gen") and (o:IsA("Model") or o:IsA("BasePart")) then 
            table.insert(newGens,o) 
        end 
    end 
    CachedGens=newGens 
    return CachedGens 
end

local function GetGenStatus(g) 
    if not g or not g.Parent then return "RUSAK",0 end 
    local c=GenCache[g] 
    if c and tick()-c.t<12 then return c.s,c.p end 
    local prog=0 
    for n,v in pairs(g:GetAttributes()) do 
        local nl=n:lower() 
        if nl:find("progress") and type(v)=="number" then prog=v break end 
        if (nl:find("complete") or nl:find("done") or nl:find("power")) and v==true then prog=100 break end 
    end 
    if prog==0 then 
        for _,ch in pairs(g:GetChildren()) do 
            if (ch:IsA("NumberValue") or ch:IsA("IntValue")) and (ch.Name:lower():find("progress") or ch.Name:lower():find("power")) then 
                prog=ch.Value break 
            end 
        end 
    end 
    local st=prog>=100 and "HIDUP" or prog>=50 and "PROGRESS" or prog>0 and "LOW" or "RUSAK" 
    GenCache[g]={s=st,p=prog,t=tick()} 
    return st,prog 
end

local function GetGenCol(g) 
    local st=GetGenStatus(g) 
    return st=="HIDUP" and S.Col.GH or st=="PROGRESS" and S.Col.GM or S.Col.GL 
end

local function SetupSkill() 
    if SkillHooked then return end 
    SkillHooked=true 
    pcall(function() 
        local old old=hookmetamethod(game,"__namecall",newcclosure(function(self,...) 
            local m,a=getnamecallmethod(),{...} 
            if (S.Rep.Gen or S.Rep.Heal) and (m=="FireServer" or m=="InvokeServer") and tostring(self):lower():find("skill") then 
                a[1],a[2]="Perfect",true 
                return old(self,unpack(a)) 
            end 
            return old(self,...) 
        end)) 
    end) 
end

local function SetupAntiSlow() 
    if SlowHooked then return end 
    SlowHooked=true 
    pcall(function() 
        local FallRemote=RST:FindFirstChild("Remotes") and RST.Remotes:FindFirstChild("Mechanics") and RST.Remotes.Mechanics:FindFirstChild("Fall") 
        local SlowRemote=RST:FindFirstChild("Remotes") and RST.Remotes:FindFirstChild("Mechanics") and RST.Remotes.Mechanics:FindFirstChild("Slowserver") 
        if FallRemote then 
            pcall(function() 
                local oldFall oldFall=hookfunction(FallRemote.FireServer,newcclosure(function(self,...) 
                    if rawequal(self,FallRemote) then return nil end 
                    return oldFall(self,...) 
                end)) 
            end) 
        end 
        if SlowRemote then 
            pcall(function() 
                local oldSlow oldSlow=hookfunction(SlowRemote.FireServer,newcclosure(function(self,...) 
                    if rawequal(self,SlowRemote) then return nil end 
                    return oldSlow(self,...) 
                end)) 
            end) 
        end 
    end) 
    pcall(function() 
        local old old=hookmetamethod(game,"__namecall",newcclosure(function(self,...) 
            local m=getnamecallmethod() 
            if m=="FireServer" then 
                local n=tostring(self):lower() 
                if n:find("fall") or n:find("slowserver") or n:find("slow") then return nil end 
            end 
            return old(self,...) 
        end)) 
    end) 
end

local function StartHeal() 
    if S.Rep.Heal then return end 
    S.Rep.Heal=true 
    SetupSkill() 
    task.spawn(function() 
        while S.Rep.Heal do 
            task.wait(1.2) 
            if not S.Rep.Heal then break end 
            if Lobby:Check() then task.wait(3) continue end 
            local mr=GetRoot(GetChar(LP)) 
            if not mr then continue end 
            for _,p in pairs(Players:GetPlayers()) do 
                if p and p~=LP and p.Parent then 
                    local h=GetHum(GetChar(p)) 
                    if h and h.Health<h.MaxHealth*0.95 then 
                        local tr=GetRoot(GetChar(p)) 
                        if tr and (mr.Position-tr.Position).Magnitude<10 then 
                            local pc=GetChar(p) 
                            if pc then 
                                for _,o in pairs(pc:GetChildren()) do 
                                    if o:IsA("ProximityPrompt") then pcall(fireproximityprompt,o) break end 
                                end 
                            end 
                            for _,r in pairs(HealRemotes) do pcall(function() r:FireServer(p) end) end 
                            break 
                        end 
                    end 
                end 
            end 
        end 
    end) 
end

local function StopHeal() S.Rep.Heal=false end

local function StartRepair() 
    if S.Rep.Gen then return end 
    S.Rep.Gen=true 
    SetupSkill() 
    task.spawn(function() 
        while S.Rep.Gen do 
            task.wait(1.2) 
            if not S.Rep.Gen then break end 
            if Lobby:Check() then task.wait(3) continue end 
            local mr=GetRoot(GetChar(LP)) 
            if not mr then continue end 
            ScanGens() 
            for _,g in pairs(CachedGens) do 
                if g and g.Parent and GetGenStatus(g)~="HIDUP" then 
                    local ok,pos=pcall(function() return g:IsA("Model") and g:GetBoundingBox().Position or g.Position end) 
                    if ok and pos and (mr.Position-pos).Magnitude<10 then 
                        for _,o in pairs(g:GetChildren()) do 
                            if o:IsA("ProximityPrompt") then pcall(fireproximityprompt,o) break end 
                        end 
                        for _,r in pairs(RepairRemotes) do pcall(function() r:FireServer(g) end) end 
                        break 
                    end 
                end 
            end 
        end 
    end) 
end

local function StopRepair() S.Rep.Gen=false end

-- OPTIMIZED: Cache drop zones separately, scan less frequently
local function ScanDropZones() 
    if tick()-LastDropZoneScan<120 then return CachedDropZones end 
    LastDropZoneScan=tick() 
    CachedDropZones={} 
    local mapFolder=WS:FindFirstChild("Map") or WS 
    for _,obj in pairs(mapFolder:GetDescendants()) do 
        local name=obj.Name:lower() 
        if (name:find("drop") or name:find("tree") or name:find("giftzone")) and obj:IsA("BasePart") then 
            table.insert(CachedDropZones,obj) 
        end 
    end 
    return CachedDropZones 
end

-- OPTIMIZED: Longer scan interval for gifts
local function ScanGifts() 
    if tick()-LastGiftScan<5 then return CachedGifts end 
    LastGiftScan=tick() 
    local newGifts={} 
    local mapFolder=WS:FindFirstChild("Map") or WS 
    for _,obj in pairs(mapFolder:GetDescendants()) do 
        local name=obj.Name:lower() 
        if (name:find("gift") or name:find("present")) and not name:find("tree") and not name:find("zone") and not name:find("drop") and (obj:IsA("Model") or obj:IsA("BasePart")) then 
            table.insert(newGifts,obj) 
        end 
    end 
    for _,obj in pairs(WS:GetChildren()) do 
        local name=obj.Name:lower() 
        if (name:find("gift") or name:find("present")) and not name:find("tree") and (obj:IsA("Model") or obj:IsA("BasePart")) then 
            local found=false 
            for _,g in pairs(newGifts) do if g==obj then found=true break end end 
            if not found then table.insert(newGifts,obj) end 
        end 
    end 
    CachedGifts=newGifts 
    return CachedGifts 
end

local function GetGiftPosition(gift) 
    if not gift or not gift.Parent then return nil end 
    if gift:IsA("Model") then 
        local ok,cf=pcall(function() return gift:GetBoundingBox() end) 
        if ok and cf then return cf.Position end 
        local part=gift:FindFirstChildWhichIsA("BasePart") 
        if part then return part.Position end 
    elseif gift:IsA("BasePart") then 
        return gift.Position 
    end 
    return nil 
end

local function IsHoldingGift() 
    local c=GetChar(LP) 
    if not c then return false end 
    for _,child in pairs(c:GetChildren()) do 
        local name=child.Name:lower() 
        if name:find("gift") or name:find("present") then return true end 
    end 
    return false 
end

-- OPTIMIZED: Use cached drop zones instead of scanning every frame
local function DoGift() 
    if not S.Gift.GO then return end 
    local root=GetRoot(GetChar(LP)) 
    if not root then return end 
    local myPos=root.Position 
    
    if tick()-LastGiftPickup>1.5 then 
        ScanGifts() 
        for _,gift in pairs(CachedGifts) do 
            if gift and gift.Parent then 
                local pos=GetGiftPosition(gift) 
                if pos and (myPos-pos).Magnitude<=S.Gift.Range then 
                    LastGiftPickup=tick() 
                    if GiftRemotes.Gift then pcall(function() GiftRemotes.Gift:FireServer(gift) end) end 
                    for _,prompt in pairs(gift:GetDescendants()) do 
                        if prompt:IsA("ProximityPrompt") then pcall(function() fireproximityprompt(prompt) end) end 
                    end 
                    break 
                end 
            end 
        end 
    end 
    
    if tick()-LastGiftDrop>2.5 then 
        if IsHoldingGift() then 
            ScanDropZones() 
            for _,obj in pairs(CachedDropZones) do 
                if obj and obj.Parent then 
                    local dist=(myPos-obj.Position).Magnitude 
                    if dist<=S.Gift.Range then 
                        LastGiftDrop=tick() 
                        if GiftRemotes.PutDown then pcall(function() GiftRemotes.PutDown:FireServer() end) end 
                        for _,prompt in pairs(obj:GetDescendants()) do 
                            if prompt:IsA("ProximityPrompt") then pcall(function() fireproximityprompt(prompt) end) end 
                        end 
                        break 
                    end 
                end 
            end 
        end 
    end 
end

local function StartGift() 
    if S.Gift.GO then return end 
    S.Gift.GO=true 
    DC("GiftLoop") 
    Conn["GiftLoop"]=RS.Heartbeat:Connect(function() 
        FrameSkip=FrameSkip+1 
        if FrameSkip%8~=0 then return end 
        if not S.Gift.GO then return end 
        if Lobby:Check() then return end 
        DoGift() 
    end) 
end

local function StopGift() S.Gift.GO=false DC("GiftLoop") end

-- GIFT ESP
local function MakeGiftHL(t) 
    if not t or not t.Parent then return end 
    local h=t:FindFirstChild("ESP_HL") 
    if h then h.FillColor,h.OutlineColor=S.Col.GF,S.Col.GF return end 
    local hl=Instance.new("Highlight") 
    hl.Name,hl.FillColor,hl.OutlineColor,hl.FillTransparency,hl.OutlineTransparency,hl.Parent="ESP_HL",S.Col.GF,S.Col.GF,S.ESP.FT,S.ESP.OT,t 
end

local function StartGiftESP() 
    if S.ESP.GFO then return end 
    S.ESP.GFO=true 
    task.spawn(function() 
        while S.ESP.GFO do 
            if ESPUpdateLock then task.wait(1) continue end 
            if Lobby:Check() then 
                for _,gf in pairs(CachedGifts) do 
                    if gf then local h=gf:FindFirstChild("ESP_HL") if h then h:Destroy() end end 
                end 
                task.wait(3) continue 
            end 
            ScanGifts() 
            for _,gf in pairs(CachedGifts) do 
                if gf and gf.Parent then MakeGiftHL(gf) end 
            end 
            task.wait(4) 
        end 
    end) 
end

local function StopGiftESP() 
    S.ESP.GFO=false 
    for _,gf in pairs(CachedGifts) do 
        if gf then local h=gf:FindFirstChild("ESP_HL") if h then h:Destroy() end end 
    end 
end

local WSys={On=false,Spd=16,Def=16,Hooked=false}

function WSys:Apply() 
    if not self.On then return end 
    local c=GetChar(LP) 
    if not c then return end 
    local h=GetHum(c) 
    if not h then return end 
    if not IsPlayerNormal() then return end 
    h.WalkSpeed=self.Spd 
end

function WSys:HookSpeed() 
    if self.Hooked then return end 
    self.Hooked=true 
    pcall(function() 
        local mt=getrawmetatable(game) 
        if not mt then return end 
        local oldIdx=mt.__newindex 
        setreadonly(mt,false) 
        mt.__newindex=newcclosure(function(t,k,v) 
            if self.On and k=="WalkSpeed" and t:IsA("Humanoid") then 
                local char=t.Parent 
                if char and char==GetChar(LP) then 
                    if IsPlayerNormal() then return oldIdx(t,k,self.Spd) else return oldIdx(t,k,v) end 
                end 
            end 
            return oldIdx(t,k,v) 
        end) 
        setreadonly(mt,true) 
    end) 
end

function WSys:TryRemotes() 
    if not ChangeOptionRemote then return end 
    pcall(function() ChangeOptionRemote:FireServer("WalkSpeed",self.Spd) end) 
    pcall(function() ChangeOptionRemote:FireServer("Speed",self.Spd) end) 
end

function WSys:SetSpeed(v) 
    v=tonumber(v) or self.Spd 
    self.Spd=math.clamp(v,1,500) 
    S.Plr.SP=self.Spd 
    if self.On then self:Apply() end 
    return self.Spd 
end

function WSys:Start() 
    if self.On then return end 
    self.On,S.Plr.SO=true,true 
    self.Spd=S.Plr.SP or 16 
    self:HookSpeed() 
    self:Apply() 
    self:TryRemotes() 
    DC("WSLoop") 
    Conn["WSLoop"]=RS.Heartbeat:Connect(function() 
        FrameSkip=FrameSkip+1 
        if FrameSkip%15~=0 then return end 
        if not self.On then return end 
        if Lobby:Check() then return end 
        local c=GetChar(LP) 
        if not c then return end 
        local h=GetHum(c) 
        if not h then return end 
        if IsPlayerNormal() and h.WalkSpeed~=self.Spd then h.WalkSpeed=self.Spd end 
    end) 
    DC("WSChar") 
    Conn["WSChar"]=LP.CharacterAdded:Connect(function() 
        if self.On then 
            task.wait(0.3) self:Apply() self:TryRemotes() 
            task.wait(1) self:Apply() 
        end 
    end) 
end

function WSys:Stop() 
    self.On,S.Plr.SO=false,false 
    DC("WSLoop") DC("WSChar") 
    local c=GetChar(LP) 
    if c then local h=GetHum(c) if h then h.WalkSpeed=self.Def end end 
end

local Aim={Target=nil,Active=false}

function Aim:GetClosest(max) 
    if Lobby:Check() then return nil end 
    local myChar=GetChar(LP) 
    if not myChar then return nil end 
    local myHum=GetHum(myChar) 
    if not myHum or myHum.Health<=0 then return nil end 
    local myRoot=GetRoot(myChar) 
    if not myRoot then return nil end 
    local closestPlayer,closestDist=nil,max 
    local myPos=myRoot.Position 
    UpdatePlayerCache() 
    local targetList=S.Aim.M=="Killer" and PlayerCache.Killers or S.Aim.M=="Survivor" and PlayerCache.Survivors or Players:GetPlayers() 
    for _,player in pairs(targetList) do 
        if player and player~=LP and player.Parent and PS:CanAim(player) then 
            local targetChar=GetChar(player) 
            if targetChar then 
                local targetPart=GetPart(targetChar,S.Aim.TP) 
                if targetPart then 
                    local dist=(myPos-targetPart.Position).Magnitude 
                    if dist<closestDist then closestDist=dist closestPlayer=player end 
                end 
            end 
        end 
    end 
    return closestPlayer 
end

function Aim:Start() 
    if self.Active then return end 
    self.Active,S.Aim.AAO=true,true 
    DC("Aim") 
    Conn["Aim"]=RS.RenderStepped:Connect(function() 
        if not self.Active or not S.Aim.AAO then return end 
        if Lobby:Check() then self.Target=nil return end 
        Cam=WS.CurrentCamera 
        if not Cam then return end 
        if self.Target and not PS:CanAim(self.Target) then self.Target=nil end 
        local target=self:GetClosest(S.Aim.AAD) 
        self.Target=target 
        if target then 
            local targetChar=GetChar(target) 
            if targetChar then 
                local targetPart=GetPart(targetChar,S.Aim.TP) 
                if targetPart then 
                    local targetPos=targetPart.Position 
                    local camPos=Cam.CFrame.Position 
                    if S.Aim.Lock then Cam.CFrame=CFrame.lookAt(camPos,targetPos) 
                    else Cam.CFrame=Cam.CFrame:Lerp(CFrame.new(camPos,targetPos),S.Aim.AAS) end 
                end 
            end 
        end 
    end) 
end

function Aim:Stop() self.Active,S.Aim.AAO,self.Target=false,false,nil DC("Aim") end
function Aim:SetPart(p) if p and table.find(TargetParts,p) then S.Aim.TP=p end end
function Aim:SetMode(m) S.Aim.M=(m=="All" or m=="Everyone") and nil or m end
function Aim:SetDist(d) S.Aim.AAD=math.clamp(d,1,200) end
function Aim:SetLock(e) S.Aim.Lock=e end

-- ESP FUNCTIONS
local function MakeHL(t,c) 
    if not t or not t.Parent then return end 
    local h=t:FindFirstChild("ESP_HL") 
    if h then h.FillColor,h.OutlineColor,h.FillTransparency,h.OutlineTransparency=c,c,S.ESP.FT,S.ESP.OT return end 
    local hl=Instance.new("Highlight") 
    hl.Name,hl.FillColor,hl.OutlineColor,hl.FillTransparency,hl.OutlineTransparency,hl.Parent="ESP_HL",c,c,S.ESP.FT,S.ESP.OT,t 
end

local function MakeTag(c,n,col,dist) 
    if not c or not c.Parent then return end 
    local hd=c:FindFirstChild("Head") 
    if not hd then return end 
    local b=hd:FindFirstChild("ESP_Tag") 
    if b then 
        local nl=b:FindFirstChild("NL") 
        local dl=b:FindFirstChild("DL") 
        if nl then nl.Text,nl.TextColor3=n,col end 
        if dl then dl.Text,dl.TextColor3,dl.Visible=dist.."m",col,S.ESP.SD end 
        return 
    end 
    local bg=Instance.new("BillboardGui") 
    bg.Name,bg.Size,bg.StudsOffset,bg.AlwaysOnTop,bg.Parent="ESP_Tag",UDim2.new(0,100,0,40),Vector3.new(0,2.5,0),true,hd 
    local nl=Instance.new("TextLabel") 
    nl.Name,nl.Size,nl.Position,nl.BackgroundTransparency,nl.Text,nl.TextColor3,nl.TextStrokeTransparency,nl.Font,nl.TextSize,nl.Parent="NL",UDim2.new(1,0,0.5,0),UDim2.new(0,0,0,0),1,n,col,0.3,Enum.Font.SourceSansBold,14,bg 
    local dl=Instance.new("TextLabel") 
    dl.Name,dl.Size,dl.Position,dl.BackgroundTransparency,dl.Text,dl.TextColor3,dl.TextStrokeTransparency,dl.Font,dl.TextSize,dl.Visible,dl.Parent="DL",UDim2.new(1,0,0.5,0),UDim2.new(0,0,0.5,0),1,dist.."m",col,0.3,Enum.Font.GothamBold,10,S.ESP.SD,bg 
end

local function RemESP(t) 
    if not t then return end 
    local h=t:FindFirstChild("ESP_HL") if h then h:Destroy() end 
    local hd=t:FindFirstChild("Head") 
    if hd then local b=hd:FindFirstChild("ESP_Tag") if b then b:Destroy() end end 
end

local function CleanAllESP() 
    ESPUpdateLock=true 
    task.defer(function() 
        for _,p in pairs(Players:GetPlayers()) do RemESP(GetChar(p)) end 
        for _,g in pairs(CachedGens) do if g then local h=g:FindFirstChild("ESP_HL") if h then h:Destroy() end end end 
        for _,pl in pairs(CachedPallets) do if pl then local h=pl:FindFirstChild("ESP_HL") if h then h:Destroy() end end end 
        for _,gf in pairs(CachedGifts) do if gf then local h=gf:FindFirstChild("ESP_HL") if h then h:Destroy() end end end 
        ESPUpdateLock=false 
    end) 
end

-- OPTIMIZED: Longer ESP update intervals
local function StartKESP() 
    if S.ESP.KO then return end 
    S.ESP.KO=true 
    task.spawn(function() 
        while S.ESP.KO do 
            if ESPUpdateLock then task.wait(1) continue end 
            if Lobby:Check() then CleanAllESP() task.wait(3) continue end 
            UpdatePlayerCache() 
            for _,p in pairs(PlayerCache.Killers) do 
                if p and p.Parent then 
                    local c=GetChar(p) 
                    if c and c.Parent then MakeHL(c,S.Col.K) MakeTag(c,p.Name,S.Col.K,GetDist(p)) end 
                end 
            end 
            task.wait(3) 
        end 
    end) 
end

local function StopKESP() 
    S.ESP.KO=false 
    task.defer(function() for _,p in pairs(Players:GetPlayers()) do RemESP(GetChar(p)) end end) 
end

local function StartSESP() 
    if S.ESP.SO then return end 
    S.ESP.SO=true 
    task.spawn(function() 
        while S.ESP.SO do 
            if ESPUpdateLock then task.wait(1) continue end 
            if Lobby:Check() then CleanAllESP() task.wait(3) continue end 
            UpdatePlayerCache() 
            for _,p in pairs(PlayerCache.Survivors) do 
                if p and p.Parent then 
                    local c=GetChar(p) 
                    if c and c.Parent then MakeHL(c,S.Col.SV) MakeTag(c,p.Name,S.Col.SV,GetDist(p)) end 
                end 
            end 
            task.wait(3) 
        end 
    end) 
end

local function StopSESP() 
    S.ESP.SO=false 
    task.defer(function() for _,p in pairs(Players:GetPlayers()) do RemESP(GetChar(p)) end end) 
end

local function StartGESP() 
    if S.ESP.GO then return end 
    S.ESP.GO=true 
    task.spawn(function() 
        while S.ESP.GO do 
            if ESPUpdateLock then task.wait(1) continue end 
            if Lobby:Check() then 
                for _,g in pairs(CachedGens) do if g then local h=g:FindFirstChild("ESP_HL") if h then h:Destroy() end end end 
                task.wait(3) continue 
            end 
            ScanGens() 
            for _,g in pairs(CachedGens) do if g and g.Parent then MakeHL(g,GetGenCol(g)) end end 
            task.wait(6) 
        end 
    end) 
end

local function StopGESP() 
    S.ESP.GO=false 
    for _,g in pairs(CachedGens) do if g then local h=g:FindFirstChild("ESP_HL") if h then h:Destroy() end end end 
    CachedGens,GenCache={},{} 
end

local function ScanPallets() 
    if tick()-LastPalletScan<180 then return CachedPallets end 
    if Lobby:Check() then CachedPallets={} return CachedPallets end 
    LastPalletScan=tick() 
    local newPallets={} 
    local mapFolder=WS:FindFirstChild("Map") or WS 
    for _,o in pairs(mapFolder:GetDescendants()) do 
        if o.Name=="Palletwrong" then table.insert(newPallets,o) end 
    end 
    CachedPallets=newPallets 
    return CachedPallets 
end

local function StartPESP() 
    if S.ESP.PO then return end 
    S.ESP.PO=true 
    task.spawn(function() 
        while S.ESP.PO do 
            if ESPUpdateLock then task.wait(1) continue end 
            if Lobby:Check() then 
                for _,pl in pairs(CachedPallets) do if pl then local h=pl:FindFirstChild("ESP_HL") if h then h:Destroy() end end end 
                task.wait(5) continue 
            end 
            ScanPallets() 
            for _,pl in pairs(CachedPallets) do if pl and pl.Parent then MakeHL(pl,S.Col.PL) end end 
            task.wait(10) 
        end 
    end) 
end

local function StopPESP() 
    S.ESP.PO=false 
    for _,pl in pairs(CachedPallets) do if pl then local h=pl:FindFirstChild("ESP_HL") if h then h:Destroy() end end end 
    CachedPallets={} 
end

-- NO FOG
local function SaveOriginalLighting() 
    OrigFog.FogEnd=Lighting.FogEnd 
    OrigFog.FogStart=Lighting.FogStart 
    OrigFog.FogColor=Lighting.FogColor 
    OrigAtmosphere={} 
    OrigBlur={} 
    for _,v in pairs(Lighting:GetChildren()) do 
        if v:IsA("Atmosphere") then OrigAtmosphere[v]={Density=v.Density,Offset=v.Offset,Color=v.Color,Decay=v.Decay,Glare=v.Glare,Haze=v.Haze} end 
        if v:IsA("BlurEffect") then OrigBlur[v]={Enabled=v.Enabled,Size=v.Size} end 
    end 
end

local function StartFog() 
    if S.Vis.NF then return end 
    S.Vis.NF=true 
    SaveOriginalLighting() 
    Lighting.FogEnd=9999 
    Lighting.FogStart=0 
    Lighting.FogColor=Color3.fromRGB(180,180,190) 
    for _,v in pairs(Lighting:GetChildren()) do 
        if v:IsA("Atmosphere") then v.Density=0.05 v.Offset=0 v.Haze=0 v.Glare=0 end 
        if v:IsA("BlurEffect") then v.Enabled=false end 
    end 
end

local function StopFog() 
    S.Vis.NF=false 
    Lighting.FogEnd=OrigFog.FogEnd or 1000 
    Lighting.FogStart=OrigFog.FogStart or 0 
    Lighting.FogColor=OrigFog.FogColor or Color3.fromRGB(128,128,128) 
    for v,data in pairs(OrigAtmosphere) do 
        if v and v.Parent then v.Density=data.Density v.Offset=data.Offset v.Color=data.Color v.Decay=data.Decay v.Glare=data.Glare v.Haze=data.Haze end 
    end 
    for v,data in pairs(OrigBlur) do if v and v.Parent then v.Enabled=data.Enabled v.Size=data.Size end end 
    OrigAtmosphere={} OrigBlur={} 
end

-- FULLBRIGHT
local function SaveOriginalBright() 
    OrigLight.Brightness=Lighting.Brightness 
    OrigLight.ClockTime=Lighting.ClockTime 
    OrigLight.GeographicLatitude=Lighting.GeographicLatitude 
    OrigLight.GlobalShadows=Lighting.GlobalShadows 
    OrigLight.Ambient=Lighting.Ambient 
    OrigLight.OutdoorAmbient=Lighting.OutdoorAmbient 
    OrigLight.ExposureCompensation=Lighting.ExposureCompensation 
    OrigLight.EnvironmentDiffuseScale=Lighting.EnvironmentDiffuseScale 
    OrigLight.EnvironmentSpecularScale=Lighting.EnvironmentSpecularScale 
    OrigLight.ShadowSoftness=Lighting.ShadowSoftness 
end

local function SetBright(e) 
    S.Vis.FB=e 
    if e then 
        SaveOriginalBright() 
        Lighting.ClockTime=6 
        Lighting.GeographicLatitude=40 
        Lighting.Brightness=1 
        Lighting.GlobalShadows=true 
        Lighting.Ambient=Color3.fromRGB(120,120,130) 
        Lighting.OutdoorAmbient=Color3.fromRGB(130,130,140) 
        Lighting.ExposureCompensation=0.1 
        Lighting.EnvironmentDiffuseScale=0.5 
        Lighting.EnvironmentSpecularScale=0.5 
        Lighting.ShadowSoftness=0.2 
        for _,v in pairs(Lighting:GetChildren()) do 
            if v:IsA("Atmosphere") then v.Density=0.2 v.Offset=0.1 end 
            if v:IsA("ColorCorrectionEffect") then v.Brightness=0 v.Contrast=0 v.Saturation=0 end 
        end 
    else 
        Lighting.Brightness=OrigLight.Brightness or 1 
        Lighting.ClockTime=OrigLight.ClockTime or 14 
        Lighting.GeographicLatitude=OrigLight.GeographicLatitude or 41.733 
        Lighting.GlobalShadows=OrigLight.GlobalShadows~=false 
        Lighting.Ambient=OrigLight.Ambient or Color3.fromRGB(0,0,0) 
        Lighting.OutdoorAmbient=OrigLight.OutdoorAmbient or Color3.fromRGB(128,128,128) 
        Lighting.ExposureCompensation=OrigLight.ExposureCompensation or 0 
        Lighting.EnvironmentDiffuseScale=OrigLight.EnvironmentDiffuseScale or 1 
        Lighting.EnvironmentSpecularScale=OrigLight.EnvironmentSpecularScale or 1 
        Lighting.ShadowSoftness=OrigLight.ShadowSoftness or 0.2 
    end 
end

local function StartLag() settings().Rendering.QualityLevel=Enum.QualityLevel.Level01 end
local function StopLag() settings().Rendering.QualityLevel=Enum.QualityLevel.Automatic end

-- AUTO ATTACK
local function StartAtk() 
    if S.Kil.AO then return end 
    S.Kil.AO,S.Kil.Can=true,true 
    task.spawn(function() 
        while S.Kil.AO do 
            task.wait(0.6) 
            if not S.Kil.AO then break end 
            if not PS:CanAtk() then continue end 
            if Lobby:Check() then task.wait(3) continue end 
            local mr=GetRoot(GetChar(LP)) 
            if not mr then continue end 
            local myPos=mr.Position 
            local targetFound=nil 
            local closestDist=S.Kil.AD+1 
            for _,p in pairs(Players:GetPlayers()) do 
                if p and p~=LP and p.Parent and PS:CanAttack(p) and GetRole(p)~="Killer" then 
                    local tr=GetRoot(GetChar(p)) 
                    if tr then 
                        local dist=(myPos-tr.Position).Magnitude 
                        if dist<=S.Kil.AD and dist<closestDist then closestDist=dist targetFound=p end 
                    end 
                end 
            end 
            if targetFound then 
                S.Kil.Can=false S.Kil.Last=tick() 
                pcall(function() if AttackRemotes.Basic then AttackRemotes.Basic:FireServer() end end) 
                task.wait(0.3) 
                pcall(function() if AttackRemotes.Hit then AttackRemotes.Hit:FireServer(targetFound) end end) 
                task.wait(0.1) 
                pcall(function() if AttackRemotes.AfterAttack then AttackRemotes.AfterAttack:FireServer() end end) 
                task.delay(S.Kil.CD,function() S.Kil.Can=true end) 
            end 
        end 
    end) 
end

local function StopAtk() S.Kil.AO=false end
local function SetAtkDist(d) S.Kil.AD=math.clamp(d,3,10) end
local function SetAtkCD(c) S.Kil.CD=math.clamp(c,2,6) end

local function StartBlind() 
    if S.Kil.AB then return end 
    S.Kil.AB=true 
    task.spawn(function() 
        while S.Kil.AB do 
            task.wait(0.8) 
            if not S.Kil.AB then break end 
            local pg=LP:FindFirstChild("PlayerGui") 
            if not pg then continue end 
            for _,g in pairs(pg:GetChildren()) do 
                if g:IsA("ScreenGui") then 
                    for _,f in pairs(g:GetChildren()) do 
                        if (f:IsA("Frame") or f:IsA("ImageLabel")) and f.Name:lower():find("blind") then f.Visible=false end 
                    end 
                end 
            end 
        end 
    end) 
end

local function StopBlind() S.Kil.AB=false end

-- OPTIMIZED FIRST PERSON: Cache character parts, update only when needed
local function CacheCharacterParts() 
    CachedCharParts={} 
    local c=GetChar(LP) 
    if c then 
        for _,part in pairs(c:GetDescendants()) do 
            if part:IsA("BasePart") then table.insert(CachedCharParts,part) end 
        end 
    end 
end

local function HideCharacter() 
    local c=GetChar(LP) 
    if not c then return end 
    for _,part in pairs(c:GetDescendants()) do 
        if part:IsA("BasePart") then part.LocalTransparencyModifier=1 end 
        if part:IsA("Decal") or part:IsA("Texture") then part.Transparency=1 end 
    end 
    CacheCharacterParts() 
end

local function ShowCharacter() 
    local c=GetChar(LP) 
    if not c then return end 
    for _,part in pairs(c:GetDescendants()) do 
        if part:IsA("BasePart") then part.LocalTransparencyModifier=0 end 
        if part:IsA("Decal") or part:IsA("Texture") then part.Transparency=0 end 
    end 
    CachedCharParts={} 
end

-- OPTIMIZED: Use cached parts instead of GetDescendants every frame
local FPFrameSkip=0
local function SetCam(m) 
    S.Cam.Mode=m 
    LP.CameraMode=Enum.CameraMode.Classic 
    DC("FPHide") 
    if m=="FirstPerson" then 
        LP.CameraMinZoomDistance,LP.CameraMaxZoomDistance=0,0.5 
        HideCharacter() 
        Conn["FPHide"]=RS.RenderStepped:Connect(function() 
            FPFrameSkip=FPFrameSkip+1 
            if FPFrameSkip%3~=0 then return end 
            if S.Cam.Mode~="FirstPerson" then return end 
            for _,part in pairs(CachedCharParts) do 
                if part and part.Parent then part.LocalTransparencyModifier=1 end 
            end 
        end) 
    elseif m=="ThirdPerson" then 
        LP.CameraMinZoomDistance,LP.CameraMaxZoomDistance=10,50 
        ShowCharacter() 
    else 
        LP.CameraMinZoomDistance,LP.CameraMaxZoomDistance=0.5,128 
        ShowCharacter() 
    end 
end

local Cross={On=false,D={},DrawingSupported=false,Initialized=false}

local function CheckDrawingSupport() 
    local success=pcall(function() 
        if Drawing and Drawing.new then 
            local test=Drawing.new("Line") 
            if test then test:Remove() return true end 
        end 
        return false 
    end) 
    Cross.DrawingSupported=success 
    return success 
end

function Cross:ClearDrawings() 
    for _,drawing in pairs(self.D) do 
        pcall(function() if drawing then drawing.Visible=false drawing:Remove() end end) 
    end 
    self.D={} 
end

function Cross:GetCenter() 
    Cam=WS.CurrentCamera 
    if Cam then local vp=Cam.ViewportSize return vp.X/2,vp.Y/2 end 
    return 960,540 
end

function Cross:Make() 
    self:ClearDrawings() 
    if not self.DrawingSupported then if not CheckDrawingSupport() then return false end end 
    local cx,cy=self:GetCenter() 
    local success=pcall(function() 
        if S.Vis.CT=="Dot" then 
            self.D.Dot=Drawing.new("Circle") 
            self.D.Dot.Filled=true self.D.Dot.Radius=S.Vis.CD self.D.Dot.Color=S.Col.CR 
            self.D.Dot.Transparency=1 self.D.Dot.Position=Vector2.new(cx,cy) self.D.Dot.Visible=true 
        elseif S.Vis.CT=="Weapon" then 
            self.D.Circ=Drawing.new("Circle") 
            self.D.Circ.Filled=false self.D.Circ.Radius=S.Vis.CS self.D.Circ.Color=S.Col.CR 
            self.D.Circ.Thickness=S.Vis.CTH self.D.Circ.Transparency=1 
            self.D.Circ.Position=Vector2.new(cx,cy) self.D.Circ.Visible=true 
            self.D.Dot=Drawing.new("Circle") 
            self.D.Dot.Filled=true self.D.Dot.Radius=2 self.D.Dot.Color=S.Col.CR 
            self.D.Dot.Transparency=1 self.D.Dot.Position=Vector2.new(cx,cy) self.D.Dot.Visible=true 
        else 
            self.D.Dot=Drawing.new("Circle") 
            self.D.Dot.Filled=true self.D.Dot.Radius=S.Vis.CD self.D.Dot.Color=S.Col.CR 
            self.D.Dot.Transparency=1 self.D.Dot.Position=Vector2.new(cx,cy) self.D.Dot.Visible=true 
            local sz,gp=S.Vis.CS,S.Vis.CG 
            self.D.Top=Drawing.new("Line") self.D.Top.Thickness=S.Vis.CTH self.D.Top.Color=S.Col.CR 
            self.D.Top.Transparency=1 self.D.Top.From=Vector2.new(cx,cy-gp-sz) self.D.Top.To=Vector2.new(cx,cy-gp) self.D.Top.Visible=true 
            self.D.Bot=Drawing.new("Line") self.D.Bot.Thickness=S.Vis.CTH self.D.Bot.Color=S.Col.CR 
            self.D.Bot.Transparency=1 self.D.Bot.From=Vector2.new(cx,cy+gp) self.D.Bot.To=Vector2.new(cx,cy+gp+sz) self.D.Bot.Visible=true 
            self.D.Left=Drawing.new("Line") self.D.Left.Thickness=S.Vis.CTH self.D.Left.Color=S.Col.CR 
            self.D.Left.Transparency=1 self.D.Left.From=Vector2.new(cx-gp-sz,cy) self.D.Left.To=Vector2.new(cx-gp,cy) self.D.Left.Visible=true 
            self.D.Right=Drawing.new("Line") self.D.Right.Thickness=S.Vis.CTH self.D.Right.Color=S.Col.CR 
            self.D.Right.Transparency=1 self.D.Right.From=Vector2.new(cx+gp,cy) self.D.Right.To=Vector2.new(cx+gp+sz,cy) self.D.Right.Visible=true 
        end 
    end) 
    if not success then return false end 
    self.Initialized=true 
    return true 
end

function Cross:Update() 
    if not self.On or not self.Initialized then return end 
    local cx,cy=self:GetCenter() 
    local sz,gp=S.Vis.CS,S.Vis.CG 
    local col=(Aim.Target and Aim.Active) and S.Col.CL or S.Col.CR 
    if S.Vis.CT=="Dot" then 
        if self.D.Dot then self.D.Dot.Position=Vector2.new(cx,cy) self.D.Dot.Color=col self.D.Dot.Radius=S.Vis.CD end 
    elseif S.Vis.CT=="Weapon" then 
        if self.D.Circ then self.D.Circ.Position=Vector2.new(cx,cy) self.D.Circ.Color=col self.D.Circ.Radius=S.Vis.CS end 
        if self.D.Dot then self.D.Dot.Position=Vector2.new(cx,cy) self.D.Dot.Color=col end 
    else 
        if self.D.Dot then self.D.Dot.Position=Vector2.new(cx,cy) self.D.Dot.Color=col self.D.Dot.Radius=S.Vis.CD end 
        if self.D.Top then self.D.Top.From=Vector2.new(cx,cy-gp-sz) self.D.Top.To=Vector2.new(cx,cy-gp) self.D.Top.Color=col end 
        if self.D.Bot then self.D.Bot.From=Vector2.new(cx,cy+gp) self.D.Bot.To=Vector2.new(cx,cy+gp+sz) self.D.Bot.Color=col end 
        if self.D.Left then self.D.Left.From=Vector2.new(cx-gp-sz,cy) self.D.Left.To=Vector2.new(cx-gp,cy) self.D.Left.Color=col end 
        if self.D.Right then self.D.Right.From=Vector2.new(cx+gp,cy) self.D.Right.To=Vector2.new(cx+gp+sz,cy) self.D.Right.Color=col end 
    end 
end

function Cross:Start() 
    if self.On then return true end 
    if not CheckDrawingSupport() then return false end 
    self.On=true S.Vis.CO=true 
    if not self:Make() then self.On=false S.Vis.CO=false return false end 
    DC("Cross") 
    Conn["Cross"]=RS.RenderStepped:Connect(function() if not self.On then return end self:Update() end) 
    return true 
end

function Cross:Stop() self.On=false S.Vis.CO=false self.Initialized=false DC("Cross") self:ClearDrawings() end
function Cross:Style(s) if s and table.find(CrosshairTypes,s) then S.Vis.CT=s if self.On then self:Make() end end end
function Cross:Refresh() if self.On then self:Make() end end

local function GetList() 
    local l={} 
    for _,p in pairs(Players:GetPlayers()) do if p and p~=LP then table.insert(l,p.Name) end end 
    return l 
end

local function TpTo(n) 
    local t=Players:FindFirstChild(n) 
    if not t then return false end 
    local mr,tr=GetRoot(GetChar(LP)),GetRoot(GetChar(t)) 
    if mr and tr then mr.CFrame=tr.CFrame*CFrame.new(0,0,3) return true end 
    return false 
end

local function Rejoin() pcall(function() game:GetService("TeleportService"):Teleport(game.PlaceId,LP) end) end

local function RefreshESP() 
    if S.ESP.KO then StopKESP() task.wait(0.2) StartKESP() end 
    if S.ESP.SO then StopSESP() task.wait(0.2) StartSESP() end 
    if S.ESP.GO then StopGESP() task.wait(0.2) StartGESP() end 
    if S.ESP.PO then StopPESP() task.wait(0.2) StartPESP() end 
    if S.ESP.GFO then StopGiftESP() task.wait(0.2) StartGiftESP() end 
end

local function StopAll() 
    ESPUpdateLock=true 
    StopKESP() StopSESP() StopGESP() StopPESP() StopGiftESP() 
    WSys:Stop() Aim:Stop() Cross:Stop() 
    StopAtk() StopBlind() StopFog() SetBright(false) StopLag() SetCam("Default") 
    StopRepair() StopHeal() StopGift() Lobby:Stop() 
    DCAll() 
    task.defer(function() 
        CleanAllESP() 
        CachedGens,CachedPallets,GenCache,StateCache,PlayerCache,CachedGifts,CachedDropZones,CachedCharParts={},{},{},{},{Killers={},Survivors={},LastUpdate=0},{},{},{} 
        ESPUpdateLock=false 
    end) 
end

DC("CharAdded") 
Conn["CharAdded"]=LP.CharacterAdded:Connect(function() 
    task.wait(1) 
    if Lobby:Check() then 
        Lobby:CleanUp() 
    else 
        if WSys.On then task.wait(0.5) WSys:Apply() task.wait(1) WSys:Apply() end 
        if S.Cam.Mode=="FirstPerson" then task.wait(0.3) HideCharacter() end 
    end 
end)

CheckDrawingSupport()
SetupAntiSlow()

getgenv().UHCore={
    WalkspeedSystem=WSys,AimSystem=Aim,CrosshairSystem=Cross,LobbyDetection=Lobby,PlayerState=PS,
    StartKillerESP=StartKESP,StopKillerESP=StopKESP,
    StartSurvivorESP=StartSESP,StopSurvivorESP=StopSESP,
    StartGenESP=StartGESP,StopGenESP=StopGESP,
    StartPalletESP=StartPESP,StopPalletESP=StopPESP,
    StartGiftESP=StartGiftESP,StopGiftESP=StopGiftESP,
    StartAutoAttack=StartAtk,StopAutoAttack=StopAtk,
    SetAutoAttackDistance=SetAtkDist,SetAutoAttackCooldown=SetAtkCD,
    StartAntiBlind=StartBlind,StopAntiBlind=StopBlind,
    StartAutoRepairGen=StartRepair,StopAutoRepairGen=StopRepair,
    StartAutoHeal=StartHeal,StopAutoHeal=StopHeal,
    StartAutoGift=StartGift,StopAutoGift=StopGift,
    StartNoFog=StartFog,StopNoFog=StopFog,
    SetFullbright=SetBright,
    StartAntiLag=StartLag,StopAntiLag=StopLag,
    StartCrosshair=function() return Cross:Start() end,
    StopCrosshair=function() Cross:Stop() end,
    RefreshCrosshair=function() Cross:Refresh() end,
    SetCameraMode=SetCam,
    SetCrosshairStyle=function(s) Cross:Style(s) end,
    SetCrosshairSize=function(v) S.Vis.CS=math.clamp(v,1,50) Cross:Refresh() end,
    SetCrosshairGap=function(v) S.Vis.CG=math.clamp(v,0,30) Cross:Refresh() end,
    SetCrosshairThickness=function(v) S.Vis.CTH=math.clamp(v,1,10) Cross:Refresh() end,
    SetCrosshairDotSize=function(v) S.Vis.CD=math.clamp(v,1,15) Cross:Refresh() end,
    SetESPFillTransparency=function(v) S.ESP.FT=math.clamp(v,0,1) end,
    SetESPOutlineTransparency=function(v) S.ESP.OT=math.clamp(v,0,1) end,
    SetShowDistance=function(v) S.ESP.SD=v end,
    SetKillerColor=function(c) S.Col.K=c end,
    SetSurvivorColor=function(c) S.Col.SV=c end,
    SetPalletColor=function(c) S.Col.PL=c end,
    SetGenLowColor=function(c) S.Col.GL=c end,
    SetGenMidColor=function(c) S.Col.GM=c end,
    SetGenHighColor=function(c) S.Col.GH=c end,
    SetGiftColor=function(c) S.Col.GF=c end,
    SetCrosshairColor=function(c) S.Col.CR=c Cross:Refresh() end,
    SetCrosshairLockColor=function(c) S.Col.CL=c end,
    RefreshESPColors=RefreshESP,
    TeleportTo=TpTo,Rejoin=Rejoin,GetPlayerList=GetList,StopAll=StopAll,
    Settings=S,CrosshairTypes=CrosshairTypes,CameraModes=CameraModes,TargetParts=TargetParts,
    CheckPlayerState=function(playerName) local p=Players:FindFirstChild(playerName) if p and p.Parent then return PS:GetState(p) end return nil end,
    IsDrawingSupported=function() return Cross.DrawingSupported end,
    GetDistance=GetDist,GetNearestKiller=GetNearestKiller,IsPlayerNormal=IsPlayerNormal,
    ForceCleanup=function() CleanupMemory() Lobby:CleanUp() end
}

return getgenv().UHCore