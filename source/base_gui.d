module base_gui;

import std.algorithm: map;
import std.array: array;
import std.exception: enforce;
import std.file: thisExePath;
import std.path: dirName, buildPath;
import std.range: iota;

import std.experimental.logger: Logger, NullLogger;

import gfm.math: mat4f, vec3f, vec4f;
import gfm.opengl;
import gfm.sdl2;

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

class BaseGui
{
    this(int width, int height, string title)
    {
        this.width = width;
        this.height = height;

        // create a logger
        //_log = new ConsoleLogger();
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
    }

    public void close()
    {
        foreach(gp; _glprovider)
            gp.freeResources();
        program.destroy();

        _gl.destroy();
        window.destroy();
        _sdl2.destroy();
    }

    public auto setVertexProvider(VertexProvider[] vertex_provider)
    {
        import std.range: lockstep;

        _vertex_provider = vertex_provider;

        if(_vertex_provider.length > _glprovider.length)
            _glprovider.length = _vertex_provider.length;

        foreach(ref vp, ref gp; lockstep(_vertex_provider, _glprovider))
        {
            if(gp is null)
                gp = new GLProvider(_gl, program, vp.vertices());
            else
                gp._vbo.setData(vp.vertices());

            gp._indices = iota(0, vp.vertices.length).map!"cast(uint)a".array;
            gp._ibo.setData(gp._indices);
        }
        _current_glprovider = _glprovider[0.._vertex_provider.length];
    }

    auto run()
    {
        import gfm.sdl2: SDL_GetTicks, SDL_QUIT, SDL_KEYDOWN, SDL_KEYDOWN, SDL_KEYUP, SDL_MOUSEBUTTONDOWN,
            SDL_MOUSEBUTTONUP, SDL_MOUSEMOTION, SDL_MOUSEWHEEL, SDLK_ESCAPE;

        while(!_sdl2.keyboard.isPressed(SDLK_ESCAPE))
        {
            SDL_Event event;
            while(_sdl2.pollEvent(&event))
            {
                processImguiEvent(event);

                switch(event.type)
                {
                    case SDL_QUIT:            return;
                    case SDL_KEYDOWN:         onKeyDown(event);
                    break;
                    case SDL_KEYUP:           onKeyUp(event);
                    break;
                    case SDL_MOUSEBUTTONDOWN: onMouseDown(event);
                    break;
                    case SDL_MOUSEBUTTONUP:   onMouseUp(event);
                    break;
                    case SDL_MOUSEMOTION:     onMouseMotion(event);
                    break;
                    case SDL_MOUSEWHEEL:      onMouseWheel(event);
                    break;
                    default:
                }
            }

            draw();
        }
    }

    void drawObjects()
    {
        import std.range: lockstep;

        foreach(vp, ref gp; lockstep(_vertex_provider, _current_glprovider))
        {
            assert(vp !is null);
            gp.drawVertices(vp.currSlices);
        }
    }

    void draw()
    {
        // clear the whole window
        glViewport(0, 0, width, height);
        glClearColor(0.6f, 0.6f, 0.6f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

        window.swapBuffers();
    }

protected:
    SDL2Window window;
    int width;
    int height;

    int mouse_x, mouse_y;
    int leftButton, rightButton, middleButton;

    // Определяет нужно выделять экстраполированные донесения
    bool highlight_predicted;
    float camera_x = 0, camera_y = 0;

    float size;
    mat4f projection = void, view = void, mvp_matrix = void, model = mat4f.identity;
    Logger _log;
    NullLogger _null_logger;

    OpenGL _gl;
    SDL2 _sdl2;
    GLProgram program;
    VertexProvider[] _vertex_provider;
    GLProvider[]     _glprovider, _current_glprovider;

    void updateMatrices(ref const(vec3f) max_space, ref const(vec3f) min_space)
    {
        auto aspect_ratio= width/cast(double)height;

        if(width <= height)
            projection = mat4f.orthographic(-size, +size,-size/aspect_ratio, +size/aspect_ratio, -size, +size);
        else
            projection = mat4f.orthographic(-size*aspect_ratio,+size*aspect_ratio,-size, +size, -size, +size);

        {
            auto camera_x = this.camera_x + (max_space.x + min_space.x)/2.;
            auto camera_y = this.camera_y + (max_space.y + min_space.y)/2.;

            // Матрица камеры
            view = mat4f.lookAt(
                vec3f(camera_x, camera_y, +size), // Камера находится в мировых координатах
                vec3f(camera_x, camera_y, -size), // И направлена в начало координат
                vec3f(0, 1, 0)  // "Голова" находится сверху
            );
        }

        // Итоговая матрица ModelViewProjection, которая является результатом перемножения наших трех матриц
        mvp_matrix = projection * view * model;
    }

    public void setMatrices(ref const(vec3f) max_space, ref const(vec3f) min_space)
    {
        {
            const xw = (max_space.x - min_space.x);
            const yw = (max_space.y - min_space.y);

            size = (xw > yw) ? xw/2 : yw/2;
        }

        camera_x = 0;
        camera_y = 0;

        updateMatrices(max_space, min_space);
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
        mouse_x = event.motion.x;
        mouse_y = height - event.motion.y;

        leftButton   = (event.motion.state & SDL_BUTTON_LMASK);
        rightButton  = (event.motion.state & SDL_BUTTON_RMASK);
        middleButton = (event.motion.state & SDL_BUTTON_MMASK);
    }

    public void onMouseUp(ref const(SDL_Event) event)
    {
        switch(event.button.button)
        {
            case SDL_BUTTON_LEFT:
                leftButton = 0;
            break;
            case SDL_BUTTON_RIGHT:
                rightButton = 0;
            break;
            case SDL_BUTTON_MIDDLE:
                middleButton = 0;
            break;
            default:
        }
    }

    public void onMouseDown(ref const(SDL_Event) event)
    {
        switch(event.button.button)
        {
            case SDL_BUTTON_LEFT:
                leftButton = 1;
            break;
            case SDL_BUTTON_RIGHT:
                rightButton = 1;
            break;
            case SDL_BUTTON_MIDDLE:
                middleButton = 1;
            break;
            default:
        }
    }
}
