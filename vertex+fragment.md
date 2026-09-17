
# does ShaderFunction properly support Vertex Shader part?

if so ..
make it so we just got one shader and each TouchData spawns a new Vertex with the GlowShader in it
i assume that how it works...


# NucleantVulkan updates

implement
* VertFragShaderNode

i see now since example PyShader generate raw SpirV bytecode
then it sounds like we just need a single type like that for vertex + fragment shader
and doesnt have to be specific for OpenGL or PyShader


but it must be possible to still maintain the ability to render to the VkImage ?
just didnt have this new ShaderNode type ?

# VertexShader View / Function
make a specific VertexShaderView / VertexShaderFunction for this new shadernode, which both accepts Vertex and 
Fragment Code either as OpenGL or PyShader



# PyShader updates

* current def main
if only fragment / compute shader like atm then we can still stick to main function
```py
def main(....) -> float4:
    return whatever

# or

def fragment(....) -> float4:
    return whatever
```
but once VertexShader

then it should be 

```py
def vertex(....) -> ?:
    # return vertex

def fragment(....) -> float4:
    return whatever
```


