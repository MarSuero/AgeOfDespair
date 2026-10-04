-- 绝望时代 / Age of Despair 0.3.5; validated replica-observer route; public item 98 only.
-- Both clients install the two original action/availability DLLs and this Lua.
-- A receiver observes the game's replicated successItem event, checks eligibility,
-- then applies effects ONLY to its own hunter during its local status update.
-- No custom outgoing packets, array stores or remote status writes.
local VERSION, DIR, ITEM = '0.3.5', 'AgeOfDespair/', 98
local cfg = {enabled=true, receive=true, free_meal=true, quest_only=true, dedup_seconds=0.75}
local S = {mod_name="绝望时代",version=VERSION, hooks={}, events={}, errors={}, category=false,
    free_meal={ready=false,checks=0,procs=0,blocked=0},
    self_uses=0, received=0, applied=0, shared_applied=0, ignored=0, message='等待角色载入',
    observer={seen=0,accepted=0,rejected=0,duplicates=0,reasons={},last={}}}
local M, F, queue, remote_pending, conditions = {}, {}, {}, {}, {}
local local_id, session_key, tick, last_local_event, last_receive = nil, nil, 0, {}, {}
local category_data, category_original, category_retry = nil, {}, 0
local category_pending
local font
local notices={}
S.notices={shown=0,dropped=0}
pcall(function()font=imgui.load_font('NotoSansSC-Regular.otf',18,{0x20,0xff,0x3000,0x303f,0x4e00,0x9fff,0xff00,0xffef,0})end)
local function text(c,e)return font and c or e end
S.message=text('等待角色载入','Waiting for local hunter')
local function addr(o)return o and tostring(o:get_address())end
local function finite(x)return type(x)=='number' and x==x and math.abs(x)<1e12 end
local function record(kind,data)
    S.events[#S.events+1]={tick=tick,kind=kind,data=data or {}}
    if #S.events>50 then table.remove(S.events,1)end
end
local function fail(where,why)
    why=tostring(why);local repeated=S.errors[where]==why;S.errors[where]=why; S.message=where..': '..why
    if repeated then return end
    record('error',{where=where,reason=why}); log.error('[绝望时代] '..S.message)
end
local function guarded(where,fn,...)
    local ok,v=pcall(fn,...);if not ok then fail(where,v)end;return ok,v
end
local function methods(t)
    local list,seen={},{}
    for _=1,8 do
        if not t then break end
        for _,m in ipairs(t:get_methods())do
            local key=tostring(m:get_function())..m:get_name()
            if not seen[key]then list[#list+1]=m;seen[key]=true end
        end
        t=t:get_parent_type()
    end
    return list
end
local function method(t,name,params,ret,static)
    if not t then return nil end
    local key=t:get_full_name()..'|'..name..'|'..table.concat(params,',')..'|'..ret..'|'..tostring(static)
    if M[key]then return M[key]end
    for _,m in ipairs(methods(t))do
        if m:get_name()==name and m:is_static()==static and m:get_num_params()==#params
            and m:get_return_type():get_full_name()==ret then
            local p,match=m:get_param_types(),true
            for i,n in ipairs(params)do if p[i]:get_full_name()~=n then match=false end end
            if match then M[key]=m;return m end
        end
    end
end
local function field(t,name,ty)
    local key=t:get_full_name()..'|'..name..'|'..tostring(ty)
    if F[key]then return F[key]end
    for _=1,8 do
        if not t then break end
        local f=t:get_field(name)
        if f and not f:is_static()and (not ty or f:get_type():get_full_name()==ty)then F[key]=f;return f end
        t=t:get_parent_type()
    end
end
local function get(o,n,ty)
    assert(o,'Missing object for '..n)
    local f=assert(field(o:get_type_definition(),n,ty),'Missing typed field '..n)
    return f:get_data(o)
end
local function put(o,n,ty,v)
    local f=assert(field(o:get_type_definition(),n,ty),'Missing typed field '..n)
    -- REField exposes get_data only. Mutate through the managed object API,
    -- after validating the real field type, then verify the stored value.
    o:set_field(f:get_name(),v)
    local actual=f:get_data(o)
    assert(actual==v or (type(v)=='number'and finite(actual)and math.abs(actual-v)<0.001),n..' readback mismatch')
end
local function call(o,n,params,ret,...)
    assert(o,'Missing receiver for '..n)
    local m=assert(method(o:get_type_definition(),n,params,ret,false),'Missing signature '..n)
    return m:call(o,...)
end
local function master()
    local pm=sdk.get_managed_singleton('app.PlayerManager');if not pm then return end
    local info=call(pm,'getMasterPlayer',{},'app.cPlayerManageInfo')
    local h=info and call(info,'get_Character',{},'app.HunterCharacter')
    return h,pm,info
end
local function status(h)return call(h,'get_HunterStatus',{},'app.cHunterStatus')end
local function player_context(info)
    local holder=call(info,'get_ContextHolder',{},'app.cPlayerContextHolder')
    return holder and call(holder,'get_Pl',{},'app.cPlayerContext')
end
-- Developer snapshots are explicit and small; no per-frame type dumps.
local sample_status
local function primitive_snapshot(o)
    return {_IsActive=get(o,'_IsActive','System.Boolean'),
        _IsRequestActivate=get(o,'_IsRequestActivate','System.Boolean'),
        _DurationTime=get(o,'_DurationTime','System.Single'),
        _DurationTimer=get(o,'_DurationTimer','System.Single')}
end
local function export()
    if sample_status then sample_status()end
    local snapshot={schema='AgeOfDespair-diagnostic-1',version=VERSION,settings=cfg,state=S,
        local_player=local_id,session=session_key,queued=#queue,pending_remote=#remote_pending,
        sharing_mode="replica_success_observer"}
    -- Serialize before opening a file; userdata never enters the export.
    local encoded=json.dump_string(snapshot,2)
    assert(type(encoded)=='string'and #encoded>10,'JSON serialization failed')
    assert(type(json.load_string(encoded))=='table','JSON validation failed')
    assert(json.dump_file(DIR..'diagnostic.json',snapshot,2)==true,'Diagnostic file write failed')
    local readback=json.load_file(DIR..'diagnostic.json')
    assert(type(readback)=='table'and readback.version==VERSION,'Diagnostic file readback failed')
    S.message=text('诊断已保存：','Diagnostic saved: ')..'reframework/data/AgeOfDespair/diagnostic.json'
end
local function save()
    assert(json.dump_file(DIR..'settings.json',cfg,2)==true,'Settings write failed')
end
do
    local ok,old=pcall(json.load_file,DIR..'settings.json')
    if ok and type(old)=='table'then for k,v in pairs(cfg)do if type(old[k])==type(v)then cfg[k]=old[k]end end end
    if ok and type(old)=='table'and old.receive==nil and type(old.share)=='boolean'then cfg.receive=old.share end
    if not finite(cfg.dedup_seconds)or cfg.dedup_seconds<0.2 or cfg.dedup_seconds>3 then cfg.dedup_seconds=0.75 end
end
local function category(enable)
    if not category_data then
        local t=sdk.find_type_definition('app.ItemDef')
        local m=assert(method(t,'Data',{'app.ItemDef.ID'},'app.user_data.ItemData.cData',true),'ItemDef.Data signature unavailable')
        category_data=m:call(nil,ITEM);if not category_data then return false end
    end
    local entries={{'_TextType','System.Int32',1},{'_Window','System.Boolean',true},
        {'_Eatable','System.Boolean',true},{'_Heal','System.Boolean',true},{'_EnableOnRaptor','System.Boolean',true}}
    -- Some builds retain _TextType as an enum; require the actual type and value.
    local tf=assert(field(category_data:get_type_definition(),'_TextType'),'Item text type field missing')
    entries[1][2]=tf:get_type():get_full_name()
    for _,e in ipairs(entries)do
        local f=assert(field(category_data:get_type_definition(),e[1],e[2]),'Item metadata missing '..e[1])
        if category_original[e[1]]==nil then category_original[e[1]]=f:get_data(category_data)end
    end
    for _,e in ipairs(entries)do
        local value=e[3];if not enable then value=category_original[e[1]]end
        put(category_data,e[1],e[2],value)
    end
    S.category=enable;return true
end
local function condition_objects(st)
    local bad=get(st,'_BadConditions','app.HunterBadConditions.cHunterBadConditions')
    return get(bad,'_Poison','app.HunterBadConditions.cPoison'),get(bad,'_Stench','app.HunterBadConditions.cStench')
end
local function condition_request(o,name,duration)
    assert(field(o:get_type_definition(),'_DurationTime','System.Single'),'Duration field unavailable')
    assert(field(o:get_type_definition(),'_DurationTimer','System.Single'),'Timer field unavailable')
    local m=assert(method(o:get_type_definition(),'requestActivate',{},'System.Void',false),'Activation API unavailable')
    local active=get(o,'_IsActive','System.Boolean')
    local requested=get(o,'_IsRequestActivate','System.Boolean')
    local state=conditions[name]
    if requested and not state then record('preserve_pending_condition',{name=name});return end
    if active and not (state and state.owner==local_id and state.address==addr(o)and state.confirmed)then
        record('preserve_existing_condition',{name=name});return
    end
    if active and state then
        put(o,'_DurationTime','System.Single',duration)
        put(o,'_DurationTimer','System.Single',state.mode=='countdown'and duration or 0)
        state.duration=duration;record('refresh_owned_condition',{name=name,seconds=duration});return
    end
    conditions[name]={owner=local_id,address=addr(o),duration=duration,requested_tick=tick,confirmed=false}
    m:call(o) -- One request; native update performs activation and native cure/UI.
    record('condition_requested',{name=name,seconds=duration,before=primitive_snapshot(o)})
end
local function observe_condition(o,name)
    local c=conditions[name]
    if not c then return end
    if c.owner~=local_id or c.address~=addr(o)then conditions[name]=nil;return end
    local active=get(o,'_IsActive','System.Boolean')
    if not active then
        if c.confirmed then record('condition_finished',{name=name});conditions[name]=nil
        elseif tick-c.requested_tick>180 then fail(name,'Activation was not confirmed');conditions[name]=nil end
        return
    end
    if not c.confirmed then
        local timer,duration=get(o,'_DurationTimer','System.Single'),get(o,'_DurationTime','System.Single')
        assert(finite(timer)and finite(duration)and duration>0,'Invalid native duration')
        -- Infer elapsed/remaining convention from the FIRST activation update.
        local mode
        if timer>=0 and timer<=0.5 then mode='elapsed'
        elseif math.abs(timer-duration)<=0.5 then mode='countdown'end
        assert(mode,'Unknown timer convention; native state left unchanged')
        put(o,'_DurationTime','System.Single',c.duration)
        put(o,'_DurationTimer','System.Single',mode=='countdown'and c.duration or 0)
        c.mode=mode;c.confirmed=true
        record('condition_confirmed',{name=name,seconds=c.duration,mode=mode,native_duration=duration,native_timer=timer})
    end
end
-- Confirmed enum name in this build's TDB; existing AutoItemBuff uses ID 98.
-- Self use reads the consumer; Wide-Range reads the actual consuming sender.
-- Read once at settlement; do not repeatedly scale a running timer.
-- Remote getSkillLevel can depend on local-only native skill state. Inspect
-- the consuming replica's CURRENT equipment contributions instead. _SkillData
-- is a global definition (maximum level), never evidence of an equipped level.
-- Collection access uses exact public member names. Runtime generic fields
-- may be absent from REFramework reflection; do not assume .NET _entries.
local function collection_method(o,name,ret)
    local best,score
    for _,m in ipairs(methods(o:get_type_definition()))do
        local mn=m:get_name();local rt=m:get_return_type():get_full_name()
        if not m:is_static()and m:get_num_params()==0
            and (mn==name or mn:sub(-#name-1)=='.'..name)
            and (not ret or rt==ret)then
            local rank=(mn==name and 4 or 0)+(rt~='System.Object'and 2 or 0)
                +((rt:find('System.Collections.Generic',1,true)or mn:find('System.Collections.Generic',1,true))and 2 or 0)
            if not best or rank>score then best=m;score=rank
            elseif rank==score and m:get_function()~=best:get_function()then
                error('Ambiguous collection method '..name)
            end
        end
    end
    return best
end
local function collection_layout(o)
    local result={type=o:get_type_definition():get_full_name(),fields={},methods={}}
    local t=o:get_type_definition()
    for _,f in ipairs(t:get_fields())do
        if #result.fields>=32 then break end
        result.fields[#result.fields+1]={name=f:get_name(),type=f:get_type():get_full_name()}
    end
    for _,m in ipairs(methods(t))do
        local name=m:get_name()
        if #result.methods>=48 then break end
        if name:find('get_',1,true)or name:find('Enumerator',1,true)or name:find('MoveNext',1,true)or name:find('Dispose',1,true)then
            local p={};for _,v in ipairs(m:get_param_types())do p[#p+1]=v:get_full_name()end
            result.methods[#result.methods+1]={name=name,parameters=p,returns=m:get_return_type():get_full_name()}
        end
    end
    return result
end
local function skill_row(value)
    assert(value,'Missing enumerated skill value')
    if value:get_type_definition():get_full_name()=='app.EquipDef.EquipSkillInfo'then return value end
    local getter=collection_method(value,'get_Value')
    if getter then return getter:call(value)end
    for _,name in ipairs({'value','_value','Value'})do
        local f=field(value:get_type_definition(),name)
        if f then return f:get_data(value)end
    end
    error('Unsupported skill enumeration item: '..value:get_type_definition():get_full_name())
end
local function skill_values(dict,trace)
    trace.collection=collection_layout(dict)
    local values=collection_method(dict,'get_Values')
    local sequence=values and values:call(dict)or dict
    assert(sequence,'Skill values collection unavailable')
    local enumerator=collection_method(sequence,'GetEnumerator')
    if enumerator then
        local e=assert(enumerator:call(sequence),'Skill enumerator unavailable')
        trace.enumerator=collection_layout(e);trace.collection_route=values and 'public_values' or 'public_dictionary'
        local dispose=collection_method(e,'Dispose','System.Void')
        local result={}
        local ok,why=pcall(function()
            local move=assert(collection_method(e,'MoveNext','System.Boolean'),'Skill MoveNext unavailable')
            local current=assert(collection_method(e,'get_Current'),'Skill Current unavailable')
            for i=1,513 do
                local more=move:call(e);assert(type(more)=='boolean','Invalid Skill MoveNext result')
                if not more then return end
                assert(i<=512,'Skill enumeration exceeded 512 rows')
                result[#result+1]=assert(skill_row(current:call(e)),'Empty live skill row')
            end
        end)
        local cleaned,cleanup_error=true,nil
        if dispose then cleaned,cleanup_error=pcall(function()dispose:call(e)end)end
        assert(ok,why);assert(cleaned,cleanup_error)
        return result
    end
    -- Older reflected dictionaries expose an entry array. Only use a field
    -- that actually exists; record which path was usable on this runtime.
    local entries
    for _,name in ipairs({'_entries','entries'})do
        local f=field(dict:get_type_definition(),name)
        if f then entries=f:get_data(dict);trace.collection_route='field:'..name;break end
    end
    assert(entries,'No public skill iterator or reflected entry array; type '..trace.collection.type)
    local n=entries:get_size()
    assert(finite(n)and n%1==0 and n>=0 and n<=512,'Invalid skill dictionary capacity')
    local result={}
    for i=0,n-1 do
        local entry=entries:get_element(i)
        if entry then local v=skill_row(entry);if v then result[#result+1]=v end end
    end
    return result
end
local function integer_array(o,trace)
    assert(o,'Equipment level contributions missing')
    trace.level_collection=collection_layout(o)
    local ty=o:get_type_definition():get_full_name()
    local n,read
    if ty=='System.Int32[]'then
        n=o:get_size();read=function(i)return o:get_element(i)end
    else
        local count=collection_method(o,'get_Count','System.Int32')
        local item=method(o:get_type_definition(),'get_Item',{'System.Int32'},'System.Int32',false)
        if count and item then
            n=count:call(o);read=function(i)return item:call(o,i)end
            trace.level_route='public_indexer'
        else
            assert(ty:find('System.Collections.Generic.List',1,true)==1,'Unsupported equipment level collection: '..ty)
            n=get(o,'_size','System.Int32');local a=get(o,'_items','System.Int32[]')
            assert(a and a:get_size()>=n,'Invalid equipment list capacity')
            read=function(i)return a:get_element(i)end;trace.level_route='reflected_list'
        end
    end
    assert(finite(n)and n%1==0 and n>0 and n<=32,'Invalid equipment level collection size')
    local levels,total={},0
    for i=0,n-1 do
        local lv=read(i)
        if type(lv)~='number'then lv=get(lv,'m_value','System.Int32')end
        assert(finite(lv)and lv%1==0 and lv>=0 and lv<=99,'Invalid equipment level contribution')
        levels[#levels+1]=lv;total=total+lv
    end
    trace.contributions=levels
    return math.min(3,total)
end
local function replica_prolonger(h,trace)
    local skill=call(h,'get_HunterSkill',{},'app.cHunterSkill')
    trace.owner=addr(h);trace.mode='lua_current_equipment';trace.phase='current skill collection'
    assert(not get(skill,'_RequestedUpdateCurrentSkillInfo','System.Boolean'),'Replica equipment update pending')
    local dict=assert(get(skill,'_CurrentSkillInfoDic'),'Replica current skill dictionary unavailable')
    local rows=skill_values(dict,trace)
    assert(#rows>0,'Replica skill dictionary empty; absence is not verified level zero')
    local result,matched=0,false
    for _,value in ipairs(rows)do
        assert(value:get_type_definition():get_full_name()=='app.EquipDef.EquipSkillInfo','Unexpected current skill entry type')
        local id=get(value,'_Skill','app.HunterDef.Skill')
        assert(finite(id)and id%1==0,'Invalid current skill identifier')
        if id==98 then
            assert(not matched,'Duplicate Item Prolonger current skill entry')
            matched=true;trace.phase='equipment level contributions';trace.skill_row=collection_layout(value)
            result=integer_array(get(value,'_ActiveEquipLv'),trace)
        end
    end
    trace.entries=#rows;trace.matched=matched;trace.level=result;trace.phase='verified'
    return result
end
local function duration_profile(h,source)
    local evidence={}
    local good,level=pcall(function()
        local t=assert(sdk.find_type_definition('app.HunterDef.Skill'),'Skill enum missing')
        local f=assert(t:get_field('HunterSkill_097'),'Item Prolonger enum missing')
        assert(f:is_static()and f:is_literal()and f:get_data(nil)==98,'Item Prolonger enum changed')
        -- Same actor / signature / Boolean options used by wide_profile.
        -- This reads a level only. Applying the multiplier remains Lua logic.
        evidence.owner=addr(h);evidence.skill_id=98
        local read_ok,native_level=pcall(function()
            local skill=call(h,'get_HunterSkill',{},'app.cHunterSkill')
            local n=call(skill,'getSkillLevel',{'app.HunterDef.Skill','System.Boolean','System.Boolean'},'System.Int32',98,true,true)
            assert(finite(n)and n%1==0 and n>=0 and n<=3,'Invalid Item Prolonger level')
            return n
        end)
        evidence.native_level=read_ok and native_level or nil
        evidence.native_error=not read_ok and tostring(native_level)or nil
        local lv
        if read_ok and native_level>0 then
            evidence.mode='skill_level_read_lua_duration';evidence.phase='verified';lv=native_level
        else
            -- A remote zero can reflect unavailable replica skill state.
            -- Cross-check equipment when available; never substitute the receiver.
            lv=replica_prolonger(h,evidence)
        end
        assert(finite(lv)and lv%1==0 and lv>=0 and lv<=3,'Invalid Item Prolonger level')
        return lv
    end)
    local multiplier=1
    if good then multiplier=({[0]=1,1.1,1.25,1.5})[level];S.errors['item prolonger']=nil
    else fail('item prolonger',level)end
    S.duration={level=good and level or nil,multiplier=multiplier,verified=good,
        poison=10*multiplier,stench=20*multiplier,source=source or 'consumer_skill',
        evidence=evidence,rule='lua_fixed_multiplier',error=not good and tostring(level)or nil}
    return S.duration
end
local function apply_effects(h,scale,origin,duration)
    local st=status(h);local poison,stench=condition_objects(st)
    local health=call(h,'get_HunterHealth',{},'app.cHunterHealth')
    local manager=call(health,'get_HealthMgr',{},'app.cHealthManager')
    local before=call(manager,'get_Health',{},'System.Single')
    local maximum=call(manager,'get_MaxHealth',{},'System.Single')
    assert(finite(before)and finite(maximum)and maximum>0 and before>0,'Hunter is not alive/ready')
    for _,o in ipairs({poison,stench})do
        assert(method(o:get_type_definition(),'requestActivate',{},'System.Void',false),'Missing native condition activation')
        assert(field(o:get_type_definition(),'_DurationTime','System.Single')and field(o:get_type_definition(),'_DurationTimer','System.Single'),'Missing native condition timers')
    end
    duration=duration or duration_profile(h);S.duration=duration
    -- A full heal at Lv5; lower levels heal maxHP * the game's Wide-Range ratio.
    local after=math.min(maximum,before+maximum*scale)
    call(health,'setHealth',{'System.Single','System.Boolean'},'System.Void',after,true)
    condition_request(poison,'poison',duration.poison);condition_request(stench,'stench',duration.stench)
    S.applied=S.applied+1;if origin=='wide_range'then S.shared_applied=S.shared_applied+1 end
    record('effects_applied',{origin=origin,hp_before=before,hp_requested=after,max_hp=maximum,heal_scale=scale,poison_seconds=duration.poison,stench_seconds=duration.stench,
        prolonger_level=duration.level,duration_scale=duration.multiplier,duration_verified=duration.verified,duration_source=duration.source})
    S.message=string.format(text('已结算：回血；中毒%g秒、恶臭%g秒','Effects: heal; poison %gs, stench %gs'),duration.poison,duration.stench)
    if not duration.verified then S.message=S.message..text('（技能读取失败，使用基础时长）',' (skill unavailable; base duration)')end
end
local function wide_profile(h)
    local skill=call(h,'get_HunterSkill',{},'app.cHunterSkill')
    local et=assert(sdk.find_type_definition('app.HunterDef.Skill'),'Skill enum missing')
    local ef=assert(et:get_field('HunterSkill_098'),'Wide-Range enum missing')
    assert(ef:is_static()and ef:is_literal(),'Wide-Range enum is not literal')
    local level=call(skill,'getSkillLevel',{'app.HunterDef.Skill','System.Boolean','System.Boolean'},'System.Int32',ef:get_data(nil),true,true)
    assert(finite(level)and level%1==0 and level>=0 and level<=5,'Invalid Wide-Range level')
    if level==0 then return 0 end
    local getter
    for _,m in ipairs(methods(skill:get_type_definition()))do
        if not m:is_static()and m:get_num_params()==0 and m:get_name():sub(1,4)=='get_'and m:get_return_type():get_full_name()=='app.user_data.PlayerSkillParam'then
            assert(not getter,'Ambiguous PlayerSkillParam getter');getter=m
        end
    end
    local param=assert(getter and getter:call(skill),'PlayerSkillParam getter unavailable')
    local function value(name)
        local pack=get(param,name,'app.user_data.PlayerSkillParam.cSkillBasicDataPack')
        local data=get(pack,'_DataPack')
        local n=data:get_size()
        assert(n==5 or n==6,'Unexpected skill data layout; share stopped')
        local row=n==5 and level-1 or level
        if n==6 then
            local zero=get(assert(data:get_element(0)),'_Value','System.Single')
            assert(zero==0,'Six-row skill pack has no zero-level sentinel')
        end
        return get(assert(data:get_element(row),'Skill level row unavailable'),'_Value','System.Single')
    end
    local radius=value('_ItemWideEffectiveRadiusData')
    local scale=value('_ItemWideEffectiveEffectiveData')
    assert(finite(radius)and radius>0 and radius<=100,'Invalid Wide-Range radius')
    assert(finite(scale)and scale>0 and scale<=1.01,'Invalid Wide-Range effect ratio')
    return level,radius,math.min(1,scale)
end
local function position(h)
    local go=call(h,'get_GameObject',{},'via.GameObject')
    local tr=call(go,'get_Transform',{},'via.Transform')
    return call(tr,'get_Position',{},'via.vec3')
end
local function distance(a,b)
    return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2)
end
local function quest_infos(pm)
    local list=get(pm,'_QuestPlayerList');assert(list,'Quest player list unavailable')
    -- Real client metadata: this is LimitedArray<Int32>, NOT player objects.
    -- Use the game's own iterator to resolve these indices; no assumptions
    -- about their relationship to player slots or network member indices.
    local n=get(list,'_Length','System.UInt32')
    local a=get(list,'_Array')
    S.party={list_type=list:get_type_definition():get_full_name(),length=n,
        array_type=a and a:get_type_definition():get_full_name(),entries={}}
    assert(finite(n)and n%1==0 and n>=0 and n<=4,'Unexpected quest party length')
    if not a and n==0 then return {}end
    assert(a,'Quest player backing array unavailable')
    assert(a:get_type_definition():get_full_name()=='System.Int32[]','Quest player index array type mismatch')
    local capacity=a:get_size();S.party.capacity=capacity
    assert(finite(capacity)and capacity%1==0 and capacity>=n and capacity<=256,'Quest player backing capacity invalid')
    S.party.raw_indices={}
    for i=0,n-1 do
        local value=a:get_element(i)
        if type(value)~='number'then value=value and value:get_field('m_value')end
        assert(finite(value)and value%1==0,'Invalid quest list index')
        S.party.raw_indices[#S.party.raw_indices+1]=value
    end
    if n==0 then return {}end
    local seq=call(pm,'getQuestMembers',{},'System.Collections.Generic.IEnumerable`1<app.cPlayerManageInfo>')
    assert(seq,'Quest member enumerable unavailable')
    local function iter_method(o,name,ret,optional)
        local found
        for _,m in ipairs(methods(o:get_type_definition()))do
            local mn=m:get_name()
            if (mn==name or mn:sub(-#name-1)=='.'..name)and not m:is_static()
                and m:get_num_params()==0 and m:get_return_type():get_full_name()==ret then
                assert(not found,'Ambiguous iterator method '..name);found=m
            end
        end
        if optional then return found end
        return assert(found,'Iterator method unavailable: '..name..' -> '..ret)
    end
    local enum=iter_method(seq,'GetEnumerator','System.Collections.Generic.IEnumerator`1<app.cPlayerManageInfo>'):call(seq)
    assert(enum,'Quest member enumerator unavailable')
    S.party.enumerator_type=enum:get_type_definition():get_full_name()
    local dispose=iter_method(enum,'Dispose','System.Void',true)
    -- Dispose on this exact generated iterator is absent from the runtime dump.
    -- REFramework filters stubs from get_methods(); the provided runtime dump
    -- has MoveNext/Current/GetEnumerator but no callable Dispose. Do not replace
    -- it with Reset or an arbitrary void method, or relax unknown iterators.
    if not dispose then
        assert(S.party.enumerator_type=='app.PlayerManager.<getQuestMembers>d__111',
            'Unknown iterator without callable Dispose; share stopped')
        S.party.cleanup='known iterator: Dispose filtered by REFramework'
    else S.party.cleanup='native Dispose' end
    local result={}
    local good,why=pcall(function()
        local move=iter_method(enum,'MoveNext','System.Boolean')
        local current=iter_method(enum,'get_Current','app.cPlayerManageInfo')
        for i=1,5 do
            local more=move:call(enum)
            assert(type(more)=='boolean','Invalid enumerator result')
            if not more then return end
            assert(i<=4,'Quest member enumeration exceeded four players')
            local info=current:call(enum)
            assert(info and info:get_type_definition():get_full_name()=='app.cPlayerManageInfo','Quest member type mismatch')
            result[#result+1]=info
            local ctx=player_context(info)
            S.party.entries[#S.party.entries+1]={ordinal=i,address=addr(info),
                network_quest=call(ctx,'get_NetworkQuestIndex',{},'System.Int32'),
                stable_quest=call(ctx,'get_StableQuestMemberIndex',{},'System.Int32')}
        end
    end)
    -- Dispose if a callable implementation is exposed, including on failure.
    -- Never retain the iterator or mutate its private state.
    local disposed,dispose_error=true,nil
    if dispose then disposed,dispose_error=pcall(function()dispose:call(enum)end)end
    assert(good,why);assert(disposed,dispose_error)
    assert(#result==n,'Quest list changed during enumeration; share stopped')
    S.party.enumerated=#result
    return result
end
local function clock_now()
    local t=os.clock();assert(finite(t)and t>=0,'Local Lua clock unavailable');return t
end
local function queue_event(origin,scale,duration)
    if #queue>=16 then fail('queue','Too many pending effects');return false end
    queue[#queue+1]={owner=local_id,session=session_key,origin=origin,scale=scale,duration=duration,created=tick}
    return true
end
local function reject_remote(reason,details)
    local o=S.observer;o.rejected=o.rejected+1;S.ignored=S.ignored+1
    o.reasons[reason]=(o.reasons[reason]or 0)+1
    if reason=='duplicate'then o.duplicates=o.duplicates+1 end
    o.last.reason=reason;o.last.accepted=false
    record('remote_rejected',{reason=reason,details=details or {},sender=o.last.sender})
end
local function enqueue_remote(h)
    S.observer.last={sender=addr(h),phase='enqueue',accepted=false}
    S.observer.seen=S.observer.seen+1
    if not cfg.receive then reject_remote('receive_disabled');return end
    if not local_id or not session_key then reject_remote('local_not_ready');return end
    if #remote_pending>=16 then reject_remote('observer_queue_full');return end
    h:add_ref() -- Keep this managed replica alive until its short queued check.
    remote_pending[#remote_pending+1]={sender=h,id=addr(h),owner=local_id,session=session_key,at=clock_now()}
    record('remote_event_queued',{sender=addr(h),session=session_key})
end
local function check_remote(event,h,pm,own_info)
    local o=S.observer;o.last={sender=event.id,at=event.at,phase='eligibility',accepted=false}
    if not cfg.enabled or not cfg.receive then reject_remote('receive_disabled');return end
    if event.owner~=local_id or event.session~=session_key then reject_remote('local_session_changed');return end
    local age=clock_now()-event.at
    if age<0 or age>1.5 then reject_remote('expired_event',{age=age});return end
    local prev=last_receive[event.id]
    if prev and (event.at<prev or event.at-prev<cfg.dedup_seconds)then reject_remote('duplicate');return end
    -- Mark observed events, including rejected ones: repeated callbacks must not
    -- become a new consumption merely because the recipient moved into range.
    last_receive[event.id]=event.at
    local sender=event.sender
    if event.id==local_id then reject_remote('self_replica');return end
    o.last.phase='sender NPC flag'
    if get(status(sender),'<IsNpc>k__BackingField','System.Boolean')then reject_remote('npc_sender');return end
    o.last.phase='resolve sender player info'
    local go=call(sender,'get_GameObject',{},'via.GameObject')
    local info=call(pm,'findPlayer_GameObject',{'via.GameObject'},'app.cPlayerManageInfo',go)
    if not info then reject_remote('sender_info_missing');return end
    if addr(call(info,'get_Character',{},'app.HunterCharacter'))~=event.id then reject_remote('sender_character_changed');return end
    o.last.phase='stage'
    local source_ctx=player_context(info);local own_ctx=player_context(own_info)
    local source_stage=call(source_ctx,'get_CurrentStage',{},'app.FieldDef.STAGE')
    local own_stage=call(own_ctx,'get_CurrentStage',{},'app.FieldDef.STAGE')
    o.last.sender_stage=source_stage;o.last.local_stage=own_stage
    o.last.sender_member=call(source_ctx,'get_NetworkQuestIndex',{},'System.Int32')
    if source_stage~=own_stage then reject_remote('different_stage');return end
    if cfg.quest_only then
        o.last.phase='same quest membership'
        local infos=quest_infos(pm);local found_source,found_self=false,false
        for _,member in ipairs(infos)do
            if addr(member)==addr(info)then found_source=true end
            if addr(member)==addr(own_info)then found_self=true end
        end
        if not found_self or not found_source then reject_remote('not_same_quest',{source=found_source,recipient=found_self});return end
    end
    o.last.phase='remote Wide-Range skill'
    local level,radius,scale=wide_profile(sender)
    o.last.level=level;o.last.radius=radius;o.last.scale=scale
    if level==0 then reject_remote('sender_no_wide_range');return end
    o.last.phase='distance'
    local dist=distance(position(sender),position(h));assert(finite(dist),'Invalid observer distance')
    o.last.distance=dist
    if dist>radius then reject_remote('outside_range',{distance=dist,radius=radius});return end
    o.last.phase='recipient health'
    local health=call(h,'get_HunterHealth',{},'app.cHunterHealth')
    local manager=call(health,'get_HealthMgr',{},'app.cHealthManager')
    local hp=call(manager,'get_Health',{},'System.Single')
    if not finite(hp)or hp<=0 then reject_remote('recipient_dead');return end
    o.last.phase='sender Item Prolonger'
    local duration=duration_profile(sender,'sender_skill')
    o.last.prolonger_level=duration.level;o.last.duration_scale=duration.multiplier;o.last.duration_verified=duration.verified
    if not queue_event('wide_range',scale,duration)then reject_remote('effect_queue_full');return end
    o.last.phase='accepted';o.last.accepted=true
    o.accepted=o.accepted+1;S.received=S.received+1
    S.errors['observe remote']=nil
    record('remote_share_accepted',{sender=event.id,member=o.last.sender_member,level=level,radius=radius,distance=dist,scale=scale,
        prolonger_level=duration.level,poison_seconds=duration.poison,stench_seconds=duration.stench,duration_verified=duration.verified})
end
-- Exact local eating scopes; never protect arbitrary inventory transactions.
local free_scopes, free_action, free_reading, native_free_seen = {},nil,{},false
local meal_reader=method(sdk.find_type_definition('app.ItemUtil'),'getItemNum',
    {'app.ItemDef.ID','app.ItemUtil.STOCK_TYPE'},'System.Int16',true)
local function meal_thread()
    assert(thread.get_id,'Thread ID unavailable for Free Meal');return thread.get_id()
end
local function new_meal(h)
    local id=meal_thread();free_reading[id]=true
    local good,lv=pcall(function()
        local t=assert(sdk.find_type_definition('app.HunterDef.Skill'))
        local f=assert(t:get_field('HunterSkill_099'),'Free Meal enum missing')
        assert(f:is_static()and f:is_literal()and f:get_data(nil)==100,'Free Meal enum changed')
        local skill=call(h,'get_HunterSkill',{},'app.cHunterSkill')
        local level=call(skill,'getSkillLevel',{'app.HunterDef.Skill','System.Boolean','System.Boolean'},'System.Int32',100,true,true)
        assert(finite(level)and level%1==0 and level>=0 and level<=3,'Invalid Free Meal level')
        return level
    end)
    free_reading[id]=nil
    if not good then fail('free meal skill',lv);return {active=false}end
    S.errors['free meal skill']=nil
    return {active=true,owner=addr(h),session=session_key,at=clock_now(),level=lv,
        chance=({[0]=0,10,25,45})[lv],skill=addr(call(h,'get_HunterSkill',{},'app.cHunterSkill'))}
end
local function enter_meal(args,storage,success)
    local id=meal_thread();local parent=free_scopes[id]
    storage.eatshit_meal_thread=id;storage.eatshit_meal_parent=parent
    free_scopes[id]={active=false}
    if not cfg.enabled or not cfg.free_meal or not S.free_meal.ready or native_free_seen then return end
    if (sdk.to_int64(args[3])&0xffffffff)~=ITEM then return end
    local extend=sdk.to_managed_object(args[2]);local h=extend and get(extend,'_Character','app.HunterCharacter')
    local own=master()
    if not h or not own or addr(h)~=addr(own)or addr(h)~=local_id then return end
    local ctx
    if parent and parent.active and parent.owner==local_id and parent.session==session_key then ctx=parent
    elseif success and not parent and free_action and free_action.owner==local_id and free_action.session==session_key
        and clock_now()>=free_action.at and clock_now()-free_action.at<=8 then ctx=free_action
    else ctx=new_meal(h);free_action=ctx end
    free_scopes[id]=ctx
    if success then storage.eatshit_notice_context=ctx end
end
local function leave_meal(storage)
    if storage.eatshit_meal_thread then
        free_scopes[storage.eatshit_meal_thread]=storage.eatshit_meal_parent
    end
end
local function current_meal()
    if not cfg.enabled or not cfg.free_meal or not S.free_meal.ready or native_free_seen or not thread.get_id then return end
    local c=free_scopes[thread.get_id()]
    if c and c.active and c.owner==local_id and c.session==session_key then return c end
end
local function signed16(v)
    local n=sdk.to_int64(v)&0xffff;return n>=0x8000 and n-0x10000 or n
end
local function pouch_stock(stock)
    local t=assert(sdk.find_type_definition('app.ItemUtil.STOCK_TYPE'),'Stock enum missing')
    -- Pouch only. BOX / mixed stock moves are intentionally left to the game.
    local f=assert(t:get_field('POUCH'),'Pouch stock unavailable')
    return f:is_static()and f:is_literal()and f:get_data(nil)==stock
end
local function meal_quantity()
    local t=assert(sdk.find_type_definition('app.ItemUtil.STOCK_TYPE'))
    local f=assert(t:get_field('POUCH'))
    local n=assert(meal_reader,'Pouch quantity reader unavailable'):call(nil,ITEM,f:get_data(nil))
    assert(finite(n)and n%1==0 and n>=0 and n<=9999,'Invalid pouch quantity')
    return n
end
local function meal_roll(c)
    if not c.decided then
        c.decided=true;S.free_meal.checks=S.free_meal.checks+1
        c.roll=c.chance>0 and math.random(1,100)or nil
        c.saved=c.roll~=nil and c.roll<=c.chance
        if c.saved then S.free_meal.procs=S.free_meal.procs+1 end
        S.free_meal.last={level=c.level,chance=c.chance,roll=c.roll,saved=c.saved,owner=c.owner,blocked=0}
        record('free_meal_decision',S.free_meal.last)
    end
    return c.saved
end
local maybe_meal_notice
local function meal_inventory(args,storage,stat,static,pouch_only)
    local item_slot=static and 2 or 3;local delta_slot=item_slot+1
    if (sdk.to_int64(args[item_slot])&0xffffffff)~=ITEM or signed16(args[delta_slot])~=-1 then return end
    stat.item98_decrements=(stat.item98_decrements or 0)+1
    local c=current_meal();if not c then return end
    if not static and not pouch_only then
        local receiver=sdk.to_managed_object(args[2])
        if not receiver or addr(get(receiver,'_Character','app.HunterCharacter'))~=c.owner then return end
    end
    if not pouch_only and not pouch_stock(sdk.to_int64(args[delta_slot+1])&0xffffffff)then return end
    stat.calls=stat.calls+1
    storage.eatshit_meal_inventory={owner=c.owner,session=c.session,before=meal_quantity(),context=c}
    if not meal_roll(c)then return end
    args[delta_slot]=sdk.to_ptr(0) -- Run original cleanup, UI and return handling.
    S.free_meal.blocked=S.free_meal.blocked+1
    if S.free_meal.last then S.free_meal.last.blocked=S.free_meal.last.blocked+1 end
    storage.eatshit_meal_blocked=true
end
local function meal_inventory_post(_,storage)
    local sample=storage.eatshit_meal_inventory
    if not sample or sample.owner~=local_id or sample.session~=session_key then return end
    local after=meal_quantity();local last=S.free_meal.last
    if last then last.inventory_before=sample.before;last.inventory_after=after
        last.quantity_preserved=storage.eatshit_meal_blocked and after==sample.before or false end
    local c=sample.context
    if storage.eatshit_meal_blocked then
        c.preserved=after==sample.before;c.failed=c.failed or after<sample.before
        maybe_meal_notice(c)
    end
    if storage.eatshit_meal_blocked and after<sample.before then
        S.free_meal.ready=false
        fail('free meal inventory','Blocked argument but pouch quantity decreased; protection stopped')
    end
end

maybe_meal_notice=function(c)
    if not c or c.notified or c.notice_queued or not c.success or not c.preserved or not c.saved or c.failed then return end
    if #notices>=8 then S.notices.dropped=S.notices.dropped+1;return end
    c.notice_queued=true;notices[#notices+1]=c
end
local function flush_notices()
    local pending=notices;notices={}
    for _,c in ipairs(pending)do
        if cfg.enabled and c.owner==local_id and c.session==session_key and not c.failed and c.success and c.preserved and not c.notified then
            c.notified=true
            guarded('free meal notice',function()
                local chat=assert(sdk.get_managed_singleton('app.ChatManager'),'Right sidebar manager unavailable')
                call(chat,'addSystemLog',{'System.String'},'System.Void','饱腹感已生效！')
                S.notices.shown=S.notices.shown+1;S.errors['free meal notice']=nil
                record('free_meal_notice',{owner=c.owner,text='饱腹感已生效！'})
            end)
        end
    end
end
local function signature(m)
    local p={};for _,t in ipairs(m:get_param_types())do p[#p+1]=t:get_full_name()end
    return m:get_declaring_type():get_full_name()..'.'..m:get_name()..'('..table.concat(p,',')..')->'..m:get_return_type():get_full_name()
end
local function install(key,ty,name,params,ret,pre,post,static)
    local stat={installed=false,calls=0};S.hooks[key]=stat
    guarded('hook '..key,function()
        local m=assert(method(sdk.find_type_definition(ty),name,params,ret,static or false),'Exact hook signature unavailable')
        stat.signature=signature(m)
        sdk.hook(m,function(args)
            local storage=thread.get_hook_storage();storage['eatshit_'..key]=nil
            storage.eatshit_meal_inventory=nil;storage.eatshit_meal_blocked=nil
            if key=='success'then storage.eatshit_remote_success=nil;storage.eatshit_notice_context=nil end
            local ok,value=pcall(pre,args,storage,stat)
            if not ok then
                if key:sub(1,10)=='free_meal_'then S.free_meal.ready=false end
                fail('hook '..key,value)
                return
            end
            return value
        end,function(retval)
            if post then
                local good,value=guarded('post '..key,post,retval,thread.get_hook_storage(),stat)
                if not good and key:sub(1,10)=='free_meal_'then S.free_meal.ready=false end
                if good and value~=nil then return value end
            end
            return retval
        end,false)
        stat.installed=true
    end)
end
install('success','app.HunterCharacter.cHunterExtendBase','successItem',
    {'app.ItemDef.ID','System.Int32','System.Boolean','ace.ShellBase','System.Single','System.Boolean','app.ItemDef.ID','System.Boolean'},'System.Void',
    function(args,storage,stat)
        local meal_ok=guarded('free meal scope',enter_meal,args,storage,true)
        if not meal_ok then S.free_meal.ready=false end
        stat.all_calls=(stat.all_calls or 0)+1
        if not cfg.enabled or (sdk.to_int64(args[3])&0xffffffff)~=ITEM then return end
        stat.item98_calls=(stat.item98_calls or 0)+1
        local o=sdk.to_managed_object(args[2]);local h=o and get(o,'_Character','app.HunterCharacter')
        local own=master();if not h or not own then return end
        if addr(h)~=addr(own)then
            -- Check this replicated success on the recipient's next local update.
            stat.remote_item98=(stat.remote_item98 or 0)+1
            record('remote_item98_success_observed',{sender=addr(h)})
            storage.eatshit_remote_success=h
            return
        end
        storage.eatshit_success={owner=addr(h)};stat.calls=stat.calls+1
    end,function(_,storage)
        local meal=storage.eatshit_notice_context
        if storage.eatshit_success and meal then meal.success=true;maybe_meal_notice(meal)end
        leave_meal(storage)
        local remote=storage.eatshit_remote_success
        if remote and cfg.enabled then enqueue_remote(remote);return end
        local event=storage.eatshit_success
        if not event or event.owner~=local_id or not cfg.enabled then return end
        -- Nested calls/multiple success callbacks from one animation settle once.
        if last_local_event[event.owner]and tick-last_local_event[event.owner]<15 then return end
        last_local_event[event.owner]=tick;S.self_uses=S.self_uses+1;record('item_success',{item=ITEM})
        queue_event('self',1,duration_profile(master(),'consumer_skill'))

    end)
-- Suppress the game's own skill read only inside our local item-98 scope.
-- Our guarded level read happens before that scope and is never masked.
install('free_meal_skill','app.cHunterSkill','getSkillLevel',
    {'app.HunterDef.Skill','System.Boolean','System.Boolean'},'System.Int32',
    function(args,storage,stat)
        storage.eatshit_mask_meal=nil
        if (sdk.to_int64(args[3])&0xffffffff)~=100 then return end
        local c=current_meal();if not c or free_reading[meal_thread()]then return end
        if addr(sdk.to_managed_object(args[2]))~=c.skill then return end
        storage.eatshit_mask_meal=true;stat.calls=stat.calls+1
        return sdk.PreHookResult.SKIP_ORIGINAL
    end,function(_,storage)
        if storage.eatshit_mask_meal then return sdk.to_ptr(0)end
    end)
-- If a native Free Meal path avoids the level hook, yield to native behavior.
-- Do not continue stacking a custom chance on top of a detected native proc.
install('free_meal_native','app.cHunterSkill','beginSkillManzoku',{},'System.Void',
    function(args,_,stat)
        local c=current_meal();if not c or addr(sdk.to_managed_object(args[2]))~=c.skill then return end
        stat.calls=stat.calls+1;native_free_seen=true;S.free_meal.native_observed=true
        S.free_meal.ready=false
        fail('free meal native','Native Free Meal bypassed scoped level hook; custom protection yielded to game')
    end)
for _,entry in ipairs({
    {'free_meal_use',{'app.ItemDef.ID','System.Boolean','app.ItemDef.ID'}},
    {'free_meal_use_shell',{'app.ItemDef.ID','ace.ShellBase','System.Boolean','app.ItemDef.ID'}}})do
    install(entry[1],'app.HunterCharacter.cHunterExtendBase','useItem',entry[2],'System.Void',
        function(args,storage,stat)enter_meal(args,storage,false);if current_meal()then stat.calls=stat.calls+1 end end,
        function(_,storage)leave_meal(storage)end)
end
install('free_meal_extend','app.HunterCharacter.cHunterExtendPlayer','changeItemNum',
    {'app.ItemDef.ID','System.Int16','app.ItemUtil.STOCK_TYPE'},'System.Int32',
    function(args,storage,stat)meal_inventory(args,storage,stat,false,false)end,meal_inventory_post)
install('free_meal_util','app.ItemUtil','changeItemNum',
    {'app.ItemDef.ID','System.Int16','app.ItemUtil.STOCK_TYPE'},'System.Int16',
    function(args,storage,stat)meal_inventory(args,storage,stat,true,false)end,meal_inventory_post,true)
install('free_meal_pouch','app.savedata.cItemParam','changeItemPouchNum',
    {'app.ItemDef.ID','System.Int16','app.savedata.cItemParam.POUCH_CHANGE_TYPE'},'System.Int16',
    function(args,storage,stat)meal_inventory(args,storage,stat,false,true)end,meal_inventory_post)
S.free_meal.ready=meal_reader~=nil and S.hooks.free_meal_skill.installed and S.hooks.free_meal_native.installed
    and S.hooks.free_meal_use.installed and S.hooks.free_meal_use_shell.installed
    and (S.hooks.free_meal_extend.installed or S.hooks.free_meal_util.installed or S.hooks.free_meal_pouch.installed)

install('status_update','app.cHunterStatus','update',{'app.HunterCharacter'},'System.Void',
    function(args,storage)
        local h=sdk.to_managed_object(args[3]);local own=master()
        if not h or not own or addr(h)~=addr(own)then return end
        storage.eatshit_status_update=h
    end,function(_,storage,stat)
        local h=storage.eatshit_status_update;if not h then return end
        tick=tick+1;stat.calls=stat.calls+1
        local _,_,info=master();local ctx=player_context(info)
        local stage=call(ctx,'get_CurrentStage',{},'app.FieldDef.STAGE')
        local member=call(ctx,'get_NetworkQuestIndex',{},'System.Int32')
        local epoch=tostring(stage)..'|'..tostring(member)
        if local_id~=addr(h)or session_key~=epoch then
            local_id=addr(h);session_key=epoch;queue={};remote_pending={};conditions={};last_local_event={};last_receive={};free_action=nil;free_scopes={};notices={}
            record('character_or_stage_changed',{owner=local_id,session=session_key})
            S.identity={network_quest=member,stable_quest=call(ctx,'get_StableQuestMemberIndex',{},'System.Int32')}
        end
        if category_pending~=nil then
            local v=category_pending;category_pending=nil;guarded('item metadata',category,v)
        end
        if not cfg.enabled then queue={};remote_pending={};notices={};return end
        if not S.category and tick>=category_retry then
            category_retry=tick+180
            guarded('item metadata',function()if category(true)then S.errors['item metadata']=nil end end)
        end
        local incoming=remote_pending;remote_pending={}
        local _,pm,own_info=master()
        for _,event in ipairs(incoming)do
            local good,why=guarded('observe remote',check_remote,event,h,pm,own_info)
            if not good then reject_remote('validation_error',{phase=S.observer.last.phase,error=tostring(why)})end
        end
        local list=queue;queue={}
        for _,v in ipairs(list)do if v.owner==local_id and v.session==session_key and tick-v.created<=180 then guarded('apply effects',apply_effects,h,v.scale,v.origin,v.duration)end end
        if next(conditions)then
        local st=status(h);local poison,stench=condition_objects(st)
        for name,o in pairs({poison=poison,stench=stench})do
            local ok=guarded('observe '..name,observe_condition,o,name)
            if not ok then conditions[name]=nil end
        end
        end
        flush_notices()
    end)
-- A native re-application by a monster relinquishes our ownership; never cure
-- another source's status or continually overwrite its timer.
for name,ty in pairs({poison='app.HunterBadConditions.cPoison',stench='app.HunterBadConditions.cStench'})do
    install(name..'_activation',ty,'onActivate',{},'System.Void',function(args)
        local o=sdk.to_managed_object(args[2]);local c=conditions[name]
        if c and c.confirmed and addr(o)==c.address then conditions[name]=nil;record('condition_reapplied_by_game',{name=name})end
    end)
end
sample_status=function()
    local h=master();if not h then return end
    local poison,stench=condition_objects(status(h))
    S.poison=primitive_snapshot(poison);S.stench=primitive_snapshot(stench)
    local health=call(h,'get_HunterHealth',{},'app.cHunterHealth')
    local manager=call(health,'get_HealthMgr',{},'app.cHealthManager')
    S.health={current=call(manager,'get_Health',{},'System.Single'),maximum=call(manager,'get_MaxHealth',{},'System.Single')}
end
re.on_draw_ui(function()
    if font then imgui.push_font(font)end
    local depth=0
    local function tree(label)
        if not imgui.tree_node(label)then return false end
        depth=depth+1;return true
    end
    local ok,why=pcall(function()
        if not tree(text('绝望时代','Age of Despair'))then return end
        local changed,v=imgui.checkbox(text('开启绝望时代','Enable Age of Despair'),cfg.enabled)
        if changed then cfg.enabled=v;queue={};remote_pending={};guarded('settings',save);category_pending=v end
        changed,v=imgui.checkbox(text('开启广域化','Enable Wide-Range reception'),cfg.receive)
        if changed then cfg.receive=v;remote_pending={};guarded('settings',save)end
        if imgui.button(text('导出诊断','Export diagnostic'))then guarded('export',export)end
    end)
    while depth>0 do imgui.tree_pop();depth=depth-1 end
    if font then imgui.pop_font()end
    if not ok then fail('UI',why)end
end)
re.on_config_save(function()guarded('settings',save)end)
return {state=S,settings=cfg,apply=apply_effects,queue=queue_event,export=export,category=category,wide=wide_profile}
