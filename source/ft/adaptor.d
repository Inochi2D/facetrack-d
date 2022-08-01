module ft.adaptor;
import ft.data;

abstract class Adaptor {
protected:
    float[string] blendshapes;
    Bone[string] bones;
    string[string] options;

    int dataLossCounter;
    enum RECV_TIMEOUT = 16;

public:
    ~this() {
        if (this.isRunning) this.stop();
    }

    abstract void start();
    abstract void stop();
    abstract void poll();
    abstract void calibrate();
    abstract string[] getOptionNames();
    abstract bool isRunning();
    abstract bool isReceivingData();
    abstract string getAdaptorName();

    final
    void start(string[string] options) {
        this.setOptions(options);
        this.start();
    }

    final
    void setOptions(string[string] options = string[string].init) { this.options = options; }
    final

    ref string[string] getOptions() { return options; }
    
    final
    ref float[string] getBlendshapes() { return blendshapes; }

    final
    ref Bone[string] getBones() { return bones; }
}