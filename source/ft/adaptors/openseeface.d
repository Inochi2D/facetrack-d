module ft.adaptors.openseeface;
import ft.adaptor;
import ft.data;

import std.socket;
import std.conv : to;
import std.range.primitives;
import std.bitmanip;
import gl3n.linalg;
import core.thread;
import core.sync.mutex;

const ushort trackingPoints = 68;
const ushort packetFrameSize = 8
    + 4
    + 2 * 4
    + 2 * 4
    + 1
    + 4
    + 3 * 4
    + 3 * 4
    + 4 * 4
    + 4 * 68
    + 4 * 2 * 68
    + 4 * 2 * 70
    + 4 * 14;

struct OSFData {
    double time;
    int32_t id;
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

    OSFFeatures openSeeFaceFeatures;
}

struct OSFFeatures {
    float eyeLeft;
    float eyeRight;

    float eyebrowSteepnessLeft;
    float eyebrowUpDownLeft;
    float eyebrowQuirkLeft;

    float eyebrowSteepnessRight;
    float eyebrowUpDownRight;
    float eyebrowQuirkRight;

    float mouthCornerUpDownLeft;
    float mouthCornerInOutLeft;

    float mouthCornerUpDownRight;
    float mouthCornerInOutRight;

    float mouthOpen;
    float mouthWide;
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

    bool readBool(ubyte[] b) {
        return b.read!bool();
    }

    int readInt(ubyte[] b) {
        return b.read!int();
    }

    float readFloat(ubyte[] b) {
        return b.read!float();
    }

    double readDouble(ubyte[] b) {
        return b.read!double();
    }

    vec2 readVec2(ubyte[] b) {
        return vec2(readFloat(b), readFloat(b));
    }

    vec3 readVec3(ubyte[] b) {
        return vec3(readFloat(b), readFloat(b), readFloat(b));
    }

    quat readQuat(ubyte[] b) {
        return quat(readFloat(b), readFloat(b), readFloat(b), readFloat(b));
    }

    void receiveThread() {
        ubyte[packetFrameSize] bytes;
        while (!isCloseRequested) {
            try {
                // Data must always match the expected amount of bytes
                if (osf.receive(bytes) < packetFrameSize) {
                    Thread.sleep(100.msecs);
                    return;
                }

                OSFData data;
                OSFFeatures features;

                data.time = readDouble(bytes);
                data.id = readInt(bytes);
                data.cameraResolution = readVec2(bytes);

                data.rightEyeOpen = readFloat(bytes);
                data.leftEyeOpen = readFloat(bytes);

                data.got3dPoints = readBool(bytes);
                data.fit3dError = readFloat(bytes);

                data.rawQuaternion = readQuat(bytes);
                data.rawEuler = readVec3(bytes);
                data.translation = readVec3(bytes);

                for (int i = 0; i < trackingPoints; i++) {
                    data.confidence[i] = readFloat(bytes);
                }
                for (int i = 0; i < trackingPoints; i++) {
                    data.points[i] = readVec2(bytes);
                }
                for (int i = 0; i < trackingPoints + 2; i++) {
                    data.points3d[i] = readVec3(bytes);
                }

                // TODO
                // 0. This 100% won't compile
                // 1. Figure out how to create the quat correctly, luckily we don't read any bytes here
                // 2. Inner quat axis rotations might not need to be normalizd
                // 
                // From official C# impl
                // rightGaze = Quaternion.LookRotation(swapX(points3D[66]) - swapX(points3D[68])) * Quaternion.AngleAxis(180, Vector3.right) * Quaternion.AngleAxis(180, Vector3.forward);
                // leftGaze = Quaternion.LookRotation(swapX(points3D[67]) - swapX(points3D[69])) * Quaternion.AngleAxis(180, Vector3.right) * Quaternion.AngleAxis(180, Vector3.forward);
                // data.rightGaze = quat.axis_rotation(
                //     data.points3d[66] - data.points3d[68],
                //     (
                //         quat.axis_rotation(
                //             180f, vec3(1f, 0f, 0f)
                //         ).normalized()
                //         *
                //         quat.axis_rotation(
                //             180f, vec3(1f, 0f, 1f)
                //         ).normalized())
                // ).normalized();
                // data.leftGaze = quat.axis_rotation(
                //     data.points3d[67] - data.points3d[69],
                //     (
                //         quat.axis_rotation(
                //             180f, vec3(1f, 0f, 0f)
                //         ).normalized()
                //         *
                //         quat.axis_rotation(
                //             180f, vec3(1f, 0f, 1f)
                //         ).normalized())
                // ).normalized();

                features.eyeLeft = readFloat(bytes);
                features.eyeRight = readFloat(bytes);
                
                features.eyebrowSteepnessLeft = readFloat(bytes);
                features.eyebrowUpDownLeft = readFloat(bytes);
                features.eyebrowQuirkLeft = readFloat(bytes);

                features.eyebrowSteepnessRight = readFloat(bytes);
                features.eyebrowUpDownRight = readFloat(bytes);
                features.eyebrowQuirkRight = readFloat(bytes);

                features.mouthCornerUpDownLeft = readFloat(bytes);
                features.mouthCornerInOutLeft = readFloat(bytes);
                features.mouthCornerUpDownRight = readFloat(bytes);
                features.mouthCornerInOutRight = readFloat(bytes);

                features.mouthOpen = readFloat(bytes);
                features.mouthWide = readFloat(bytes);

                data.openSeeFaceFeatures = features;

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
        if ("port" in options) {
            port = to!ushort(options["port"]);
        }

        if ("address" in options) {
            bind = options["address"];
        }

        if (isRunning) {
            this.stop();
        }

        tsdata = OSFThreadSafeData(new Mutex());
        
        osf = new UdpSocket();
        osf.bind(new InternetAddress(bind, port));

        if (osf.isAlive) {
            receivingThread = new Thread(&receiveThread);
            receivingThread.start();
        }
    }

    override
    void stop() {
        isCloseRequested = true;

        receivingThread.join();
        osf.close();

        receivingThread = null;
        osf = null;
    }

    override
    void poll() {
        if (tsdata.updated) {
            OSFData data = tsdata.get();

            bones[BoneNames.ftHead] = Bone(
                data.translation,
                data.rawQuaternion
            );
        }
    }

    override
    bool isRunning() {
        return osf !is null;
    }

    override
    string[] getOptionNames() {
        return [
            "port",
            "address"
        ];
    }

}
