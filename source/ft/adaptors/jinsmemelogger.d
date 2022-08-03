module ft.adaptors.jinsmemelogger;
version (JML) {
import ft.adaptor;
import ft.data;

import inmath.linalg;
import core.thread;
import core.sync.mutex;
import std.traits;
import std.string;
import std.stdio:writeln, write, writefln;
import std.conv;
import std.json;

import hunt.http;


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
    HttpServer server;

    bool isCloseRequested;
    Thread receivingThread;

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

    void handleText(string text) {
        if (!isCloseRequested) {
            JMLData data;
            foreach (string key, value; parseJSON(text)) {
                try {
                    data.data[key] = value.get!float();
                } catch (Exception ex) {                    
                }
            }

            tsdata.set(data);

        }
    }

    override
    void start() {
        calibrate();
        if ("jml_bind_port" in this.options) {
            string port_str = options["jml_bind_port"];
            if (port_str !is null && port_str != "")
                this.port = to!ushort(this.options["jml_bind_port"]);
        }

        if ("jml_bind_ip" in this.options) {
            string addr_str = options["jml_bind_ip"];
            if (addr_str !is null && addr_str != "")
                this.bind = this.options["jml_bind_ip"];
        }
        if (isRunning) {
            this.stop();
        }

        isCloseRequested = false;
        tsdata = JMLThreadSafeData(new Mutex());
        this.server = HttpServer.builder()
            .setListener(port, bind)
            .websocket("/", new class AbstractWebSocketMessageHandler {
                override void onText(WebSocketConnection connection, string text)
                {
                    if (isCloseRequested) {
                        connection.close();
                    } else
                        handleText(text);
                }
            }).build();

        server.start(); // serer is running in background.
    }

    override
    void stop() {
        if (isRunning) {
            isCloseRequested = true;
            server.stop();
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
        return server !is null && server.isRunning();
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
