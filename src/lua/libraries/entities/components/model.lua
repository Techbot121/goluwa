local META = prototype.CreateTemplate()

META.Name = "model"
META.Require = {"transform"}

META:StartStorable()
	META:GetSet("Cull", true)
	META:GetSet("ModelPath", "models/cube.obj")
	META:GetSet("Color", Color(1,1,1,1))
	META:GetSet("RoughnessMultiplier", 1)
	META:GetSet("MetallicMultiplier", 1)
	META:GetSet("UVMultiplier", 1)
META:EndStorable()

META:IsSet("Loading", false)
META:GetSet("Model", nil)
META:GetSet("AABB", AABB())
META:GetSet("MaterialOverride", nil)

META.Network = {
	ModelPath = {"string", 1/5, "reliable"},
	Cull = {"boolean", 1/5},
}

if GRAPHICS then
	function META:Initialize()
		self.sub_meshes = {}
		self.next_visible = {}
		self.visible = {}
		self.occluders = {}
	end

	function META:SetVisible(b)
		if b then
			render3d.AddModel(self)
		else
			render3d.RemoveModel(self)
		end
		self.is_visible = b
	end

	function META:SetMaterialOverride(mat)
		self.MaterialOverride = mat
	end

	function META:OnAdd()
		self.tr = self:GetComponent("transform")
	end

	function META:SetAABB(aabb)
		self.tr:SetAABB(aabb)
		self.AABB = aabb
	end

	function META:OnRemove()
		render3d.RemoveModel(self)
		for _, v in pairs(self.occluders) do
			v:Delete()
		end
	end

	function META:SetModelPath(path)
		self:RemoveMeshes()

		self.ModelPath = path

		self:SetLoading(true)

		render3d.LoadModel(
			path,
			function()
				self:SetLoading(false)
				self:BuildBoundingBox()
			end,
			function(mesh)
				self:AddMesh(mesh)
			end,
			function(err)
				logf("%s failed to load mesh %q: %s\n", self, path, err)
				self:MakeError()
			end
		)

		self.EditorName = ("/" .. self.ModelPath):match("^.+/(.+)%."):lower():gsub("_", " "):gsub("%d", ""):gsub("%s+", " ")
	end

	function META:MakeError()
		self:RemoveMeshes()
		self:SetLoading(false)
		self:SetModelPath("models/error.mdl")
	end

	do
		local function check_translucent(self)
			self.translucent = false

			if self.MaterialOverride then
				self.translucent = self.MaterialOverride:GetTranslucent()
			else
				for _, mesh in ipairs(self.sub_meshes) do
					if mesh.material:GetTranslucent() then
						self.translucent = true
					end
				end
			end
		end

		function META:AddMesh(mesh)
			table.insert(self.sub_meshes, mesh)
			mesh.material = mesh.material or render3d.default_material
			mesh:CallOnRemove(function()
				if self:IsValid() then
					self:RemoveMesh(mesh)
				end
			end, self)

			if self.MaterialOverride then
				self:SetMaterialOverride(self:GetMaterialOverride())
			end

			render3d.AddModel(self)

			check_translucent(self)
		end

		function META:RemoveMesh(mesh)
			for i, v in ipairs(self.sub_meshes) do
				if v == mesh then
					table.remove(self.sub_meshes, i)
					break
				end
			end

			if not self.sub_meshes[1] then
				render3d.RemoveModel(self)
			end

			check_translucent(self)
		end

		function META:RemoveMeshes()
			for _, mesh in pairs(self.sub_meshes) do
				self:RemoveMesh(mesh)
			end
		end

		function META:GetMeshes()
			return self.sub_meshes
		end
	end

	function META:BuildBoundingBox()
		for _, mesh in ipairs(self.sub_meshes) do
			self.AABB:Expand(mesh.AABB)
		end

		self:SetAABB(self.AABB)

		render3d.largest_aabb = render3d.largest_aabb or AABB()
		local old = render3d.largest_aabb:Copy()
		render3d.largest_aabb:Expand(self.AABB)
		if old ~= render3d.largest_aabb then
			event.Call("LargestAABB", render3d.largest_aabb)
		end
	end

	function META:IsTranslucent()
		return self.translucent
	end

	local system_GetElapsedTime = system.GetElapsedTime

	function META:IsVisible(what)
		if not self.next_visible[what] or self.next_visible[what] < system_GetElapsedTime() then
			self.visible[what] = camera.camera_3d:IsAABBVisible(self.tr:GetTranslatedAABB(), self.tr:GetCameraDistance(), self.tr:GetBoundingSphere())
			self.next_visible[what] = system_GetElapsedTime() + 0.25
		end

		return self.visible[what]
	end

	local ipairs = ipairs
	local render_SetMaterial = render.SetMaterial

	if DISABLE_CULLING then
		function META:Draw()
			camera.camera_3d:SetWorld(self.tr:GetMatrix())

			for _, mesh in ipairs(self.sub_meshes) do
				mesh.material.Color = self.Color
				mesh.material.RoughnessMultiplier = self.RoughnessMultiplier
				mesh.material.MetallicMultiplier = self.MetallicMultiplier
				render_SetMaterial(mesh.material)
				render3d.shader:Bind()
				mesh.vertex_buffer:Draw()
			end
		end
	else
		function META:Draw(what)
			--[[
			if render3d.draw_once and self.Cull then
				if self.drawn_once then
					return
				end
			else
				self.drawn_once = false
			end
			]]

			if self:IsVisible(what) then
				camera.camera_3d:SetWorld(self.tr:GetMatrix())

				if self.occluders[what] then
					self.occluders[what]:BeginConditional()
				end
				if self.MaterialOverride then
					local mat = self.MaterialOverride
					mat.Color = self.Color
					mat.RoughnessMultiplier = self.RoughnessMultiplier
					mat.MetallicMultiplier = self.MetallicMultiplier
					mat.UVMultiplier = self.UVMultiplier
					render_SetMaterial(mat)
					for _, mesh in ipairs(self.sub_meshes) do
						render3d.shader:Bind()
						mesh.vertex_buffer:Draw()
					end
				else
					for _, mesh in ipairs(self.sub_meshes) do
						mesh.material.Color = self.Color
						mesh.material.RoughnessMultiplier = self.RoughnessMultiplier
						mesh.material.MetallicMultiplier = self.MetallicMultiplier
						mesh.material.UVMultiplier = self.UVMultiplier
						render_SetMaterial(mesh.material)
						render3d.shader:Bind()
						mesh.vertex_buffer:Draw()
					end
				end

				if self.occluders[what] then
					self.occluders[what]:EndConditional()
				end

				--[[
				if render3d.draw_once then
					self.drawn_once = true
				end
				]]
			end
		end
	end
end

META:RegisterComponent()

if RELOAD then
	render3d.Initialize()
end