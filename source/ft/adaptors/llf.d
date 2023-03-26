module ft.adaptors.llf;
import ft.adaptor;
import ft.data;
import std.conv : to;
import std.bitmanip;
import std.socket;
import fghj.serialization;
import fghj;
import inmath.linalg;
import core.thread;
import core.sync.mutex;
import std.exception;
import inmath.math;
import std.stdio : writeln;

const ushort llfBlendshapes = 61;
// canonical 61 IDs mapping
const string[] llfBlendshapeNames = [
    BlendshapeNames.eyeBlinkLeft,
    BlendshapeNames.eyeLookDownLeft,
    BlendshapeNames.eyeLookInLeft,
    BlendshapeNames.eyeLookOutLeft,
    BlendshapeNames.eyeLookUpLeft,
    BlendshapeNames.eyeSquintLeft,
    BlendshapeNames.eyeWideLeft,

    BlendshapeNames.eyeBlinkRight,
    BlendshapeNames.eyeLookDownRight,
    BlendshapeNames.eyeLookInRight,
    BlendshapeNames.eyeLookOutRight,
    BlendshapeNames.eyeLookUpRight,
    BlendshapeNames.eyeSquintRight,
    BlendshapeNames.eyeWideRight,

    BlendshapeNames.jawForward,
    BlendshapeNames.jawLeft,
    BlendshapeNames.jawRight,
    BlendshapeNames.jawOpen,

    BlendshapeNames.mouthClose,
    BlendshapeNames.mouthFunnel,
    BlendshapeNames.mouthPucker,
    BlendshapeNames.mouthLeft,
    BlendshapeNames.mouthRight,
    BlendshapeNames.mouthSmileLeft,
    BlendshapeNames.mouthSmileRight,
    BlendshapeNames.mouthFrownLeft,
    BlendshapeNames.mouthFrownRight,
    BlendshapeNames.mouthDimpleLeft,
    BlendshapeNames.mouthDimpleRight,
    BlendshapeNames.mouthStretchLeft,
    BlendshapeNames.mouthStretchRight,
    BlendshapeNames.mouthRollLower,
    BlendshapeNames.mouthRollUpper,
    BlendshapeNames.mouthShrugLower,
    BlendshapeNames.mouthShrugUpper,
    BlendshapeNames.mouthPressLeft,
    BlendshapeNames.mouthPressRight,
    BlendshapeNames.mouthLowerDownLeft,
    BlendshapeNames.mouthLowerDownRight,
    BlendshapeNames.mouthUpperUpLeft,
    BlendshapeNames.mouthUpperUpRight,
    BlendshapeNames.browDownLeft,
    BlendshapeNames.browDownRight,
    BlendshapeNames.browInnerUp,
    BlendshapeNames.browOuterUpLeft,
    BlendshapeNames.browOuterUpRight,
    BlendshapeNames.cheekPuff,
    BlendshapeNames.cheekSquintLeft,
    BlendshapeNames.cheekSquintRight,
    BlendshapeNames.noseSneerLeft,
    BlendshapeNames.noseSneerRight,
    BlendshapeNames.tongueOut,
    "headYaw",
    "headPitch",
    "headRoll",
    "leftEyeYaw",
    "leftEyePitch",
    "leftEyeRoll",
    "rightEyeYaw",
    "rightEyePitch",
    "rightEyeRoll"
];

/**
    Represents the raw blendshape tracking data to be sent to facetrack-d via UDP.
*/
struct LLFRawTrackingData {
    /**
        Current blendshapes.
    */
    float[llfBlendshapes] blendshapes;
}

/**
    Thread-safe queue for LLF tracking data
*/
struct LLFThreadSafeData {
private:
    LLFRawTrackingData data;
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

    void set(LLFRawTrackingData data) {
        mtx.lock();
        updated_ = true;
        this.data = data;
        mtx.unlock();
    }

    LLFRawTrackingData get() {
        mtx.lock();
        updated_ = false;
        scope(exit) mtx.unlock();
        return data;
    }
}

/**
    Adaptor to recieve LiveLinkFace/MeFaMo tracking data
*/
class LLFAdaptor : Adaptor {
private:
    // Constant enums
    enum llfPort = 11111;
    enum llfBind = "0.0.0.0";
    enum vtsRequestDataFramesForSeconds = 1;
    
    // Data
    LLFThreadSafeData tsdata;

    // Settings

    // Sockets
    Socket llfIn;

    // Threading
    bool isCloseRequested;
    Thread listeningThread;

    bool gotDataFromFetch;

    void listenThread() {
        ubyte[ushort.max] buff;
        Address addr = new InternetAddress(InternetAddress.ADDR_ANY, 0);
        
        while (!isCloseRequested) {
            try {
                ptrdiff_t recvBytes = llfIn.receiveFrom(buff, SocketFlags.NONE, addr);
                if (recvBytes != Socket.ERROR && recvBytes <= buff.length) {
                    // need to actually decode here
                    if (recvBytes < 46)
                        continue;
                    // this is a uint, but let's not invite overflows, so decode as a ushort and cast up
                    uint nameLen = bigEndianToNative!ushort(buff[43 .. 45]);
                    if (recvBytes < (45 + nameLen + 17))
                        continue;
                    ubyte[] mainBody = buff[(45 + nameLen + 17) .. recvBytes];

                    auto trackingData = LLFRawTrackingData();
                    foreach (i; 0..llfBlendshapeNames.length) {
                    	if (mainBody.length >= 4) {
                            trackingData.blendshapes[i] = mainBody.read!(float, Endian.bigEndian);
                        } else {
                            trackingData.blendshapes[i] = 0.0f;
                        }
                    }

                    tsdata.set(trackingData);
                }
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
        return "LiveLinkFace/MeFaMo Receiver";
    }

    override 
    void start() {

        // Do not create zombie threads please
        if (isRunning) this.stop();

        // Start our new threading
        isCloseRequested = false;
        tsdata = LLFThreadSafeData(new Mutex());

        llfIn = new UdpSocket();
        llfIn.setOption(SocketOptionLevel.SOCKET, SocketOption.RCVTIMEO, 16.msecs);
        llfIn.bind(new InternetAddress(llfBind, llfPort));
        
        // Start threads
        if (llfIn.isAlive) {
            listeningThread = new Thread(&listenThread);
            listeningThread.start();
        }       
    }

    override
    void stop() {
        if (isRunning) {
            // Stop threads
            isCloseRequested = true;
            
            listeningThread.join();

            // Close UDP sockets
            llfIn.close();

            // Set everything to null
            listeningThread = null;
            llfIn = null;
        }
    }

    override
    void poll() {
        if (!isRunning) return;
        
        if (tsdata.updated) {
            LLFRawTrackingData data = tsdata.get();
            dataLossCounter = 0;
            gotDataFromFetch = data.blendshapes.length > 0;

            // Write in blendshapes
            foreach (i; 0..llfBlendshapeNames.length) {
                this.blendshapes[llfBlendshapeNames[i]] = i < data.blendshapes.length ? data.blendshapes[i] : 0;
            }
        } else {
            dataLossCounter++;
            if (dataLossCounter > RECV_TIMEOUT) gotDataFromFetch = false;
        }
    }

    override
    bool isRunning() {
        return llfIn !is null;
    }

    override
    bool isReceivingData() {
        return gotDataFromFetch;
    }

    override
    string[] getOptionNames() {
        return [
        ];
    }
}
