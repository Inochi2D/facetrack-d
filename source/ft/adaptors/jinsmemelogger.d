module ft.adaptors.jinsmemelogger;
version (JML) {
import ft.adaptor;
import ft.data;

import vibe.http.websockets;
import vibe.http.server;
import vibe.http.router;
import vibe.data.json;
import vibe.core.sync;
import core.thread;
import core.sync.mutex;
import std.conv;


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

    bool isCloseRequested;
    Thread receivingThread;
    Mutex mutex;
    TaskCondition condition;

    int dataLossCounter;
    int sequenceNumber;
    enum RECV_TIMEOUT = 30;
    enum CALIBRATION_TRIGGER_INTERVAL = 20 * 30;

    bool gotDataFromFetch = false;

    JMLThreadSafeData tsdata;

    float initYaw = 0;
    float nextYaw = 0;
    int numInitYaw;
    int lastSequenceNumber;
    int onBootup = true;
    float[CALIBRATION_TRIGGER_INTERVAL] yawHistory = [0];

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
        calibrate();
        if ("jml_bind_port" in this.options) {
            string port_str = options["jml_bind_port"];
            if (port_str !is null && port_str != "")
                port = to!ushort(this.options["jml_bind_port"]);
        }

        if ("jml_bind_ip" in this.options) {
            string addr_str = options["jml_bind_ip"];
            if (addr_str !is null && addr_str != "")
                bind = this.options["jml_bind_ip"];
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
            receivingThread.join();
            mutex = null;
            condition = null;
            receivingThread = null;
        }
    }

    override
    void poll() {
        if (tsdata.updated) {
            dataLossCounter = 0;
            gotDataFromFetch = true;
            JMLData data = tsdata.get();

            blendshapes = data.data.dup;

            if (lastSequenceNumber < 0) {
                lastSequenceNumber = cast(int)blendshapes["sequenceNumber"];
                sequenceNumber = 0;
            }

            int sequenceDiff = cast(int)blendshapes["sequenceNumber"] - lastSequenceNumber;
            if (sequenceDiff < 0)
                sequenceDiff += 256;

            if (sequenceDiff > 0) {
                sequenceNumber += sequenceDiff;
                if (sequenceNumber >= CALIBRATION_TRIGGER_INTERVAL) {
                    sequenceNumber = 0;
                    onBootup = false;
                }
                nextYaw -= yawHistory[sequenceNumber];
                yawHistory[sequenceNumber] = cast(int)blendshapes["yaw"];
                nextYaw += yawHistory[sequenceNumber];
                if (onBootup)
                    numInitYaw += sequenceDiff;
            }

            lastSequenceNumber = cast(int)blendshapes["sequenceNumber"];
            if (numInitYaw > 0)
                initYaw = nextYaw / numInitYaw;

            float headYaw;
            headYaw    = blendshapes["yaw"] - initYaw;
            headYaw    = headYaw > 180? -360 + headYaw: headYaw;
            headYaw    = headYaw < -180? 360 + headYaw: headYaw;
            blendshapes["jmlYaw"] = headYaw;

        } else {
            dataLossCounter ++;
            if (dataLossCounter > RECV_TIMEOUT)
               gotDataFromFetch = false;
        }
    }

    void calibrate() {
        lastSequenceNumber = -1;
        numInitYaw = 0;
        if (onBootup)
            foreach (i; 0..CALIBRATION_TRIGGER_INTERVAL)
                yawHistory[i] = 0;
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

    
}
