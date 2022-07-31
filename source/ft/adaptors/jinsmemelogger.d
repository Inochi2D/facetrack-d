module ft.adaptors.jinsmemelogger;
import ft.adaptor;
import ft.data;

import vibe.d;
import inmath.linalg;
import core.thread;
import core.sync.mutex;
import std.traits;
import std.string;
import std.stdio:writeln, write;
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
        mtx.lock();
        scope(exit) mtx.unlock();
        return updated_;
    }

    void set(JMLData data) {
        mtx.lock();
        updated_ = true;
        this.data = data;
        mtx.unlock();
    }

    JMLData get() {
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
    bool gotDataFromFetch = false;

    JMLThreadSafeData tsdata;


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
        if ("jml_bind_port" in this.options) {
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

    override
    void poll() {
        if (tsdata.updated) {
            gotDataFromFetch = true;
            JMLData data = tsdata.get();

            blendshapes = data.data.dup;
        } else gotDataFromFetch = false;
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
