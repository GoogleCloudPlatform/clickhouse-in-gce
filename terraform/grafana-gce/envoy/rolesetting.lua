-- set http header x-user-email and x-user-role according to jwt assert
function find_default_role(roles)
   local min=1
   local current=""
   for r,l in pairs(roles) do
      if l<= min then
	 current = r
      end
   end
   return current
end
function simple_json_path(payload, path)
   local cn = payload
   for _, n in pairs(path) do
      if cn[n] == nil then
	 return nil
      end
      cn = cn[n]
   end
   return cn
end
function accesslvl_to_role(mapping, accesslevels, policyname, default_role, roles)
   local role = default_role
   for _,a in pairs(accesslevels) do
      local normalized,count = string.gsub(a, "^accessPolicies/".. tostring(policyname) .."/accessLevels/","")
      if count>0 then
	 mapped = roles[mapping[normalized]]
	 if mapped and mapped > roles[role] then
	    role = mapping[normalized]
	 end
      end
   end
   return role
end
local builtin_roles = {Viewer=1, Editor=2, Admin=3}
local builtin_rolemapping = {viewer="Viewer", editor="Editor", admin="Admin"}
function try_require(m)
   return (function (stat, v)
	 if stat
	 then
	    return v
	 else
	    return nil
	 end
   end) (pcall(function () return require(m) end))
end
function envoy_on_request(request_handle)
   local dmeta = request_handle:streamInfo():dynamicMetadata():get("envoy.filters.http.jwt_authn")
   if dmeta == nil then
      return
   end
   local email = dmeta["jwt_payload"]["email"]
   local accesslevels = simple_json_path(dmeta["jwt_payload"], {"google", "access_levels"})

   local metadata = request_handle:metadata()
   
   local mapping = metadata:get("accesslevel-mapping") or builtin_rolemapping
   local roles   = metadata:get("roles") or builtin_roles
   local policyname = metadata:get("accesslevel-policy")
   local role    = find_default_role(roles)

   if not (mapping == nil) and not (accesslevels == nil) and not (policyname == nil) then
      role = accesslvl_to_role(mapping, accesslevels, policyname, role, roles)
   else
      role = metadata:get("rolebindings") and metadata:get("rolebindings")[email] or role
   end
   request_handle:headers():add("X-User-Email", email)
   request_handle:headers():add("X-User-Role", role)
end

local rolesetting = {}
rolesetting.envoy_on_request=envoy_on_request

return rolesetting
