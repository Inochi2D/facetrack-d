module ft.adaptors.phiz;
version (Phiz) {
import ft.adaptor;
import ft.data;

import vibe.http.websockets;
import vibe.http.server;
import vibe.http.router;
import vibe.core.sync;
import core.thread;
import core.sync.mutex;
import std.conv;

import std.array;
import inmath.linalg;
import std.traits;
import inmath.math;


enum PhizBlendshapes {
    browInnerUp = "browInnerUp",
    browDownLeft = "browDownLeft",
    browDownRight = "browDownRight",
    browOuterUpLeft = "browOuterUpLeft",
    browOuterUpRight = "browOuterUpRight",
    eyeLookUpLeft = "eyeLookUpLeft",
    eyeLookUpRight = "eyeLookUpRight",
    eyeLookDownLeft = "eyeLookDownLeft",
    eyeLookDownRight = "eyeLookDownRight",
    eyeLookInLeft = "eyeLookInLeft",
    eyeLookInRight = "eyeLookInRight",
    eyeLookOutLeft = "eyeLookOutLeft",
    eyeLookOutRight = "eyeLookOutRight",
    eyeBlinkLeft = "eyeBlinkLeft",
    eyeBlinkRight = "eyeBlinkRight",
    eyeSquintLeft = "eyeSquintLeft",
    eyeSquintRight = "eyeSquintRight",
    eyeWideLeft = "eyeWideLeft",
    eyeWideRight = "eyeWideRight",
    cheekPuff = "cheekPuff",
    cheekSquintLeft = "cheekSquintLeft",
    cheekSquintRight = "cheekSquintRight",
    noseSneerLeft = "noseSneerLeft",
    noseSneerRight = "noseSneerRight",
    mouthFunnel = "mouthFunnel",
    mouthPucker = "mouthPucker",
    mouthRollUpper = "mouthRollUpper",
    mouthRollLower = "mouthRollLower",
    mouthShrugUpper = "mouthShrugUpper",
    mouthShrugLower = "mouthShrugLower",
    mouthClose = "mouthClose",
    mouthSmileLeft = "mouthSmileLeft",
    mouthSmileRight = "mouthSmileRight",
    mouthFrownLeft = "mouthFrownLeft",
    mouthFrownRight = "mouthFrownRight",
    mouthDimpleLeft = "mouthDimpleLeft",
    mouthDimpleRight = "mouthDimpleRight",
    mouthUpperUpLeft = "mouthUpperUpLeft",
    mouthUpperUpRight = "mouthUpperUpRight",
    mouthLowerDownLeft = "mouthLowerDownLeft",
    mouthLowerDownRight = "mouthLowerDownRight",
    mouthPressLeft = "mouthPressLeft",
    mouthPressRight = "mouthPressRight",
    mouthStretchLeft = "mouthStretchLeft",
    mouthStretchRight = "mouthStretchRight",
    mouthLeft = "mouthLeft",
    mouthRight = "mouthRight",
    jawOpen = "jawOpen",
    jawForward = "jawForward",
    jawLeft = "jawLeft",
    jawRight = "jawRight",
    tongueOut = "tongueOut"
}

struct PhizBSData {
    float[52] data;
}

struct PhizQData {
    float[4] data;
}

struct PhizBSThreadSafeData {
private:
    PhizBSData data;
    Mutex mtx;
    bool updated_;

public:
    this(Mutex mutex) {
        this.mtx = mutex;
    }

    bool updated() {
        if (mtx is null)
            return false;
        mtx.lock();
        scope(exit) mtx.unlock();
        return updated_;
    }

    void set(PhizBSData data) {
        if (mtx is null)
            return;
        mtx.lock();
        updated_ = true;
        this.data = data;
        mtx.unlock();
    }

    PhizBSData get() {
        if (mtx is null)
            return data;
        mtx.lock();
        updated_ = false;
        scope(exit) mtx.unlock();
        return data;
    }
}

struct PhizQThreadSafeData {
private:
    PhizQData data;
    Mutex mtx;
    bool updated_;

public:
    this(Mutex mutex) {
        this.mtx = mutex;
    }

    bool updated() {
        if (mtx is null)
            return false;
        mtx.lock();
        scope(exit) mtx.unlock();
        return updated_;
    }

    void set(PhizQData data) {
        if (mtx is null)
            return;
        mtx.lock();
        updated_ = true;
        this.data = data;
        mtx.unlock();
    }

    PhizQData get() {
        if (mtx is null)
            return data;
        mtx.lock();
        updated_ = false;
        scope(exit) mtx.unlock();
        return data;
    }
}

class PhizAdaptor : Adaptor {
private:
    ushort port = 9912;
    string bind = "0.0.0.0";

    bool isCloseRequested;
    Thread receivingThread;
    Mutex mutex;
    TaskCondition condition;

    bool gotDataFromFetch = false;

    PhizBSThreadSafeData tsblendshapes;
    PhizQThreadSafeData tshead;
    PhizQThreadSafeData tsleftgaze;
    PhizQThreadSafeData tsrightgaze;

public:
    ~this() {
        this.stop();
    }

    void handleConnection(scope WebSocket socket) {

        while (!isCloseRequested && socket.connected) {
            try {
                ptrdiff_t received = socket.waitForData(16.msecs);
                if (received < 0) {
                    continue;
                }

                auto text = socket.receiveText.split(",");
                auto addressPattern = text[0].split("/");
                if (addressPattern[1] != "phiz") continue;
                switch(addressPattern[2]) {
                    case "headRotation":
                    {
                        PhizQData data;
                        for(size_t i = 1; i < text.length ; i++) {
                            data.data[i-1] = text[i].to!float;
                        }
                        tshead.set(data);
                    }
                        break;
                    case "leftEyeRotation":
                    {
                        PhizQData data;
                        for(size_t i = 1; i < text.length ; i++) {
                            data.data[i-1] = text[i].to!float;
                        }
                        tsleftgaze.set(data);
                    }
                        break;
                    case "rightEyeRotation":
                    {
                        PhizQData data;
                        for(size_t i = 1; i < text.length ; i++) {
                            data.data[i-1] = text[i].to!float;
                        }
                        tsrightgaze.set(data);
                    }
                        break;
                    case "blendshapes":
                    {
                        PhizBSData data;
                        for(size_t i = 1; i < text.length ; i++) {
                            data.data[i-1] = text[i].to!float;
                        }
                        tsblendshapes.set(data);
                    }
                        break;
                    default: break;
                }
            } catch (Exception ex) {
                Thread.sleep(100.msecs);
            }
        }
        
    }

    void receiveThread() {
        isCloseRequested = false;
        tsblendshapes = PhizBSThreadSafeData(new Mutex());
        tshead = PhizQThreadSafeData(new Mutex());
        tsleftgaze = PhizQThreadSafeData(new Mutex());
        tsrightgaze = PhizQThreadSafeData(new Mutex());

        HTTPServerSettings settings =  new HTTPServerSettings();
        settings.port = port;
        settings.bindAddresses = [bind];

        auto router = new URLRouter;
        router.get("/", handleWebSockets(&this.handleConnection));

        HTTPListener listener = listenHTTP(settings, router);
        synchronized (mutex) {
            condition.wait();
        }
        listener.stopListening();
    }

    override
    void start() {
        if ("phiz_bind_port" in this.options) {
            string port_str = options["phiz_bind_port"];
            if (port_str !is null && port_str != "")
                port = to!ushort(this.options["phiz_bind_port"]);
        }

        if ("phiz_bind_ip" in this.options) {
            string addr_str = options["phiz_bind_ip"];
            if (addr_str !is null && addr_str != "")
                bind = this.options["phiz_bind_ip"];
        }

        this.stop();
        mutex = new Mutex;
        condition = new TaskCondition(mutex);
        receivingThread = new Thread(&receiveThread);
        receivingThread.start();
    }

    override
    void stop() {
        if (isRunning) {
            isCloseRequested = true;
            condition.notify();
            receivingThread.join(false);
            mutex = null;
            condition = null;
            receivingThread = null;
        }
    }

    override
    void poll() {
        if (tsblendshapes.updated) {
            gotDataFromFetch = true;
            PhizBSData data = tsblendshapes.get();

            int i = 0;
            foreach(name; EnumMembers!PhizBlendshapes) {
                this.blendshapes[name] = data.data[i];
                i++;
            }

            // LEFT EYE
            this.blendshapes[BlendshapeNames.ftEyeBlinkLeft] = this.blendshapes["eyeBlinkLeft"];
            this.blendshapes[BlendshapeNames.ftEyeXLeft] = this.blendshapes["eyeLookOutLeft"]-this.blendshapes["eyeLookInLeft"];
            this.blendshapes[BlendshapeNames.ftEyeYLeft] = this.blendshapes["eyeLookUpLeft"]-this.blendshapes["eyeLookDownLeft"];
            this.blendshapes[BlendshapeNames.ftEyeSquintLeft] = this.blendshapes["eyeSquintLeft"];
            this.blendshapes[BlendshapeNames.ftEyeWidenLeft] = this.blendshapes["eyeWideLeft"];

            // RIGHT EYE
            this.blendshapes[BlendshapeNames.ftEyeBlinkRight] = this.blendshapes["eyeBlinkRight"];
            this.blendshapes[BlendshapeNames.ftEyeXRight] = this.blendshapes["eyeLookInRight"]-this.blendshapes["eyeLookOutRight"];
            this.blendshapes[BlendshapeNames.ftEyeYRight] = this.blendshapes["eyeLookUpRight"]-this.blendshapes["eyeLookDownRight"];
            this.blendshapes[BlendshapeNames.ftEyeSquintRight] = this.blendshapes["eyeSquintRight"];
            this.blendshapes[BlendshapeNames.ftEyeWidenRight] = this.blendshapes["eyeWideRight"];

            // MOUTH
            this.blendshapes[BlendshapeNames.ftMouthOpen] = clamp(

                // Avg out the different ways of opening the mouth
                (
                    ((this.blendshapes["mouthLowerDownLeft"]+this.blendshapes["mouthUpperUpLeft"])/2) +
                    ((this.blendshapes["mouthLowerDownRight"]+this.blendshapes["mouthUpperUpRight"])/2)
                ),
                0,
                1
            );

            this.blendshapes[BlendshapeNames.ftMouthX] = (1 + this.blendshapes["mouthLeft"]-this.blendshapes["mouthRight"]) / 2.0;
            this.blendshapes[BlendshapeNames.ftMouthEmotion] = (
                    clamp(
                        1 +
                            (this.blendshapes["mouthSmileLeft"]+this.blendshapes["mouthSmileRight"]/2.0) -
                            (this.blendshapes["mouthFrownLeft"]+this.blendshapes["mouthFrownRight"]/2.0),
                        0, 2
                    )
                ) / 2.0;
        }

        if(tshead.updated) {
            gotDataFromFetch = true;
            PhizQData data = tshead.get();

            if ("Head" !in bones) {
                bones["Head"] = Bone(
                    vec3.init,
                    quat.identity
                );
            }
            this.bones["Head"].rotation = quat(
                data.data[3], 
                -data.data[2], 
                data.data[0], 
                -data.data[1], 
            );
        }

        if(tsleftgaze.updated) {
            gotDataFromFetch = true;
            PhizQData data = tsleftgaze.get();

            if ("LeftGaze" !in bones) {
                bones["LeftGaze"] = Bone(
                    vec3.init,
                    quat.identity
                );
            }

            this.bones["LeftGaze"].rotation = quat(
                data.data[3], 
                -data.data[2], 
                data.data[0], 
                -data.data[1], 
            );
        }

        if(tsrightgaze.updated) {
            gotDataFromFetch = true;
            PhizQData data = tsrightgaze.get();

            if ("RightGaze" !in bones) {
                bones["RightGaze"] = Bone(
                    vec3.init,
                    quat.identity
                );
            }

            this.bones["RightGaze"].rotation = quat(
                data.data[3], 
                -data.data[2], 
                data.data[0], 
                -data.data[1], 
            );
        }
    }

    override
    bool isRunning() {
        return receivingThread !is null;
    }

    override
    string[] getOptionNames() {
        return [
            "phiz_bind_port",
            "phiz_bind_ip"
        ];
    }

    override string getAdaptorName() {
        return "Phiz Receiver";
    }

    override
    bool isReceivingData() {
        return gotDataFromFetch;
    }
}
    
}
