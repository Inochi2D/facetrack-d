module ft.data;
import inmath.linalg;

enum BlendshapeNames : string {
    eyeBlinkLeft = "EyeBlinkLeft",
    eyeLookDownLeft = "EyeLookDownLeft",
    eyeLookInLeft = "EyeLookInLeft",
    eyeLookOutLeft = "EyeLookOutLeft",
    eyeLookUpLeft = "EyeLookUpLeft",
    eyeSquintLeft = "EyeSquintLeft",
    eyeWideLeft = "EyeWideLeft",

    eyeBlinkRight = "EyeBlinkRight",
    eyeLookDownRight = "EyeLookDownRight",
    eyeLookInRight = "EyeLookInRight",
    eyeLookOutRight = "EyeLookOutRight",
    eyeLookUpRight = "EyeLookUpRight",
    eyeSquintRight = "EyeSquintRight",
    eyeWideRight = "EyeWideRight",

    jawForward = "JawForward",
    jawLeft = "JawLeft",
    jawRight = "JawRight",
    jawOpen = "JawOpen",
    mouthClose = "MouthClose",
    mouthFunnel = "MouthFunnel",
    mouthPucker = "MouthPucker",
    mouthLeft = "MouthLeft",
    mouthRight = "MouthRight",
    mouthSmileLeft = "MouthSmileLeft",
    mouthSmileRight = "MouthSmileRight",
    mouthFrownLeft = "MouthFrownLeft",
    mouthFrownRight = "MouthFrownRight",
    mouthDimpleLeft = "MouthDimpleLeft",
    mouthDimpleRight = "MouthDimpleRight",
    mouthStretchLeft = "MouthStretchLeft",
    mouthStretchRight = "MouthStretchRight",
    mouthRollLower = "MouthRollLower",
    mouthRollUpper = "MouthRollUpper",
    mouthShrugLower = "MouthShrugLower",
    mouthShrugUpper = "MouthShrugUpper",
    mouthPressLeft = "MouthPressLeft",
    mouthPressRight = "MouthPressRight",
    mouthLowerDownLeft = "MouthLowerDownLeft",
    mouthLowerDownRight = "MouthLowerDownRight",
    mouthUpperUpLeft = "MouthUpperUpLeft",
    mouthUpperUpRight = "MouthUpperUpRight",

    browDownLeft = "BrowDownLeft",
    browDownRight = "BrowDownRight",
    browInnerUp = "BrowInnerUp",
    browOuterUpLeft = "BrowOuterUpLeft",
    browOuterUpRight = "BrowOuterUpRight",
    cheekPuff = "CheekPuff",
    cheekSquintLeft = "CheekSquintLeft",
    cheekSquintRight = "CheekSquintRight",
    noseSneerLeft = "NoseSneerLeft",
    noseSneerRight = "NoseSneerRight",

    tongueOut = "TongueOut",

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

    // LEFT EYE
    ftEyeBlinkLeft = "ftEyeBlinkLeft",
    ftEyeYLeft = "ftEyeYLeft",
    ftEyeXLeft = "ftEyeXLeft",
    ftEyeSquintLeft = "ftEyeSquintLeft",
    ftEyeWidenLeft = "ftEyeWidenLeft",

    // RIGHT EYE
    ftEyeBlinkRight = "ftEyeBlinkRight",
    ftEyeYRight = "ftEyeYRight",
    ftEyeXRight = "ftEyeXRight",
    ftEyeSquintRight = "ftEyeSquintRight",
    ftEyeWidenRight = "ftEyeWidenRight",

    // MOUTH
    ftMouthOpen = "ftMouthOpen",
    ftMouthX = "ftMouthX",
    ftMouthEmotion = "ftMouthEmotion",

    // VOWELS
    ftA = "ftA",
    ftI = "ftI",
    ftU = "ftU",
    ftE = "ftE",
    ftO = "ftO",
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
    vmcLastBone = "LastBone",


    ftHead = "Head"
}

struct Bone {
    /**
        Position of the bone
    */
    vec3 position = vec3(0);

    /**
        Rotation of the bone
    */
    quat rotation = quat.identity;
}