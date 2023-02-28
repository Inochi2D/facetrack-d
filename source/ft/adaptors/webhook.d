module ft.adaptors.webhook;
version (WebHookAdaptor) {
import ft.adaptor;
import ft.data;

import vibe.http.server;
import vibe.http.router;
import vibe.data.json;
import vibe.core.sync;
import core.thread;
import core.sync.mutex;
import std.conv;
import std.exception : collectException;

struct WebHookData {
    float[string] data;
}

struct WebHookThreadSafeData {
private:
    WebHookData data;
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

    void set(WebHookData data) {
        if (mtx is null)
            return;
        mtx.lock();
        updated_ = true;
        this.data = data;
        mtx.unlock();
    }

    WebHookData get() {
        if (mtx is null)
            return data;
        mtx.lock();
        updated_ = false;
        scope(exit) mtx.unlock();
        return data;
    }
}

class WebHookAdaptor : Adaptor {
private:
    ushort port = 8080;
    string bind = "0.0.0.0";

    Thread receivingThread;
    Mutex mutex;
    TaskCondition condition;

    bool gotDataFromFetch = false;

    WebHookThreadSafeData tsdata;

public:
    ~this() {
        this.stop();
    }

    void recvData(HTTPServerRequest req, HTTPServerResponse res) {
        Json json_data;
        auto e_result = collectException!Exception(req.json, json_data);
        enforceHTTP(
            e_result is null, 
            HTTPStatus.badRequest, 
            "Error processing request. "~e_result.msg);
        enforceHTTP(
            req.json.type == Json.Type.object, 
            HTTPStatus.badRequest, 
            "No json object in data.");
        WebHookData data;
        foreach (string key, value; req.json) {
            try {
                data.data[key] = value.to!float;
            }
            catch (Exception) {
                // Ignore malformed data
            }
        }

        tsdata.set(data);
        res.writeVoidBody();
    }

    void receiveThread() {
        tsdata = WebHookThreadSafeData(new Mutex());

        HTTPListener listener;
        HTTPServerSettings settings =  new HTTPServerSettings();
        settings.port = port;
        settings.bindAddresses = [bind];

        auto router = new URLRouter;
        router.post("/blendshapes", &this.recvData);

        listener = listenHTTP(settings, router);
        synchronized (mutex) {
            condition.wait();
        }
        listener.stopListening();
    }

    override
    void start() {

        if ("port" in this.options) {
            string port_str = options["port"];
            if (port_str !is null && port_str != "")
                port = this.options["port"].to!ushort;
        }

        if ("address" in this.options) {
            string addr_str = options["address"];
            if (addr_str !is null && addr_str != "")
                bind = this.options["address"];
        }
        if (isRunning) {
            this.stop();
        }
        mutex = new Mutex;
        condition = new TaskCondition(mutex);
        receivingThread = new Thread(&receiveThread);
        receivingThread.start();
    }

    override
    void stop() {
        if (isRunning) {
            condition.notify();
            receivingThread.join();
            mutex = null;
            condition = null;
            receivingThread = null;
            gotDataFromFetch = false;
        }
    }

    override
    void poll() {
        if (tsdata.updated) {
            WebHookData data = tsdata.get();
            gotDataFromFetch = data.data.length > 0;
            foreach(string key, float value; data.data) {
                blendshapes[key] = value;
            }
        }
    }

    override
    bool isRunning() {
        return receivingThread !is null;
    }

    override
    string[] getOptionNames() {
        return [
            "address",
            "port", 
        ];
    }

    override string getAdaptorName() {
        return "Web Hook Receiver";
    }

    override
    bool isReceivingData() {
        return gotDataFromFetch;
    }
}
}
