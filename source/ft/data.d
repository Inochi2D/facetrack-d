module ft.data;
import gl3n.linalg;

enum BlendshapeNames : string {
    eyeBlinkLeft = "eyeBlinkLeft",
    eyeLookDownLeft = "eyeLookDownLeft",
    eyeLookInLeft = "eyeLookInLeft",
    eyeLookOutLeft = "eyeLookOutLeft",
    eyeLookUpLeft = "eyeLookUpLeft",
    eyeSquintLeft = "eyeSquintLeft",
    eyeWideLeft = "eyeWideLeft",

    eyeBlinkRight = "eyeBlinkRight",
    eyeLookDownRight = "eyeLookDownRight",
    eyeLookInRight = "eyeLookInRight",
    eyeLookOutRight = "eyeLookOutRight",
    eyeLookUpRight = "eyeLookUpRight",
    eyeSquintRight = "eyeSquintRight",
    eyeWideRight = "eyeWideRight",

    jawForward = "jawForward",
    jawLeft = "jawLeft",
    jawRight = "jawRight",
    jawOpen = "jawOpen",
    mouthClose = "mouthClose",
    mouthFunnel = "mouthFunnel",
    mouthPucker = "mouthPucker",
    mouthLeft = "mouthLeft",
    mouthRight = "mouthRight",
    mouthSmileLeft = "mouthSmileLeft",
    mouthSmileRight = "mouthSmileRight",
    mouthFrownLeft = "mouthFrownLeft",
    mouthFrownRight = "mouthFrownRight",
    mouthDimpleLeft = "mouthDimpleLeft",
    mouthDimpleRight = "mouthDimpleRight",
    mouthStretchLeft = "mouthStretchLeft",
    mouthStretchRight = "mouthStretchRight",
    mouthRollLower = "mouthRollLower",
    mouthRollUpper = "mouthRollUpper",
    mouthShrugLower = "mouthShrugLower",
    mouthShrugUpper = "mouthShrugUpper",
    mouthPressLeft = "mouthPressLeft",
    mouthPressRight = "mouthPressRight",
    mouthLowerDownLeft = "mouthLowerDownLeft",
    mouthLowerDownRight = "mouthLowerDownRight",
    mouthUpperUpLeft = "mouthUpperUpLeft",
    mouthUpperUpRight = "mouthUpperUpRight",

    browDownLeft = "browDownLeft",
    browDownRight = "browDownRight",
    browInnerUp = "browInnerUp",
    browOuterUpLeft = "browOuterUpLeft",
    browOuterUpRight = "browOuterUpRight",
    cheekPuff = "cheekPuff",
    cheekSquintLeft = "cheekSquintLeft",
    cheekSquintRight = "cheekSquintRight",
    noseSneerLeft = "noseSneerLeft",
    noseSneerRight = "noseSneerRight",

    tongueOut = "tongueOut",

    vrmNeutral = "NEUTRAL",
    vrmA = "A",
    vrmI = "I",
    vrmU = "U",
    vrmE = "E",
    vrmO = "O",
    vrmBlink = "BLINK",
    vrmJoy = "JOY",
    vrmAngry = "ANGRY",
    vrmSorrow = "SORROW",
    vrmFun = "FUN",
    vrmLookUp = "LOOKUP",
    vrmLookLeft = "LOOKLEFT",
    vrmLookRight = "LOOKRIGHT",
    vrmBlinkLeft = "BLINK_L",
    vrmBlinkRight = "BLINK_R",
}

/**
    Names of humanoid bones according to Unity
    and the VMC protocol
*/
enum BoneNames {
    vmcHips = "Hips",
    vmcLeftUpperLeg = "LeftUpperLeg",
    vmcRightUpperLeg = "RightUpperLeg",
    vmcLeftLowerLeg = "LeftLowerLeg",
    vmcRightLowerLeg = "RightLowerLeg",
    vmcLeftFoot = "LeftFoot",
    vmcRightFoot = "RightFoot",
    vmcSpine = "Spine",
    vmcChest = "Chest",
    vmcUpperChest = "UpperChest",
    vmcNeck = "Neck",
    vmcHead = "Head",
    vmcLeftShoulder = "LeftShoulder",
    vmcRightShoulder = "RightShoulder",
    vmcLeftUpperArm = "LeftUpperArm",
    vmcRightUpperArm = "RightUpperArm",
    vmcLeftLowerArm = "LeftLowerArm",
    vmcRightLowerArm = "RightLowerArm",
    vmcLeftHand = "LeftHand",
    vmcRightHand = "RightHand",
    vmcLeftToes = "LeftToes",
    vmcRightToes = "RightToes",
    vmcLeftEye = "LeftEye",
    vmcRightEye = "RightEye",
    vmcJaw = "Jaw",
    vmcLeftThumbProximal = "LeftThumbProximal",
    vmcLeftThumbIntermediate = "LeftThumbIntermediate",
    vmcLeftThumbDistal = "LeftThumbDistal",
    vmcLeftIndexProximal = "LeftIndexProximal",
    vmcLeftIndexIntermediate = "LeftIndexIntermediate",
    vmcLeftIndexDistal = "LeftIndexDistal",
    vmcLeftMiddleProximal = "LeftMiddleProximal",
    vmcLeftMiddleIntermediate = "LeftMiddleIntermediate",
    vmcLeftMiddleDistal = "LeftMiddleDistal",
    vmcLeftRingProximal = "LeftRingProximal",
    vmcLeftRingIntermediate = "LeftRingIntermediate",
    vmcLeftRingDistal = "LeftRingDistal",
    vmcLeftLittleProximal = "LeftLittleProximal",
    vmcLeftLittleIntermediate = "LeftLittleIntermediate",
    vmcLeftLittleDistal = "LeftLittleDistal",
    vmcRightThumbProximal = "RightThumbProximal",
    vmcRightThumbIntermediate = "RightThumbIntermediate",
    vmcRightThumbDistal = "RightThumbDistal",
    vmcRightIndexProximal = "RightIndexProximal",
    vmcRightIndexIntermediate = "RightIndexIntermediate",
    vmcRightIndexDistal = "RightIndexDistal",
    vmcRightMiddleProximal = "RightMiddleProximal",
    vmcRightMiddleIntermediate = "RightMiddleIntermediate",
    vmcRightMiddleDistal = "RightMiddleDistal",
    vmcRightRingProximal = "RightRingProximal",
    vmcRightRingIntermediate = "RightRingIntermediate",
    vmcRightRingDistal = "RightRingDistal",
    vmcRightLittleProximal = "RightLittleProximal",
    vmcRightLittleIntermediate = "RightLittleIntermediate",
    vmcRightLittleDistal = "RightLittleDistal",
    vmcLastBone = "LastBone"
}

struct Bone {
    /**
        Position of the bone
    */
    vec3 position;

    /**
        Rotation of the bone
    */
    quat rotation;
}