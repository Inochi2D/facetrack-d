module ft.adaptor;
import ft.data;

abstract class Adaptor {
protected:
    float[string] blendshapes;
    Bone[string] bones;
    string[string] options;

public:
    abstract void start(string[string] options = string[string].init);
    abstract void stop();
    abstract void poll();
    abstract string[] getOptionNames();
    abstract bool isRunning();
    abstract bool isReceivingData();
    abstract string getAdaptorName();

    final
    ref string[string] getOptions() { return options; }
    
    final
    ref float[string] getBlendshapes() { return blendshapes; }

    final
    ref Bone[string] getBones() { return bones; }
}