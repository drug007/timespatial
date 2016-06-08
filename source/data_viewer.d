module data_viewer;

import base_viewer: BaseViewer;
import data_provider: DataProvider;
import data_item: timeToStringz;

class DataViewer : BaseViewer
{
    this(int width, int height, string title, ref DataProvider dprovider)
    {
        _data_provider = dprovider;
        super(width, height, title);
        _data_provider.updateTimeWindow();
        auto max_point_counts = 2;
        _data_provider.setElementCount(max_point_counts);
        updateGlData();
    }

    override protected void updateGlData()
    {
        import std.algorithm: filter;

        // TODO очень топорное решение - после обновления данных нужно пробежаться
        // по всем VertexProvider'ам, собрать в один массив и передать в BaseGui для
        // обновления/создания соответствующих GLProvider
        import vertex_provider: VertexProvider;
        
        VertexProvider[] vp;
        foreach(ts; _data_provider.timeSpatial)
        {
            foreach(r; ts.record.filter!"a.visible")
            {
                vp ~= r.vertex_provider;
            }
        }
        setVertexProvider(vp);
        _invalidated = false;
    }

    override void close()
    {
        _data_provider.close();

        super.close();
    }

    void invalidate()
    {
        _invalidated = true;
    }

protected:    
    DataProvider _data_provider;
}