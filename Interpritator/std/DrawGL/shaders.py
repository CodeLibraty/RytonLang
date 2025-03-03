from pyglet.gl import *

# Шейдеры для пост-обработки
BLUR_VERTEX = """
#version 330
in vec2 position;
out vec2 texCoord;
void main() {
    gl_Position = vec4(position, 0.0, 1.0);
    texCoord = (position + 1.0) * 0.5;
}
"""

BLUR_FRAGMENT = """
#version 330
uniform sampler2D tex;
uniform vec2 resolution;
uniform float strength;
in vec2 texCoord;
out vec4 fragColor;

void main() {
    vec2 texelSize = 1.0 / resolution;
    vec4 color = vec4(0.0);
    
    // 13x13 gaussian blur
    for(float x = -6.0; x <= 6.0; x++) {
        for(float y = -6.0; y <= 6.0; y++) {
            vec2 offset = vec2(x, y) * texelSize * strength;
            color += texture(tex, texCoord + offset);
        }
    }
    
    fragColor = color / 169.0;
}
"""

import ctypes

class Shaders:
    def __init__(self):
        # Create and bind framebuffer
        self.fbo = GLuint()
        glGenFramebuffers(1, self.fbo)
        glBindFramebuffer(GL_FRAMEBUFFER, self.fbo)
        
        # Create and configure texture
        self.texture = GLuint()
        glGenTextures(1, self.texture)
        glBindTexture(GL_TEXTURE_2D, self.texture)
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 800, 600, 0, GL_RGBA, GL_UNSIGNED_BYTE, None)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR)
        
        # Attach texture to framebuffer
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, self.texture, 0)
        
        # Create renderbuffer for depth and stencil
        self.rbo = GLuint()
        glGenRenderbuffers(1, self.rbo)
        glBindRenderbuffer(GL_RENDERBUFFER, self.rbo)
        glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH24_STENCIL8, 800, 600)
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_STENCIL_ATTACHMENT, GL_RENDERBUFFER, self.rbo)
        
        # Check framebuffer status
        if glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE:
            print("Framebuffer is not complete!")
            
        glBindFramebuffer(GL_FRAMEBUFFER, 0)
        
    def begin_render_to_texture(self):
        pass
        
    def apply_post_processing(self):
        pass
        
    def create_program(self, vert_src, frag_src):
        program = glCreateProgram()
        
        # Create vertex shader
        vertex = glCreateShader(GL_VERTEX_SHADER)
        src = ctypes.c_char_p(vert_src.encode('utf-8'))
        length = ctypes.c_int(len(vert_src))
        ptr = ctypes.cast(ctypes.pointer(src), ctypes.POINTER(ctypes.POINTER(ctypes.c_char)))
        glShaderSource(vertex, 1, ptr, ctypes.pointer(length))
        glCompileShader(vertex)
        
        # Create fragment shader
        fragment = glCreateShader(GL_FRAGMENT_SHADER)
        src = ctypes.c_char_p(frag_src.encode('utf-8'))
        length = ctypes.c_int(len(frag_src))
        ptr = ctypes.cast(ctypes.pointer(src), ctypes.POINTER(ctypes.POINTER(ctypes.c_char)))
        glShaderSource(fragment, 1, ptr, ctypes.pointer(length))
        glCompileShader(fragment)
        
        glAttachShader(program, vertex)
        glAttachShader(program, fragment)
        glLinkProgram(program)
        
        return program