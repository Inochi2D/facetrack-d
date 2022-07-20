module ft.adaptors;
import ft.adaptor;
public import ft.adaptors.vmc : VMCAdaptor;
public import ft.adaptors.vtsproto : VTSAdaptor;
public import ft.adaptors.openseeface : OSFAdaptor;

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

shared static this() {
    ftRegisterAdaptorFactory("VTubeStudio", () { return new VTSAdaptor(); });
    ftRegisterAdaptorFactory("OpenSeeFace", () { return new OSFAdaptor(); });
    ftRegisterAdaptorFactory("VMC Reciever", () { return new VMCAdaptor(); });
}