module ft.adaptor;
import ft.data;

abstract class Adaptor {
protected:
    float[string] nativeBlendshapes;
    float[string] blendshapes;
    Bone[string] bones;

public:
    abstract void start(string[string] options = string[string].init);
    abstract void stop();
    abstract void poll();
    abstract string[] getOptionNames();
    abstract bool isRunning();

    final
    ref float[string] getBlendshapes() { return blendshapes; }

    final
    ref float[string] getNativeBlendshapes() { return nativeBlendshapes; }

    final
    ref Bone[string] getBones() { return bones; }
}