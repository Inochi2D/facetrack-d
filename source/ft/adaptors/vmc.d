module ft.adaptors.vmc;
import ft.adaptor;
import ft.data;
import osc;
import std.conv : to;
import std.socket;
import inmath.linalg;

class VMCAdaptor : Adaptor {
private:
    Server server;
    ushort port = 39540;
    string bind = "0.0.0.0";

public:

    override
    void start(string[string] options = string[string].init) {
        if ("port" in options) {
            port = to!ushort(options["port"]);
        }

        if ("address" in options) {
            bind = options["address"];
        }

        server = new Server(new InternetAddress(bind, port));
    }

    override
    bool isRunning() {
        return server !is null;
    }

    override
    void stop() {
        if (server) {
            server.close();
            server = null;
        }
    }

    override
    void poll() {
        const(Message)[] msgs = server.popMessages();
        foreach(const(Message) msg; msgs) {
            if (msg.addressPattern.length < 3) continue;
            if (msg.addressPattern[0].toString != "/VMC" && msg.addressPattern[1].toString != "/Ext") continue;
            switch(msg.addressPattern[2].toString) {
                case "/Bone":
                    if (msg.arg!string(0) !in bones) {
                        bones[msg.arg!string(0)] = Bone(
                            vec3.init,
                            quat.identity
                        );
                    }

                    this.bones[msg.arg!string(0)].position = vec3(
                        msg.arg!float(1),
                        msg.arg!float(2),
                        msg.arg!float(3)
                    );
                    
                    this.bones[msg.arg!string(0)].rotation = quat(
                        msg.arg!float(7), 
                        msg.arg!float(4), 
                        msg.arg!float(5), 
                        msg.arg!float(6)
                    );
                    break;
                case "/Blend":
                    if (msg.addressPattern[3].toString == "/Apply") break;
                    this.blendshapes[msg.arg!string(0)] = msg.arg!float(1);
                    break;
                default: break;
            }
        }
    }

    override
    string[] getOptionNames() {
        return [
            "port", 
            "address"
        ];
    }
}