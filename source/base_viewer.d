module base_viewer;

import std.algorithm: map;
import std.array: array;
import std.exception: enforce;
import std.file: thisExePath;
import std.path: dirName, buildPath;
import std.range: iota;
import std.typecons: tuple, Tuple;

import std.experimental.logger: Logger, NullLogger;

import gfm.math: mat4f, vec2f, vec3f, vec4f;
import gfm.opengl;
import gfm.sdl2;

import derelict.imgui.imgui: ImGuiIO;

import vertex_provider: Vertex, VertexSlice, VertexProvider;

class GLProvider
{
    this(ref OpenGL gl, ref GLProgram program, Vertex[] vertices)
    {
        assert(vertices.length);
        freeResources();

        _indices     = iota(0, vertices.length).map!"cast(uint)a".array;

        _vbo = new GLBuffer(gl, GL_ARRAY_BUFFER, GL_STATIC_DRAW, vertices);
        _ibo = new GLBuffer(gl, GL_ELEMENT_ARRAY_BUFFER, GL_STATIC_DRAW, _indices);

        // Create an OpenGL vertex description from the Vertex structure.
        _vert_spec = new VertexSpecification!Vertex(program);

        _vao_points = new GLVAO(gl);
        // prepare VAO
        {
            _vao_points.bind();
            _vbo.bind();
            _ibo.bind();
            _vert_spec.use();
            _vao_points.unbind();
        }
    }

    void drawVertices(VertexSlice[] slices)
    {
        _vao_points.bind();
        foreach(vslice; slices)
        {
            auto length = cast(int) vslice.length;
            auto start  = cast(int) vslice.start;

            glDrawElements(vslice.glKind, length, GL_UNSIGNED_INT, cast(void *)(start * 4));
        }
        _vao_points.unbind();
    }

    void freeResources()
    {
        if(_vbo)
        {
            _vbo.destroy();
            _vbo = null;
        }
        if(_ibo)
        {
            _ibo.destroy();
            _ibo = null;
        }
        if(_vert_spec)
        {
            _vert_spec.destroy();
            _vert_spec = null;
        }
        if(_vao_points)
        {
            _vao_points.destroy();
            _vao_points = null;
        }
    }

    uint[]        _indices;
    GLBuffer      _vbo, _ibo;
    GLVAO         _vao_points;
    VertexSpecification!Vertex _vert_spec;
}

class BaseViewer
{
    this(int width, int height, string title)
    {
        import imgui_helpers: imguiInit;

        this.width = width;
        this.height = height;

        // create a logger
        _null_logger = new NullLogger();

        // load dynamic libraries
        _sdl2 = new SDL2(_null_logger, SharedLibVersion(2, 0, 0));
        _gl = new OpenGL(_null_logger); // отключаем лог, потому что на одной из машин
                                        // сыпется в консоль очень подробный лог

        // You have to initialize each SDL subsystem you want by hand
        _sdl2.subSystemInit(SDL_INIT_VIDEO);
        _sdl2.subSystemInit(SDL_INIT_EVENTS);

        SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
        SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 3);
        SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE);

        // create an OpenGL-enabled SDL window
        window = new SDL2Window(_sdl2,
                                SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
                                width, height,
                                SDL_WINDOW_OPENGL);

        window.setTitle(title);
        //window.setFullscreenSetting(SDL_WINDOW_FULLSCREEN_DESKTOP);

        // reload OpenGL now that a context exists
        _gl.reload();

        // redirect OpenGL output to our Logger
        _gl.redirectDebugOutput();

        // create a shader program made of a single fragment shader
        const program_source =
            q{#version 330 core

            #if VERTEX_SHADER
            layout(location = 0) in vec3 position;
            layout(location = 1) in vec4 color;
            out vec4 fragment;
            uniform mat4 mvp_matrix;
            void main()
            {
                gl_Position = mvp_matrix * vec4(position.xyz, 1.0);
                fragment = color;
            }
            #endif

            #if FRAGMENT_SHADER
            in vec4 fragment;
            out vec4 color_out;

            void main()
            {
                color_out = fragment;
            }
            #endif
        };

        program = new GLProgram(_gl, program_source);

        imguiInit(window);

        running = true;
    }

    public void close()
    {
        import imgui_helpers: shutdown;

        shutdown();

        foreach(rd; _rdata)
            if(rd.g)
                rd.g.freeResources();

        program.destroy();

        _gl.destroy();
        window.destroy();
        _sdl2.destroy();
    }

    auto setVertexProvider(VertexProvider[] vp)
    {
        foreach(e; vp)
            setVertexProvider(e);
    }

    auto setVertexProvider(VertexProvider vp)
    {
        if(auto ptr = vp.no in _rdata)
        {
            ptr.v = vp;
            ptr.g.freeResources();
            ptr.g = new GLProvider(_gl, program, vp.vertices()); // TODO возможно нет смысле пересоздавать GLProvider
        }
        else
        {
            _rdata[vp.no] = tuple(vp, new GLProvider(_gl, program, vp.vertices()));
        }
    }

    auto getVertexProvider(uint no)
    {
        return _rdata[no].v;
    }

    auto run()
    {
        import gfm.sdl2: SDL_GetTicks, SDL_QUIT, SDL_KEYDOWN, SDL_KEYDOWN, SDL_KEYUP, SDL_MOUSEBUTTONDOWN,
            SDL_MOUSEBUTTONUP, SDL_MOUSEMOTION, SDL_MOUSEWHEEL;

        while(running)
        {
            SDL_Event event;
            while(_sdl2.pollEvent(&event))
            {
                processImguiEvent(event);

                switch(event.type)
                {
                    case SDL_QUIT:            if(aboutQuit()) return;
                    break;
                    case SDL_KEYDOWN:         onKeyDown(event);
                    break;
                    case SDL_KEYUP:           onKeyUp(event);
                    break;
                    case SDL_MOUSEBUTTONDOWN: processMouseDown(event);
                                              onMouseDown(event);
                    break;
                    case SDL_MOUSEBUTTONUP:   processMouseUp(event);
                                              onMouseUp(event);
                    break;
                    case SDL_MOUSEMOTION:     processMouseMotion(event);
                                              onMouseMotion(event);
                    break;
                    case SDL_MOUSEWHEEL:      processMouseWheel(event);
                                              onMouseWheel(event);
                    break;
                    default:
                }
            }
            
            import imgui_helpers: imguiNewFrame, igGetIO, igRender;
        
            _imgui_io = igGetIO();
            imguiNewFrame(window);

            draw();

            program.uniform("mvp_matrix").set(mvp_matrix);
            program.use();
            drawObjects();
            program.unuse();

            igRender();

            window.swapBuffers();
        }
    }

    void drawObjects()
    {
        foreach(ref rd; _rdata)
        {
            if(rd.v.visible)
                rd.g.drawVertices(rd.v.currSlices);
        }
    }

    void draw()
    {
        // clear the whole window
        glViewport(0, 0, width, height);
        glClearColor(0.6f, 0.6f, 0.6f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    }

    auto genVertexProviderHandle()
    {
        return _vp_handle++;
    }

protected:
    SDL2Window window;
    int width;
    int height;

    int mouse_x, mouse_y;
    int leftButton, rightButton, middleButton;

    //// Определяет нужно выделять экстраполированные донесения
    //bool highlight_predicted;
    vec3f _camera_pos;

    float size;
    mat4f projection = void, view = void, mvp_matrix = void, model = mat4f.identity;
    NullLogger _null_logger;

    OpenGL _gl;
    SDL2 _sdl2;
    GLProgram program;

    ImGuiIO* _imgui_io;
    bool _camera_moving;
    uint _vp_handle; // текущий handle для VertexProvider
    Tuple!(VertexProvider, "v", GLProvider, "g")[uint] _rdata; // rendering data
    bool running;

    bool aboutQuit()
    {
        return true;
    }

    protected void updateMatrices()
    {
        auto aspect_ratio= width/cast(double)height;

        if(width <= height)
            projection = mat4f.orthographic(-size, +size,-size/aspect_ratio, +size/aspect_ratio, -size, +size);
        else
            projection = mat4f.orthographic(-size*aspect_ratio,+size*aspect_ratio,-size, +size, -size, +size);

        // Матрица камеры
        view = mat4f.lookAt(
            vec3f(_camera_pos.x, _camera_pos.y, +size), // Камера находится в мировых координатах
            vec3f(_camera_pos.x, _camera_pos.y, -size), // И направлена в начало координат
            vec3f(0, 1, 0)  // "Голова" находится сверху
        );

        // Итоговая матрица ModelViewProjection, которая является результатом перемножения наших трех матриц
        mvp_matrix = projection * view * model;
    }

    /// Преобразование экранных координат в мировые.
    /// Возвращает луч из камеры в мировых координатах.
    public vec3f screenPoint2worldRay(in vec2f screenCoords) pure const //FIXME: Isn't need to be public
    {
        vec3f normalized;
        normalized.x = (2.0f * screenCoords.x) / width - 1.0f;
        normalized.y = 1.0f - (2.0f * screenCoords.y) / height;

        vec4f rayClip = vec4f(normalized.xy, -1.0, 1.0);

        vec4f rayEye = projection.inverse * rayClip;
        rayEye = vec4f(rayEye.xy, -1.0, 0.0);

        vec3f rayWorld = (view.inverse * rayEye).xyz;
        rayWorld.normalize;

        return rayWorld;
    }

    public void setCameraSize(double size)
    {
        this.size = size;

        updateMatrices();
    }

    public void setCameraPosition(ref const(vec3f) position)
    {
        _camera_pos = position;

        updateMatrices();
    }

    public void processMouseWheel(ref const(SDL_Event) event)
    {
        if(event.wheel.y > 0)
        {
            size *= 1.1;
            updateMatrices();
        }
        else if(event.wheel.y < 0)
        {
            size *= 0.9;
            updateMatrices();
        }
    }

    public void processMouseUp(ref const(SDL_Event) event)
    {
        switch(event.button.button)
        {
            case SDL_BUTTON_LEFT:
                leftButton = 0;
            break;
            case SDL_BUTTON_RIGHT:
                rightButton = 0;
                _camera_moving = false;
            break;
            case SDL_BUTTON_MIDDLE:
                middleButton = 0;
            break;
            default:
        }
    }

    public void processMouseDown(ref const(SDL_Event) event)
    {
        switch(event.button.button)
        {
            case SDL_BUTTON_LEFT:
                leftButton = 1;
            break;
            case SDL_BUTTON_RIGHT:
                rightButton = 1;
                _camera_moving = true;
            break;
            case SDL_BUTTON_MIDDLE:
                middleButton = 1;
            break;
            default:
        }
    }

    public void processMouseMotion(ref const(SDL_Event) event)
    {
        auto new_mouse_x = event.motion.x;
        auto new_mouse_y = height - event.motion.y;
        
        if(_camera_moving)
        {
            double factor_x = void, factor_y = void;
            const aspect_ratio = width/cast(double)height;
            if(width > height) 
            {
                factor_x = 2 * size / cast(double) width * aspect_ratio;
                factor_y = 2 * size / cast(double) height;
            }
            else
            {
                factor_x = 2 * size / cast(double) width;
                factor_y = 2 * size / cast(double) height / aspect_ratio;
            }
            auto new_pos = vec3f(
                _camera_pos.x + (mouse_x - new_mouse_x)*factor_x, 
                _camera_pos.y + (mouse_y - new_mouse_y)*factor_y,
                0,
            );
            setCameraPosition(new_pos);
        }

        mouse_x = new_mouse_x;
        mouse_y = new_mouse_y;

        leftButton   = (event.motion.state & SDL_BUTTON_LMASK);
        rightButton  = (event.motion.state & SDL_BUTTON_RMASK);
        middleButton = (event.motion.state & SDL_BUTTON_MMASK);
    }

    public void processImguiEvent(ref const(SDL_Event) event)
    {
        import imgui_helpers: processEvent;

        processEvent(event);
    }

    public void onKeyDown(ref const(SDL_Event) event)
    {

    }

    public void onKeyUp(ref const(SDL_Event) event)
    {

    }

    public void onMouseWheel(ref const(SDL_Event) event)
    {

    }

    public void onMouseMotion(ref const(SDL_Event) event)
    {

    }

    public void onMouseUp(ref const(SDL_Event) event)
    {

    }

    public void onMouseDown(ref const(SDL_Event) event)
    {

    }
}
