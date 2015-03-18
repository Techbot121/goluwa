local gmod = ... or gmod
local render = gmod.env.render

function render.GetBloomTex0() return _G.render.GetErrorTexture() end
function render.GetBloomTex1() return _G.render.GetErrorTexture() end
function render.GetScreenEffectTexture() return _G.render.GetErrorTexture() end

local current_fb

function render.SetRenderTarget(tex)
	if tex.__obj.fb then 	
		tex.__obj.fb:Bind()
		current_fb = tex.__obj.fb
	end
end

function render.GetRenderTarget()
	return current_fb
end

function render.PushRenderTarget(rt, x,y,w,h)
	render.PushFramebuffer(rt.__obj.fb)
	
	x = x or 0
	y = y or 0
	w = w or rt.__obj.fb.w
	h = h or rt.__obj.fb.h
	
	render.PushViewport(x,y,w,h)
end

function render.PopRenderTarget()
	render.PopViewport()
	
	render.PopFramebuffer()
end