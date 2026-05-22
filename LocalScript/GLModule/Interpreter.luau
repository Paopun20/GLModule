--!strict
--!native
--!optimize 2

local SIN = math.sin
local COS = math.cos
local TAN = math.tan

local ABS = math.abs
local MIN = math.min
local MAX = math.max

local SQRT = math.sqrt

export type vec2 = {
	x: number,
	y: number,
}

export type vec3 = {
	x: number,
	y: number,
	z: number,
}

export type vec4 = {
	x: number,
	y: number,
	z: number,
	w: number,
}

type Scope = {
	parent: Scope?,
	variables: {[string]: any},
}

local function vec2Ctor(
	x: number,
	y: number?
): vec2

	y = y or x

	return {
		x = x,
		y = y,
	}
end

local function vec3Ctor(
	x: number,
	y: number?,
	z: number?
): vec3

	y = y or x
	z = z or x

	return {
		x = x,
		y = y,
		z = z,
	}
end

local function vec4Ctor(
	x: number,
	y: number?,
	z: number?,
	w: number?
): vec4

	y = y or x
	z = z or x
	w = w or x

	return {
		x = x,
		y = y,
		z = z,
		w = w,
	}
end

local BUILTINS = {

	sin = SIN,
	cos = COS,
	tan = TAN,

	abs = ABS,
	min = MIN,
	max = MAX,
	sqrt = SQRT,

	vec2 = vec2Ctor,
	vec3 = vec3Ctor,
	vec4 = vec4Ctor,
}

local Interpreter = {}
Interpreter.__index = Interpreter

function Interpreter.new()

	local self = setmetatable({}, Interpreter)

	self.globalScope = {
		parent = nil,
		variables = {
			gl_FragColor = vec4Ctor(0, 0, 0, 1),
		},
	}

	self.functions = {}

	return self
end

local function createScope(
	parent: Scope?
): Scope

	return {
		parent = parent,
		variables = {},
	}
end

local function defineVariable(
	scope: Scope,
	name: string,
	value: any
)
	scope.variables[name] = value
end

local function resolveVariable(
	scope: Scope,
	name: string
)

	local current = scope

	while current do

		local value =
			current.variables[name]

		if value ~= nil then
			return value
		end

		current = current.parent
	end

	error(
		("Undefined variable '%s'")
			:format(name)
	)
end

local function assignVariable(
	scope: Scope,
	name: string,
	value: any
)

	local current = scope

	while current do

		if current.variables[name] ~= nil then
			current.variables[name] = value
			return
		end

		current = current.parent
	end

	error(
		("Undefined variable '%s'")
			:format(name)
	)
end

local function isVector(value: any): boolean

	return type(value) == "table"
		and value.x ~= nil
end

local function binaryAdd(a, b)

	if isVector(a)
		and isVector(b)
	then

		if a.w ~= nil then
			return vec4Ctor(
				a.x + b.x,
				a.y + b.y,
				a.z + b.z,
				a.w + b.w
			)
		end

		if a.z ~= nil then
			return vec3Ctor(
				a.x + b.x,
				a.y + b.y,
				a.z + b.z
			)
		end

		return vec2Ctor(
			a.x + b.x,
			a.y + b.y
		)
	end

	return a + b
end

local function binarySub(a, b)

	if isVector(a)
		and isVector(b)
	then

		if a.w ~= nil then
			return vec4Ctor(
				a.x - b.x,
				a.y - b.y,
				a.z - b.z,
				a.w - b.w
			)
		end

		if a.z ~= nil then
			return vec3Ctor(
				a.x - b.x,
				a.y - b.y,
				a.z - b.z
			)
		end

		return vec2Ctor(
			a.x - b.x,
			a.y - b.y
		)
	end

	return a - b
end

local function binaryMul(a, b)

	if isVector(a)
		and type(b) == "number"
	then

		if a.w ~= nil then
			return vec4Ctor(
				a.x * b,
				a.y * b,
				a.z * b,
				a.w * b
			)
		end

		if a.z ~= nil then
			return vec3Ctor(
				a.x * b,
				a.y * b,
				a.z * b
			)
		end

		return vec2Ctor(
			a.x * b,
			a.y * b
		)
	end

	return a * b
end

local function binaryDiv(a, b)

	if isVector(a)
		and type(b) == "number"
	then

		if a.w ~= nil then
			return vec4Ctor(
				a.x / b,
				a.y / b,
				a.z / b,
				a.w / b
			)
		end

		if a.z ~= nil then
			return vec3Ctor(
				a.x / b,
				a.y / b,
				a.z / b
			)
		end

		return vec2Ctor(
			a.x / b,
			a.y / b
		)
	end

	return a / b
end

function Interpreter:execute(program)

	for _, node in program.body do

		if node.type == "FunctionDeclaration" then

			self.functions[node.name] =
				node

			continue
		end

		if node.type == "UniformDeclaration" then

			defineVariable(
				self.globalScope,
				node.name,
				0
			)

			continue
		end

		self:evaluate(
			node,
			self.globalScope
		)
	end
end

function Interpreter:setUniform(
	name: string,
	value: any
)
	defineVariable(
		self.globalScope,
		name,
		value
	)
end

function Interpreter:callFunction(
	name: string,
	args: {any}
)

	local builtin =
		BUILTINS[name]

	if builtin then
		return builtin(
			table.unpack(args)
		)
	end

	local fn =
		self.functions[name]

	if not fn then
		error(
			("Unknown function '%s'")
				:format(name)
		)
	end

	local scope =
		createScope(
			self.globalScope
		)

	for index, param
		in fn.parameters
	do
		defineVariable(
			scope,
			param.name,
			args[index]
		)
	end

	local result =
		self:evaluate(
			fn.body,
			scope
		)

	if type(result) == "table"
		and result.__return
	then
		return result.value
	end

	return nil
end

function Interpreter:evaluate(
	node,
	scope: Scope
)

	-- literals

	if node.type == "NumberLiteral" then
		return node.value
	end

	if node.type == "BooleanLiteral" then
		return node.value
	end

	-- identifiers

	if node.type == "Identifier" then
		return resolveVariable(
			scope,
			node.name
		)
	end

	-- variable declaration

	if node.type
		== "VariableDeclaration"
	then

		local value = nil

		if node.value then
			value = self:evaluate(
				node.value,
				scope
			)
		end

		defineVariable(
			scope,
			node.name,
			value
		)

		return nil
	end

	-- assignment

	if node.type
		== "AssignmentExpression"
	then

		local value =
			self:evaluate(
				node.right,
				scope
			)

		local left = node.left

		if left.type
			~= "Identifier"
		then
			error(
				"Invalid assignment target"
			)
		end

		if node.operator == "+=" then
			value = binaryAdd(
				resolveVariable(scope, left.name),
				value
			)
		elseif node.operator == "-=" then
			value = binarySub(
				resolveVariable(scope, left.name),
				value
			)
		elseif node.operator == "*=" then
			value = binaryMul(
				resolveVariable(scope, left.name),
				value
			)
		elseif node.operator == "/=" then
			value = binaryDiv(
				resolveVariable(scope, left.name),
				value
			)
		end

		assignVariable(
			scope,
			left.name,
			value
		)

		return value
	end

	-- binary

	if node.type
		== "BinaryExpression"
	then

		local left =
			self:evaluate(
				node.left,
				scope
			)

		local right =
			self:evaluate(
				node.right,
				scope
			)

		local op =
			node.operator

		if op == "+" then
			return binaryAdd(
				left,
				right
			)
		end

		if op == "-" then
			return binarySub(
				left,
				right
			)
		end

		if op == "*" then
			return binaryMul(
				left,
				right
			)
		end

		if op == "/" then
			return binaryDiv(
				left,
				right
			)
		end

		if op == "==" then
			return left == right
		end

		if op == "!=" then
			return left ~= right
		end

		if op == ">" then
			return left > right
		end

		if op == "<" then
			return left < right
		end

		if op == ">=" then
			return left >= right
		end

		if op == "<=" then
			return left <= right
		end

		if op == "&&" then
			return left and right
		end

		if op == "||" then
			return left or right
		end

		error(
			("Unknown operator '%s'")
				:format(op)
		)
	end

	-- unary

	if node.type
		== "UnaryExpression"
	then

		local value =
			self:evaluate(
				node.argument,
				scope
			)

		local op =
			node.operator

		if op == "-" then
			return -value
		end

		if op == "!" then
			return not value
		end

		error(
			("Unknown unary '%s'")
				:format(op)
		)
	end

	-- member access

	if node.type
		== "MemberExpression"
	then

		local object =
			self:evaluate(
				node.object,
				scope
			)

		return object[
		node.property
		]
	end

	-- call

	if node.type
		== "CallExpression"
	then

		local callee =
			node.callee

		if callee.type
			~= "Identifier"
		then
			error(
				"Unsupported callee"
			)
		end

		local args = {}

		for _, arg
			in node.arguments
		do
			table.insert(
				args,
				self:evaluate(
					arg,
					scope
				)
			)
		end

		return self:callFunction(
			callee.name,
			args
		)
	end

	-- expression statement

	if node.type
		== "ExpressionStatement"
	then

		return self:evaluate(
			node.expression,
			scope
		)
	end

	-- block

	if node.type
		== "BlockStatement"
	then

		local blockScope =
			createScope(scope)

		for _, statement
			in node.body
		do

			local result =
				self:evaluate(
					statement,
					blockScope
				)

			if type(result) == "table"
				and result.__return
			then
				return result
			end
		end

		return nil
	end

	-- if

	if node.type
		== "IfStatement"
	then

		local test =
			self:evaluate(
				node.test,
				scope
			)

		if test then

			return self:evaluate(
				node.consequent,
				scope
			)
		end

		if node.alternate then

			return self:evaluate(
				node.alternate,
				scope
			)
		end

		return nil
	end

	-- return

	if node.type
		== "ReturnStatement"
	then

		local value = nil

		if node.argument then
			value =
				self:evaluate(
					node.argument,
					scope
				)
		end

		return {
			__return = true,
			value = value,
		}
	end

	error(
		("Unknown node '%s'")
			:format(node.type)
	)
end

return Interpreter
