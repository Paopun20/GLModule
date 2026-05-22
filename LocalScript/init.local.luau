local GLModule = require(script:WaitForChild("GLModule"))
local Image = script.Parent.Image

local size = Vector2.new(854, 480)

local editable = game:GetService("AssetService"):CreateEditableImage({
	Size = size,
})

Image.ImageContent = Content.fromObject(editable)

local shaderSource = [[
#pragma header

const float AMP_A = 40.0;
const float AMP_B = 20.0;
const float AMP_C = 60.0;

uniform float areaWidth;
uniform float areaHeight;

uniform float uTime0; // be dummy variable
uniform float uTime1;
uniform float uTime2;
uniform float uTime3;
uniform float uTime4;
uniform float uTime5;

uniform float uOffsetY0; // be dummy variable
uniform float uOffsetY1;
uniform float uOffsetY2;
uniform float uOffsetY3;
uniform float uOffsetY4;
uniform float uOffsetY5;

uniform float uFreq0; // be dummy variable
uniform float uFreq1;
uniform float uFreq2;
uniform float uFreq3;
uniform float uFreq4;
uniform float uFreq5;

uniform vec4 uColor0;
uniform vec4 uColor1;
uniform vec4 uColor2;
uniform vec4 uColor3;
uniform vec4 uColor4;
uniform vec4 uColor5;

float waveY(float px, float freq, float t, float offsetY)
{
    return offsetY
		+ sin(px * freq + t) * AMP_A
		+ sin(px * freq * 2.0 + t * 1.5) * AMP_B
		+ sin(px * freq * 0.5 + t * 0.7) * AMP_C;
}

void main()
{
    float px = openfl_TextureCoordv.x * areaWidth;
    float py = openfl_TextureCoordv.y * areaHeight;
    vec4 color = vec4(0.0);
    color = uColor0;

    if (py >= waveY(px, uFreq1, uTime1, uOffsetY1)) color = uColor1;
    if (py >= waveY(px, uFreq2, uTime2, uOffsetY2)) color = uColor2;
    if (py >= waveY(px, uFreq3, uTime3, uOffsetY3)) color = uColor3;
    if (py >= waveY(px, uFreq4, uTime4, uOffsetY4)) color = uColor4;
    if (py >= waveY(px, uFreq5, uTime5, uOffsetY5)) color = uColor5;

    gl_FragColor = color;
}
]]

local shader = GLModule.compile(shaderSource)

-- [0x714A9A, 0xAD5492, 0xD56985, 0xEC897C, 0xF5AE7D, 0xF4D48E] from haxe code
--[[
for (i in 0...n) {
	var c = [0x714A9A, 0xAD5492, 0xD56985, 0xEC897C, 0xF5AE7D, 0xF4D48E][i]; // Get color for this layer
	geoShader.setColor(i, c); // Set shader color for this layer
	var speed:Float = FlxG.random.float(minSpeed, maxSpeed);
	if (FlxG.random.bool())
		speed = -speed;
	speeds.push(speed);
	timers.push(0.0);
	var offsetY = (step * i) - 5.0;
	var freq = (0.003 + i * 0.001) / widthMult;
	geoShader.setOffsetY(i, offsetY);
	geoShader.setFreq(i, freq);
	geoShader.setTime(i, 0.0);
}
]]

shader:setUniform("uFreq1", 0.003)
shader:setUniform("uFreq2", 0.004)
shader:setUniform("uFreq3", 0.005)
shader:setUniform("uFreq4", 0.006)
shader:setUniform("uFreq5", 0.007)

shader:setUniform("uOffsetY1", 100)
shader:setUniform("uOffsetY2", 200)
shader:setUniform("uOffsetY3", 300)
shader:setUniform("uOffsetY4", 400)
shader:setUniform("uOffsetY5", 500)

shader:setUniform("uColor0", { x = 0.1, y = 0.1, z = 0.3, w = 1 })
shader:setUniform("uColor1", { x = 0.2, y = 0.2, z = 0.5, w = 1 })
shader:setUniform("uColor2", { x = 0.3, y = 0.3, z = 0.6, w = 1 })
shader:setUniform("uColor3", { x = 0.5, y = 0.4, z = 0.7, w = 1 })
shader:setUniform("uColor4", { x = 0.8, y = 0.5, z = 0.5, w = 1 })
shader:setUniform("uColor5", { x = 1.0, y = 0.8, z = 0.4, w = 1 })

shader:setSizeXY(size.X, size.Y)

task.spawn(function()
	local f = 0

	while true do
		shader:step()

		local width = size.X
		local height = size.Y

		local bc = buffer.create(width * height * 4)

		for y = 0, height - 1 do
			for x = 0, width - 1 do
				local color = shader:getColorAtPos(x, y)

				local index = (y * width + x) * 4

				buffer.writeu8(bc, index + 0, math.floor(color.x * 255))
				buffer.writeu8(bc, index + 1, math.floor(color.y * 255))
				buffer.writeu8(bc, index + 2, math.floor(color.z * 255))
				buffer.writeu8(bc, index + 3, math.floor((color.w or 1) * 255))
			end
		end

		shader:setUniform("uTime1", f)
		shader:setUniform("uTime2", f + 1)
		shader:setUniform("uTime3", f + 2)
		shader:setUniform("uTime4", f + 3)
		shader:setUniform("uTime5", f + 4)

		editable:WritePixelsBuffer(Vector2.zero, size, bc)

		f += 1 / 60
		task.wait(1 / 25)
	end
end)
