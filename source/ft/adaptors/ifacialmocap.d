module ft.adaptors.ifacialmocap;
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
import std.stdio : writeln, write;
import std.array;

/**
    Represents the raw blendshape tracking data to be sent to facetrack-d via UDP.
*/
struct IFMTrackingData {

    this(string datastr) {
        this.indata = datastr;

        // writeln(datastr);

        size_t i = 0;
        size_t nBufStart;
        size_t nBufEnd;
        size_t nBufSplit;
        try {
            while(i < datastr.length) {
                
                // Skip whitespace
                while(datastr[i] == ' ') i++;

                if (datastr[i] != '|') nBufEnd = i;
                else {
                    nBufEnd++;
                    // writeln(datastr[nBufStart..nBufEnd]);
                    // Head bone mode
                    if (datastr[nBufStart] == '=') {
                        nBufStart += 5; // Skip "head#" part

                        // Fetch values
                        float[6] values;
                        size_t rStart = nBufStart+1;
                        size_t rEnd = rStart;
                        size_t aIdx = 0;
                        while (rEnd < nBufEnd) {
                            rEnd++;
                            if (datastr[rEnd] == ',' || datastr[rEnd] == '|') {
                                values[aIdx++] = datastr[rStart..rEnd].to!float;
                                rStart = rEnd+1;
                            }
                        }

                        headRot.x = values[0];
                        headRot.y = values[1];
                        headRot.z = values[2];
                        headPos.x = values[3];
                        headPos.y = values[4];
                        headPos.z = values[5];
                    } else {
                    
                        nBufSplit = nBufStart;
                        while(nBufSplit++ < nBufEnd) {
                            if (datastr[nBufSplit] == '-') {
                                
                                // Blendshape mode
                                blendshapes[datastr[nBufStart..nBufSplit].idup] = datastr[nBufSplit+1..nBufEnd].to!float/100.0;
                                break;
                            } else if (datastr[nBufSplit] == '#') {

                                // Bone mode
                                float[3] values;
                                size_t rStart = nBufSplit+1;
                                size_t rEnd = rStart;
                                size_t aIdx = 0;
                                while (rEnd < nBufEnd) {
                                    rEnd++;
                                    if (datastr[rEnd] == ',' || datastr[rEnd] == '|') {
                                        values[aIdx++] = datastr[rStart..rEnd].to!float;
                                        rStart = rEnd+1;
                                    }
                                }

                                // Load data in to leftEye or rightEye
                                if (datastr[nBufStart..nBufSplit] == "leftEye") {
                                    leftEye.x = values[0];
                                    leftEye.y = values[1];
                                    leftEye.z = values[2];
                                } else if (datastr[nBufStart..nBufSplit] == "rightEye") {
                                    rightEye.x = values[0];
                                    rightEye.y = values[1];
                                    rightEye.z = values[2];
                                }
                                break;
                            }
                        }
                    }

                    // Next iteration
                    nBufStart = ++i;
                    nBufEnd = nBufStart;
                }


                // Next iter
                i++;
            }
        } catch(Exception ex) {
            writeln(ex.msg, " ", nBufStart, " ", nBufSplit, " ", nBufEnd, " ", datastr[nBufStart..nBufEnd]);
        }
    }

    /**
        Current iOS blendshapes.
    */
    float[string] blendshapes;

    vec3 headPos = vec3(0, 0, 0);
    vec3 headRot = vec3(0, 0, 0);
    vec3 leftEye = vec3(0, 0, 0);
    vec3 rightEye = vec3(0, 0, 0);

    string indata;
}

/**
    Thread-safe queue for IFM tracking data
*/
struct IFMThreadSafeData {
private:
    IFMTrackingData data;
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

    void set(IFMTrackingData data) {
        mtx.lock();
        updated_ = true;
        this.data = data;
        mtx.unlock();
    }

    IFMTrackingData get() {
        mtx.lock();
        updated_ = false;
        scope(exit) mtx.unlock();
        return data;
    }
}

/**
    Adaptor to recieve iFacialMocap tracking data
*/
class IFMAdaptor : Adaptor {
private:
    // Constant enums
    enum ifmPort = 49983;
    enum ifmPollRate = 8;
    
    // Data
    size_t dataPacketsReceivedTotal;
    IFMThreadSafeData tsdata;

    // Settings
    string phoneIP;

    // Sockets
    Socket sender;
    Socket dataIn;

    // Threading
    bool isCloseRequested;
    Thread listeningThread;

    bool gotDataFromFetch;

    void listenThread() {
        ubyte[ushort.max] buff;
        Address addr = new InternetAddress(InternetAddress.ADDR_ANY, ifmPort);
        
        int failed = 0;
        while (!isCloseRequested) {
            try {
                ptrdiff_t recvBytes = dataIn.receiveFrom(buff, SocketFlags.NONE, addr);
                if (recvBytes != Socket.ERROR && recvBytes <= buff.length) {
                    dataPacketsReceivedTotal++;
                    string recvString = cast(string)buff[0..recvBytes];
                    auto trackingData = IFMTrackingData(recvString);
                    failed = 0;
                    tsdata.set(trackingData);
                }
                Thread.sleep(ifmPollRate.msecs);
            } catch (Exception ex) {
                writeln(ex.msg);
                failed++;
                Thread.sleep(ifmPollRate.msecs);

                if (failed > 100) {

                    // try connecting again
                    sender.sendTo("iFacialMocap_sahuasouryya9218sauhuiayeta91555dy3719", SocketFlags.NONE, new InternetAddress(phoneIP, ifmPort)); // Nani the fuck, if I may ask?
                    Thread.sleep(1.seconds);
                    failed = 0;
                    dataLossCounter = RECV_TIMEOUT;
                }
            }
        }
    }

public:
    ~this() {
        this.stop();
    }

    override 
    string getAdaptorName() {
        return "iFacialMocap";
    }

    override 
    void start() {
        if ("phoneIP" in options) {
            phoneIP = options["phoneIP"];
        } else return;

        if (isRunning) this.stop();

        // Start our new threading
        isCloseRequested = false;
        tsdata = IFMThreadSafeData(new Mutex());

        try {
            sender = new UdpSocket();
            sender.sendTo("iFacialMocap_sahuasouryya9218sauhuiayeta91555dy3719", SocketFlags.NONE, new InternetAddress(phoneIP, ifmPort)); // Nani the fuck, if I may ask?
            
            dataIn = new UdpSocket();
            dataIn.setOption(SocketOptionLevel.SOCKET, SocketOption.RCVTIMEO, 5.msecs);
            dataIn.bind(new InternetAddress("0.0.0.0", ifmPort));
        } catch (Exception ex) {
            dataIn.close();
            dataIn = null;
            return;
        }
        
        // Reset PPS counter
        dataPacketsReceivedTotal = 0;

        // Start threads
        if (dataIn.isAlive) {
            listeningThread = new Thread(&listenThread);
            listeningThread.start();
        }       
    }

    override
    void stop() {
        if (isRunning) {
            // Stop threads
            isCloseRequested = true;
            listeningThread.join(false);

            // Close UDP sockets
            dataIn.close();

            // Set everything to null
            listeningThread = null;
            dataIn = null;
        }
    }

    override
    void poll() {
        if (!isRunning) return;
        
        if (tsdata.updated) {
            IFMTrackingData data = tsdata.get();
            dataLossCounter = 0;
            gotDataFromFetch = true;

            bones[BoneNames.ftHead] = Bone(
                vec3(data.headPos.x*-1, data.headPos.y, data.headPos.z),
                quat.eulerRotation(radians(data.headRot.z), radians(data.headRot.y), radians(data.headRot.x))
            );

            bones[BoneNames.vmcLeftEye] = Bone(
                vec3(0, 0, 0),
                quat.eulerRotation(radians(data.leftEye.z), radians(data.leftEye.y), radians(data.leftEye.x))
            );
            
            bones[BoneNames.vmcRightEye] = Bone(
                vec3(data.headPos.x*-1, data.headPos.y, data.headPos.z),
                quat.eulerRotation(radians(data.rightEye.z), radians(data.rightEye.y), radians(data.rightEye.x))
            );

            // Duplicate blendshapes in
            this.blendshapes = data.blendshapes.dup;

            try {
                if (this.blendshapes.length > 0) {
                    this.blendshapes[BlendshapeNames.ftEyeBlinkLeft] = this.blendshapes["eyeBlink_L"];
                    this.blendshapes[BlendshapeNames.ftEyeXLeft] = this.blendshapes["eyeLookOut_L"]-this.blendshapes["eyeLookIn_L"];
                    this.blendshapes[BlendshapeNames.ftEyeYLeft] = this.blendshapes["eyeLookUp_L"]-this.blendshapes["eyeLookDown_L"];
                    this.blendshapes[BlendshapeNames.ftEyeSquintLeft] = this.blendshapes["eyeSquint_L"];
                    this.blendshapes[BlendshapeNames.ftEyeWidenLeft] = this.blendshapes["eyeWide_L"];

                    // RIGHT EYE
                    this.blendshapes[BlendshapeNames.ftEyeBlinkRight] = this.blendshapes["eyeBlink_R"];
                    this.blendshapes[BlendshapeNames.ftEyeXRight] = this.blendshapes["eyeLookIn_R"]-this.blendshapes["eyeLookOut_R"];
                    this.blendshapes[BlendshapeNames.ftEyeYRight] = this.blendshapes["eyeLookUp_R"]-this.blendshapes["eyeLookDown_R"];
                    this.blendshapes[BlendshapeNames.ftEyeSquintRight] = this.blendshapes["eyeSquint_R"];
                    this.blendshapes[BlendshapeNames.ftEyeWidenRight] = this.blendshapes["eyeWide_R"];

                    // MOUTH
                    this.blendshapes[BlendshapeNames.ftMouthOpen] = clamp(

                            // Avg out the different ways of opening the mouth
                            (
                                ((this.blendshapes["mouthLowerDown_L"]+this.blendshapes["mouthUpperUp_L"])/2) +
                                ((this.blendshapes["mouthLowerDown_R"]+this.blendshapes["mouthUpperUp_R"])/2)
                            ),
                            0,
                            1
                        );
                    this.blendshapes[BlendshapeNames.ftMouthX] = (1 + this.blendshapes["mouthLeft"]-this.blendshapes["mouthRight"]) / 2.0;
                    this.blendshapes[BlendshapeNames.ftMouthEmotion] = (
                        clamp(
                            1 +
                                (this.blendshapes["mouthSmile_L"]+this.blendshapes["mouthSmile_R"]/2.0) -
                                (this.blendshapes["mouthFrown_L"]+this.blendshapes["mouthFrown_R"]/2.0),
                            0, 2
                        )
                    ) / 2.0;
                }
            } catch (Exception ex) { } // Some unknown format, drop creating ft blendshapes
        } else {
            if (dataLossCounter > RECV_TIMEOUT*10) gotDataFromFetch = false;
            dataLossCounter++;
        }
    }

    override
    bool isRunning() {
        return dataIn !is null;
    }

    override
    bool isReceivingData() {
        return gotDataFromFetch;
    }

    override
    string[] getOptionNames() {
        return [
            "phoneIP"
        ];
    }
}
