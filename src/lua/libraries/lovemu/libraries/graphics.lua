if not GRAPHICS then return end

local love = ... or _G.love
local ENV = love._lovemu_env

ENV.textures = ENV.textures or utility.CreateWeakTable()
ENV.graphics_filter_min = ENV.graphics_filter_min or "linear"
ENV.graphics_filter_mag = ENV.graphics_filter_mag or "linear"
ENV.graphics_filter_anisotropy = ENV.graphics_filter_anisotropy or 1

love.graphics = love.graphics or {}

local function ADD_FILTER(obj)
	obj.setFilter = function(s, min, mag, anistropy)

		ENV.textures[s]:SetMinFilter(min)
		ENV.textures[s]:SetMagFilter(mag)

		s.filter_min = min
		s.filter_mag = mag
		s.filter_anistropy = anistropy
	end

	obj.getFilter = function() return s.filter_min, s.filter_mag, s.filter_anistropy end
end

do -- filter
	function love.graphics.setDefaultImageFilter(min, mag, anisotropy)
		ENV.graphics_filter_min = min
		ENV.graphics_filter_mag = mag
		ENV.graphics_filter_anisotropy = anisotropy
	end

	love.graphics.setDefaultFilter = love.graphics.setDefaultImageFilter
end

do -- quad
	local Quad = lovemu.TypeTemplate("Quad")

	local function refresh(vertices, x,y,w,h, sw, sh)
		vertices[0].x = 0;
		vertices[0].y = 0;
		vertices[1].x = 0;
		vertices[1].y = h;
		vertices[2].x = w;
		vertices[2].y = h;
		vertices[3].x = w;
		vertices[3].y = 0;

		vertices[0].s = x/sw;
		vertices[0].t = y/sh;
		vertices[1].s = x/sw;
		vertices[1].t = (y+h)/sh;
		vertices[2].s = (x+w)/sw;
		vertices[2].t = (y+h)/sh;
		vertices[3].s = (x+w)/sw;
		vertices[3].t = y/sh;
	end

	function Quad:flip()

	end

	function Quad:getViewport()
		return self.x, self.y, self.w, self.h
	end

	function Quad:setViewport(x,y,w,h)
		self.x = x
		self.y = y
		self.w = w
		self.h = h

		refresh(self.vertices, self.x,self.y,self.w,self.h, self.sw, self.sh)
	end


	function love.graphics.newQuad(x,y,w,h, sw,sh)
		local self = lovemu.CreateObject("Quad")

		local vertices = {}

		for i = 0, 3 do
			vertices[i] = {x = 0, y = 0, s = 0, t = 0}
		end

		self.x = x
		self.y = y
		self.w = w
		self.h = h

		self.sw = sw or 1
		self.sh = sh or 1

		self.vertices = vertices

		refresh(self.vertices, x,y,w,h, sw,sh)

		return self
	end

	lovemu.RegisterType(Quad)
end

love.graphics.origin = surface.LoadIdentity
love.graphics.translate = surface.Translate
love.graphics.shear = surface.Shear
love.graphics.rotate = surface.Rotate
love.graphics.push = surface.PushMatrix
love.graphics.pop = surface.PopMatrix

function love.graphics.scale(x, y)
	y = y or x
	surface.Scale(x, y)
end

function love.graphics.setCaption(title)
	window.SetTitle(title)
end


function love.graphics.getWidth()
	return render.GetWidth()
end

function love.graphics.getHeight()
	return render.GetHeight()
end

function love.graphics.setMode()

end

function love.graphics.getDimensions()
	return render.GetWidth(), render.GetHeight()
end

function love.graphics.reset()

end

function love.graphics.isSupported(what)
	if what == "multicanvas" then
		return false
	end
	return true
end

do
	ENV.graphics_color_r = 255
	ENV.graphics_color_g = 255
	ENV.graphics_color_b = 255
	ENV.graphics_color_a = 255

	function love.graphics.setColor(r, g, b, a)
		if type(r) == "number" then
			ENV.graphics_color_r = r or 0
			ENV.graphics_color_g = g or 0
			ENV.graphics_color_b = b or 0
			ENV.graphics_color_a = a or 255
		else
			ENV.graphics_color_r = r[1] or 0
			ENV.graphics_color_g = r[2] or 0
			ENV.graphics_color_b = r[3] or 0
			ENV.graphics_color_a = r[4] or 255
		end

		surface.SetColor(ENV.graphics_color_r/255, ENV.graphics_color_g/255, ENV.graphics_color_b/255, ENV.graphics_color_a/255)
	end

	function love.graphics.getColor()
		return ENV.graphics_color_r, ENV.graphics_color_g, ENV.graphics_color_b, ENV.graphics_color_a
	end
end

do -- background
	ENV.graphics_bg_color_r = 0
	ENV.graphics_bg_color_g = 0
	ENV.graphics_bg_color_b = 0
	ENV.graphics_bg_color_a = 255

	function love.graphics.setBackgroundColor(r, g, b, a)
		if type(r) == "number" then
			ENV.graphics_bg_color_r = r or 0
			ENV.graphics_bg_color_g = g or 0
			ENV.graphics_bg_color_b = b or 0
			ENV.graphics_bg_color_a = a or 255
		else
			ENV.graphics_bg_color_r = r[1] or 0
			ENV.graphics_bg_color_g = r[2] or 0
			ENV.graphics_bg_color_b = r[3] or 0
			ENV.graphics_bg_color_a = r[4] or 255
		end
	end

	function love.graphics.getBackgroundColor()
		return ENV.graphics_bg_color_r, ENV.graphics_bg_color_g, ENV.graphics_bg_color_b, ENV.graphics_bg_color_a
	end

	function love.graphics.clear()
		local canvas = love.graphics.getCanvas()
		if canvas then
			canvas:clear()
		else
			local br, bg, bb, ba = love.graphics.getBackgroundColor()
			surface.SetWhiteTexture()
			surface.SetColor(br/255,bg/255,bb/255,ba/255)
			surface.DrawRect(0, 0, render.GetWidth(), render.GetHeight())
			love.graphics.setColor(love.graphics.getColor())
		end
	end
end

do
	local COLOR_MDOE
	local ALPHA_MDOE

	function love.graphics.setBlendMode(color_mode, alpha_mode)
		alpha_mode = alpha_mode or "alphamultiply"
		local func   = "add"
		local srcRGB = "one"
		local srcA   = "one"
		local dstRGB = "zero"
		local dstA   = "zero"

		if color_mode == "alpha" then
			srcRGB = "one"
			srcA = "one"

			dstRGB = "one_minus_src_alpha"
			dstA = "one_minus_src_alpha"
		elseif color_mode == "multiply" or "multiplicative" then
			srcRGB = "dst_color"
			srcA = "dst_color"

			dstRGB = "zero"
			dstA = "zero"
		elseif color_mode == "subtract" or color_mode == "subtractive" then
			func = "subtract"
		elseif color_mode == "add" or color_mode == "additive" then
			srcRGB = "one"
			srcA = "zero"

			dstRGB = "one"
			dstA = "one"
		elseif color_mode == "lighten" then
			func = "max"
		elseif color_mode == "darken" then
			func = "min"
		elseif color_mode == "screen" then
			srcRGB = "one"
			srcA = "one"

			dstRGB = "one_minus_src_color"
			dstA = "one_minus_src_color"
		else --if color_mode == "replace" then
			srcRGB = "one"
			srcA = "one"

			dstRGB = "zero"
			dstA = "zero"
		end

		if srcRGB == "one" and alpha_mode == "alphamultiply" then
			srcRGB = "src_alpha"
		end

		render.SetBlendMode(srcRGB, dstRGB, func, srcA, dstA, func)

		COLOR_MDOE = color_mode
		ALPHA_MDOE = alpha_mode
	end

	function love.graphics.getBlendMode()
		return COLOR_MDOE, ALPHA_MDOE
	end
end

do
	function love.graphics.setColorMode(mode)
		if mode == "replace" then mode = "none" end
		--render.SetColorMode(mode)
	end

	function love.graphics.getColorMode()
		--return render.GetBlendMode()
		return "modulate"
	end
end

do -- points
	function love.graphics.setPointStyle(style)
		surface.SetPointStyle(style)
	end

	function love.graphics.getPointStyle()
		return surface.GetPointStyle()
	end

	function love.graphics.setPointSize(size)
		surface.SetPointSize(size)
	end

	function love.graphics.getPointSize()
		return surface.GetPointSize()
	end

	function love.graphics.setPoint(size, style)
		surface.SetPointSize(size)
		surface.SetPointStyle(style)
	end

	function love.graphics.point(x, y)
		surface.DrawPoint(x, y)
	end

	function love.graphics.points(...)
		if type(...) == "number" then
			surface.DrawPoint(...)
		else
			for i, point in ipairs(...) do
				if point[3] then
					surface.SetColor(point[3], point[4], point[5], point[6])
				end
				surface.DrawPoint(point[1], point[2])
			end
		end
	end
end


do -- font

	local Font = lovemu.TypeTemplate("Font")
	function Font:getWidth(str)
		str = str or "W"
		return (self.font:GetTextSize(str))
	end

	function Font:getHeight(str)
		str = str or "W"
		return select(2, self.font:GetTextSize())
	end

	function Font:setLineHeight(num)
		self.line_height = num
	end

	function Font:getLineHeight(num)
		self.line_height = num
	end

	function Font:getWrap()
		return 1, 1
	end

	function Font:setFilter(filter)
		self.filter = filter
	end

	function Font:getFilter()
		return self.filter
	end

	function Font:setFallbacks(...)

	end

	local function create_font(path, size, glyphs, texture)
		local self = lovemu.CreateObject("Font")

		path = lovemu.FixPath(path)

		self.font = surface.CreateFont({
			size = size,
			path = path,
			filtering = ENV.graphics_filter_min,
			glyphs = glyphs,
			texture = texture,
		})


		self.Name = self.font:GetName()

		local w, h = self.font:GetTextSize("W")
		self.Size = size or w

		return self
	end

	function love.graphics.newFont(a, b)
		local font = a
		local size = b

		if type(a) == "number" then
			font = "fonts/vera.ttf"
			size = a
		end

		if not a then
			font = "fonts/vera.ttf"
			size = b or 10
		end

		size = size or 12

		return create_font(font, size)
	end

	function love.graphics.newImageFont(path, glyphs)
		local tex
		if lovemu.Type(path) == "Image" then
			tex = ENV.textures[path]
			path = "memory"
		end
		return create_font(path, nil, glyphs, tex)
	end

	function love.graphics.setFont(font)
		font = font or love.graphics.getFont()
		ENV.current_font = font
		surface.SetFont(font.font)
	end

	function love.graphics.getFont()
		if not ENV.default_font then
			ENV.default_font = love.graphics.newFont()
		end
		return ENV.current_font or ENV.default_font
	end

	function love.graphics.setNewFont(...)
		love.graphics.setFont(love.graphics.newFont(...))
	end

	local function draw_text(text, x, y, r, sx, sy, ox, oy, kx, ky, align, limit)
		text = tostring(text)
		x = x or 0
		y = y or 0
		sx = sx or 1
		sy = sy or sx
		r = r or 0
		ox = ox or 0
		oy = oy or 0
		kx = kx or 0
		ky = ky or 0

		local cr, cg, cb, ca = love.graphics.getColor()
		surface.SetColor(cr/255, cg/255, cb/255, ca/255)
		surface.PushMatrix(x, y, sx, sy, r)
			if align then
				local max_width = 0
				local t = surface.WrapString(text, limit)

				for i, line in ipairs(t) do
					local w, h = surface.GetTextSize(line)
					if w > max_width then
						max_width = w
					end
				end

				for i, line in ipairs(t) do
					local w, h = surface.GetTextSize(line)

					local align_x = 0

					if align == "right" then
						align_x = max_width - w
					elseif align == "center" then
						align_x = (-w / 2) + limit/2 - x
					end

					surface.SetTextPosition(x + align_x, (i-1) * h)
					surface.DrawText(line)
				end
			else
				surface.SetTextPosition(0, 0)
				surface.DrawText(text)
			end
		surface.PopMatrix()
	end

	function love.graphics.print(text, x, y, r, sx, sy, ox, oy, kx, ky)
		return draw_text(text, x, y, r, sx, sy, ox, oy, kx, ky)
	end

	function love.graphics.printf(text, x, y, limit, align, r, sx, sy, ox, oy, kx, ky)
		return draw_text(text, x, y, r, sx, sy, ox, oy, kx, ky, align or "left", limit or 0)
	end

	lovemu.RegisterType(Font)
end

do -- line
	ENV.graphics_line_width = 1
	ENV.graphics_line_style = "huh"
	ENV.graphics_line_join = "huh"

	function love.graphics.setLineStyle(s)
		ENV.graphics_line_style = s
	end

	function love.graphics.getLineStyle()
		return ENV.graphics_line_style
	end

	function love.graphics.setLineJoin(s)
		ENV.graphics_line_join = s
	end

	function love.graphics.getLineJoin(s)
		return ENV.graphics_line_join
	end

	function love.graphics.setLineWidth(w)
		ENV.graphics_line_width = w
	end

	function love.graphics.getLineWidth()
		return ENV.graphics_line_width
	end

	function love.graphics.line(...)
		local tbl = {...}

		if type(tbl[1]) == "table" then
			tbl = tbl[1]
		end

		local last_x
		local last_y

		for i = 1, #tbl, 2 do
			local x, y = tbl[i+0], tbl[i+1]
			if last_x and last_y then
				surface.DrawLine(last_x, last_y, x, y)
			end
			last_x = x
			last_y = y
		end
	end
end

do -- canvas
	local Canvas = lovemu.TypeTemplate("Canvas")

	ADD_FILTER(Canvas)

	function Canvas:renderTo(cb)
		local old = love.graphics.getCanvas()
		love.graphics.setCanvas(self)

		local ok, err = pcall(cb)
		if not ok then wlog(err) end

		love.graphics.setCanvas(old)
	end

	function Canvas:getWidth()
		return self.w
	end

	function Canvas:getHeight()
		return self.h
	end

	function Canvas:getImageData()

	end

	function Canvas:clear(...)
		self.fb:ClearAll()
	end

	function Canvas:setWrap()

	end

	function Canvas:getWrap()

	end

	function love.graphics.newCanvas(w, h)
		w = w or render.GetWidth()
		h = h or render.GetHeight()

		local self = lovemu.CreateObject("Canvas")

		self.fb = render.CreateFrameBuffer(Vec2(w, h), {
			mag_filter = ENV.graphics_filter_mag,
			min_filter = ENV.graphics_filter_min,
		})

		ENV.textures[self] = self.fb:GetTexture()

		return self
	end

	function love.graphics.setCanvas(canvas)
		ENV.graphics_current_canvas = canvas

		if canvas then
			canvas.fb:Bind()
			render.SetViewport(0, 0, canvas.fb:GetTexture():GetSize().x, canvas.fb:GetTexture():GetSize().y)
		else
			render.GetScreenFrameBuffer():Bind()
			render.SetViewport(0, 0, window.GetSize():Unpack())
		end
	end

	function love.graphics.getCanvas()
		return ENV.graphics_current_canvas
	end

	lovemu.RegisterType(Canvas)
end

do -- image
	local Image = lovemu.TypeTemplate("Image")

	function Image:getWidth()
		return ENV.textures[self]:GetSize().x
	end

	function Image:getHeight()
		return ENV.textures[self]:GetSize().y
	end

	function Image:getDimensions()
		return ENV.textures[self]:GetSize().x, ENV.textures[self]:GetSize().y
	end

	function Image:getHeight()
		return ENV.textures[self]:GetSize().y
	end

	function Image:getData()
		local tex = ENV.textures[self]
		local data = tex:Download()
		local img_data = love.image.newImageData(self:getDimensions())
		img_data.buffer = data.buffer
		img_data.tex = tex
		return img_data
	end

	ADD_FILTER(Image)

	function Image:setWrap()

	end

	function Image:getWrap()

	end

	function love.graphics.newImage(path)
		if lovemu.Type(path) == "ImageData" then
			return path
		else
			local self = lovemu.CreateObject("Image")

			path = lovemu.FixPath(path)

			local tex = render.CreateTextureFromPath(path)
			tex:SetMinFilter(ENV.graphics_filter_min)
			tex:SetMagFilter(ENV.graphics_filter_mag)
			ENV.textures[self] = tex

			return self
		end
	end

	function love.graphics.newImageData(path)
		local self = lovemu.CreateObject("Image")

		path = lovemu.FixPath(path)

		local tex = render.CreateTextureFromPath(path)
		tex:SetMinFilter(ENV.graphics_filter_min)
		tex:SetMagFilter(ENV.graphics_filter_mag)
		ENV.textures[self] = tex

		return self
	end

	lovemu.RegisterType(Image)
end

do -- stencil
	function love.graphics.newStencil(func)

	end

	function love.graphics.setStencil(func)

	end

	function love.graphics.setStencilTest(b)
		ENV.graphics_stencil_test = b
	end

	function love.graphics.getStencilTest()
		return ENV.graphics_stencil_test
	end

	function love.graphics.stencil(stencilfunction, keepbuffer)

	end
end

function love.graphics.rectangle(mode, x, y, w, h)
	if mode == "fill" then
		surface.SetWhiteTexture()
		surface.DrawRect(x, y, w, h)
	else
		surface.DrawLine(x,y, x+w,y)
		surface.DrawLine(x,y, x,y+h)
		surface.DrawLine(x+w,y, x+w,y+h)
		surface.DrawLine(x,y+h, x+w,y+h)
	end
end

function love.graphics.circle(mode,x,y,w,h)
	surface.SetWhiteTexture()
	surface.DrawRect(x or 0, y or 0, w or 0, h or 0)
end

function love.graphics.arc(...)
	if type(select(2, ...)) == "string" then
		local drawmode, arctype, x, y, radius, angle1, angle2, segments = ...

	else
		local drawmode, x, y, radius, angle1, angle2, segments = ...

	end
end

function love.graphics.drawq(drawable, quad, x,y, r, sx,sy, ox,oy)
	x=x or 0
	y=y or 0
	sx=sx or 1
	sy=sy or sx
	ox=ox or 0
	oy=oy or 0
	r=r or 0

	local cr, cg, cb, ca = love.graphics.getColor()
	surface.SetColor(cr/255, cg/255, cb/255, ca/255)
	surface.SetTexture(ENV.textures[drawable])
	surface.SetRectUV(quad.x,quad.y, quad.w,quad.h, quad.sw,quad.sh)
	surface.DrawRect(x,y, quad.w*sx, quad.h*sy,r,ox*sx,oy*sy)
	surface.SetRectUV()
end

function love.graphics.draw(drawable, x, y, r, sx, sy, ox, oy, quad_arg)
	if lovemu.Type(drawable) == "SpriteBatch" then
		surface.SetColor(1,1,1,1)
		surface.SetTexture(ENV.textures[drawable.img])
		drawable.poly:Draw()
	else
		if ENV.textures[drawable] then
			if lovemu.Type(x) == "Quad" then
				love.graphics.drawq(drawable, x, y, r, sx, sy, ox, oy, quad_arg)
			else
				x=x or 0
				y=y or 0
				sx=sx or 1
				sy=sy or sx
				ox=ox or 0
				oy=oy or 0
				r=r or 0

				local tex = ENV.textures[drawable]

				--if drawable.fb then  sx = 5 sy = 6 end

				surface.SetTexture(tex)
				surface.DrawRect(x,y, tex:GetSize().x*sx, tex:GetSize().y*sy, r, ox*sx,oy*sy)
			end
		end
	end
end

function love.graphics.present()
end

function love.graphics.setIcon()
end

do
	local Shader = lovemu.TypeTemplate("Shader")

	function Shader:getWarnings()
		return ""
	end

	function Shader:send()

	end

	function love.graphics.newShader()
		local obj = lovemu.CreateObject("Shader")

		return obj
	end

	lovemu.RegisterType(Shader)
end

love.graphics.newPixelEffect = love.graphics.newShader

function love.graphics.setShader()
end

function love.graphics.setPixelEffect()
end

function love.graphics.isCreated()
	return true
end

function love.graphics.getModes()
	return {
		{width=720,height=480},
		{width=800,height=480},
		{width=800,height=600},
		{width=852,height=480},
		{width=1024,height=768},
		{width=1152,height=768},
		{width=1152,height=864},
		{width=1280,height=720},
		{width=1280,height=768},
		{width=1280,height=800},
		{width=1280,height=854},
		{width=1280,height=960},
		{width=1280,height=1024},
		{width=1365,height=768},
		{width=1366,height=768},
		{width=1400,height=1050},
		{width=1440,height=900},
		{width=1440,height=960},
		{width=1600,height=900},
		{width=1600,height=1200},
		{width=1680,height=1050},
		{width=1920,height=1080},
		{width=1920,height=1200},
		{width=2048,height=1536},
		{width=2560,height=1600},
		{width=2560,height=2048}
	}
end

do
	function love.graphics.setScissor(x,y,w,h)
		render.SetScissor(x, y, w, h)
	end

	function love.graphics.getScissor()
		return render.GetScissor()
	end
end

local poly = surface.CreatePoly(4096)
local lines = surface.CreateQuadricBeizerCurve(4096)

function love.graphics.polygon(mode, ...)
	local points = type(...) == "table" and ... or {...}

	surface.SetWhiteTexture()
	local idx = 0

	if mode == "line" then
		for i = 1, #points, 2 do
			lines:Set(idx + 1, Vec2(points[i + 0], points[i + 1]))
			idx = idx + 1
		end

		lines:SetMaxLines(idx)
		lines:ConstructPoly(ENV.graphics_line_width*0.75, 1, 1, poly)

		idx = idx * 4
		poly.mesh:SetMode("triangle_strip")
	else
		for i = 1, #points, 2 do
			poly:SetVertex(idx, points[i + 0], points[i + 1])
			idx = idx + 1
		end

		poly.mesh:SetMode("triangle_fan")
	end

	poly:Draw(idx)
end

function love.graphics.getStats()
	return {
		fonts = 1,
		images = 1,
		canvases = 1,
		images = 1,
		texturememory = 1,
		canvasswitches = 1,
		drawcalls = 1,
	}
end

do -- sprite batch
	local SpriteBatch = lovemu.TypeTemplate("SpriteBatch")

	local function set_rect(self, i, x,y, r, sx,sy, ox,oy, kx,ky)
		sx = sx or self.w
		sy = sy or self.h

		if ox then ox = -ox end
		if oy then oy = -oy end

		self.poly:SetRect(i, x,y, sx,sy, r, ox,oy)
	end

	function SpriteBatch:set(id, q, ...)
		id = id or 1
		if lovemu.Type(q) == "Quad" then
			self.poly:SetUV(q.x,q.y, q.w,q.h, q.sw,q.sh)
			local x,y, r, sx,sy, ox,oy, kx,ky = ...
			set_rect(self, id, x,y, r, q.w,q.h, ox,oy,kx,ky)
		else
			set_rect(self, id, q, ...)
		end
	end

	SpriteBatch.setq = SpriteBatch.set

	function SpriteBatch:add(...)
		if self.i < self.size then
			self:set(self.i, ...)
		end

		self.i = self.i + 1

		return self.i
	end

	SpriteBatch.addq = SpriteBatch.add

	function SpriteBatch:setColor(r,g,b,a)

		r = r or 255
		g = g or 255
		b = b or 255
		a = a or 255

		self.poly:SetColor(r/255,g/255,b/255,a/255)
	end

	function SpriteBatch:clear()
		self.i = 1
	end

	function SpriteBatch:getImage()
		return self.image
	end

	function SpriteBatch:bind()

	end

	function SpriteBatch:unbind()

	end

	function SpriteBatch:setImage(image)
		self.img = image
		self.w = image:getWidth()
		self.h = image:getHeight()
	end

	function SpriteBatch:getImage(image)
		return self.img
	end

	function love.graphics.newSpriteBatch(image, size, usagehint)
		local self = lovemu.CreateObject("SpriteBatch")
		local poly = surface.CreatePoly(size * 6)

		self.size = size

		self.poly = poly
		self.img = image
		self.w = image:getWidth()
		self.h = image:getHeight()
		self.i = 1

		return self
	end

	lovemu.RegisterType(SpriteBatch)
end

event.AddListener("PreDrawGUI", "love", function(dt)
	if menu and menu.IsVisible() then
		surface.PushHSV(1,0,1)
	end

	lovemu.CallEvent("lovemu_draw", dt)

	if ENV.error_message and not ENV.no_error then
		love.errhand(ENV.error_message)
	end

	if menu and menu.IsVisible() then
		surface.PopHSV(1,0,1)
	end
end, {on_error = system.pcall})