-- Test Minimal Lua - Pass-through implementation for testing

function pre_proxy(request)
    return request
end

function post_proxy(response)
    return response
end
