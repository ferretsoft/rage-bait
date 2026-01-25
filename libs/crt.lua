--[[
Public domain:

Copyright (C) 2017 by Matthias Richter <vrld@vrld.org>

Permission to use, copy, modify, and/or distribute this software for any
purpose with or without fee is hereby granted.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH
REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND
FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT,
INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR
OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
PERFORMANCE OF THIS SOFTWARE.
]]--

return function(moonshine)
  -- Barrel distortion adapted from Daniel Oaks (see commit cef01b67fd)
  -- Added feather to mask out outside of distorted texture
  -- Added scanlines for CRT effect
  local distortionFactor
  local shader = love.graphics.newShader[[
    extern vec2 distortionFactor;
    extern vec2 scaleFactor;
    extern number feather;
    extern number scanlineIntensity;
    extern number chromaIntensity;
    extern vec2 screenSize;
    extern number vignetteIntensity;
    extern vec4 windowBounds;  // x, y, width, height in normalized coordinates (0-1)

    vec4 effect(vec4 color, Image tex, vec2 uv, vec2 px) {
      // to barrel coordinates
      vec2 barrelUV = uv * 2.0 - vec2(1.0);

      // distort
      barrelUV *= scaleFactor;
      barrelUV += (barrelUV.yx*barrelUV.yx) * barrelUV * (distortionFactor - 1.0);
      number mask = (1.0 - smoothstep(1.0-feather,1.0,abs(barrelUV.x)))
                  * (1.0 - smoothstep(1.0-feather,1.0,abs(barrelUV.y)));

      // to cartesian coordinates
      barrelUV = (barrelUV + vec2(1.0)) / 2.0;
      
      // Clamp UV coordinates to prevent color artifacts from out-of-bounds sampling
      barrelUV = clamp(barrelUV, vec2(0.0), vec2(1.0));

      // Apply chromatic aberration (color separation)
      number chromaOffset = chromaIntensity * 0.003;
      vec4 r = Texel(tex, clamp(barrelUV + vec2(chromaOffset, 0.0), vec2(0.0), vec2(1.0))) * mask;
      vec4 g = Texel(tex, clamp(barrelUV, vec2(0.0), vec2(1.0))) * mask;
      vec4 b = Texel(tex, clamp(barrelUV - vec2(chromaOffset, 0.0), vec2(0.0), vec2(1.0))) * mask;
      
      vec4 col = color * vec4(r.r, g.g, b.b, g.a);
      
      // Add scanlines (every other line should be darker)
      // scanline = 0 for even lines, 1 for odd lines
      number scanline = mod(floor(uv.y * screenSize.y), 2.0);
      // Make even lines darker, keep odd lines at full brightness
      col.rgb *= mix(1.0 - scanlineIntensity, 1.0, scanline);
      
      // Vignette based on distance from window bounds box
      // Calculate distance from each edge of the window bounds box
      number distLeft = max(0.0, windowBounds.x - uv.x);
      number distRight = max(0.0, uv.x - (windowBounds.x + windowBounds.z));
      number distTop = max(0.0, windowBounds.y - uv.y);
      number distBottom = max(0.0, uv.y - (windowBounds.y + windowBounds.w));
      
      // Calculate distance from the box (0 if inside, positive if outside)
      number distFromBox = max(max(distLeft, distRight), max(distTop, distBottom));
      
      // Apply vignette - stronger at corners (further from box)
      // Use smoothstep to create smooth falloff
      number vignette = 1.0 - smoothstep(0.0, 0.4, distFromBox) * vignetteIntensity;
      
      col.rgb *= vignette;
      
      return col;
    }
  ]]

  local setters = {}

  setters.distortionFactor = function(v)
    assert(type(v) == "table" and #v == 2, "Invalid value for `distortionFactor'")
    distortionFactor = {unpack(v)}
    shader:send("distortionFactor", v)
  end

  setters.x = function(v) setters.distortionFactor{v, distortionFactor[2]} end
  setters.y = function(v) setters.distortionFactor{distortionFactor[1], v} end

  setters.scaleFactor = function(v)
    if type(v) == "table" and #v == 2 then
      shader:send("scaleFactor", v)
    elseif type(v) == "number" then
      shader:send("scaleFactor", {v,v})
    else
      error("Invalid value for `scaleFactor'")
    end
  end

  setters.feather = function(v) shader:send("feather", v) end
  
  setters.scanlineIntensity = function(v) shader:send("scanlineIntensity", v) end
  
  setters.chromaIntensity = function(v) shader:send("chromaIntensity", v) end
  
  setters.screenSize = function(v)
    if type(v) == "table" and #v == 2 then
      shader:send("screenSize", v)
    else
      error("Invalid value for `screenSize'")
    end
  end

  setters.vignetteIntensity = function(v) shader:send("vignetteIntensity", v) end
  
  setters.windowBounds = function(v)
    if type(v) == "table" and #v == 4 then
      shader:send("windowBounds", v)
    else
      error("Invalid value for `windowBounds'")
    end
  end

  local defaults = {
    distortionFactor = {1.06, 1.065},
    feather = 0.02,
    scaleFactor = 1,
    scanlineIntensity = 0.3,
    chromaIntensity = 0.5,
    screenSize = {love.graphics.getWidth(), love.graphics.getHeight()},
    vignetteIntensity = 0.0,
    windowBounds = {0.5, 0.5, 0.0, 0.0},  -- Center, no size by default
  }

  return moonshine.Effect{
    name = "crt",
    shader = shader,
    setters = setters,
    defaults = defaults
  }
end
