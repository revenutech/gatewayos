function pre_proxy(request)
  local api_key = request:headers("X-API-Key")
  if api_key == "dev-test-key-001" then
    request:headers("X-Auth-Method", "api-key")
    request:headers("X-API-Key-ID", "dev-key-1")
  elseif api_key and api_key ~= "" then
    local resp = request:response()
    resp:statusCode(401)
    resp:headers("Content-Type", "application/json")
    resp:body('{"error":"invalid_api_key"}')
    return
  end

  local ua = request:headers("User-Agent")
  if ua and string.find(string.lower(ua), "sqlmap") then
    local resp = request:response()
    resp:statusCode(403)
    resp:headers("Content-Type", "application/json")
    resp:body('{"error":"blocked_client"}')
    return
  end

  local referer = request:headers("Referer")
  if referer and string.find(string.lower(referer), "169.254.169.254") then
    local resp = request:response()
    resp:statusCode(403)
    resp:headers("Content-Type", "application/json")
    resp:body('{"error":"web_filter_blocked"}')
    return
  end

  if referer and string.find(string.lower(referer), "javascript:") then
    local resp = request:response()
    resp:statusCode(400)
    resp:headers("Content-Type", "application/json")
    resp:body('{"error":"xss_blocked"}')
    return
  end
end

function post_proxy(response)
  response:headers("X-Content-Classification", "INTERNAL")
  response:headers("X-Audit-Logged", "true")
end
