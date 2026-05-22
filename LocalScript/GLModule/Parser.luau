--!strict
--!native
--!optimize 2

local Ast = require(script.Parent.Ast)

type Token = {
	type: string,
	value: string,
	line: number,
	column: number,
}

local PRECEDENCE = {
	["||"] = 1,
	["&&"] = 2,

	["=="] = 3,
	["!="] = 3,

	[">"] = 4,
	["<"] = 4,
	[">="] = 4,
	["<="] = 4,

	["+"] = 5,
	["-"] = 5,

	["*"] = 6,
	["/"] = 6,
}

local Parser = {}
Parser.__index = Parser

function Parser.new(tokens: {Token})
	local self = setmetatable({}, Parser)

	self.tokens = tokens
	self.position = 1

	return self
end

function Parser:peek(offset: number?): Token
	offset = offset or 0

	return self.tokens[
	math.min(
		self.position + offset,
		#self.tokens
	)
	]
end

function Parser:advance(): Token
	local token = self:peek()
	self.position += 1
	return token
end

function Parser:match(
	tokenType: string,
	value: string?
): boolean

	local token = self:peek()

	if token.type ~= tokenType then
		return false
	end

	if value ~= nil
		and token.value ~= value
	then
		return false
	end

	self:advance()

	return true
end

function Parser:expect(
	tokenType: string,
	value: string?
): Token

	local token = self:peek()

	if not self:match(tokenType, value) then

		error(string.format(
			"Expected %s (%s), got %s (%s) at %d:%d",
			tokenType,
			tostring(value),

			token.type,
			token.value,

			token.line,
			token.column
			))
	end

	return token
end

function Parser:parseProgram()

	local body = {}

	while self:peek().type ~= "EOF" do
		table.insert(
			body,
			self:parseTopLevel()
		)
	end

	return {
		type = "Program",
		body = body,
	}
end

function Parser:parseTopLevel()

	local token = self:peek()

	-- uniform

	if token.type == "KEYWORD"
		and token.value == "uniform"
	then
		return self:parseUniform()
	end

	-- const/global variable

	if token.type == "KEYWORD"
		and token.value == "const"
	then
		return self:parseVariableDeclaration()
	end

	-- function

	if token.type == "KEYWORD"
		or token.type == "IDENTIFIER"
	then

		local nextToken = self:peek(1)
		local nextNext = self:peek(2)

		if nextToken.type == "IDENTIFIER"
			and nextNext.type == "LPAREN"
		then
			return self:parseFunctionDeclaration()
		end
	end

	return self:parseStatement()
end

function Parser:parseUniform()

	self:expect("KEYWORD", "uniform")

	local dataType =
		self:advance().value

	local name =
		self:expect(
			"IDENTIFIER"
		).value

	self:expect("SEMICOLON")

	return {
		type = "UniformDeclaration",

		dataType = dataType,
		name = name,
	}
end

function Parser:parseFunctionDeclaration()

	local returnType =
		self:advance().value

	local name =
		self:expect(
			"IDENTIFIER"
		).value

	self:expect("LPAREN")

	local parameters = {}

	while not self:match("RPAREN") do

		local typeName =
			self:advance().value

		local paramName =
			self:expect(
				"IDENTIFIER"
			).value

		table.insert(parameters, {
			typeName = typeName,
			name = paramName,
		})

		self:match("COMMA")
	end

	local body =
		self:parseBlockStatement()

	return {
		type = "FunctionDeclaration",

		returnType = returnType,
		name = name,

		parameters = parameters,
		body = body,
	}
end

function Parser:parseStatement()

	local token = self:peek()

	-- block

	if token.type == "LBRACE" then
		return self:parseBlockStatement()
	end

	-- if

	if token.type == "KEYWORD"
		and token.value == "if"
	then
		return self:parseIfStatement()
	end

	-- return

	if token.type == "KEYWORD"
		and token.value == "return"
	then
		return self:parseReturnStatement()
	end

	-- variable declaration

	if token.type == "KEYWORD" then

		local value = token.value

		if value == "float"
			or value == "int"
			or value == "bool"
			or value == "vec2"
			or value == "vec3"
			or value == "vec4"
			or value == "const"
		then
			return self:parseVariableDeclaration()
		end
	end

	-- expression statement

	local expr =
		self:parseExpression()

	self:expect("SEMICOLON")

	return {
		type = "ExpressionStatement",
		expression = expr,
	}
end

function Parser:parseBlockStatement()

	self:expect("LBRACE")

	local body = {}

	while not self:match("RBRACE") do
		table.insert(
			body,
			self:parseStatement()
		)
	end

	return {
		type = "BlockStatement",
		body = body,
	}
end

function Parser:parseIfStatement()

	self:expect("KEYWORD", "if")

	self:expect("LPAREN")

	local test =
		self:parseExpression()

	self:expect("RPAREN")

	local consequent =
		self:parseStatement()

	local alternate = nil

	if self:match("KEYWORD", "else") then
		alternate =
			self:parseStatement()
	end

	return {
		type = "IfStatement",

		test = test,

		consequent = consequent,
		alternate = alternate,
	}
end

function Parser:parseReturnStatement()

	self:expect("KEYWORD", "return")

	local argument = nil

	if self:peek().type ~= "SEMICOLON" then
		argument =
			self:parseExpression()
	end

	self:expect("SEMICOLON")

	return {
		type = "ReturnStatement",
		argument = argument,
	}
end

function Parser:parseVariableDeclaration()

	local constant = false

	if self:match("KEYWORD", "const") then
		constant = true
	end

	local kind =
		self:advance().value

	local name =
		self:expect(
			"IDENTIFIER"
		).value

	local value = nil

	if self:match("EQUAL") then
		value =
			self:parseExpression()
	end

	self:expect("SEMICOLON")

	return {
		type = "VariableDeclaration",

		kind = kind,
		name = name,

		value = value,
		constant = constant,
	}
end

function Parser:parseExpression()
	return self:parseAssignment()
end

function Parser:parseAssignment()

	local left =
		self:parseBinaryExpression(1)

	local token = self:peek()

	if token.type == "EQUAL"
		or (
			token.type == "OPERATOR"
				and (
					token.value == "+="
					or token.value == "-="
					or token.value == "*="
					or token.value == "/="
				)
		)
	then

		self:advance()

		local right =
			self:parseAssignment()

		return {
			type = "AssignmentExpression",

			operator = token.value,

			left = left,
			right = right,
		}
	end

	return left
end

function Parser:parseBinaryExpression(
	minPrecedence: number
)

	local left =
		self:parseUnary()

	while true do

		local token = self:peek()

		local op =
			token.value

		local precedence =
			PRECEDENCE[op]

		if precedence == nil
			or precedence < minPrecedence
		then
			break
		end

		self:advance()

		local right =
			self:parseBinaryExpression(
				precedence + 1
			)

		left = {
			type = "BinaryExpression",

			operator = op,

			left = left,
			right = right,
		}
	end

	return left
end

function Parser:parseUnary()

	local token = self:peek()

	if token.type == "MINUS"
		or token.type == "BANG"
	then

		self:advance()

		return {
			type = "UnaryExpression",

			operator = token.value,

			argument = self:parseUnary(),
		}
	end

	return self:parsePostfix()
end

function Parser:parsePostfix()

	local expr =
		self:parsePrimary()

	while true do

		-- member access

		if self:match("DOT") then

			local property =
				self:expect(
					"IDENTIFIER"
				).value

			expr = {
				type = "MemberExpression",

				object = expr,
				property = property,
			}

			continue
		end

		-- call

		if self:match("LPAREN") then

			local arguments = {}

			while not self:match("RPAREN") do

				table.insert(
					arguments,
					self:parseExpression()
				)

				self:match("COMMA")
			end

			expr = {
				type = "CallExpression",

				callee = expr,
				arguments = arguments,
			}

			continue
		end

		break
	end

	return expr
end

function Parser:parsePrimary()

	local token = self:peek()

	-- number

	if token.type == "NUMBER" then

		self:advance()

		return {
			type = "NumberLiteral",
			value = tonumber(token.value),
		}
	end

	-- booleans

	if token.type == "KEYWORD" then

		if token.value == "true"
			or token.value == "false"
		then

			self:advance()

			return {
				type = "BooleanLiteral",
				value =
					token.value == "true",
			}
		end
	end

	-- identifiers

	if token.type == "IDENTIFIER"
		or token.type == "KEYWORD"
	then

		self:advance()

		return {
			type = "Identifier",
			name = token.value,
		}
	end

	-- grouping

	if self:match("LPAREN") then

		local expr =
			self:parseExpression()

		self:expect("RPAREN")

		return expr
	end

	error(string.format(
		"Unexpected token %s (%s) at %d:%d",
		token.type,
		token.value,
		token.line,
		token.column
		))
end

return Parser