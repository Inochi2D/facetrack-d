module ft.adaptors.vtsproto;
import ft.adaptor;
import ft.data;
import std.conv : to;
import std.socket;
import fghj.serialization;
import fghj;
import inmath.linalg;
import core.thread;
import core.sync.mutex;
import std.exception;
import inmath.math;
import std.stdio : writeln;

struct VTSUDPDataRequest {
    string messageType = "iOSTrackingDataRequest";
    float time;
    string sentBy;
    int[] ports;

    this(string appName, float sendTime, int[] recieverPorts) {
        this.sentBy = appName;
        this.time = sendTime;
        this.ports = recieverPorts;
    }
}


/**
    Wrapper for VTubeStudio Vectors
*/
struct VTSVector {
    union {
        struct {
            float x;
            float y;
            float z;
        }

        @serdeIgnore
        vec3 vec;
    }
}

/**
    Represents the raw blendshape tracking data to be sent to facetrack-d via UDP.
*/
struct VTSRawTrackingData {
    struct VTSTrackingDataEntry {

        @serdeKeys("k")
        string key;

        @serdeKeys("v")
        float value;
    }

    /**
        Current UNIX millisecond timestamp.
    */
    @serdeKeys("Timestamp")
    long timestamp = 0;

    /**
        Last pressed on-screen hotkey.
    */
    @serdeKeys("Hotkey")
    int hotkey = -1;

    /**
        Whether or not face has been found
    */
    @serdeKeys("FaceFound")
    bool faceFound = false;

    /**
        Current face rotation.
    */
    @serdeKeys("Rotation")
    VTSVector rotation;

    /**
        Current face position.
    */
    @serdeKeys("Position")
    VTSVector position;

    /**
        Current iOS blendshapes.
    */
    @serdeKeys("BlendShapes")
    VTSTrackingDataEntry[] blendShapes;

    /**
        Current iOS blendshapes.
    */
    @serdeIgnore
    float[string] blendShapesDict;
}

/**
    Thread-safe queue for VTS tracking data
*/
struct VTSThreadSafeData {
private:
    VTSRawTrackingData data;
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

    void set(VTSRawTrackingData data) {
        mtx.lock();
        updated_ = true;
        this.data = data;
        mtx.unlock();
    }

    VTSRawTrackingData get() {
        mtx.lock();
        updated_ = false;
        scope(exit) mtx.unlock();
        return data;
    }
}

/**
    Adaptor to recieve VTubeStudio tracking data

    DO NOTE: The VTubeStudio tracking API is not stable yet,
    this Adaptor may break any any point due to updates to the API.
*/
class VTSAdaptor : Adaptor {
private:
    // Constant enums
    enum vtsPort = 21412;
    enum vtsBind = "0.0.0.0";
    enum vtsKeepAlivePerSecond = 5;
    enum vtsRequestDataFramesForSeconds = 1;
    
    // Data
    size_t dataPacketsReceivedTotal;
    size_t dataPacketsReceivedInLastSecond;
    VTSThreadSafeData tsdata;

    // Settings
    string appName = "facetrack-d";
    string phoneIP;

    // Sockets
    Socket vtsIn;
    Socket vtsOut;

    // Threading
    bool isCloseRequested;
    Thread sendingThread;
    Thread listeningThread;

    bool gotDataFromFetch;

    void listenThread() {
        ubyte[ushort.max] buff;
        Address addr = new InternetAddress(InternetAddress.ADDR_ANY, 0);
        
        while (!isCloseRequested) {
            try {
                ptrdiff_t recvBytes = vtsIn.receiveFrom(buff, SocketFlags.NONE, addr);
                if (recvBytes != Socket.ERROR && recvBytes <= buff.length) {
                    string recvString = cast(string)buff[0..recvBytes];
                    auto trackingData = deserialize!VTSRawTrackingData(parseJson(recvString));

                    // copy blendshape data in to an easy spot
                    foreach(blendshapeKV; trackingData.blendShapes) {
                        trackingData.blendShapesDict[blendshapeKV.key] = blendshapeKV.value;
                    }

                    tsdata.set(trackingData);
                }
            } catch (Exception ex) {
                Thread.sleep(100.msecs);
            }
        }
    }

    void sendThread() {
        VTSUDPDataRequest req = VTSUDPDataRequest(appName, vtsRequestDataFramesForSeconds, [vtsPort]);
        string serializedDataReq = req.serializeToJson();

        int senderThreadSleepTimeMs = clamp(1000 / vtsKeepAlivePerSecond, 10, 5000);
        InternetAddress addr = new InternetAddress(phoneIP, vtsPort);
        while(!isCloseRequested) {
            try {
                vtsOut.sendTo(serializedDataReq, SocketFlags.NONE, addr);
            } catch(Exception ex) {
                // Do nothing :)
            }

            Thread.sleep(senderThreadSleepTimeMs.msecs);
        }
    }

public:
    ~this() {
        this.stop();
    }

    override 
    string getAdaptorName() {
        return "VTubeStudio";
    }

    override
    void start(string[string] options = string[string].init) {

        // VTubeStudio wants an app name to be known by
        if ("appName" in options) {
            appName = options["appName"];
            enforce(appName.length > 0, "App Name can't be empty.");
            enforce(appName.length <= 32, "App Name can't be longer than 32 characters.");
        }

        if ("phoneIP" in options) {
            phoneIP = options["phoneIP"];
        } else return;

        // Do not create zombie threads please
        if (isRunning) this.stop();

        // Start our new threading
        isCloseRequested = false;
        tsdata = VTSThreadSafeData(new Mutex());

        vtsOut = new UdpSocket();
        vtsOut.setOption(SocketOptionLevel.SOCKET, SocketOption.SNDTIMEO, 16.msecs);
        vtsIn = new UdpSocket();
        vtsIn.setOption(SocketOptionLevel.SOCKET, SocketOption.RCVTIMEO, 16.msecs);
        vtsIn.bind(new InternetAddress(vtsBind, vtsPort));
        
        // Reset PPS counter
        dataPacketsReceivedTotal = 0;
        dataPacketsReceivedInLastSecond = 0;

        // Start threads
        if (vtsIn.isAlive) {
            sendingThread = new Thread(&sendThread);
            sendingThread.start();

            listeningThread = new Thread(&listenThread);
            listeningThread.start();
        }        
    }

    override
    void stop() {
        if (isRunning) {
            // Stop threads
            isCloseRequested = true;
            
            sendingThread.join();
            listeningThread.join();

            // Close UDP sockets
            vtsIn.close();
            vtsOut.close();

            // Set everything to null
            sendingThread = null;
            listeningThread = null;
            vtsIn = null;
            vtsOut = null;
        }
    }

    override
    void poll() {
        if (tsdata.updated) {
            gotDataFromFetch = true;
            VTSRawTrackingData data = tsdata.get();

            bones[BoneNames.ftHead] = Bone(
                vec3(data.position.x*-1, data.position.y, data.position.z),
                quat.eulerRotation(radians(data.rotation.z), radians(data.rotation.y), radians(data.rotation.x))
            );

            // Duplicate blendshapes in
            this.blendshapes = data.blendShapesDict.dup;

            if (this.blendshapes.length > 0) {

                // CHECK FOR ANDROID
                if ("jawOpen" in this.blendshapes) {    // LEFT EYE
                    this.blendshapes[BlendshapeNames.ftEyeBlinkLeft] = this.blendshapes["EyeBlinkLeft"];
                    this.blendshapes[BlendshapeNames.ftEyeXLeft] = this.blendshapes["eyeLookOut_L"]-this.blendshapes["eyeLookIn_L"];
                    this.blendshapes[BlendshapeNames.ftEyeYLeft] = this.blendshapes["eyeLookUp_L"]-this.blendshapes["eyeLookDown_L"];
                    this.blendshapes[BlendshapeNames.ftEyeSquintLeft] = this.blendshapes["eyeSquint_L"];
                    this.blendshapes[BlendshapeNames.ftEyeWidenLeft] = this.blendshapes["eyeSquint_L"];

                    // RIGHT EYE
                    this.blendshapes[BlendshapeNames.ftEyeBlinkRight] = this.blendshapes["EyeBlinkRight"];
                    this.blendshapes[BlendshapeNames.ftEyeXRight] = this.blendshapes["eyeLookIn_R"]-this.blendshapes["eyeLookOut_R"];
                    this.blendshapes[BlendshapeNames.ftEyeYRight] = this.blendshapes["eyeLookUp_R"]-this.blendshapes["eyeLookDown_R"];
                    this.blendshapes[BlendshapeNames.ftEyeSquintRight] = this.blendshapes["eyeSquint_R"];
                    this.blendshapes[BlendshapeNames.ftEyeWidenRight] = this.blendshapes["eyeSquint_R"];

                    // MOUTH
                    this.blendshapes[BlendshapeNames.ftMouthOpen] = this.blendshapes["jawOpen"];
                    this.blendshapes[BlendshapeNames.ftMouthX] = (1 + this.blendshapes["mouthLeft"]-this.blendshapes["mouthRight"]) / 2.0;
                    this.blendshapes[BlendshapeNames.ftMouthEmotion] = (
                            clamp(
                                1 +
                                    (this.blendshapes["mouthSmile_L"]+this.blendshapes["mouthSmile_R"]/2.0) -
                                    (this.blendshapes["mouthFrown_L"]+this.blendshapes["mouthFrown_R"]/2.0),
                                0, 2
                            )
                        ) / 2.0;

                } else if ("JawOpen" in this.blendshapes) {

                    // WE'RE ON IOS
                    // LEFT EYE
                    this.blendshapes[BlendshapeNames.ftEyeBlinkLeft] = this.blendshapes["EyeBlinkLeft"];
                    this.blendshapes[BlendshapeNames.ftEyeXLeft] = this.blendshapes["EyeLookOutLeft"]-this.blendshapes["EyeLookInLeft"];
                    this.blendshapes[BlendshapeNames.ftEyeYLeft] = this.blendshapes["EyeLookUpLeft"]-this.blendshapes["EyeLookDownLeft"];
                    this.blendshapes[BlendshapeNames.ftEyeSquintLeft] = this.blendshapes["EyeSquintLeft"];
                    this.blendshapes[BlendshapeNames.ftEyeWidenLeft] = this.blendshapes["EyeSquintLeft"];

                    // RIGHT EYE
                    this.blendshapes[BlendshapeNames.ftEyeBlinkRight] = this.blendshapes["EyeBlinkRight"];
                    this.blendshapes[BlendshapeNames.ftEyeXRight] = this.blendshapes["EyeLookInRight"]-this.blendshapes["EyeLookOutRight"];
                    this.blendshapes[BlendshapeNames.ftEyeYRight] = this.blendshapes["EyeLookUpRight"]-this.blendshapes["EyeLookDownRight"];
                    this.blendshapes[BlendshapeNames.ftEyeSquintRight] = this.blendshapes["EyeSquintRight"];
                    this.blendshapes[BlendshapeNames.ftEyeWidenRight] = this.blendshapes["EyeSquintRight"];

                    // MOUTH
                    this.blendshapes[BlendshapeNames.ftMouthOpen] = this.blendshapes["JawOpen"];
                    this.blendshapes[BlendshapeNames.ftMouthX] = (1 + this.blendshapes["MouthLeft"]-this.blendshapes["MouthRight"]) / 2.0;
                    this.blendshapes[BlendshapeNames.ftMouthEmotion] = (
                            clamp(
                                1 +
                                    (this.blendshapes["MouthSmileLeft"]+this.blendshapes["MouthSmileRight"]/2.0) -
                                    (this.blendshapes["MouthFrownLeft"]+this.blendshapes["MouthFrownRight"]/2.0),
                                0, 2
                            )
                        ) / 2.0;
                }

                // If both cases are false there's a problem!
                // TODO: make some logs that can be sent to devs?
            }
        } else {
            gotDataFromFetch = false;
        }
    }

    override
    bool isRunning() {
        return vtsOut !is null;
    }

    override
    bool isReceivingData() {
        return gotDataFromFetch;
    }

    override
    string[] getOptionNames() {
        return [
            "phoneIP",
            "appName"
        ];
    }
}