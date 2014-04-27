render.framebuffers = setmetatable({}, { __mode = 'v' })

function render.GetFramebuffers()
	return render.framebuffers
end

local META = utilities.CreateBaseMeta("framebuffer")

function META:__tostring()
	return ("frame_buffer[%i]"):format(self.id)
end

function META:Begin()	
	gl.BindFramebuffer(e.GL_FRAMEBUFFER, self.id)
	gl.Viewport(0, 0, self.width, self.height)
end

function META:Bind()
	self:Begin()
end

function META:End()
	gl.BindFramebuffer(e.GL_FRAMEBUFFER, 0)
end

function META:Clear(r,g,b,a)
	gl.ClearColor(r or 0, g or 0, b or 0, a or 1)
	gl.Clear(bit.bor(e.GL_COLOR_BUFFER_BIT, e.GL_DEPTH_BUFFER_BIT))
end

function META:GetTexture(type)
	type = type or "default"
	
	if self.buffers[type] then
		return self.buffers[type].tex
	end
	
	return render.GetErrorTexture()
end

function META:Remove()
	gl.DeleteFramebuffers(1, ffi.new("GLuint[1]", self.id))
	
	for k, v in pairs(self.buffers) do
		gl.DeleteRenderbuffers(1, ffi.new("GLuint[1]", v.id))
	end
		
	utilities.MakeNULL(self)
end

function render.CreateFrameBuffer(width, height, format)

	if not render.CheckSupport("GenFramebuffer") then return NULL end
	
	local self = META:New()

	self.buffers = {}
	self.width = width
	self.height = height
	self.draw_buffers = {}
	
	if not format then
		format = {
			attach = e.GL_COLOR_ATTACHMENT0,
			texture_format = {
				internal_format = e.GL_RGBA32F,
			}
		}
	end
	
	if not format[1] then 
		format.name = format.name or "default"
		format = {format} 
	end
	
		
	local id = gl.GenFramebuffer()
	self.id = id
	gl.BindFramebuffer(e.GL_FRAMEBUFFER, id)
	 
	for i, info in pairs(format) do
		local tex_info = info.texture_format
		
		local tex = NULL
		local id
		
		if tex_info then
			tex_info.format = e.GL_BGRA
			tex_info.channel = i-1
						
			tex = render.CreateTexture(width, height, nil, tex_info)
			id = tex.id
		
			tex.framebuffer_name = info.name
						
			if not info.draw_manual then
				table.insert(self.draw_buffers, info.attach)
			end
		else
			id = gl.GenRenderbuffer()
			gl.BindRenderbuffer(e.GL_RENDERBUFFER, id)		
		
			gl.RenderbufferStorage(e.GL_RENDERBUFFER, info.internal_format, width, height)
		end
		
		self.buffers[info.name] = {id = id, tex = tex, info = info, draw_enum = ffi.new("GLenum[1]", info.attach)}
	end

	for i, data in pairs(self.buffers) do
		if data.tex:IsValid() then
			gl.FramebufferTexture2D(e.GL_FRAMEBUFFER, data.info.attach, e.GL_TEXTURE_2D, data.id, 0)
		else
			gl.FramebufferRenderbuffer(e.GL_FRAMEBUFFER, data.info.attach, e.GL_RENDERBUFFER, data.id)
		end
		data.info = nil
	end
	
	self.draw_buffers_size = #self.draw_buffers
	self.draw_buffers = ffi.new("GLenum["..self.draw_buffers_size.."]", self.draw_buffers)
	
	gl.DrawBuffers(self.draw_buffers_size, self.draw_buffers)
		
	local err = gl.CheckFramebufferStatus(e.GL_FRAMEBUFFER)
	
	if err ~= e.GL_FRAMEBUFFER_COMPLETE then
		local str = "Unknown error: " .. err
		
		if err == e.GL_FRAMEBUFFER_UNSUPPORTED then
			str = "format not supported"
		elseif err == e.GL_FRAMEBUFFER_INCOMPLETE_ATTACHMENT then
			str = "incomplete attachment"
		elseif err == e.GL_FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT then
			str = "incomplete missing attachment"
		elseif err == e.GL_FRAMEBUFFER_INCOMPLETE_DIMENSIONS then
			str = "attached images must have same dimensions"
		elseif err == e.GL_FRAMEBUFFER_INCOMPLETE_FORMATS then
			str = "attached images must have same format"
		elseif err == e.GL_FRAMEBUFFER_INCOMPLETE_DRAW_BUFFER then
			str = "missing draw buffer"
		elseif err == e.GL_FRAMEBUFFER_INCOMPLETE_READ_BUFFER then
			str = "missing read buffer"
		end
		
		self:Remove()
		error(str, 2)
	end
	
	gl.BindFramebuffer(e.GL_FRAMEBUFFER, 0)
		
	render.framebuffers[id] = self
	
	return self
end