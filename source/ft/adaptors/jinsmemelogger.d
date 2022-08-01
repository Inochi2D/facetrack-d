module ft.adaptors.jinsmemelogger;
import ft.adaptor;
import ft.data;

import vibe.d;
import inmath.linalg;
import core.thread;
import core.sync.mutex;
import std.traits;
import std.string;
import std.stdio:writeln, write, writefln;
import std.json;


struct JMLData {
    double time;
    float[string] data;
}

struct JMLThreadSafeData {
private:
    JMLData data;
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

    void set(JMLData data) {
        if (mtx is null)
            return;
        mtx.lock();
        updated_ = true;
        this.data = data;
        mtx.unlock();
    }

    JMLData get() {
        if (mtx is null)
            return data;
        mtx.lock();
        updated_ = false;
        scope(exit) mtx.unlock();
        return data;
    }
}

class JMLAdaptor : Adaptor {
private:
    ushort port = 23456;
    string bind = "0.0.0.0";
    HTTPListener listener;

    bool isCloseRequested;
    Thread receivingThread;

    int dataLossCounter;
    enum RECV_TIMEOUT = 30;
    bool gotDataFromFetch = false;

    JMLThreadSafeData tsdata;

    bool calibrated;
    float initYaw;
    int initSequenceNumber;
    int numInitYaw;

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
                JMLData data;

                auto text = socket.receiveText;
                foreach (string key, value; parseJson(text)) {
                    data.data[key] = value.to!float;
                }

                tsdata.set(data);
            } catch (Exception ex) {
                Thread.sleep(100.msecs);
            }
        }
        
    }

    void receiveThread() {
        isCloseRequested = false;
        tsdata = JMLThreadSafeData(new Mutex());

        HTTPServerSettings settings =  new HTTPServerSettings();
        settings.port = port;
        settings.bindAddresses = [bind];
        writeln("bindAddresses=", settings.bindAddresses);

        auto router = new URLRouter;
        router.get("/", handleWebSockets(&this.handleConnection));

        listener = listenHTTP(settings, router);
        while (!isCloseRequested) {
            runEventLoopOnce();
        }
        writeln("Stopped");
        listener.stopListening();
    }

    override
    void start() {
        calibrate();
        if ("jml_bind_port" in this.options) {
            if (options["jml_bind_port"] != "")
                port = to!ushort(this.options["jml_bind_port"]);
        }

        if ("jml_bind_ip" in this.options) {
            bind = this.options["jml_bind_ip"];
        }
        if (isRunning) {
            this.stop();
        }
        receivingThread = new Thread(&receiveThread);
        receivingThread.start();
    }

    override
    void stop() {
        if (isRunning) {
            isCloseRequested = true;
            listener.stopListening();
            receivingThread.join();
            receivingThread = null;
        }
    }

    int CALIBRATION_PERIOD = 60;
    override
    void poll() {
        if (tsdata.updated) {
            dataLossCounter = 0;
            gotDataFromFetch = true;
            JMLData data = tsdata.get();

            blendshapes = data.data.dup;
            if (!calibrated) {
                if (initSequenceNumber < 0)
                    initSequenceNumber = cast(int)blendshapes["sequenceNumber"];
                int sequenceNumber = cast(int)blendshapes["sequenceNumber"] - initSequenceNumber;
                sequenceNumber = sequenceNumber < 0 ? sequenceNumber + 256 : sequenceNumber;
                if (sequenceNumber < CALIBRATION_PERIOD) {
                    initYaw += blendshapes["yaw"];
                    numInitYaw ++;
                } else {
                    initYaw = initYaw / numInitYaw;
                    this.calibrated = true;
                }
                blendshapes["jmlYaw"] = 0.0;
            } else {
                float headYaw;
                headYaw    = blendshapes["yaw"] - initYaw;
                headYaw    = headYaw > 180? -360 + headYaw: headYaw;
                headYaw    = headYaw < -180? 360 + headYaw: headYaw;
                blendshapes["jmlYaw"] = headYaw;
            }
        } else {
            dataLossCounter ++;
            if (dataLossCounter > RECV_TIMEOUT)
               gotDataFromFetch = false;
        }
    }

    override
    void calibrate() {
        calibrated = false;
        initYaw = 0;
        initSequenceNumber = -1;
        numInitYaw = 0;
    }

    override
    bool isRunning() {
        return receivingThread !is null;
    }

    override
    string[] getOptionNames() {
        return [
            "jml_bind_port",
            "jml_bind_ip"
        ];
    }

    override string getAdaptorName() {
        return "JINS MEME Logger";
    }

    override
    bool isReceivingData() {
        return gotDataFromFetch;
    }
}
