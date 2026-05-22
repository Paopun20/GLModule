--!strict
--!native
--!optimize 2

local Lexer = require(script.Lexer)

local Parser = require(script.Parser)

local Interpreter = require(script.Interpreter)

export type ShaderInstance = {
	Program: any,
	Interpreter: any,

	Width: number,
	Height: number,

	Time: number,
	AutoYield: boolean,
	YieldInterval: number,
	YieldCheckCount: number,
	LastYieldTime: number,

	setSizeXY: (self: ShaderInstance, x: number, y: number) -> (),

	setUniform: (self: ShaderInstance, name: string, value: any) -> (),

	step: (self: ShaderInstance, deltaTime: number?) -> (),

	getColorAtPos: (self: ShaderInstance, x: number, y: number) -> any,

	setAutoYield: (self: ShaderInstance, enabled: boolean, interval: number?) -> (),

	_maybeYield: (self: ShaderInstance) -> (),
}

local ShaderInstance = {}
ShaderInstance.__index = ShaderInstance

local function preprocessSource(source: string): string
	local lines = {}
	local defines: { [string]: string } = {}

	local function applyDefines(line: string): string
		for name, value in defines do
			line = string.gsub(line, "%f[%w_]" .. name .. "%f[^%w_]", function()
				return value
			end)
		end

		return line
	end

	for line in string.gmatch(source .. "\n", "(.-)\n") do
		local directive = string.match(line, "^%s*#%s*(.-)%s*$")

		if directive then
			directive = string.gsub(directive, "%s*//.*$", "")

			local name = string.match(directive, "^(%S+)")

			if not name then
				table.insert(lines, "")
			elseif name == "define" then
				local defineName, defineValue = string.match(directive, "^define%s+([_%a][_%w]*)%s*(.-)%s*$")

				if not defineName then
					error(("Invalid preprocessor directive '#%s'"):format(directive))
				end

				defines[defineName] = if defineValue == "" then "1" else defineValue

				table.insert(lines, "")
			elseif name == "undef" then
				local defineName = string.match(directive, "^undef%s+([_%a][_%w]*)%s*$")

				if not defineName then
					error(("Invalid preprocessor directive '#%s'"):format(directive))
				end

				defines[defineName] = nil

				table.insert(lines, "")
			elseif name == "pragma" or name == "version" or name == "extension" then
				table.insert(lines, "")
			else
				error(("Unsupported preprocessor directive '#%s'"):format(directive))
			end
		else
			table.insert(lines, applyDefines(line))
		end
	end

	return table.concat(lines, "\n")
end

function ShaderInstance.new(program): ShaderInstance
	local interpreter = Interpreter.new()

	interpreter:execute(program)

	local self = setmetatable({}, ShaderInstance)

	self.Program = program
	self.Interpreter = interpreter

	self.Width = 1
	self.Height = 1

	self.Time = 0
	self.AutoYield = true
	self.YieldInterval = 0.02
	self.YieldCheckCount = 0
	self.LastYieldTime = os.clock()

	return self
end

function ShaderInstance:setAutoYield(enabled: boolean, interval: number?)
	self.AutoYield = enabled

	if interval then
		self.YieldInterval = interval
	end
end

function ShaderInstance:_maybeYield()
	if not self.AutoYield then
		return
	end

	self.YieldCheckCount += 1

	if self.YieldCheckCount < 512 then
		return
	end

	self.YieldCheckCount = 0

	local now = os.clock()

	if now - self.LastYieldTime < self.YieldInterval then
		return
	end

	task.wait()
	self.LastYieldTime = os.clock()
end

function ShaderInstance:setSizeXY(x: number, y: number)
	self.Width = x
	self.Height = y

	self:setUniform("areaWidth", x)

	self:setUniform("areaHeight", y)
end

function ShaderInstance:setUniform(name: string, value: any)
	self.Interpreter:setUniform(name, value)
end

function ShaderInstance:step(deltaTime: number?)
	deltaTime = deltaTime or (1 / 60)

	self.Time += deltaTime

	self:setUniform("iTime", self.Time)
end

function ShaderInstance:getColorAtPos(x: number, y: number)
	-- self:_maybeYield()

	local uv = {
		x = x / self.Width,
		y = y / self.Height,
	}

	self:setUniform("openfl_TextureCoordv", uv)

	self:setUniform("gl_FragColor", {
		x = 0,
		y = 0,
		z = 0,
		w = 1,
	})

	self.Interpreter:callFunction("main", {})

	local fragColor = self.Interpreter.globalScope.variables.gl_FragColor

	if fragColor then
		return fragColor
	end

	return {
		x = 1,
		y = 0,
		z = 1,
		w = 1,
	}
end

local GLModule = {}

function GLModule.compile(source: string): ShaderInstance
	local lexer = Lexer.new(preprocessSource(source))

	local tokens = lexer:tokenize()

	local parser = Parser.new(tokens)

	local program = parser:parseProgram()

	return ShaderInstance.new(program)
end

return GLModule
