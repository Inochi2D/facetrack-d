module ft.adaptors;
import ft.adaptor;
public import ft.adaptors.vmc : VMCAdaptor;
public import ft.adaptors.vtsproto : VTSAdaptor;
public import ft.adaptors.openseeface : OSFAdaptor;
public import ft.adaptors.ifacialmocap : IFMAdaptor;
public import ft.adaptors.llf : LLFAdaptor;

version (WebHookAdaptor){
    public import ft.adaptors.webhook : WebHookAdaptor;
}
version (JML) {
    public import ft.adaptors.jinsmemelogger : JMLAdaptor;
}

private {
    Adaptor function()[string] adaptorFactories;
}

/**
    Adds an adaptor factory to the factory handler
*/
void ftRegisterAdaptorFactory(string name, Adaptor function() func) {
    adaptorFactories[name] = func;
}

/**
    Creates a new adaptor from an adaptor factory tag
*/
Adaptor ftCreateAdaptor(string name) {
    if (name in adaptorFactories) return adaptorFactories[name]();
    return null;
}

/**
    Creates a new adaptor from an adaptor factory tag,
    this adaptor will have the specified start options
*/
Adaptor ftCreateAdaptor(string name, string[string] options) {
    if (name in adaptorFactories) {
        auto adaptor = adaptorFactories[name]();
        adaptor.start(options);
        return adaptor;
    }
    return null;
}

shared static this() {
    ftRegisterAdaptorFactory("VTubeStudio", () { return new VTSAdaptor(); });
    ftRegisterAdaptorFactory("OpenSeeFace", () { return new OSFAdaptor(); });
    ftRegisterAdaptorFactory("VMC Receiver", () { return new VMCAdaptor(); });
    ftRegisterAdaptorFactory("iFacialMocap", () { return new IFMAdaptor(); });
    ftRegisterAdaptorFactory("LiveLinkFace/MeFaMo Receiver", () { return new LLFAdaptor(); });
    version (WebHookAdaptor){
        ftRegisterAdaptorFactory("Web Hook Receiver", () { return new WebHookAdaptor(); });
    }
    version (JML) {
        ftRegisterAdaptorFactory("JINS MEME Logger", () { return new JMLAdaptor(); });
    }
}
