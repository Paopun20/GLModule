--!strict
--!native
--!optimize 2

export type SourceLocation = {
	line: number,
	column: number,
}

export type BaseNode = {
	type: string,
	loc: SourceLocation?,
}

-- literals

export type NumberLiteral = BaseNode & {
	type: "NumberLiteral",
	value: number,
}

export type BooleanLiteral = BaseNode & {
	type: "BooleanLiteral",
	value: boolean,
}

-- identifiers

export type Identifier = BaseNode & {
	type: "Identifier",
	name: string,
}

-- expressions

export type BinaryExpression = BaseNode & {
	type: "BinaryExpression",

	operator: string,

	left: Expression,
	right: Expression,
}

export type UnaryExpression = BaseNode & {
	type: "UnaryExpression",

	operator: string,
	argument: Expression,
}

export type AssignmentExpression = BaseNode & {
	type: "AssignmentExpression",

	operator: string,

	left: Expression,
	right: Expression,
}

export type CallExpression = BaseNode & {
	type: "CallExpression",

	callee: Expression,
	arguments: { Expression },
}

export type MemberExpression = BaseNode & {
	type: "MemberExpression",

	object: Expression,
	property: string,
}

export type ConstructorExpression = BaseNode & {
	type: "ConstructorExpression",

	kind: string,
	arguments: { Expression },
}

-- statements

export type ExpressionStatement = BaseNode & {
	type: "ExpressionStatement",

	expression: Expression,
}

export type VariableDeclaration = BaseNode & {
	type: "VariableDeclaration",

	kind: string,
	name: string,

	value: Expression?,
	constant: boolean,
}

export type BlockStatement = BaseNode & {
	type: "BlockStatement",

	body: { Statement },
}

export type IfStatement = BaseNode & {
	type: "IfStatement",

	test: Expression,
	consequent: Statement,
	alternate: Statement?,
}

export type ReturnStatement = BaseNode & {
	type: "ReturnStatement",

	argument: Expression?,
}

-- functions

export type FunctionParameter = {
	typeName: string,
	name: string,
}

export type FunctionDeclaration = BaseNode & {
	type: "FunctionDeclaration",

	returnType: string,
	name: string,

	parameters: { FunctionParameter },

	body: BlockStatement,
}

-- globals

export type UniformDeclaration = BaseNode & {
	type: "UniformDeclaration",

	dataType: string,
	name: string,
}

export type Program = BaseNode & {
	type: "Program",

	body: { TopLevelStatement },
}

-- unions

export type Literal = NumberLiteral | BooleanLiteral

export type Expression =
	Literal
	| Identifier
	| BinaryExpression
	| UnaryExpression
	| AssignmentExpression
	| CallExpression
	| MemberExpression
	| ConstructorExpression

export type Statement = ExpressionStatement | VariableDeclaration | BlockStatement | IfStatement | ReturnStatement

export type TopLevelStatement = Statement | FunctionDeclaration | UniformDeclaration

local Ast = {}

return Ast
