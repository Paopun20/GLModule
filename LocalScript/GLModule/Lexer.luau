--!strict
--!native
--!optimize 2

export type Token = {
	type: string,
	value: string,
	line: number,
	column: number,
}

local KEYWORDS = {
	["if"] = true,
	["else"] = true,
	["return"] = true,

	["const"] = true,
	["uniform"] = true,

	["void"] = true,
	["float"] = true,
	["int"] = true,
	["bool"] = true,

	["vec2"] = true,
	["vec3"] = true,
	["vec4"] = true,
}

local TWO_CHAR_OPERATORS = {
	["=="] = true,
	["!="] = true,
	[">="] = true,
	["<="] = true,

	["&&"] = true,
	["||"] = true,

	["+="] = true,
	["-="] = true,
	["*="] = true,
	["/="] = true,
}

local SINGLE_CHAR_TOKENS = {
	["+"] = "PLUS",
	["-"] = "MINUS",
	["*"] = "STAR",
	["/"] = "SLASH",

	["="] = "EQUAL",

	[">"] = "GREATER",
	["<"] = "LESS",

	["!"] = "BANG",

	["("] = "LPAREN",
	[")"] = "RPAREN",

	["{"] = "LBRACE",
	["}"] = "RBRACE",

	["["] = "LBRACKET",
	["]"] = "RBRACKET",

	[";"] = "SEMICOLON",
	[","] = "COMMA",
	["."] = "DOT",
}

local Lexer = {}
Lexer.__index = Lexer

function Lexer.new(source: string)
	local self = setmetatable({}, Lexer)

	self.source = source
	self.length = #source

	self.position = 1

	self.line = 1
	self.column = 1

	self.tokens = {}

	return self
end

function Lexer:peek(offset: number?): string
	offset = offset or 0

	local index = self.position + offset

	if index > self.length then
		return "\0"
	end

	return string.sub(
		self.source,
		index,
		index
	)
end

function Lexer:advance(): string
	local char = self:peek()

	self.position += 1

	if char == "\n" then
		self.line += 1
		self.column = 1
	else
		self.column += 1
	end

	return char
end

function Lexer:addToken(
	typeName: string,
	value: string
)
	table.insert(self.tokens, {
		type = typeName,
		value = value,

		line = self.line,
		column = self.column,
	})
end

function Lexer:skipWhitespace()
	while true do
		local char = self:peek()

		if char == " "
			or char == "\t"
			or char == "\r"
			or char == "\n"
		then
			self:advance()
		else
			break
		end
	end
end

function Lexer:skipComment()
	if self:peek() == "/"
		and self:peek(1) == "/"
	then
		while self:peek() ~= "\n"
			and self:peek() ~= "\0"
		do
			self:advance()
		end

		return true
	end

	if self:peek() == "/"
		and self:peek(1) == "*"
	then
		self:advance()
		self:advance()

		while true do
			if self:peek() == "\0" then
				break
			end

			if self:peek() == "*"
				and self:peek(1) == "/"
			then
				self:advance()
				self:advance()
				break
			end

			self:advance()
		end

		return true
	end

	return false
end

function Lexer:readNumber()
	local start = self.position

	while string.match(
		self:peek(),
		"%d"
		) do
		self:advance()
	end

	if self:peek() == "." then
		self:advance()

		while string.match(
			self:peek(),
			"%d"
			) do
			self:advance()
		end
	end

	local value = string.sub(
		self.source,
		start,
		self.position - 1
	)

	self:addToken(
		"NUMBER",
		value
	)
end

function Lexer:readIdentifier()
	local start = self.position

	while string.match(
		self:peek(),
		"[%w_]"
		) do
		self:advance()
	end

	local value = string.sub(
		self.source,
		start,
		self.position - 1
	)

	if KEYWORDS[value] then
		self:addToken(
			"KEYWORD",
			value
		)
	else
		self:addToken(
			"IDENTIFIER",
			value
		)
	end
end

function Lexer:tokenize(): {Token}

	while self.position <= self.length do

		self:skipWhitespace()

		if self:skipComment() then
			continue
		end

		local char = self:peek()

		if char == "\0" then
			break
		end

		-- numbers

		if string.match(char, "%d") then
			self:readNumber()
			continue
		end

		-- identifiers

		if string.match(char, "[%a_]") then
			self:readIdentifier()
			continue
		end

		-- two-char operators

		local pair =
			char .. self:peek(1)

		if TWO_CHAR_OPERATORS[pair] then

			self:addToken(
				"OPERATOR",
				pair
			)

			self:advance()
			self:advance()

			continue
		end

		-- single-char

		local tokenType =
			SINGLE_CHAR_TOKENS[char]

		if tokenType then

			self:addToken(
				tokenType,
				char
			)

			self:advance()

			continue
		end

		error(
			string.format(
				"Unexpected character '%s' at %d:%d",
				char,
				self.line,
				self.column
			)
		)
	end

	self:addToken(
		"EOF",
		""
	)

	return self.tokens
end

return Lexer