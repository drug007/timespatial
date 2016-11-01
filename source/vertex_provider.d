module vertex_provider;

import gfm.math: vec3f, vec4f;
import gfm.opengl: GLenum, GL_TRIANGLES, GL_POINTS, GL_LINE_STRIP;

struct Vertex
{
    vec3f position;
    vec4f color;
}

struct VertexSlice
{
    private GLenum _kind;

    enum Kind { Triangles, Points, LineStrip, }

    auto glKind() const
    {
        return _kind;
    }

    auto kind() const
    {
        switch(_kind)
        {
            case GL_TRIANGLES:
                return Kind.Triangles;
            case GL_POINTS:
                return Kind.Points;
            case GL_LINE_STRIP:
                return Kind.LineStrip;
            default:
                assert(0);
        }
    }

    auto kind(Kind kind)
    {
        final switch(kind)
        {
            case Kind.Triangles:
                _kind = GL_TRIANGLES;
            break;
            case Kind.Points:
                _kind = GL_POINTS;
            break;
            case Kind.LineStrip:
                _kind = GL_LINE_STRIP;
            break;
        }
    }

    size_t start, length;

    this(Kind k, size_t start, size_t length)
    {
        kind(k);
        this.start  = start;
        this.length = length;
    }
}

class VertexProvider
{
    uint no;
	auto vertices()
	{
		return _vertices;
	}

	auto slices()
	{
		return _slices;
	}

	@property currSlices()
	{
		return _curr_slices;
	}

    @property currSlices(VertexSlice[] vs)
    {
        _curr_slices = vs;
    }

	/// allow rendering of only n last elements
	auto setElementCount(long n)
	{
		import std.algorithm: min;
		import std.range: lockstep;

		foreach(s, ref cs; lockstep(_slices, _curr_slices))
        {
            auto nn = n;
            if(cs.kind == VertexSlice.Kind.Triangles)
                nn = n*3;
            cs.length = min(s.length, nn);
            cs.start = s.start + s.length - cs.length;
        }
	}

	this(uint no, Vertex[] vertices, VertexSlice[] slices)
	{
        assert(vertices.length);
        assert(slices.length);
        this.no      = no;
		_vertices    = vertices;
		_slices      = slices; 
		_curr_slices = slices.dup;
	}

private:
	VertexSlice[] _slices, _curr_slices;
	Vertex[]      _vertices;
}
