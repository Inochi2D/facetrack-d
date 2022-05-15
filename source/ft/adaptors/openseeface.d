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
import std.traits;
import std.string;
import std.stdio:writeln, write;

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
/*
    double readDouble(ubyte[] bytes) {
        return bytes.read!(double, Endian.littleEndian)();
    }
    float readFloat(ubyte[] bytes) {
        return bytes.read!(float, Endian.littleEndian)();
    }
    int readInt(ubyte[] bytes) {
        return bytes.read!(int, Endian.littleEndian)();
    }
    bool readBool(ubyte[] bytes) {
        return bytes.read!(bool, Endian.littleEndian)();
    }
    vec2 readVec2(ubyte[] bytes) {
        return vec2(read!(float, Endian.littleEndian)(bytes), read!(float, Endian.littleEndian)(bytes));
    }
    vec3 readVec3(ubyte[] bytes) {
        return vec3(read!(float, Endian.littleEndian)(bytes), read!(float, Endian.littleEndian)(bytes), read!(float, Endian.littleEndian)(bytes));
    }
    quat readQuat(ubyte[] bytes) {
        return quat(read!(float, Endian.littleEndian)(bytes), read!(float, Endian.littleEndian)(bytes), read!(float, Endian.littleEndian)(bytes), read!(float, Endian.littleEndian)(bytes));
    }
*/
    void receiveThread() {
        ubyte[packetFrameSize] buffer;
        while (!isCloseRequested) {
            try {
                // Data must always match the expected amount of bytes
                long recvBytes = osf.receive(buffer);
                ubyte[] bytes = buffer;
//                debug writeln(format("Received bytes = %d, expected %d bytes", recvBytes, packetFrameSize));
                if (recvBytes < packetFrameSize) {
                    writeln("Buffer shorted.");
                    Thread.sleep(100.msecs);
                    return;
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

//                debug writeln(format("left %d bytes, read: %d bytes", bytes.length, recvBytes - bytes.length));

                for (int i = 0; i < trackingPoints; i++) {
                    data.confidence[i] = bytes.read!(float, Endian.littleEndian)();
                }
//                debug writeln(format("left %d bytes, read: %d bytes", bytes.length, recvBytes - bytes.length));
                for (int i = 0; i < trackingPoints; i++) {
                    data.points[i] = vec2(bytes.read!(float, Endian.littleEndian)(), bytes.read!(float, Endian.littleEndian)());
                }
//                debug writeln(format("left %d bytes, read: %d bytes", bytes.length, recvBytes - bytes.length));
                for (int i = 0; i < trackingPoints + 2; i++) {
                    data.points3d[i] = vec3(bytes.read!(float, Endian.littleEndian)(), bytes.read!(float, Endian.littleEndian)(), bytes.read!(float, Endian.littleEndian)());
                }
//                debug writeln(format("left %d bytes, read: %d bytes", bytes.length, recvBytes - bytes.length));

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

//                debug foreach (b; bytes) {
//                    write(format("%02x ", b));
//                }
//                debug writeln();
                foreach(name; EnumMembers!OSFFeatureName) {
                    data.features[name] = bytes.read!(float, Endian.littleEndian)();
//                    debug writeln(format("read: %s = %0.4f", name, data.features[name]));
                }
//                debug writeln(format("read: %d bytes", recvBytes - bytes.length));
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

            if (data.got3dPoints) {
                bones[BoneNames.ftHead] = Bone(
                    data.translation,
                    data.rawQuaternion
                );
                blendshapes = data.features.dup;
                blendshapes["EyeOpenRight"] = data.rightEyeOpen;
                blendshapes["EyeOpenLeft"]  = data.leftEyeOpen;
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
            "port",
            "address"
        ];
    }

}
