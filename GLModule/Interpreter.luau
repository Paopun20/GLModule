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
	variables: { [string]: any },
}

type Instruction = {
	op: string,
	a: any?,
	b: any?,
}

type Chunk = {
	code: { Instruction },
	parameters: { any },
}

local function vec2Ctor(x: number, y: number?): vec2
	y = y or x

	return {
		x = x,
		y = y,
	}
end

local function vec3Ctor(x: number, y: number?, z: number?): vec3
	y = y or x
	z = z or x

	return {
		x = x,
		y = y,
		z = z,
	}
end

local function vec4Ctor(x: number, y: number?, z: number?, w: number?): vec4
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

local function createScope(parent: Scope?): Scope
	return {
		parent = parent,
		variables = {},
	}
end

local function defineVariable(scope: Scope, name: string, value: any)
	scope.variables[name] = value
end

local function resolveVariable(scope: Scope, name: string)
	local current = scope

	while current do
		local value = current.variables[name]

		if value ~= nil then
			return value
		end

		current = current.parent
	end

	error(("Undefined variable '%s'"):format(name))
end

local function assignVariable(scope: Scope, name: string, value: any)
	local current = scope

	while current do
		if current.variables[name] ~= nil then
			current.variables[name] = value
			return
		end

		current = current.parent
	end

	error(("Undefined variable '%s'"):format(name))
end

local function isVector(value: any): boolean
	return type(value) == "table" and value.x ~= nil
end

local function binaryAdd(a, b)
	if isVector(a) and isVector(b) then
		if a.w ~= nil then
			return vec4Ctor(a.x + b.x, a.y + b.y, a.z + b.z, a.w + b.w)
		end

		if a.z ~= nil then
			return vec3Ctor(a.x + b.x, a.y + b.y, a.z + b.z)
		end

		return vec2Ctor(a.x + b.x, a.y + b.y)
	end

	return a + b
end

local function binarySub(a, b)
	if isVector(a) and isVector(b) then
		if a.w ~= nil then
			return vec4Ctor(a.x - b.x, a.y - b.y, a.z - b.z, a.w - b.w)
		end

		if a.z ~= nil then
			return vec3Ctor(a.x - b.x, a.y - b.y, a.z - b.z)
		end

		return vec2Ctor(a.x - b.x, a.y - b.y)
	end

	return a - b
end

local function binaryMul(a, b)
	if isVector(a) and type(b) == "number" then
		if a.w ~= nil then
			return vec4Ctor(a.x * b, a.y * b, a.z * b, a.w * b)
		end

		if a.z ~= nil then
			return vec3Ctor(a.x * b, a.y * b, a.z * b)
		end

		return vec2Ctor(a.x * b, a.y * b)
	end

	return a * b
end

local function binaryDiv(a, b)
	if isVector(a) and type(b) == "number" then
		if a.w ~= nil then
			return vec4Ctor(a.x / b, a.y / b, a.z / b, a.w / b)
		end

		if a.z ~= nil then
			return vec3Ctor(a.x / b, a.y / b, a.z / b)
		end

		return vec2Ctor(a.x / b, a.y / b)
	end

	return a / b
end

local function emit(code: { Instruction }, op: string, a: any?, b: any?): number
	table.insert(code, {
		op = op,
		a = a,
		b = b,
	})

	return #code
end

local function patchJump(code: { Instruction }, index: number, target: number)
	code[index].a = target
end

local function compileExpression(self, node, code: { Instruction })
	if node.type == "NumberLiteral" or node.type == "BooleanLiteral" then
		emit(code, "PUSH", node.value)
		return
	end

	if node.type == "Identifier" then
		emit(code, "LOAD", node.name)
		return
	end

	if node.type == "MemberExpression" then
		compileExpression(self, node.object, code)
		emit(code, "GET_MEMBER", node.property)
		return
	end

	if node.type == "UnaryExpression" then
		compileExpression(self, node.argument, code)
		emit(code, "UNARY", node.operator)
		return
	end

	if node.type == "BinaryExpression" then
		compileExpression(self, node.left, code)
		compileExpression(self, node.right, code)
		emit(code, "BINARY", node.operator)
		return
	end

	if node.type == "CallExpression" then
		if node.callee.type ~= "Identifier" then
			error("Unsupported callee")
		end

		for _, arg in node.arguments do
			compileExpression(self, arg, code)
		end

		emit(code, "CALL", node.callee.name, #node.arguments)
		return
	end

	if node.type == "AssignmentExpression" then
		local left = node.left

		if left.type ~= "Identifier" then
			error("Invalid assignment target")
		end

		if node.operator ~= "=" then
			emit(code, "LOAD", left.name)
		end

		compileExpression(self, node.right, code)

		if node.operator == "+=" then
			emit(code, "BINARY", "+")
		elseif node.operator == "-=" then
			emit(code, "BINARY", "-")
		elseif node.operator == "*=" then
			emit(code, "BINARY", "*")
		elseif node.operator == "/=" then
			emit(code, "BINARY", "/")
		end

		emit(code, "STORE", left.name)
		return
	end

	error(("Unknown expression '%s'"):format(node.type))
end

local function compileStatement(self, node, code: { Instruction })
	if node.type == "ExpressionStatement" then
		compileExpression(self, node.expression, code)
		emit(code, "POP")
		return
	end

	if node.type == "VariableDeclaration" then
		if node.value then
			compileExpression(self, node.value, code)
		else
			emit(code, "PUSH", nil)
		end

		emit(code, "DEFINE", node.name)
		return
	end

	if node.type == "BlockStatement" then
		emit(code, "BEGIN_SCOPE")

		for _, statement in node.body do
			compileStatement(self, statement, code)
		end

		emit(code, "END_SCOPE")
		return
	end

	if node.type == "IfStatement" then
		compileExpression(self, node.test, code)

		local falseJump = emit(code, "JUMP_IF_FALSE", 0)

		compileStatement(self, node.consequent, code)

		local endJump = emit(code, "JUMP", 0)

		patchJump(code, falseJump, #code + 1)

		if node.alternate then
			compileStatement(self, node.alternate, code)
		end

		patchJump(code, endJump, #code + 1)
		return
	end

	if node.type == "ReturnStatement" then
		if node.argument then
			compileExpression(self, node.argument, code)
		else
			emit(code, "PUSH", nil)
		end

		emit(code, "RETURN")
		return
	end

	error(("Unknown statement '%s'"):format(node.type))
end

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

function Interpreter:compileFunction(node): Chunk
	local code = {}

	compileStatement(self, node.body, code)
	emit(code, "PUSH", nil)
	emit(code, "RETURN")

	return {
		code = code,
		parameters = node.parameters,
	}
end

function Interpreter:execute(program)
	for _, node in program.body do
		if node.type == "FunctionDeclaration" then
			self.functions[node.name] = self:compileFunction(node)
			continue
		end

		if node.type == "UniformDeclaration" then
			defineVariable(self.globalScope, node.name, 0)
			continue
		end

		local code = {}

		compileStatement(self, node, code)
		emit(code, "PUSH", nil)
		emit(code, "RETURN")

		self:runChunk({
			code = code,
			parameters = {},
		}, self.globalScope, {})
	end
end

function Interpreter:setUniform(name: string, value: any)
	defineVariable(self.globalScope, name, value)
end

function Interpreter:runChunk(chunk: Chunk, scope: Scope, args: { any })
	for index, param in chunk.parameters do
		defineVariable(scope, param.name, args[index])
	end

	local code = chunk.code
	local stack = {}
	local top = 0
	local ip = 1
	local currentScope = scope

	while true do
		local instruction = code[ip]
		ip += 1

		local op = instruction.op

		if op == "PUSH" then
			top += 1
			stack[top] = instruction.a
		elseif op == "POP" then
			stack[top] = nil
			top -= 1
		elseif op == "LOAD" then
			top += 1
			stack[top] = resolveVariable(currentScope, instruction.a)
		elseif op == "DEFINE" then
			defineVariable(currentScope, instruction.a, stack[top])
			stack[top] = nil
			top -= 1
		elseif op == "STORE" then
			assignVariable(currentScope, instruction.a, stack[top])
		elseif op == "GET_MEMBER" then
			stack[top] = stack[top][instruction.a]
		elseif op == "UNARY" then
			if instruction.a == "-" then
				stack[top] = -stack[top]
			elseif instruction.a == "!" then
				stack[top] = not stack[top]
			else
				error(("Unknown unary '%s'"):format(instruction.a))
			end
		elseif op == "BINARY" then
			local right = stack[top]
			stack[top] = nil
			top -= 1

			local left = stack[top]
			local operator = instruction.a

			if operator == "+" then
				stack[top] = binaryAdd(left, right)
			elseif operator == "-" then
				stack[top] = binarySub(left, right)
			elseif operator == "*" then
				stack[top] = binaryMul(left, right)
			elseif operator == "/" then
				stack[top] = binaryDiv(left, right)
			elseif operator == "==" then
				stack[top] = left == right
			elseif operator == "!=" then
				stack[top] = left ~= right
			elseif operator == ">" then
				stack[top] = left > right
			elseif operator == "<" then
				stack[top] = left < right
			elseif operator == ">=" then
				stack[top] = left >= right
			elseif operator == "<=" then
				stack[top] = left <= right
			elseif operator == "&&" then
				stack[top] = left and right
			elseif operator == "||" then
				stack[top] = left or right
			else
				error(("Unknown operator '%s'"):format(operator))
			end
		elseif op == "CALL" then
			local argCount = instruction.b
			local callArgs = table.create(argCount)

			for argIndex = argCount, 1, -1 do
				callArgs[argIndex] = stack[top]
				stack[top] = nil
				top -= 1
			end

			top += 1
			stack[top] = self:callFunction(instruction.a, callArgs)
		elseif op == "JUMP_IF_FALSE" then
			local test = stack[top]
			stack[top] = nil
			top -= 1

			if not test then
				ip = instruction.a
			end
		elseif op == "JUMP" then
			ip = instruction.a
		elseif op == "BEGIN_SCOPE" then
			currentScope = createScope(currentScope)
		elseif op == "END_SCOPE" then
			currentScope = currentScope.parent :: Scope
		elseif op == "RETURN" then
			return stack[top]
		else
			error(("Unknown bytecode op '%s'"):format(op))
		end
	end
end

function Interpreter:callFunction(name: string, args: { any })
	local builtin = BUILTINS[name]

	if builtin then
		return builtin(table.unpack(args))
	end

	local chunk = self.functions[name]

	if not chunk then
		error(("Unknown function '%s'"):format(name))
	end

	return self:runChunk(chunk, createScope(self.globalScope), args)
end

function Interpreter:evaluate(node, scope: Scope)
	local code = {}

	compileStatement(self, node, code)
	emit(code, "PUSH", nil)
	emit(code, "RETURN")

	return self:runChunk({
		code = code,
		parameters = {},
	}, scope, {})
end

return Interpreter
