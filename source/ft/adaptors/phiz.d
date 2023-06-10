module ft.adaptors.phiz;
import ft.adaptor;
import ft.data;

import osc;
import std.conv : to;
import std.socket;
import inmath.linalg;
import std.traits;

enum PhizBlendshapes {
    browInnerUp = "browInnerUp",
    browDownLeft = "browDownLeft",
    browDownRight = "browDownRight",
    browOuterUpLeft = "browOuterUpLeft",
    browOuterUpRight = "browOuterUpRight",
    eyeLookUpLeft = "eyeLookUpLeft",
    eyeLookUpRight = "eyeLookUpRight",
    eyeLookDownLeft = "eyeLookDownLeft",
    eyeLookDownRight = "eyeLookDownRight",
    eyeLookInLeft = "eyeLookInLeft",
    eyeLookInRight = "eyeLookInRight",
    eyeLookOutLeft = "eyeLookOutLeft",
    eyeLookOutRight = "eyeLookOutRight",
    eyeBlinkLeft = "eyeBlinkLeft",
    eyeBlinkRight = "eyeBlinkRight",
    eyeSquintLeft = "eyeSquintLeft",
    eyeSquintRight = "eyeSquintRight",
    eyeWideLeft = "eyeWideLeft",
    eyeWideRight = "eyeWideRight",
    cheekPuff = "cheekPuff",
    cheekSquintLeft = "cheekSquintLeft",
    cheekSquintRight = "cheekSquintRight",
    noseSneerLeft = "noseSneerLeft",
    noseSneerRight = "noseSneerRight",
    mouthFunnel = "mouthFunnel",
    mouthPucker = "mouthPucker",
    mouthRollUpper = "mouthRollUpper",
    mouthRollLower = "mouthRollLower",
    mouthShrugUpper = "mouthShrugUpper",
    mouthShrugLower = "mouthShrugLower",
    mouthClose = "mouthClose",
    mouthSmileLeft = "mouthSmileLeft",
    mouthSmileRight = "mouthSmileRight",
    mouthFrownLeft = "mouthFrownLeft",
    mouthFrownRight = "mouthFrownRight",
    mouthDimpleLeft = "mouthDimpleLeft",
    mouthDimpleRight = "mouthDimpleRight",
    mouthUpperUpLeft = "mouthUpperUpLeft",
    mouthUpperUpRight = "mouthUpperUpRight",
    mouthLowerDownLeft = "mouthLowerDownLeft",
    mouthLowerDownRight = "mouthLowerDownRight",
    mouthPressLeft = "mouthPressLeft",
    mouthPressRight = "mouthPressRight",
    mouthStretchLeft = "mouthStretchLeft",
    mouthStretchRight = "mouthStretchRight",
    mouthLeft = "mouthLeft",
    mouthRight = "mouthRight",
    jawOpen = "jawOpen",
    jawForward = "jawForward",
    jawLeft = "jawLeft",
    jawRight = "jawRight",
    tongueOut = "tongueOut"
}

class PhizAdaptor : Adaptor {
private:
    Server server;
    ushort port = 41235;
    string bind = "0.0.0.0";

    bool gotDataFromFetch;

public:

    override 
    string getAdaptorName() {
        return "Phiz Receiver";
    }

    override
    void start() {
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
        if (!isRunning) return;
        
        const(Message)[] msgs = server.popMessages();
        if (msgs.length > 0) {
            dataLossCounter = 0;
            gotDataFromFetch = true;

            foreach(const(Message) msg; msgs) {
                if (msg.addressPattern.length < 2) continue;
                if (msg.addressPattern[0].toString != "/phiz") continue;
                switch(msg.addressPattern[1].toString) {
                    case "/headRotation":
                        if (msg.arg!string(0) !in bones) {
                            bones["Head"] = Bone(
                                vec3.init,
                                quat.identity
                            );
                        }

                        this.bones["Head"].rotation = quat(
                            msg.arg!float(3), 
                            -msg.arg!float(2), 
                            msg.arg!float(0), 
                            -msg.arg!float(1), 
                        );
                        break;
                    case "/leftEyeRotation":
                        if (msg.arg!string(0) !in bones) {
                            bones["LeftGaze"] = Bone(
                                vec3.init,
                                quat.identity
                            );
                        }

                        this.bones["LeftGaze"].rotation = quat(
                            msg.arg!float(3), 
                            -msg.arg!float(2), 
                            msg.arg!float(0), 
                            -msg.arg!float(1), 
                        );
                        break;
                    case "/rightEyeRotation":
                        if (msg.arg!string(0) !in bones) {
                            bones["RightGaze"] = Bone(
                                vec3.init,
                                quat.identity
                            );
                        }

                        this.bones["RightGaze"].rotation = quat(
                            msg.arg!float(3), 
                            -msg.arg!float(2), 
                            msg.arg!float(0), 
                            -msg.arg!float(1), 
                        );
                        break;
                    case "/blendshapes":
                        int i = 0;
                        foreach(name; EnumMembers!PhizBlendshapes) {
                            this.blendshapes[name] = msg.arg!float(i);
                            i++;
                        }
                        break;
                    default: break;
                }
            }
        } else {
            dataLossCounter++;
            if (dataLossCounter > RECV_TIMEOUT) gotDataFromFetch = false;
        }
    }

    override
    bool isReceivingData() {
        return gotDataFromFetch;
    }

    override
    string[] getOptionNames() {
        return [
            "port", 
            "address"
        ];
    }
}