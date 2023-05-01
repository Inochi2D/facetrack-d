module ft.adaptors.openseeface;
import ft.adaptor;
import ft.data;

import std.socket;
import std.conv : to;
import std.range.primitives;
import std.bitmanip;
import inmath.linalg;
import core.thread;
import core.sync.mutex;
import std.traits;
import std.string;
import std.math : PI;
import inmath.math;

const ushort trackingPoints = 68;
enum OSFFeatureName {
    eyeLeft                = "eyeLeft",
    eyeRight               = "eyeRight",
    eyebrowSteepnessLeft   = "eyebrowSteppnessLeft",
    eyebrowUpDownLeft      = "eyebrowUpDownLeft",
    eyebrowQuirkLeft       = "eyebrowQuirkLeft",
    eyebrowSteepnessRight  = "eyebrowSteppnessRight",
    eyebrowUpDownRight     = "eyebrowUpDownRight",
    eyebrowQuirkRight      = "eyebrowQuirkRight",
    mouthCornerUpDownLeft  = "mouthCornerUpDownLeft",
    mouthCornerInOutLeft   = "mouthCornerInOutLeft",
    mouthCornerUpDownRight = "mouthCornerUpDownRight",
    mouthCornerInOutRight  = "mouthCornerInOutRight",
    mouthOpen              = "mouthOpen",
    mouthWide              = "mouthWide"
}

const ushort packetFrameSize = 8
    + 4
    + 2 * 4
    + 2 * 4
    + 1
    + 4
    + 3 * 4
    + 3 * 4
    + 4 * 4
    + 4 * (trackingPoints)
    + 4 * 2 * (trackingPoints)
    + 4 * 3 * (trackingPoints + 2)
    + 4 * 14;

struct OSFData {
    double time;
    int id;
    vec2 cameraResolution;

    float rightEyeOpen;
    float leftEyeOpen;
    quat rightGaze;
    quat leftGaze;
    bool got3dPoints;
    float fit3dError;

    vec3 translation;
    quat rawQuaternion;
    vec3 rawEuler;

    float[trackingPoints] confidence;
    vec2[trackingPoints] points;
    vec3[trackingPoints + 2] points3d;

    float[string] features;
}

struct OSFThreadSafeData {
private:
    OSFData data;
    Mutex mtx;
    bool updated_;

public:
    this(Mutex mutex) {
        this.mtx = mutex;
    }

    bool updated() {
        mtx.lock();
        scope(exit) mtx.unlock();
        return updated_;
    }

    void set(OSFData data) {
        mtx.lock();
        updated_ = true;
        this.data = data;
        mtx.unlock();
    }

    OSFData get() {
        mtx.lock();
        updated_ = false;
        scope(exit) mtx.unlock();
        return data;
    }
}

class OSFAdaptor : Adaptor {
private:
    ushort port = 11573;
    string bind = "0.0.0.0";

    Socket osf;

    bool isCloseRequested;
    Thread receivingThread;

    OSFThreadSafeData tsdata;


    int dataLossCounter;
    enum RECV_TIMEOUT = 16;
    bool gotDataFromFetch;

    vec3 swapX(vec3 v) {
        v.x = -v.x;
        return v;
    }

    float degreesAngleWrap(float af) {
        return ((af + 180) % 360) - 180;
    }

    void receiveThread() {
        ubyte[packetFrameSize] buffer;

        while (!isCloseRequested) {
            try {
                // Data must always match the expected amount of bytes
                ptrdiff_t recvBytes = osf.receive(buffer);
                ubyte[] bytes = buffer;
                if (recvBytes < packetFrameSize) {
                    // Ignoring short packets, and read next packet.
                    continue;
                }

                OSFData data;

                data.time = bytes.read!(double, Endian.littleEndian)();
                data.id = bytes.read!(int, Endian.littleEndian)();
                data.cameraResolution = vec2(bytes.read!(float, Endian.littleEndian)(), bytes.read!(float, Endian.littleEndian)());

                data.rightEyeOpen = bytes.read!(float, Endian.littleEndian)();
                data.leftEyeOpen = bytes.read!(float, Endian.littleEndian)();

                data.got3dPoints = bytes.read!(bool, Endian.littleEndian)();
                data.fit3dError = bytes.read!(float, Endian.littleEndian)();

                float qx = bytes.read!(float, Endian.littleEndian)();
                float qy = bytes.read!(float, Endian.littleEndian)();
                float qz = bytes.read!(float, Endian.littleEndian)();
                float qw = bytes.read!(float, Endian.littleEndian)();
                // (-qw, qx, qy, qz) corresponds to `rawEuler` below in `ZXY` conventiobn

                data.rawQuaternion = quat(-qw, qx, qy, qz); 
                data.rawEuler = vec3(bytes.read!(float, Endian.littleEndian)(), bytes.read!(float, Endian.littleEndian)(), bytes.read!(float, Endian.littleEndian)());
                data.translation = vec3(bytes.read!(float, Endian.littleEndian)(), bytes.read!(float, Endian.littleEndian)(), bytes.read!(float, Endian.littleEndian)());

                for (int i = 0; i < trackingPoints; i++) {
                    data.confidence[i] = bytes.read!(float, Endian.littleEndian)();
                }
                for (int i = 0; i < trackingPoints; i++) {
                    data.points[i] = vec2(bytes.read!(float, Endian.littleEndian)(), bytes.read!(float, Endian.littleEndian)());
                }
                for (int i = 0; i < trackingPoints + 2; i++) {
                    // OSF C# code negates y
                    data.points3d[i] = vec3(bytes.read!(float, Endian.littleEndian)(), -bytes.read!(float, Endian.littleEndian)(), bytes.read!(float, Endian.littleEndian)());
                }

                data.rightGaze = quat.lookRotation(swapX(data.points3d[66]) - swapX(data.points3d[68]), vec3(0, 1, 0)) * quat.axisRotation(PI, vec3(1, 0, 0)) * quat.axisRotation(PI, vec3(0, 0, 1));
                data.leftGaze  = quat.lookRotation(swapX(data.points3d[67]) - swapX(data.points3d[69]), vec3(0, 1, 0)) * quat.axisRotation(PI, vec3(1, 0, 0)) * quat.axisRotation(PI, vec3(0, 0, 1));

                foreach(name; EnumMembers!OSFFeatureName) {
                    data.features[name] = bytes.read!(float, Endian.littleEndian)();
                }
                tsdata.set(data);
            } catch (Exception ex) {
                Thread.sleep(100.msecs);
            }
        }
    }

public:
    ~this() {
        this.stop();
    }

    override 
    string getAdaptorName() {
        return "OpenSeeFace";
    }

    override
    void start() {

        if ("osf_bind_port" in options) {
            port = to!ushort(options["osf_bind_port"]);
        }

        if ("osf_bind_ip" in options) {
            bind = options["osf_bind_ip"];
        }
        if (isRunning) {
            this.stop();
        }

        isCloseRequested = false;
        tsdata = OSFThreadSafeData(new Mutex());
        
        osf = new UdpSocket();
        osf.bind(new InternetAddress(bind, port));
        osf.setOption(SocketOptionLevel.SOCKET, SocketOption.RCVTIMEO, 16.msecs);

        if (osf.isAlive) {
            receivingThread = new Thread(&receiveThread);
            receivingThread.start();
        }
    }

    override
    void stop() {
        if (isRunning) {
            isCloseRequested = true;
            if (receivingThread !is null)
                receivingThread.join(false);
            osf.close();

            receivingThread = null;
            osf = null;
        }
    }

    override
    void poll() {
        if (!isRunning) return;
        
        if (tsdata.updated) {
            dataLossCounter = 0;
            gotDataFromFetch = true;
            OSFData data = tsdata.get();

            if (data.got3dPoints) {
                // convert OpenCV coordinate system to Unity
                quat toRotate = quat.eulerRotation(radians(180), 0, radians(90));
                quat temp = toRotate * data.rawQuaternion;

                // convert from Unity to Inochi2d convention
                quat converted = quat(temp.w, temp.z, temp.x, temp.y);
                bones[BoneNames.ftHead] = Bone(
                    data.translation,
                    converted
                );

                // convert from Unity to Inochi2d convention
                auto convertedLeft = quat(data.leftGaze.w, data.leftGaze.z, data.leftGaze.x, data.leftGaze.y);
                auto convertedRight = quat(data.rightGaze.w, data.rightGaze.z, data.rightGaze.x, data.rightGaze.y);

                bones["LeftGaze"]  = Bone(vec3(0,0,0), convertedLeft);
                bones["RightGaze"] = Bone(vec3(0,0,0), convertedRight);

                blendshapes = data.features.dup;

                blendshapes["EyeOpenRight"] = data.rightEyeOpen;
                blendshapes["EyeOpenLeft"]  = data.leftEyeOpen;

                this.blendshapes[BlendshapeNames.ftEyeBlinkLeft] = 1-data.leftEyeOpen;
                this.blendshapes[BlendshapeNames.ftEyeBlinkRight] = 1-data.rightEyeOpen;
                this.blendshapes[BlendshapeNames.ftMouthOpen] = data.features[OSFFeatureName.mouthOpen];
                this.blendshapes[BlendshapeNames.ftMouthX] = (1 + data.features[OSFFeatureName.mouthCornerInOutLeft]-data.features[OSFFeatureName.mouthCornerInOutRight]) / 2.0;
                this.blendshapes[BlendshapeNames.ftMouthEmotion] = (
                    clamp(
                        1 +
                            ((data.features[OSFFeatureName.mouthCornerUpDownRight]*2)-1) -
                            ((data.features[OSFFeatureName.mouthCornerUpDownLeft]*2)-1),
                        0, 2
                    )
                ) / 2.0;
            }

        } else {
            dataLossCounter++;
            if (dataLossCounter > RECV_TIMEOUT) gotDataFromFetch = false;
        }
    }

    override
    bool isRunning() {
        return osf !is null;
    }

    override
    bool isReceivingData() {
        return gotDataFromFetch;
    }

    override
    string[] getOptionNames() {
        return [
            "osf_bind_port",
            "osf_bind_ip"
        ];
    }

}
