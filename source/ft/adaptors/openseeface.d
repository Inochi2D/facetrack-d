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
import std.stdio:writeln, write;
import std.math : PI;

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

    vec3 swapX(vec3 v) {
        v.x = -v.x;
        return v;
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

                data.rawQuaternion = quat(bytes.read!(float, Endian.littleEndian)(), bytes.read!(float, Endian.littleEndian)(), bytes.read!(float, Endian.littleEndian)(), bytes.read!(float, Endian.littleEndian)());
                data.rawEuler = vec3(bytes.read!(float, Endian.littleEndian)(), bytes.read!(float, Endian.littleEndian)(), bytes.read!(float, Endian.littleEndian)());
                data.translation = vec3(bytes.read!(float, Endian.littleEndian)(), bytes.read!(float, Endian.littleEndian)(), bytes.read!(float, Endian.littleEndian)());

                for (int i = 0; i < trackingPoints; i++) {
                    data.confidence[i] = bytes.read!(float, Endian.littleEndian)();
                }
                for (int i = 0; i < trackingPoints; i++) {
                    data.points[i] = vec2(bytes.read!(float, Endian.littleEndian)(), bytes.read!(float, Endian.littleEndian)());
                }
                for (int i = 0; i < trackingPoints + 2; i++) {
                    data.points3d[i] = vec3(bytes.read!(float, Endian.littleEndian)(), bytes.read!(float, Endian.littleEndian)(), bytes.read!(float, Endian.littleEndian)());
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
    void start(string[string] options = string[string].init) {
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
                receivingThread.join();
            osf.close();

            receivingThread = null;
            osf = null;
        }
    }

    override
    void poll() {
        if (tsdata.updated) {
            OSFData data = tsdata.get();

            if (data.got3dPoints) {
                bones[BoneNames.ftHead] = Bone(
                    data.translation,
                    data.rawQuaternion
                );
                blendshapes = data.features.dup;
                blendshapes["EyeOpenRight"] = data.rightEyeOpen;
                blendshapes["EyeOpenLeft"]  = data.leftEyeOpen;
                bones["RightGaze"] = Bone(vec3(0,0,0), data.rightGaze);
                bones["LeftGaze"]  = Bone(vec3(0,0,0), data.leftGaze);
            }

        }
    }

    override
    bool isRunning() {
        return osf !is null;
    }

    override
    string[] getOptionNames() {
        return [
            "osf_bind_port",
            "osf_bind_ip"
        ];
    }

}
