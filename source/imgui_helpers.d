module imgui_helpers;

import derelict.imgui.imgui;
import gfm.opengl: GLuint, GLint;
import gfm.sdl2: SDL_Event, SDL2Window; 

/// Global time
double  g_Time = 0.0f;
/// Are mouse buttons pressed
bool[3] g_MousePressed = [ false, false, false ];
/// Mouse wheel state
float   g_MouseWheel = 0.0f;
/// opengl id of the font texture
GLuint  g_FontTexture = 0;
/// opengl id of shaders
int     g_ShaderHandle = 0, g_VertHandle = 0, g_FragHandle = 0;
/// opengl uniforms to pass data to shaders
int     g_AttribLocationTex = 0, g_AttribLocationProjMtx = 0;
/// ditto
int     g_AttribLocationPosition = 0, g_AttribLocationUV = 0, g_AttribLocationColor = 0;
/// buffer objects handles
uint    g_VboHandle = 0, g_VaoHandle = 0, g_ElementsHandle = 0;

// Helper: Manually clip large list of items.
// If you are displaying thousands of even spaced items and you have a random access to the list, you can perform clipping yourself to save on CPU.
// Usage:
//    ImGuiListClipper clipper(count, ImGui::GetTextLineHeightWithSpacing());
//    for (int i = clipper.DisplayStart; i < clipper.DisplayEnd; i++) // display only visible items
//        ImGui::Text("line number %d", i);
//    clipper.End();
// NB: 'count' is only used to clamp the result, if you don't know your count you can use INT_MAX
struct ImGuiListClipper
{
    float   ItemsHeight;
    int     ItemsCount, DisplayStart, DisplayEnd;

    @disable
    this();                       
    this(int count, float height)  { ItemsCount = -1; Begin(count, height); }
    ~this()                        { assert(ItemsCount == -1); } // user forgot to call End()

    void Begin(int count, float height)        // items_height: generally pass GetTextLineHeightWithSpacing() or GetItemsLineHeightWithSpacing()
    {
        assert(ItemsCount == -1);
        ItemsCount = count;
        ItemsHeight = height;
        igCalcListClipping(ItemsCount, ItemsHeight, &DisplayStart, &DisplayEnd); // calculate how many to clip/display
        igSetCursorPosY(igGetCursorPosY() + DisplayStart * ItemsHeight);    // advance cursor
    }
    void End()
    {
        assert(ItemsCount >= 0);
        igSetCursorPosY(igGetCursorPosY() + (ItemsCount - DisplayEnd) * ItemsHeight); // advance cursor
        ItemsCount = -1;
    }
};

/// The function renders all graphics
private extern(C) nothrow void renderDrawLists(ImDrawData* data)
{
	import gfm.opengl: glGetIntegerv, glEnable, glBlendEquation, glBlendFunc, glDisable, GL_CURRENT_PROGRAM,
		GL_TEXTURE_BINDING_2D, GL_BLEND, GL_FUNC_ADD, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA, GL_CULL_FACE,
		GL_DEPTH_TEST, GL_SCISSOR_TEST, glActiveTexture, glUseProgram, glUniform1i, glUniformMatrix4fv,
		glBindVertexArray, glBindBuffer, glBufferData, glScissor, GL_TEXTURE0, GL_FALSE, GL_ARRAY_BUFFER,
		GL_ELEMENT_ARRAY_BUFFER, GLvoid, GL_STREAM_DRAW, glBindTexture, glDrawElements, glBindTexture,
		GL_TEXTURE_2D, GL_TRIANGLES, GL_UNSIGNED_SHORT;

	// Setup render state: alpha-blending enabled, no face culling, no depth testing, scissor enabled
    GLint last_program, last_texture;
    glGetIntegerv(GL_CURRENT_PROGRAM, &last_program);
    glGetIntegerv(GL_TEXTURE_BINDING_2D, &last_texture);
    glEnable(GL_BLEND);
    glBlendEquation(GL_FUNC_ADD);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glDisable(GL_CULL_FACE);
    glDisable(GL_DEPTH_TEST);
    glEnable(GL_SCISSOR_TEST);
    glActiveTexture(GL_TEXTURE0);

	const io = igGetIO();
	// Setup orthographic projection matrix
	const float width = io.DisplaySize.x;
	const float height = io.DisplaySize.y;
	const float[4][4] ortho_projection =
	[
		[ 2.0f/width,	0.0f,			0.0f,		0.0f ],
		[ 0.0f,			2.0f/-height,	0.0f,		0.0f ],
		[ 0.0f,			0.0f,			-1.0f,		0.0f ],
		[ -1.0f,		1.0f,			0.0f,		1.0f ],
	];
	glUseProgram(g_ShaderHandle);
	glUniform1i(g_AttribLocationTex, 0);
	glUniformMatrix4fv(g_AttribLocationProjMtx, 1, GL_FALSE, &ortho_projection[0][0]);

    glBindVertexArray(g_VaoHandle);
    glBindBuffer(GL_ARRAY_BUFFER, g_VboHandle);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, g_ElementsHandle);

    foreach (n; 0..data.CmdListsCount)
    {
        ImDrawList* cmd_list = data.CmdLists[n];
        ImDrawIdx* idx_buffer_offset;

        auto countVertices = ImDrawList_GetVertexBufferSize(cmd_list);
        auto countIndices = ImDrawList_GetIndexBufferSize(cmd_list);

        glBufferData(GL_ARRAY_BUFFER, countVertices * ImDrawVert.sizeof, cast(GLvoid*)ImDrawList_GetVertexPtr(cmd_list,0), GL_STREAM_DRAW);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, countIndices * ImDrawIdx.sizeof, cast(GLvoid*)ImDrawList_GetIndexPtr(cmd_list,0), GL_STREAM_DRAW);

        const cmdCnt = ImDrawList_GetCmdSize(cmd_list);

        foreach(i; 0..cmdCnt)
        {
            auto pcmd = ImDrawList_GetCmdPtr(cmd_list, i);

            if (pcmd.UserCallback)
            {
                pcmd.UserCallback(cmd_list, pcmd);
            }
            else
            {
                glBindTexture(GL_TEXTURE_2D, cast(GLuint)pcmd.TextureId);
                glScissor(cast(int)pcmd.ClipRect.x, cast(int)(height - pcmd.ClipRect.w), cast(int)(pcmd.ClipRect.z - pcmd.ClipRect.x), cast(int)(pcmd.ClipRect.w - pcmd.ClipRect.y));
                glDrawElements(GL_TRIANGLES, pcmd.ElemCount, GL_UNSIGNED_SHORT, idx_buffer_offset);
            }

            idx_buffer_offset += pcmd.ElemCount;
        }
    }

    // Restore modified state
    glBindVertexArray(0);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
    glUseProgram(last_program);
    glDisable(GL_SCISSOR_TEST);
    glBindTexture(GL_TEXTURE_2D, last_texture);
}

private extern(C) nothrow const(char)* getClipboardText()
{
	import gfm.sdl2: SDL_GetClipboardText;

    return SDL_GetClipboardText();
}

private extern(C) nothrow void setClipboardText(const(char)* text)
{
    import gfm.sdl2: SDL_SetClipboardText;
	
    SDL_SetClipboardText(text);
}

/// sets internal imgui state according SDL event
public bool processEvent(ref const(SDL_Event) event)
{
	import gfm.sdl2: SDL_MOUSEWHEEL, SDL_MOUSEBUTTONDOWN, SDL_TEXTINPUT, SDL_KEYDOWN, SDL_KEYUP,
		SDL_BUTTON_LEFT, SDL_BUTTON_RIGHT, SDL_BUTTON_MIDDLE, SDLK_SCANCODE_MASK, KMOD_SHIFT, 
		KMOD_CTRL, KMOD_ALT, KMOD_GUI, SDL_GetModState;

    auto io = igGetIO();
    switch (event.type)
    {
    case SDL_MOUSEWHEEL:
        {
            if (event.wheel.y > 0)
                g_MouseWheel = 1;
            if (event.wheel.y < 0)
                g_MouseWheel = -1;
            return true;
        }
    case SDL_MOUSEBUTTONDOWN:
        {
            if (event.button.button == SDL_BUTTON_LEFT) g_MousePressed[0] = true;
            if (event.button.button == SDL_BUTTON_RIGHT) g_MousePressed[1] = true;
            if (event.button.button == SDL_BUTTON_MIDDLE) g_MousePressed[2] = true;
            return true;
        }
    case SDL_TEXTINPUT:
        {
            ImGuiIO_AddInputCharactersUTF8(event.text.text.ptr);
            return true;
        }
    case SDL_KEYDOWN:
    case SDL_KEYUP:
        {
            int key = event.key.keysym.sym & ~SDLK_SCANCODE_MASK;
            io.KeysDown[key] = (event.type == SDL_KEYDOWN);
            io.KeyShift = ((SDL_GetModState() & KMOD_SHIFT) != 0);
            io.KeyCtrl = ((SDL_GetModState() & KMOD_CTRL) != 0);
            io.KeyAlt = ((SDL_GetModState() & KMOD_ALT) != 0);
            //io.KeySuper = ((SDL_GetModState() & KMOD_GUI) != 0);
            return true;
        }
    default:
    }
    return false;
}

/// creates fonts texture for text rendering
private void createFontsTexture()
{
	import gfm.opengl: glGetIntegerv, glGenTextures, glBindTexture, glTexParameteri, glTexImage2D,
		GL_TEXTURE_BINDING_2D, GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_TEXTURE_MAG_FILTER, 
		GL_LINEAR, GL_RGBA, GL_UNSIGNED_BYTE;

    ImGuiIO* io = igGetIO();
	
	ubyte* pixels;
	int width, height;
	ImFontAtlas_GetTexDataAsRGBA32(io.Fonts,&pixels,&width,&height,null);
	
	// Upload texture to graphics system
    GLint last_texture;
    glGetIntegerv(GL_TEXTURE_BINDING_2D, &last_texture);
	glGenTextures(1, &g_FontTexture);
	glBindTexture(GL_TEXTURE_2D, g_FontTexture);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, pixels);

	// Store our identifier
	ImFontAtlas_SetTexID(io.Fonts, cast(void*)g_FontTexture);

    // Restore state
    glBindTexture(GL_TEXTURE_2D, last_texture);
}

/// creates opengl pipeline for imgui rendering
private bool createOpenGLPipeline()
{
	import gfm.opengl: glGetIntegerv, GLchar, glCreateProgram, glCreateShader, glShaderSource,
		glCompileShader, glAttachShader, glLinkProgram, glGetUniformLocation, glGetAttribLocation,
		GL_TEXTURE_BINDING_2D, GL_ARRAY_BUFFER_BINDING, GL_VERTEX_ARRAY_BINDING, GL_VERTEX_SHADER,
		GL_FRAGMENT_SHADER, GL_ARRAY_BUFFER, glGenBuffers, glGenVertexArrays, glBindBuffer, glBindVertexArray,
		glEnableVertexAttribArray, glVertexAttribPointer, GL_FLOAT, GL_FALSE, GL_UNSIGNED_BYTE, GL_TRUE,
		glBindTexture, glDeleteVertexArrays, glDeleteBuffers, glDeleteShader, glDetachShader, GL_TEXTURE_2D;


    // Backup GL state
    GLint last_texture, last_array_buffer, last_vertex_array;
    glGetIntegerv(GL_TEXTURE_BINDING_2D, &last_texture);
    glGetIntegerv(GL_ARRAY_BUFFER_BINDING, &last_array_buffer);
    glGetIntegerv(GL_VERTEX_ARRAY_BINDING, &last_vertex_array);

    const GLchar *vertex_shader = "
        #version 330
        uniform mat4 ProjMtx;
        in vec2 Position;
        in vec2 UV;
        in vec4 Color;
        out vec2 Frag_UV;
        out vec4 Frag_Color;
        void main()
        {
        	Frag_UV = UV;
        	Frag_Color = Color;
        	gl_Position = ProjMtx * vec4(Position.xy,0,1);
        }";

    const GLchar* fragment_shader = "
        #version 330
        uniform sampler2D Texture;
        in vec2 Frag_UV;
        in vec4 Frag_Color;
        out vec4 Out_Color;
        void main()
        {
        	Out_Color = Frag_Color * texture( Texture, Frag_UV.st);
        }";

    g_ShaderHandle = glCreateProgram();
    g_VertHandle = glCreateShader(GL_VERTEX_SHADER);
    g_FragHandle = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(g_VertHandle, 1, &vertex_shader, null);
    glShaderSource(g_FragHandle, 1, &fragment_shader, null);
    glCompileShader(g_VertHandle);
    glCompileShader(g_FragHandle);
    glAttachShader(g_ShaderHandle, g_VertHandle);
    glAttachShader(g_ShaderHandle, g_FragHandle);
    glLinkProgram(g_ShaderHandle);

    g_AttribLocationTex = glGetUniformLocation(g_ShaderHandle, "Texture");
    g_AttribLocationProjMtx = glGetUniformLocation(g_ShaderHandle, "ProjMtx");
    g_AttribLocationPosition = glGetAttribLocation(g_ShaderHandle, "Position");
    g_AttribLocationUV = glGetAttribLocation(g_ShaderHandle, "UV");
    g_AttribLocationColor = glGetAttribLocation(g_ShaderHandle, "Color");

    glGenBuffers(1, &g_VboHandle);
    glGenBuffers(1, &g_ElementsHandle);

    glGenVertexArrays(1, &g_VaoHandle);
    glBindVertexArray(g_VaoHandle);
    glBindBuffer(GL_ARRAY_BUFFER, g_VboHandle);
    glEnableVertexAttribArray(g_AttribLocationPosition);
    glEnableVertexAttribArray(g_AttribLocationUV);
    glEnableVertexAttribArray(g_AttribLocationColor);

    glVertexAttribPointer(g_AttribLocationPosition, 2, GL_FLOAT, GL_FALSE, ImDrawVert.sizeof, cast(void*)0);
    glVertexAttribPointer(g_AttribLocationUV, 2, GL_FLOAT, GL_FALSE, ImDrawVert.sizeof, cast(void*)ImDrawVert.uv.offsetof);
    glVertexAttribPointer(g_AttribLocationColor, 4, GL_UNSIGNED_BYTE, GL_TRUE, ImDrawVert.sizeof, cast(void*)ImDrawVert.col.offsetof);

    createFontsTexture();
	
	return true;
}

/// destroy opengl pipeline to free resources
private void shutdownOpenGLPipeline()
{
	import gfm.opengl: glDeleteVertexArrays, glDeleteBuffers, glDetachShader, glDeleteShader, glDeleteProgram,
		glDeleteTextures;

    if (g_VaoHandle) glDeleteVertexArrays(1, &g_VaoHandle);
    if (g_VboHandle) glDeleteBuffers(1, &g_VboHandle);
    if (g_ElementsHandle) glDeleteBuffers(1, &g_ElementsHandle);
    g_VaoHandle = g_VboHandle = g_ElementsHandle = 0;

    glDetachShader(g_ShaderHandle, g_VertHandle);
    glDeleteShader(g_VertHandle);
    g_VertHandle = 0;

    glDetachShader(g_ShaderHandle, g_FragHandle);
    glDeleteShader(g_FragHandle);
    g_FragHandle = 0;

    glDeleteProgram(g_ShaderHandle);
    g_ShaderHandle = 0;

    if (g_FontTexture)
    {
        glDeleteTextures(1, &g_FontTexture);
        ImFontAtlas_SetTexID(igGetIO().Fonts, null);
        g_FontTexture = 0;
    }
}

/// initialize imgui
public bool imguiInit(SDL2Window window)
{
	import gfm.sdl2: SDLK_TAB, SDL_SCANCODE_LEFT, SDL_SCANCODE_RIGHT, SDL_SCANCODE_UP, SDL_SCANCODE_DOWN,
		SDL_SCANCODE_PAGEUP, SDL_SCANCODE_PAGEDOWN, SDL_SCANCODE_HOME, SDL_SCANCODE_END, SDLK_DELETE,
		SDLK_BACKSPACE, SDLK_RETURN, SDLK_ESCAPE, SDLK_a, SDLK_c, SDLK_v, SDLK_x, SDLK_y, SDLK_z;

    auto io = igGetIO();
    io.KeyMap[ImGuiKey_Tab] = SDLK_TAB;                     // Keyboard mapping. ImGui will use those indices to peek into the io.KeyDown[] array.
    io.KeyMap[ImGuiKey_LeftArrow] = SDL_SCANCODE_LEFT;
    io.KeyMap[ImGuiKey_RightArrow] = SDL_SCANCODE_RIGHT;
    io.KeyMap[ImGuiKey_UpArrow] = SDL_SCANCODE_UP;
    io.KeyMap[ImGuiKey_DownArrow] = SDL_SCANCODE_DOWN;
    io.KeyMap[ImGuiKey_PageUp] = SDL_SCANCODE_PAGEUP;
    io.KeyMap[ImGuiKey_PageDown] = SDL_SCANCODE_PAGEDOWN;
    io.KeyMap[ImGuiKey_Home] = SDL_SCANCODE_HOME;
    io.KeyMap[ImGuiKey_End] = SDL_SCANCODE_END;
    io.KeyMap[ImGuiKey_Delete] = SDLK_DELETE;
    io.KeyMap[ImGuiKey_Backspace] = SDLK_BACKSPACE;
    io.KeyMap[ImGuiKey_Enter] = SDLK_RETURN;
    io.KeyMap[ImGuiKey_Escape] = SDLK_ESCAPE;
    io.KeyMap[ImGuiKey_A] = SDLK_a;
    io.KeyMap[ImGuiKey_C] = SDLK_c;
    io.KeyMap[ImGuiKey_V] = SDLK_v;
    io.KeyMap[ImGuiKey_X] = SDLK_x;
    io.KeyMap[ImGuiKey_Y] = SDLK_y;
    io.KeyMap[ImGuiKey_Z] = SDLK_z;

    io.RenderDrawListsFn = &renderDrawLists;   // Alternatively you can set this to NULL and call ImGui::GetDrawData() after ImGui::Render() to get the same ImDrawData pointer.
    io.SetClipboardTextFn = &setClipboardText;
    io.GetClipboardTextFn = &getClipboardText;

// #ifdef _WIN32
version(win32)
{
    SDL_SysWMinfo wmInfo;
    SDL_VERSION(&wmInfo.version_);
    SDL_GetWindowWMInfo(window, &wmInfo);
    io.ImeWindowHandle = wmInfo.info.win.window;
// #endif
}

    return true;
}

/// finish imgui
public void shutdown()
{
    shutdownOpenGLPipeline();
    igShutdown();
}

/// start new imgui frame, all imgui code should be embraced by imguiNewFrame() and igRender() calls
public void imguiNewFrame(SDL2Window window)
{
	import gfm.sdl2: SDL_GetWindowSize, SDL_GL_GetDrawableSize, SDL_GetMouseState, SDL_GetWindowFlags,
		SDL_GetTicks, SDL_BUTTON, SDL_BUTTON_LEFT, SDL_BUTTON_RIGHT, SDL_BUTTON_MIDDLE, SDL_ShowCursor;

    if (!g_FontTexture)
        createOpenGLPipeline();

    auto io = igGetIO();

    // Setup display size (every frame to accommodate for window resizing)
    int w = window.getWidth();
    int h = window.getHeight();
    //SDL_GL_GetDrawableSize(window, &display_w, &display_h);
    int display_w = w;
    int display_h = h;
    io.DisplaySize = ImVec2(cast(float)w, cast(float)h);
    io.DisplayFramebufferScale = ImVec2(w > 0 ? (cast(float)display_w / w) : 0, h > 0 ? (cast(float)display_h / h) : 0);

    // Setup time step
    const time = SDL_GetTicks();
    const current_time = time / 1000.0;
    io.DeltaTime = g_Time > 0.0 ? cast(float)(current_time - g_Time) : cast(float)(1.0f / 60.0f);
    g_Time = current_time;

    // Setup inputs
    int mx, my;
    const mouseMask = SDL_GetMouseState(&mx, &my);
//if (SDL_GetWindowFlags(window) & SDL_WINDOW_MOUSE_FOCUS)
        io.MousePos = ImVec2(mx, my);   // Mouse position, in pixels (set to -1,-1 if no mouse / on another screen, etc.)
//    else
//        io.MousePos = ImVec2(-1, -1);

    io.MouseDown[0] = g_MousePressed[0] || (mouseMask & SDL_BUTTON(SDL_BUTTON_LEFT)) != 0;		// If a mouse press event came, always pass it as "mouse held this frame", so we don't miss click-release events that are shorter than 1 frame.
    io.MouseDown[1] = g_MousePressed[1] || (mouseMask & SDL_BUTTON(SDL_BUTTON_RIGHT)) != 0;
    io.MouseDown[2] = g_MousePressed[2] || (mouseMask & SDL_BUTTON(SDL_BUTTON_MIDDLE)) != 0;
    g_MousePressed[0] = g_MousePressed[1] = g_MousePressed[2] = false;

    io.MouseWheel = g_MouseWheel;
    g_MouseWheel = 0.0f;

    // Hide OS mouse cursor if ImGui is drawing it
    SDL_ShowCursor(io.MouseDrawCursor ? 0 : 1);

    // Start the frame
    igNewFrame();
}
