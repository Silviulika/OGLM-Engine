unit DWS.FastMath;

interface

uses
  System.Classes, System.SysUtils, System.Math, Vcl.Dialogs,
  Neslib.FastMath,
  dwsComp, dwsExprs, dwsInfo, dwsTokenTypes;

type
  TdwsFastMath = class(TdwsUnit)
  private
    // Internal helper: creates a DWS record type whose fields all use the same DWS data type.
    procedure RegisterRecordType(const AName, AFieldType: string; const AFieldNames: array of string);
    // Internal helper: creates a script-visible function and assigns its native Delphi callback.
    procedure RegisterFastMathFunction(const AName, AResultType: string;
      const AParamNames, AParamTypes: array of string; const AOnEval: TFuncEvalEvent;
      const AOverloaded: Boolean = False);
    // Internal helper: maps a script binary operator to one of the registered native functions.
    procedure RegisterBinaryOperator(const AName: string; const AOperator: TTokenType;
      const ALeftType, ARightType, AResultType, AUsesAccess: string);

    // Internal helper: copies a DWS TVector2 record into a native Neslib TVector2.
    function InfoAsVector2(const AInfo: IInfo): TVector2;
    // Internal helper: reads a TVector2 parameter from DWS call information.
    function ParamAsVector2(Info: TProgramInfo; const AIndex: Integer): TVector2;
    // Internal helper: writes a native TVector2 into a DWS TVector2 record.
    procedure SetInfoVector2(const AInfo: IInfo; const AVector: TVector2);
    // Internal helper: writes a native TVector2 into the current DWS result record.
    procedure SetResultVector2(Info: TProgramInfo; const AVector: TVector2);

    // Internal helper: copies a DWS TVector3 record into a native Neslib TVector3.
    function InfoAsVector3(const AInfo: IInfo): TVector3;
    // Internal helper: reads a TVector3 parameter from DWS call information.
    function ParamAsVector3(Info: TProgramInfo; const AIndex: Integer): TVector3;
    // Internal helper: writes a native TVector3 into a DWS TVector3 record.
    procedure SetInfoVector3(const AInfo: IInfo; const AVector: TVector3);
    // Internal helper: writes a native TVector3 into the current DWS result record.
    procedure SetResultVector3(Info: TProgramInfo; const AVector: TVector3);

    // Internal helper: copies a DWS TVector4 record into a native Neslib TVector4.
    function InfoAsVector4(const AInfo: IInfo): TVector4;
    // Internal helper: reads a TVector4 parameter from DWS call information.
    function ParamAsVector4(Info: TProgramInfo; const AIndex: Integer): TVector4;
    // Internal helper: writes a native TVector4 into a DWS TVector4 record.
    procedure SetInfoVector4(const AInfo: IInfo; const AVector: TVector4);
    // Internal helper: writes a native TVector4 into the current DWS result record.
    procedure SetResultVector4(Info: TProgramInfo; const AVector: TVector4);

    // Internal helper: copies a DWS TMatrix2 record into a native Neslib TMatrix2.
    function InfoAsMatrix2(const AInfo: IInfo): TMatrix2;
    // Internal helper: reads a TMatrix2 parameter from DWS call information.
    function ParamAsMatrix2(Info: TProgramInfo; const AIndex: Integer): TMatrix2;
    // Internal helper: writes a native TMatrix2 into a DWS TMatrix2 record.
    procedure SetInfoMatrix2(const AInfo: IInfo; const AMatrix: TMatrix2);
    // Internal helper: writes a native TMatrix2 into the current DWS result record.
    procedure SetResultMatrix2(Info: TProgramInfo; const AMatrix: TMatrix2);

    // Internal helper: copies a DWS TMatrix3 record into a native Neslib TMatrix3.
    function InfoAsMatrix3(const AInfo: IInfo): TMatrix3;
    // Internal helper: reads a TMatrix3 parameter from DWS call information.
    function ParamAsMatrix3(Info: TProgramInfo; const AIndex: Integer): TMatrix3;
    // Internal helper: writes a native TMatrix3 into a DWS TMatrix3 record.
    procedure SetInfoMatrix3(const AInfo: IInfo; const AMatrix: TMatrix3);
    // Internal helper: writes a native TMatrix3 into the current DWS result record.
    procedure SetResultMatrix3(Info: TProgramInfo; const AMatrix: TMatrix3);

    // Internal helper: copies a DWS TMatrix4 record into a native Neslib TMatrix4.
    function InfoAsMatrix4(const AInfo: IInfo): TMatrix4;
    // Internal helper: reads a TMatrix4 parameter from DWS call information.
    function ParamAsMatrix4(Info: TProgramInfo; const AIndex: Integer): TMatrix4;
    // Internal helper: writes a native TMatrix4 into a DWS TMatrix4 record.
    procedure SetInfoMatrix4(const AInfo: IInfo; const AMatrix: TMatrix4);
    // Internal helper: writes a native TMatrix4 into the current DWS result record.
    procedure SetResultMatrix4(Info: TProgramInfo; const AMatrix: TMatrix4);

    // Internal helper: copies a DWS TQuaternion record into a native Neslib TQuaternion.
    function InfoAsQuaternion(const AInfo: IInfo): TQuaternion;
    // Internal helper: reads a TQuaternion parameter from DWS call information.
    function ParamAsQuaternion(Info: TProgramInfo; const AIndex: Integer): TQuaternion;
    // Internal helper: writes a native TQuaternion into a DWS TQuaternion record.
    procedure SetInfoQuaternion(const AInfo: IInfo; const AQuaternion: TQuaternion);
    // Internal helper: writes a native TQuaternion into the current DWS result record.
    procedure SetResultQuaternion(Info: TProgramInfo; const AQuaternion: TQuaternion);

    // Internal helper: copies a DWS TIVector2 record into a native Neslib TIVector2.
    function InfoAsIVector2(const AInfo: IInfo): TIVector2;
    // Internal helper: reads a TIVector2 parameter from DWS call information.
    function ParamAsIVector2(Info: TProgramInfo; const AIndex: Integer): TIVector2;
    // Internal helper: writes a native TIVector2 into a DWS TIVector2 record.
    procedure SetInfoIVector2(const AInfo: IInfo; const AVector: TIVector2);
    // Internal helper: writes a native TIVector2 into the current DWS result record.
    procedure SetResultIVector2(Info: TProgramInfo; const AVector: TIVector2);

    // Internal helper: copies a DWS TIVector3 record into a native Neslib TIVector3.
    function InfoAsIVector3(const AInfo: IInfo): TIVector3;
    // Internal helper: reads a TIVector3 parameter from DWS call information.
    function ParamAsIVector3(Info: TProgramInfo; const AIndex: Integer): TIVector3;
    // Internal helper: writes a native TIVector3 into a DWS TIVector3 record.
    procedure SetInfoIVector3(const AInfo: IInfo; const AVector: TIVector3);
    // Internal helper: writes a native TIVector3 into the current DWS result record.
    procedure SetResultIVector3(Info: TProgramInfo; const AVector: TIVector3);

    // Internal helper: copies a DWS TIVector4 record into a native Neslib TIVector4.
    function InfoAsIVector4(const AInfo: IInfo): TIVector4;
    // Internal helper: reads a TIVector4 parameter from DWS call information.
    function ParamAsIVector4(Info: TProgramInfo; const AIndex: Integer): TIVector4;
    // Internal helper: writes a native TIVector4 into a DWS TIVector4 record.
    procedure SetInfoIVector4(const AInfo: IInfo; const AVector: TIVector4);
    // Internal helper: writes a native TIVector4 into the current DWS result record.
    procedure SetResultIVector4(Info: TProgramInfo; const AVector: TIVector4);
  public
    // DWS callback for Vector2(): returns the native Neslib zero vector.
    procedure DoGlobalVector2Zero(Info: TProgramInfo);
    // DWS callback for Vector2(Float): creates a native splat vector.
    procedure DoGlobalVector2Val(Info: TProgramInfo);
    // DWS callback for Vector2(Float, Float): creates a native vector from X/Y.
    procedure DoGlobalVector2XY(Info: TProgramInfo);
    // DWS callback for TVector2 + TVector2.
    procedure DoVector2Add(Info: TProgramInfo);
    // DWS callback for Float + TVector2.
    procedure DoVector2AddFloatVector2(Info: TProgramInfo);
    // DWS callback for TVector2 + Float.
    procedure DoVector2AddVector2Float(Info: TProgramInfo);
    // DWS callback for TVector2 - TVector2.
    procedure DoVector2Subtract(Info: TProgramInfo);
    // DWS callback for Float - TVector2.
    procedure DoVector2SubtractFloatVector2(Info: TProgramInfo);
    // DWS callback for TVector2 - Float.
    procedure DoVector2SubtractVector2Float(Info: TProgramInfo);
    // DWS callback for TVector2 * TVector2.
    procedure DoVector2Multiply(Info: TProgramInfo);
    // DWS callback for Float * TVector2.
    procedure DoVector2MultiplyFloatVector2(Info: TProgramInfo);
    // DWS callback for TVector2 * Float.
    procedure DoVector2MultiplyVector2Float(Info: TProgramInfo);
    // DWS callback for TVector2 / TVector2.
    procedure DoVector2Divide(Info: TProgramInfo);
    // DWS callback for Float / TVector2.
    procedure DoVector2DivideFloatVector2(Info: TProgramInfo);
    // DWS callback for TVector2 / Float.
    procedure DoVector2DivideVector2Float(Info: TProgramInfo);
    // DWS callback for Vector2Dot.
    procedure DoVector2Dot(Info: TProgramInfo);
    // DWS callback for Vector2Cross.
    procedure DoVector2Cross(Info: TProgramInfo);
    // DWS callback for Vector2Normalize.
    procedure DoVector2Normalize(Info: TProgramInfo);
    // DWS callback for Vector2NormalizeFast.
    procedure DoVector2NormalizeFast(Info: TProgramInfo);
    // DWS callback for Vector2Length.
    procedure DoVector2Length(Info: TProgramInfo);
    // DWS callback for Vector2LengthSquared.
    procedure DoVector2LengthSquared(Info: TProgramInfo);
    // DWS callback for Vector2Distance.
    procedure DoVector2Distance(Info: TProgramInfo);
    // DWS callback for Vector2DistanceSquared.
    procedure DoVector2DistanceSquared(Info: TProgramInfo);
    // DWS callback for Vector2Lerp.
    procedure DoVector2Lerp(Info: TProgramInfo);
    // DWS callback for Vector2Equals.
    procedure DoVector2Equals(Info: TProgramInfo);
    // DWS callback for Vector2ToString.
    procedure DoVector2ToString(Info: TProgramInfo);

    // DWS callback for Vector3(): returns the native Neslib zero vector.
    procedure DoGlobalVector3Zero(Info: TProgramInfo);
    // DWS callback for Vector3(Float): creates a native splat vector.
    procedure DoGlobalVector3Val(Info: TProgramInfo);
    // DWS callback for Vector3(Float, Float, Float): creates a native vector from X/Y/Z.
    procedure DoGlobalVector3XYZ(Info: TProgramInfo);
    // DWS callback for Vector3(TVector2, Float): combines a 2D vector with Z.
    procedure DoGlobalVector3Vector2Float(Info: TProgramInfo);
    // DWS callback for Vector3(Float, TVector2): combines X with a 2D Y/Z vector.
    procedure DoGlobalVector3FloatVector2(Info: TProgramInfo);
    // DWS callback for TVector3 + TVector3.
    procedure DoVector3Add(Info: TProgramInfo);
    // DWS callback for Float + TVector3.
    procedure DoVector3AddFloatVector3(Info: TProgramInfo);
    // DWS callback for TVector3 + Float.
    procedure DoVector3AddVector3Float(Info: TProgramInfo);
    // DWS callback for TVector3 - TVector3.
    procedure DoVector3Subtract(Info: TProgramInfo);
    // DWS callback for Float - TVector3.
    procedure DoVector3SubtractFloatVector3(Info: TProgramInfo);
    // DWS callback for TVector3 - Float.
    procedure DoVector3SubtractVector3Float(Info: TProgramInfo);
    // DWS callback for TVector3 * TVector3.
    procedure DoVector3Multiply(Info: TProgramInfo);
    // DWS callback for Float * TVector3.
    procedure DoVector3MultiplyFloatVector3(Info: TProgramInfo);
    // DWS callback for TVector3 * Float.
    procedure DoVector3MultiplyVector3Float(Info: TProgramInfo);
    // DWS callback for TVector3 / TVector3.
    procedure DoVector3Divide(Info: TProgramInfo);
    // DWS callback for Float / TVector3.
    procedure DoVector3DivideFloatVector3(Info: TProgramInfo);
    // DWS callback for TVector3 / Float.
    procedure DoVector3DivideVector3Float(Info: TProgramInfo);
    // DWS callback for Vector3Dot.
    procedure DoVector3Dot(Info: TProgramInfo);
    // DWS callback for Vector3Cross.
    procedure DoVector3Cross(Info: TProgramInfo);
    // DWS callback for Vector3Normalize.
    procedure DoVector3Normalize(Info: TProgramInfo);
    // DWS callback for Vector3NormalizeFast.
    procedure DoVector3NormalizeFast(Info: TProgramInfo);
    // DWS callback for Vector3Length.
    procedure DoVector3Length(Info: TProgramInfo);
    // DWS callback for Vector3LengthSquared.
    procedure DoVector3LengthSquared(Info: TProgramInfo);
    // DWS callback for Vector3Distance.
    procedure DoVector3Distance(Info: TProgramInfo);
    // DWS callback for Vector3DistanceSquared.
    procedure DoVector3DistanceSquared(Info: TProgramInfo);
    // DWS callback for Vector3Lerp.
    procedure DoVector3Lerp(Info: TProgramInfo);
    // DWS callback for Vector3Equals.
    procedure DoVector3Equals(Info: TProgramInfo);
    // DWS callback for Vector3ToString.
    procedure DoVector3ToString(Info: TProgramInfo);

    // DWS callback for Vector4(): returns the native Neslib zero vector.
    procedure DoGlobalVector4Zero(Info: TProgramInfo);
    // DWS callback for Vector4(Float): creates a native splat vector.
    procedure DoGlobalVector4Val(Info: TProgramInfo);
    // DWS callback for Vector4(Float, Float, Float, Float): creates a native vector from X/Y/Z/W.
    procedure DoGlobalVector4XYZW(Info: TProgramInfo);
    // DWS callback for Vector4(TVector3, Float): combines a 3D vector with W.
    procedure DoGlobalVector4Vector3Float(Info: TProgramInfo);
    // DWS callback for Vector4(Float, TVector3): combines X with a 3D Y/Z/W vector.
    procedure DoGlobalVector4FloatVector3(Info: TProgramInfo);
    // DWS callback for TVector4 + TVector4.
    procedure DoVector4Add(Info: TProgramInfo);
    // DWS callback for Float + TVector4.
    procedure DoVector4AddFloatVector4(Info: TProgramInfo);
    // DWS callback for TVector4 + Float.
    procedure DoVector4AddVector4Float(Info: TProgramInfo);
    // DWS callback for TVector4 - TVector4.
    procedure DoVector4Subtract(Info: TProgramInfo);
    // DWS callback for Float - TVector4.
    procedure DoVector4SubtractFloatVector4(Info: TProgramInfo);
    // DWS callback for TVector4 - Float.
    procedure DoVector4SubtractVector4Float(Info: TProgramInfo);
    // DWS callback for TVector4 * TVector4.
    procedure DoVector4Multiply(Info: TProgramInfo);
    // DWS callback for Float * TVector4.
    procedure DoVector4MultiplyFloatVector4(Info: TProgramInfo);
    // DWS callback for TVector4 * Float.
    procedure DoVector4MultiplyVector4Float(Info: TProgramInfo);
    // DWS callback for TVector4 / TVector4.
    procedure DoVector4Divide(Info: TProgramInfo);
    // DWS callback for Float / TVector4.
    procedure DoVector4DivideFloatVector4(Info: TProgramInfo);
    // DWS callback for TVector4 / Float.
    procedure DoVector4DivideVector4Float(Info: TProgramInfo);
    // DWS callback for Vector4Dot.
    procedure DoVector4Dot(Info: TProgramInfo);
    // DWS callback for Vector4Normalize.
    procedure DoVector4Normalize(Info: TProgramInfo);
    // DWS callback for Vector4NormalizeFast.
    procedure DoVector4NormalizeFast(Info: TProgramInfo);
    // DWS callback for Vector4Length.
    procedure DoVector4Length(Info: TProgramInfo);
    // DWS callback for Vector4LengthSquared.
    procedure DoVector4LengthSquared(Info: TProgramInfo);
    // DWS callback for Vector4Distance.
    procedure DoVector4Distance(Info: TProgramInfo);
    // DWS callback for Vector4DistanceSquared.
    procedure DoVector4DistanceSquared(Info: TProgramInfo);
    // DWS callback for Vector4Lerp.
    procedure DoVector4Lerp(Info: TProgramInfo);
    // DWS callback for Vector4Equals.
    procedure DoVector4Equals(Info: TProgramInfo);
    // DWS callback for Vector4ToString.
    procedure DoVector4ToString(Info: TProgramInfo);

    // DWS callback for Matrix2(): returns the native Neslib identity matrix.
    procedure DoGlobalMatrix2Identity(Info: TProgramInfo);
    // DWS callback for Matrix2(Float): creates a diagonal matrix.
    procedure DoGlobalMatrix2Diagonal(Info: TProgramInfo);
    // DWS callback for Matrix2(TVector2, TVector2): creates a matrix from rows.
    procedure DoGlobalMatrix2Rows(Info: TProgramInfo);
    // DWS callback for Matrix2(Float, Float, Float, Float): creates a matrix from components.
    procedure DoGlobalMatrix2Values(Info: TProgramInfo);
    // DWS callback for TMatrix2 + TMatrix2.
    procedure DoMatrix2Add(Info: TProgramInfo);
    // DWS callback for TMatrix2 - TMatrix2.
    procedure DoMatrix2Subtract(Info: TProgramInfo);
    // DWS callback for TMatrix2 * TMatrix2.
    procedure DoMatrix2Multiply(Info: TProgramInfo);
    // DWS callback for TMatrix2 / TMatrix2.
    procedure DoMatrix2Divide(Info: TProgramInfo);
    // DWS callback for TMatrix2 * Float.
    procedure DoMatrix2MultiplyMatrixFloat(Info: TProgramInfo);
    // DWS callback for Float * TMatrix2.
    procedure DoMatrix2MultiplyFloatMatrix(Info: TProgramInfo);
    // DWS callback for TMatrix2 / Float.
    procedure DoMatrix2DivideMatrixFloat(Info: TProgramInfo);
    // DWS callback for TMatrix2 * TVector2.
    procedure DoMatrix2MultiplyMatrixVector(Info: TProgramInfo);
    // DWS callback for TVector2 * TMatrix2.
    procedure DoMatrix2MultiplyVectorMatrix(Info: TProgramInfo);
    // DWS callback for Matrix2Transpose.
    procedure DoMatrix2Transpose(Info: TProgramInfo);
    // DWS callback for Matrix2Inverse.
    procedure DoMatrix2Inverse(Info: TProgramInfo);
    // DWS callback for Matrix2Determinant.
    procedure DoMatrix2Determinant(Info: TProgramInfo);
    // DWS callback for Matrix2CompMult.
    procedure DoMatrix2CompMult(Info: TProgramInfo);
    // DWS callback for Matrix2Equals.
    procedure DoMatrix2Equals(Info: TProgramInfo);
    // DWS callback for Matrix2ToString.
    procedure DoMatrix2ToString(Info: TProgramInfo);

    // DWS callback for Matrix3(): returns the native Neslib identity matrix.
    procedure DoGlobalMatrix3Identity(Info: TProgramInfo);
    // DWS callback for Matrix3(Float): creates a diagonal matrix.
    procedure DoGlobalMatrix3Diagonal(Info: TProgramInfo);
    // DWS callback for Matrix3(TVector3, TVector3, TVector3): creates a matrix from rows.
    procedure DoGlobalMatrix3Rows(Info: TProgramInfo);
    // DWS callback for Matrix3(Float...): creates a matrix from components.
    procedure DoGlobalMatrix3Values(Info: TProgramInfo);
    // DWS callback for Matrix3Scaling(Float, Float).
    procedure DoMatrix3ScalingXY(Info: TProgramInfo);
    // DWS callback for Matrix3Scaling(TVector2).
    procedure DoMatrix3ScalingVector(Info: TProgramInfo);
    // DWS callback for Matrix3Translation(Float, Float).
    procedure DoMatrix3TranslationXY(Info: TProgramInfo);
    // DWS callback for Matrix3Translation(TVector2).
    procedure DoMatrix3TranslationVector(Info: TProgramInfo);
    // DWS callback for Matrix3Rotation.
    procedure DoMatrix3Rotation(Info: TProgramInfo);
    // DWS callback for TMatrix3 + TMatrix3.
    procedure DoMatrix3Add(Info: TProgramInfo);
    // DWS callback for TMatrix3 - TMatrix3.
    procedure DoMatrix3Subtract(Info: TProgramInfo);
    // DWS callback for TMatrix3 * TMatrix3.
    procedure DoMatrix3Multiply(Info: TProgramInfo);
    // DWS callback for TMatrix3 / TMatrix3.
    procedure DoMatrix3Divide(Info: TProgramInfo);
    // DWS callback for TMatrix3 * Float.
    procedure DoMatrix3MultiplyMatrixFloat(Info: TProgramInfo);
    // DWS callback for Float * TMatrix3.
    procedure DoMatrix3MultiplyFloatMatrix(Info: TProgramInfo);
    // DWS callback for TMatrix3 / Float.
    procedure DoMatrix3DivideMatrixFloat(Info: TProgramInfo);
    // DWS callback for TMatrix3 * TVector3.
    procedure DoMatrix3MultiplyMatrixVector(Info: TProgramInfo);
    // DWS callback for TVector3 * TMatrix3.
    procedure DoMatrix3MultiplyVectorMatrix(Info: TProgramInfo);
    // DWS callback for Matrix3Transpose.
    procedure DoMatrix3Transpose(Info: TProgramInfo);
    // DWS callback for Matrix3Inverse.
    procedure DoMatrix3Inverse(Info: TProgramInfo);
    // DWS callback for Matrix3Determinant.
    procedure DoMatrix3Determinant(Info: TProgramInfo);
    // DWS callback for Matrix3CompMult.
    procedure DoMatrix3CompMult(Info: TProgramInfo);
    // DWS callback for Matrix3Equals.
    procedure DoMatrix3Equals(Info: TProgramInfo);
    // DWS callback for Matrix3ToString.
    procedure DoMatrix3ToString(Info: TProgramInfo);

    // DWS callback for Matrix4(): returns the native Neslib identity matrix.
    procedure DoGlobalMatrix4Identity(Info: TProgramInfo);
    // DWS callback for Matrix4(Float): creates a diagonal matrix.
    procedure DoGlobalMatrix4Diagonal(Info: TProgramInfo);
    // DWS callback for Matrix4(TVector4, TVector4, TVector4, TVector4): creates a matrix from rows.
    procedure DoGlobalMatrix4Rows(Info: TProgramInfo);
    // DWS callback for Matrix4(Float...): creates a matrix from components.
    procedure DoGlobalMatrix4Values(Info: TProgramInfo);
    // DWS callback for Matrix4Scaling(Float, Float, Float).
    procedure DoMatrix4ScalingXYZ(Info: TProgramInfo);
    // DWS callback for Matrix4Scaling(TVector3).
    procedure DoMatrix4ScalingVector(Info: TProgramInfo);
    // DWS callback for Matrix4Translation(Float, Float, Float).
    procedure DoMatrix4TranslationXYZ(Info: TProgramInfo);
    // DWS callback for Matrix4Translation(TVector3).
    procedure DoMatrix4TranslationVector(Info: TProgramInfo);
    // DWS callback for Matrix4RotationX.
    procedure DoMatrix4RotationX(Info: TProgramInfo);
    // DWS callback for Matrix4RotationY.
    procedure DoMatrix4RotationY(Info: TProgramInfo);
    // DWS callback for Matrix4RotationZ.
    procedure DoMatrix4RotationZ(Info: TProgramInfo);
    // DWS callback for Matrix4RotationAxis.
    procedure DoMatrix4RotationAxis(Info: TProgramInfo);
    // DWS callback for Matrix4RotationYawPitchRoll.
    procedure DoMatrix4RotationYawPitchRoll(Info: TProgramInfo);
    // DWS callback for Matrix4LookAtLH.
    procedure DoMatrix4LookAtLH(Info: TProgramInfo);
    // DWS callback for Matrix4LookAtRH.
    procedure DoMatrix4LookAtRH(Info: TProgramInfo);
    // DWS callback for Matrix4PerspectiveFovLH.
    procedure DoMatrix4PerspectiveFovLH(Info: TProgramInfo);
    // DWS callback for Matrix4PerspectiveFovRH.
    procedure DoMatrix4PerspectiveFovRH(Info: TProgramInfo);
    // DWS callback for TMatrix4 + TMatrix4.
    procedure DoMatrix4Add(Info: TProgramInfo);
    // DWS callback for TMatrix4 - TMatrix4.
    procedure DoMatrix4Subtract(Info: TProgramInfo);
    // DWS callback for TMatrix4 * TMatrix4.
    procedure DoMatrix4Multiply(Info: TProgramInfo);
    // DWS callback for TMatrix4 / TMatrix4.
    procedure DoMatrix4Divide(Info: TProgramInfo);
    // DWS callback for TMatrix4 * Float.
    procedure DoMatrix4MultiplyMatrixFloat(Info: TProgramInfo);
    // DWS callback for Float * TMatrix4.
    procedure DoMatrix4MultiplyFloatMatrix(Info: TProgramInfo);
    // DWS callback for TMatrix4 / Float.
    procedure DoMatrix4DivideMatrixFloat(Info: TProgramInfo);
    // DWS callback for TMatrix4 * TVector4.
    procedure DoMatrix4MultiplyMatrixVector(Info: TProgramInfo);
    // DWS callback for TVector4 * TMatrix4.
    procedure DoMatrix4MultiplyVectorMatrix(Info: TProgramInfo);
    // DWS callback for Matrix4Transpose.
    procedure DoMatrix4Transpose(Info: TProgramInfo);
    // DWS callback for Matrix4Inverse.
    procedure DoMatrix4Inverse(Info: TProgramInfo);
    // DWS callback for Matrix4Determinant.
    procedure DoMatrix4Determinant(Info: TProgramInfo);
    // DWS callback for Matrix4CompMult.
    procedure DoMatrix4CompMult(Info: TProgramInfo);
    // DWS callback for Matrix4Equals.
    procedure DoMatrix4Equals(Info: TProgramInfo);
    // DWS callback for Matrix4ToString.
    procedure DoMatrix4ToString(Info: TProgramInfo);

    // DWS callback for Quaternion(): returns the native identity quaternion.
    procedure DoGlobalQuaternionIdentity(Info: TProgramInfo);
    // DWS callback for Quaternion(Float, Float, Float, Float).
    procedure DoGlobalQuaternionXYZW(Info: TProgramInfo);
    // DWS callback for Quaternion(TVector3, Float).
    procedure DoGlobalQuaternionAxisAngle(Info: TProgramInfo);
    // DWS callback for QuaternionYawPitchRoll.
    procedure DoQuaternionYawPitchRoll(Info: TProgramInfo);
    // DWS callback for QuaternionFromMatrix4.
    procedure DoQuaternionFromMatrix4(Info: TProgramInfo);
    // DWS callback for TQuaternion + TQuaternion.
    procedure DoQuaternionAdd(Info: TProgramInfo);
    // DWS callback for TQuaternion * TQuaternion.
    procedure DoQuaternionMultiply(Info: TProgramInfo);
    // DWS callback for TQuaternion * Float.
    procedure DoQuaternionMultiplyQuaternionFloat(Info: TProgramInfo);
    // DWS callback for Float * TQuaternion.
    procedure DoQuaternionMultiplyFloatQuaternion(Info: TProgramInfo);
    // DWS callback for QuaternionNormalize.
    procedure DoQuaternionNormalize(Info: TProgramInfo);
    // DWS callback for QuaternionNormalizeFast.
    procedure DoQuaternionNormalizeFast(Info: TProgramInfo);
    // DWS callback for QuaternionConjugate.
    procedure DoQuaternionConjugate(Info: TProgramInfo);
    // DWS callback for QuaternionToMatrix4.
    procedure DoQuaternionToMatrix4(Info: TProgramInfo);
    // DWS callback for QuaternionLength.
    procedure DoQuaternionLength(Info: TProgramInfo);
    // DWS callback for QuaternionLengthSquared.
    procedure DoQuaternionLengthSquared(Info: TProgramInfo);
    // DWS callback for QuaternionIsIdentity.
    procedure DoQuaternionIsIdentity(Info: TProgramInfo);
    // DWS callback for QuaternionToString.
    procedure DoQuaternionToString(Info: TProgramInfo);

    // DWS callback for IVector2 constructors.
    procedure DoGlobalIVector2(Info: TProgramInfo);
    // DWS callback for IVector3 constructors.
    procedure DoGlobalIVector3(Info: TProgramInfo);
    // DWS callback for IVector4 constructors.
    procedure DoGlobalIVector4(Info: TProgramInfo);
    // DWS callback for integer vector zero checks.
    procedure DoIVectorIsZero(Info: TProgramInfo);
    // DWS callback for integer-to-float vector conversion.
    procedure DoIVectorToVector(Info: TProgramInfo);
    // DWS callback for integer vector text formatting.
    procedure DoIVectorToString(Info: TProgramInfo);

    // DWS callback for scalar clamp/lerp helpers.
    procedure DoFloatClamp(Info: TProgramInfo);
    procedure DoFloatLerp(Info: TProgramInfo);
    procedure DoFloatSmoothStep(Info: TProgramInfo);
    procedure DoRadians(Info: TProgramInfo);
    procedure DoDegrees(Info: TProgramInfo);

    // DWS callback for component-wise vector helpers.
    procedure DoVector2Min(Info: TProgramInfo);
    procedure DoVector2Max(Info: TProgramInfo);
    procedure DoVector2Clamp(Info: TProgramInfo);
    procedure DoVector3Min(Info: TProgramInfo);
    procedure DoVector3Max(Info: TProgramInfo);
    procedure DoVector3Clamp(Info: TProgramInfo);
    procedure DoVector3Reflect(Info: TProgramInfo);
    procedure DoVector3Project(Info: TProgramInfo);
    procedure DoVector4Min(Info: TProgramInfo);
    procedure DoVector4Max(Info: TProgramInfo);
    procedure DoVector4Clamp(Info: TProgramInfo);

    // DWS callback for ShowMessage.
    procedure DoShowMessage(Info: TProgramInfo);

    // Delphi-side setup entry point: registers records, functions, and operators with DWS.
    constructor RegisterFastMath(AOwner: TComponent; AScript: TDelphiWebScript);
  end;

implementation

function FastMathMinSingle(const A, B: Single): Single;
begin
  if A < B then
    Result := A
  else
    Result := B;
end;

function FastMathMaxSingle(const A, B: Single): Single;
begin
  if A > B then
    Result := A
  else
    Result := B;
end;

function FastMathClampSingle(const Value, MinValue, MaxValue: Single): Single;
begin
  if Value < MinValue then
    Result := MinValue
  else if Value > MaxValue then
    Result := MaxValue
  else
    Result := Value;
end;

procedure TdwsFastMath.RegisterRecordType(const AName, AFieldType: string;
  const AFieldNames: array of string);
var
  Rec: TdwsRecord;
  Member: TdwsMember;
  I: Integer;
begin
  Rec := Records.Add;
  Rec.Name := AName;

  for I := 0 to High(AFieldNames) do
  begin
    Member := Rec.Members.Add;
    Member.Name := AFieldNames[I];
    Member.DataType := AFieldType;
  end;
end;

procedure TdwsFastMath.RegisterFastMathFunction(const AName, AResultType: string;
  const AParamNames, AParamTypes: array of string; const AOnEval: TFuncEvalEvent;
  const AOverloaded: Boolean);
var
  Func: TdwsFunction;
  I: Integer;
  Param: TdwsParameter;
begin
  if Length(AParamNames) <> Length(AParamTypes) then
    raise Exception.Create('FastMath function parameter metadata mismatch');

  Func := Functions.Add;
  Func.Name := AName;
  Func.ResultType := AResultType;
  Func.Overloaded := AOverloaded;
  Func.OnEval := AOnEval;

  for I := 0 to High(AParamNames) do
  begin
    Param := Func.Parameters.Add;
    Param.Name := AParamNames[I];
    Param.DataType := AParamTypes[I];
  end;
end;

procedure TdwsFastMath.RegisterBinaryOperator(const AName: string; const AOperator: TTokenType;
  const ALeftType, ARightType, AResultType, AUsesAccess: string);
var
  Op: TdwsOperator;
begin
  Op := Operators.Add;
  Op.Name := AName;
  Op.Operator := AOperator;
  Op.ResultType := AResultType;
  Op.UsesAccess := AUsesAccess;
  Op.Params.Add.Name := ALeftType;
  Op.Params.Add.Name := ARightType;
end;

function TdwsFastMath.InfoAsVector2(const AInfo: IInfo): TVector2;
begin
  Result := Vector2(
    AInfo.Member['X'].ValueAsFloat,
    AInfo.Member['Y'].ValueAsFloat);
end;

function TdwsFastMath.ParamAsVector2(Info: TProgramInfo; const AIndex: Integer): TVector2;
begin
  Result := InfoAsVector2(Info.Params[AIndex]);
end;

procedure TdwsFastMath.SetInfoVector2(const AInfo: IInfo; const AVector: TVector2);
begin
  AInfo.Member['X'].Value := AVector.X;
  AInfo.Member['Y'].Value := AVector.Y;
end;

procedure TdwsFastMath.SetResultVector2(Info: TProgramInfo; const AVector: TVector2);
begin
  SetInfoVector2(Info.ResultVars, AVector);
end;

function TdwsFastMath.InfoAsVector3(const AInfo: IInfo): TVector3;
begin
  Result := Vector3(
    AInfo.Member['X'].ValueAsFloat,
    AInfo.Member['Y'].ValueAsFloat,
    AInfo.Member['Z'].ValueAsFloat);
end;

function TdwsFastMath.ParamAsVector3(Info: TProgramInfo; const AIndex: Integer): TVector3;
begin
  Result := InfoAsVector3(Info.Params[AIndex]);
end;

procedure TdwsFastMath.SetInfoVector3(const AInfo: IInfo; const AVector: TVector3);
begin
  AInfo.Member['X'].Value := AVector.X;
  AInfo.Member['Y'].Value := AVector.Y;
  AInfo.Member['Z'].Value := AVector.Z;
end;

procedure TdwsFastMath.SetResultVector3(Info: TProgramInfo; const AVector: TVector3);
begin
  SetInfoVector3(Info.ResultVars, AVector);
end;

function TdwsFastMath.InfoAsVector4(const AInfo: IInfo): TVector4;
begin
  Result := Vector4(
    AInfo.Member['X'].ValueAsFloat,
    AInfo.Member['Y'].ValueAsFloat,
    AInfo.Member['Z'].ValueAsFloat,
    AInfo.Member['W'].ValueAsFloat);
end;

function TdwsFastMath.ParamAsVector4(Info: TProgramInfo; const AIndex: Integer): TVector4;
begin
  Result := InfoAsVector4(Info.Params[AIndex]);
end;

procedure TdwsFastMath.SetInfoVector4(const AInfo: IInfo; const AVector: TVector4);
begin
  AInfo.Member['X'].Value := AVector.X;
  AInfo.Member['Y'].Value := AVector.Y;
  AInfo.Member['Z'].Value := AVector.Z;
  AInfo.Member['W'].Value := AVector.W;
end;

procedure TdwsFastMath.SetResultVector4(Info: TProgramInfo; const AVector: TVector4);
begin
  SetInfoVector4(Info.ResultVars, AVector);
end;

function TdwsFastMath.InfoAsMatrix2(const AInfo: IInfo): TMatrix2;
begin
  Result := Matrix2(
    AInfo.Member['M11'].ValueAsFloat, AInfo.Member['M12'].ValueAsFloat,
    AInfo.Member['M21'].ValueAsFloat, AInfo.Member['M22'].ValueAsFloat);
end;

function TdwsFastMath.ParamAsMatrix2(Info: TProgramInfo; const AIndex: Integer): TMatrix2;
begin
  Result := InfoAsMatrix2(Info.Params[AIndex]);
end;

procedure TdwsFastMath.SetInfoMatrix2(const AInfo: IInfo; const AMatrix: TMatrix2);
begin
  AInfo.Member['M11'].Value := AMatrix.m11;
  AInfo.Member['M12'].Value := AMatrix.m12;
  AInfo.Member['M21'].Value := AMatrix.m21;
  AInfo.Member['M22'].Value := AMatrix.m22;
end;

procedure TdwsFastMath.SetResultMatrix2(Info: TProgramInfo; const AMatrix: TMatrix2);
begin
  SetInfoMatrix2(Info.ResultVars, AMatrix);
end;

function TdwsFastMath.InfoAsMatrix3(const AInfo: IInfo): TMatrix3;
begin
  Result := Matrix3(
    AInfo.Member['M11'].ValueAsFloat, AInfo.Member['M12'].ValueAsFloat, AInfo.Member['M13'].ValueAsFloat,
    AInfo.Member['M21'].ValueAsFloat, AInfo.Member['M22'].ValueAsFloat, AInfo.Member['M23'].ValueAsFloat,
    AInfo.Member['M31'].ValueAsFloat, AInfo.Member['M32'].ValueAsFloat, AInfo.Member['M33'].ValueAsFloat);
end;

function TdwsFastMath.ParamAsMatrix3(Info: TProgramInfo; const AIndex: Integer): TMatrix3;
begin
  Result := InfoAsMatrix3(Info.Params[AIndex]);
end;

procedure TdwsFastMath.SetInfoMatrix3(const AInfo: IInfo; const AMatrix: TMatrix3);
begin
  AInfo.Member['M11'].Value := AMatrix.m11;
  AInfo.Member['M12'].Value := AMatrix.m12;
  AInfo.Member['M13'].Value := AMatrix.m13;
  AInfo.Member['M21'].Value := AMatrix.m21;
  AInfo.Member['M22'].Value := AMatrix.m22;
  AInfo.Member['M23'].Value := AMatrix.m23;
  AInfo.Member['M31'].Value := AMatrix.m31;
  AInfo.Member['M32'].Value := AMatrix.m32;
  AInfo.Member['M33'].Value := AMatrix.m33;
end;

procedure TdwsFastMath.SetResultMatrix3(Info: TProgramInfo; const AMatrix: TMatrix3);
begin
  SetInfoMatrix3(Info.ResultVars, AMatrix);
end;

function TdwsFastMath.InfoAsMatrix4(const AInfo: IInfo): TMatrix4;
begin
  Result := Matrix4(
    AInfo.Member['M11'].ValueAsFloat, AInfo.Member['M12'].ValueAsFloat, AInfo.Member['M13'].ValueAsFloat, AInfo.Member['M14'].ValueAsFloat,
    AInfo.Member['M21'].ValueAsFloat, AInfo.Member['M22'].ValueAsFloat, AInfo.Member['M23'].ValueAsFloat, AInfo.Member['M24'].ValueAsFloat,
    AInfo.Member['M31'].ValueAsFloat, AInfo.Member['M32'].ValueAsFloat, AInfo.Member['M33'].ValueAsFloat, AInfo.Member['M34'].ValueAsFloat,
    AInfo.Member['M41'].ValueAsFloat, AInfo.Member['M42'].ValueAsFloat, AInfo.Member['M43'].ValueAsFloat, AInfo.Member['M44'].ValueAsFloat);
end;

function TdwsFastMath.ParamAsMatrix4(Info: TProgramInfo; const AIndex: Integer): TMatrix4;
begin
  Result := InfoAsMatrix4(Info.Params[AIndex]);
end;

procedure TdwsFastMath.SetInfoMatrix4(const AInfo: IInfo; const AMatrix: TMatrix4);
begin
  AInfo.Member['M11'].Value := AMatrix.m11;
  AInfo.Member['M12'].Value := AMatrix.m12;
  AInfo.Member['M13'].Value := AMatrix.m13;
  AInfo.Member['M14'].Value := AMatrix.m14;
  AInfo.Member['M21'].Value := AMatrix.m21;
  AInfo.Member['M22'].Value := AMatrix.m22;
  AInfo.Member['M23'].Value := AMatrix.m23;
  AInfo.Member['M24'].Value := AMatrix.m24;
  AInfo.Member['M31'].Value := AMatrix.m31;
  AInfo.Member['M32'].Value := AMatrix.m32;
  AInfo.Member['M33'].Value := AMatrix.m33;
  AInfo.Member['M34'].Value := AMatrix.m34;
  AInfo.Member['M41'].Value := AMatrix.m41;
  AInfo.Member['M42'].Value := AMatrix.m42;
  AInfo.Member['M43'].Value := AMatrix.m43;
  AInfo.Member['M44'].Value := AMatrix.m44;
end;

procedure TdwsFastMath.SetResultMatrix4(Info: TProgramInfo; const AMatrix: TMatrix4);
begin
  SetInfoMatrix4(Info.ResultVars, AMatrix);
end;

function TdwsFastMath.InfoAsQuaternion(const AInfo: IInfo): TQuaternion;
begin
  Result := Quaternion(
    AInfo.Member['X'].ValueAsFloat,
    AInfo.Member['Y'].ValueAsFloat,
    AInfo.Member['Z'].ValueAsFloat,
    AInfo.Member['W'].ValueAsFloat);
end;

function TdwsFastMath.ParamAsQuaternion(Info: TProgramInfo; const AIndex: Integer): TQuaternion;
begin
  Result := InfoAsQuaternion(Info.Params[AIndex]);
end;

procedure TdwsFastMath.SetInfoQuaternion(const AInfo: IInfo; const AQuaternion: TQuaternion);
begin
  AInfo.Member['X'].Value := AQuaternion.X;
  AInfo.Member['Y'].Value := AQuaternion.Y;
  AInfo.Member['Z'].Value := AQuaternion.Z;
  AInfo.Member['W'].Value := AQuaternion.W;
end;

procedure TdwsFastMath.SetResultQuaternion(Info: TProgramInfo; const AQuaternion: TQuaternion);
begin
  SetInfoQuaternion(Info.ResultVars, AQuaternion);
end;

function TdwsFastMath.InfoAsIVector2(const AInfo: IInfo): TIVector2;
begin
  Result := IVector2(
    AInfo.Member['X'].ValueAsInteger,
    AInfo.Member['Y'].ValueAsInteger);
end;

function TdwsFastMath.ParamAsIVector2(Info: TProgramInfo; const AIndex: Integer): TIVector2;
begin
  Result := InfoAsIVector2(Info.Params[AIndex]);
end;

procedure TdwsFastMath.SetInfoIVector2(const AInfo: IInfo; const AVector: TIVector2);
begin
  AInfo.Member['X'].Value := AVector.X;
  AInfo.Member['Y'].Value := AVector.Y;
end;

procedure TdwsFastMath.SetResultIVector2(Info: TProgramInfo; const AVector: TIVector2);
begin
  SetInfoIVector2(Info.ResultVars, AVector);
end;

function TdwsFastMath.InfoAsIVector3(const AInfo: IInfo): TIVector3;
begin
  Result := IVector3(
    AInfo.Member['X'].ValueAsInteger,
    AInfo.Member['Y'].ValueAsInteger,
    AInfo.Member['Z'].ValueAsInteger);
end;

function TdwsFastMath.ParamAsIVector3(Info: TProgramInfo; const AIndex: Integer): TIVector3;
begin
  Result := InfoAsIVector3(Info.Params[AIndex]);
end;

procedure TdwsFastMath.SetInfoIVector3(const AInfo: IInfo; const AVector: TIVector3);
begin
  AInfo.Member['X'].Value := AVector.X;
  AInfo.Member['Y'].Value := AVector.Y;
  AInfo.Member['Z'].Value := AVector.Z;
end;

procedure TdwsFastMath.SetResultIVector3(Info: TProgramInfo; const AVector: TIVector3);
begin
  SetInfoIVector3(Info.ResultVars, AVector);
end;

function TdwsFastMath.InfoAsIVector4(const AInfo: IInfo): TIVector4;
begin
  Result := IVector4(
    AInfo.Member['X'].ValueAsInteger,
    AInfo.Member['Y'].ValueAsInteger,
    AInfo.Member['Z'].ValueAsInteger,
    AInfo.Member['W'].ValueAsInteger);
end;

function TdwsFastMath.ParamAsIVector4(Info: TProgramInfo; const AIndex: Integer): TIVector4;
begin
  Result := InfoAsIVector4(Info.Params[AIndex]);
end;

procedure TdwsFastMath.SetInfoIVector4(const AInfo: IInfo; const AVector: TIVector4);
begin
  AInfo.Member['X'].Value := AVector.X;
  AInfo.Member['Y'].Value := AVector.Y;
  AInfo.Member['Z'].Value := AVector.Z;
  AInfo.Member['W'].Value := AVector.W;
end;

procedure TdwsFastMath.SetResultIVector4(Info: TProgramInfo; const AVector: TIVector4);
begin
  SetInfoIVector4(Info.ResultVars, AVector);
end;

procedure TdwsFastMath.DoGlobalVector2Zero(Info: TProgramInfo);
begin
  SetResultVector2(Info, Vector2);
end;

procedure TdwsFastMath.DoGlobalVector2Val(Info: TProgramInfo);
begin
  SetResultVector2(Info, Vector2(Info.ParamAsFloat[0]));
end;

procedure TdwsFastMath.DoGlobalVector2XY(Info: TProgramInfo);
begin
  SetResultVector2(Info, Vector2(Info.ParamAsFloat[0], Info.ParamAsFloat[1]));
end;

procedure TdwsFastMath.DoVector2Add(Info: TProgramInfo);
begin
  SetResultVector2(Info, ParamAsVector2(Info, 0) + ParamAsVector2(Info, 1));
end;

procedure TdwsFastMath.DoVector2AddFloatVector2(Info: TProgramInfo);
begin
  SetResultVector2(Info, Vector2(Info.ParamAsFloat[0]) + ParamAsVector2(Info, 1));
end;

procedure TdwsFastMath.DoVector2AddVector2Float(Info: TProgramInfo);
begin
  SetResultVector2(Info, ParamAsVector2(Info, 0) + Vector2(Info.ParamAsFloat[1]));
end;

procedure TdwsFastMath.DoVector2Subtract(Info: TProgramInfo);
begin
  SetResultVector2(Info, ParamAsVector2(Info, 0) - ParamAsVector2(Info, 1));
end;

procedure TdwsFastMath.DoVector2SubtractFloatVector2(Info: TProgramInfo);
begin
  SetResultVector2(Info, Vector2(Info.ParamAsFloat[0]) - ParamAsVector2(Info, 1));
end;

procedure TdwsFastMath.DoVector2SubtractVector2Float(Info: TProgramInfo);
begin
  SetResultVector2(Info, ParamAsVector2(Info, 0) - Vector2(Info.ParamAsFloat[1]));
end;

procedure TdwsFastMath.DoVector2Multiply(Info: TProgramInfo);
begin
  SetResultVector2(Info, ParamAsVector2(Info, 0) * ParamAsVector2(Info, 1));
end;

procedure TdwsFastMath.DoVector2MultiplyFloatVector2(Info: TProgramInfo);
begin
  SetResultVector2(Info, Info.ParamAsFloat[0] * ParamAsVector2(Info, 1));
end;

procedure TdwsFastMath.DoVector2MultiplyVector2Float(Info: TProgramInfo);
begin
  SetResultVector2(Info, ParamAsVector2(Info, 0) * Info.ParamAsFloat[1]);
end;

procedure TdwsFastMath.DoVector2Divide(Info: TProgramInfo);
begin
  SetResultVector2(Info, ParamAsVector2(Info, 0) / ParamAsVector2(Info, 1));
end;

procedure TdwsFastMath.DoVector2DivideFloatVector2(Info: TProgramInfo);
begin
  SetResultVector2(Info, Info.ParamAsFloat[0] / ParamAsVector2(Info, 1));
end;

procedure TdwsFastMath.DoVector2DivideVector2Float(Info: TProgramInfo);
begin
  SetResultVector2(Info, ParamAsVector2(Info, 0) / Info.ParamAsFloat[1]);
end;

procedure TdwsFastMath.DoVector2Dot(Info: TProgramInfo);
begin
  Info.ResultAsFloat := ParamAsVector2(Info, 0).Dot(ParamAsVector2(Info, 1));
end;

procedure TdwsFastMath.DoVector2Cross(Info: TProgramInfo);
begin
  Info.ResultAsFloat := ParamAsVector2(Info, 0).Cross(ParamAsVector2(Info, 1));
end;

procedure TdwsFastMath.DoVector2Normalize(Info: TProgramInfo);
begin
  SetResultVector2(Info, ParamAsVector2(Info, 0).Normalize);
end;

procedure TdwsFastMath.DoVector2NormalizeFast(Info: TProgramInfo);
begin
  SetResultVector2(Info, ParamAsVector2(Info, 0).NormalizeFast);
end;

procedure TdwsFastMath.DoVector2Length(Info: TProgramInfo);
begin
  Info.ResultAsFloat := ParamAsVector2(Info, 0).Length;
end;

procedure TdwsFastMath.DoVector2LengthSquared(Info: TProgramInfo);
begin
  Info.ResultAsFloat := ParamAsVector2(Info, 0).LengthSquared;
end;

procedure TdwsFastMath.DoVector2Distance(Info: TProgramInfo);
begin
  Info.ResultAsFloat := ParamAsVector2(Info, 0).Distance(ParamAsVector2(Info, 1));
end;

procedure TdwsFastMath.DoVector2DistanceSquared(Info: TProgramInfo);
begin
  Info.ResultAsFloat := ParamAsVector2(Info, 0).DistanceSquared(ParamAsVector2(Info, 1));
end;

procedure TdwsFastMath.DoVector2Lerp(Info: TProgramInfo);
begin
  SetResultVector2(Info, ParamAsVector2(Info, 0).Lerp(ParamAsVector2(Info, 1), Info.ParamAsFloat[2]));
end;

procedure TdwsFastMath.DoVector2Equals(Info: TProgramInfo);
var
  Tolerance: Single;
begin
  Tolerance := 0.000001;
  if Info.ParamCount > 2 then
    Tolerance := Info.ParamAsFloat[2];

  Info.ResultAsBoolean := ParamAsVector2(Info, 0).Equals(ParamAsVector2(Info, 1), Tolerance);
end;

procedure TdwsFastMath.DoVector2ToString(Info: TProgramInfo);
var
  V: TVector2;
begin
  V := ParamAsVector2(Info, 0);
  Info.ResultAsString := Format('(%g, %g)', [V.X, V.Y]);
end;

procedure TdwsFastMath.DoGlobalVector3Zero(Info: TProgramInfo);
begin
  SetResultVector3(Info, Vector3);
end;

procedure TdwsFastMath.DoGlobalVector3Val(Info: TProgramInfo);
begin
  SetResultVector3(Info, Vector3(Info.ParamAsFloat[0]));
end;

procedure TdwsFastMath.DoGlobalVector3XYZ(Info: TProgramInfo);
begin
  SetResultVector3(Info, Vector3(Info.ParamAsFloat[0], Info.ParamAsFloat[1], Info.ParamAsFloat[2]));
end;

procedure TdwsFastMath.DoGlobalVector3Vector2Float(Info: TProgramInfo);
begin
  SetResultVector3(Info, Vector3(ParamAsVector2(Info, 0), Info.ParamAsFloat[1]));
end;

procedure TdwsFastMath.DoGlobalVector3FloatVector2(Info: TProgramInfo);
begin
  SetResultVector3(Info, Vector3(Info.ParamAsFloat[0], ParamAsVector2(Info, 1)));
end;

procedure TdwsFastMath.DoVector3Add(Info: TProgramInfo);
begin
  SetResultVector3(Info, ParamAsVector3(Info, 0) + ParamAsVector3(Info, 1));
end;

procedure TdwsFastMath.DoVector3AddFloatVector3(Info: TProgramInfo);
begin
  SetResultVector3(Info, Vector3(Info.ParamAsFloat[0]) + ParamAsVector3(Info, 1));
end;

procedure TdwsFastMath.DoVector3AddVector3Float(Info: TProgramInfo);
begin
  SetResultVector3(Info, ParamAsVector3(Info, 0) + Vector3(Info.ParamAsFloat[1]));
end;

procedure TdwsFastMath.DoVector3Subtract(Info: TProgramInfo);
begin
  SetResultVector3(Info, ParamAsVector3(Info, 0) - ParamAsVector3(Info, 1));
end;

procedure TdwsFastMath.DoVector3SubtractFloatVector3(Info: TProgramInfo);
begin
  SetResultVector3(Info, Vector3(Info.ParamAsFloat[0]) - ParamAsVector3(Info, 1));
end;

procedure TdwsFastMath.DoVector3SubtractVector3Float(Info: TProgramInfo);
begin
  SetResultVector3(Info, ParamAsVector3(Info, 0) - Vector3(Info.ParamAsFloat[1]));
end;

procedure TdwsFastMath.DoVector3Multiply(Info: TProgramInfo);
begin
  SetResultVector3(Info, ParamAsVector3(Info, 0) * ParamAsVector3(Info, 1));
end;

procedure TdwsFastMath.DoVector3MultiplyFloatVector3(Info: TProgramInfo);
begin
  SetResultVector3(Info, Info.ParamAsFloat[0] * ParamAsVector3(Info, 1));
end;

procedure TdwsFastMath.DoVector3MultiplyVector3Float(Info: TProgramInfo);
begin
  SetResultVector3(Info, ParamAsVector3(Info, 0) * Info.ParamAsFloat[1]);
end;

procedure TdwsFastMath.DoVector3Divide(Info: TProgramInfo);
begin
  SetResultVector3(Info, ParamAsVector3(Info, 0) / ParamAsVector3(Info, 1));
end;

procedure TdwsFastMath.DoVector3DivideFloatVector3(Info: TProgramInfo);
begin
  SetResultVector3(Info, Info.ParamAsFloat[0] / ParamAsVector3(Info, 1));
end;

procedure TdwsFastMath.DoVector3DivideVector3Float(Info: TProgramInfo);
begin
  SetResultVector3(Info, ParamAsVector3(Info, 0) / Info.ParamAsFloat[1]);
end;

procedure TdwsFastMath.DoVector3Dot(Info: TProgramInfo);
begin
  Info.ResultAsFloat := ParamAsVector3(Info, 0).Dot(ParamAsVector3(Info, 1));
end;

procedure TdwsFastMath.DoVector3Cross(Info: TProgramInfo);
begin
  SetResultVector3(Info, ParamAsVector3(Info, 0).Cross(ParamAsVector3(Info, 1)));
end;

procedure TdwsFastMath.DoVector3Normalize(Info: TProgramInfo);
begin
  SetResultVector3(Info, ParamAsVector3(Info, 0).Normalize);
end;

procedure TdwsFastMath.DoVector3NormalizeFast(Info: TProgramInfo);
begin
  SetResultVector3(Info, ParamAsVector3(Info, 0).NormalizeFast);
end;

procedure TdwsFastMath.DoVector3Length(Info: TProgramInfo);
begin
  Info.ResultAsFloat := ParamAsVector3(Info, 0).Length;
end;

procedure TdwsFastMath.DoVector3LengthSquared(Info: TProgramInfo);
begin
  Info.ResultAsFloat := ParamAsVector3(Info, 0).LengthSquared;
end;

procedure TdwsFastMath.DoVector3Distance(Info: TProgramInfo);
begin
  Info.ResultAsFloat := ParamAsVector3(Info, 0).Distance(ParamAsVector3(Info, 1));
end;

procedure TdwsFastMath.DoVector3DistanceSquared(Info: TProgramInfo);
begin
  Info.ResultAsFloat := ParamAsVector3(Info, 0).DistanceSquared(ParamAsVector3(Info, 1));
end;

procedure TdwsFastMath.DoVector3Lerp(Info: TProgramInfo);
begin
  SetResultVector3(Info, ParamAsVector3(Info, 0).Lerp(ParamAsVector3(Info, 1), Info.ParamAsFloat[2]));
end;

procedure TdwsFastMath.DoVector3Equals(Info: TProgramInfo);
var
  Tolerance: Single;
begin
  Tolerance := 0.000001;
  if Info.ParamCount > 2 then
    Tolerance := Info.ParamAsFloat[2];

  Info.ResultAsBoolean := ParamAsVector3(Info, 0).Equals(ParamAsVector3(Info, 1), Tolerance);
end;

procedure TdwsFastMath.DoVector3ToString(Info: TProgramInfo);
var
  V: TVector3;
begin
  V := ParamAsVector3(Info, 0);
  Info.ResultAsString := Format('(%g, %g, %g)', [V.X, V.Y, V.Z]);
end;

procedure TdwsFastMath.DoGlobalVector4Zero(Info: TProgramInfo);
begin
  SetResultVector4(Info, Vector4);
end;

procedure TdwsFastMath.DoGlobalVector4Val(Info: TProgramInfo);
begin
  SetResultVector4(Info, Vector4(Info.ParamAsFloat[0]));
end;

procedure TdwsFastMath.DoGlobalVector4XYZW(Info: TProgramInfo);
begin
  SetResultVector4(Info, Vector4(Info.ParamAsFloat[0], Info.ParamAsFloat[1],
    Info.ParamAsFloat[2], Info.ParamAsFloat[3]));
end;

procedure TdwsFastMath.DoGlobalVector4Vector3Float(Info: TProgramInfo);
begin
  SetResultVector4(Info, Vector4(ParamAsVector3(Info, 0), Info.ParamAsFloat[1]));
end;

procedure TdwsFastMath.DoGlobalVector4FloatVector3(Info: TProgramInfo);
begin
  SetResultVector4(Info, Vector4(Info.ParamAsFloat[0], ParamAsVector3(Info, 1)));
end;

procedure TdwsFastMath.DoVector4Add(Info: TProgramInfo);
begin
  SetResultVector4(Info, ParamAsVector4(Info, 0) + ParamAsVector4(Info, 1));
end;

procedure TdwsFastMath.DoVector4AddFloatVector4(Info: TProgramInfo);
begin
  SetResultVector4(Info, Vector4(Info.ParamAsFloat[0]) + ParamAsVector4(Info, 1));
end;

procedure TdwsFastMath.DoVector4AddVector4Float(Info: TProgramInfo);
begin
  SetResultVector4(Info, ParamAsVector4(Info, 0) + Vector4(Info.ParamAsFloat[1]));
end;

procedure TdwsFastMath.DoVector4Subtract(Info: TProgramInfo);
begin
  SetResultVector4(Info, ParamAsVector4(Info, 0) - ParamAsVector4(Info, 1));
end;

procedure TdwsFastMath.DoVector4SubtractFloatVector4(Info: TProgramInfo);
begin
  SetResultVector4(Info, Vector4(Info.ParamAsFloat[0]) - ParamAsVector4(Info, 1));
end;

procedure TdwsFastMath.DoVector4SubtractVector4Float(Info: TProgramInfo);
begin
  SetResultVector4(Info, ParamAsVector4(Info, 0) - Vector4(Info.ParamAsFloat[1]));
end;

procedure TdwsFastMath.DoVector4Multiply(Info: TProgramInfo);
begin
  SetResultVector4(Info, ParamAsVector4(Info, 0) * ParamAsVector4(Info, 1));
end;

procedure TdwsFastMath.DoVector4MultiplyFloatVector4(Info: TProgramInfo);
begin
  SetResultVector4(Info, Info.ParamAsFloat[0] * ParamAsVector4(Info, 1));
end;

procedure TdwsFastMath.DoVector4MultiplyVector4Float(Info: TProgramInfo);
begin
  SetResultVector4(Info, ParamAsVector4(Info, 0) * Info.ParamAsFloat[1]);
end;

procedure TdwsFastMath.DoVector4Divide(Info: TProgramInfo);
begin
  SetResultVector4(Info, ParamAsVector4(Info, 0) / ParamAsVector4(Info, 1));
end;

procedure TdwsFastMath.DoVector4DivideFloatVector4(Info: TProgramInfo);
begin
  SetResultVector4(Info, Info.ParamAsFloat[0] / ParamAsVector4(Info, 1));
end;

procedure TdwsFastMath.DoVector4DivideVector4Float(Info: TProgramInfo);
begin
  SetResultVector4(Info, ParamAsVector4(Info, 0) / Info.ParamAsFloat[1]);
end;

procedure TdwsFastMath.DoVector4Dot(Info: TProgramInfo);
begin
  Info.ResultAsFloat := ParamAsVector4(Info, 0).Dot(ParamAsVector4(Info, 1));
end;

procedure TdwsFastMath.DoVector4Normalize(Info: TProgramInfo);
begin
  SetResultVector4(Info, ParamAsVector4(Info, 0).Normalize);
end;

procedure TdwsFastMath.DoVector4NormalizeFast(Info: TProgramInfo);
begin
  SetResultVector4(Info, ParamAsVector4(Info, 0).NormalizeFast);
end;

procedure TdwsFastMath.DoVector4Length(Info: TProgramInfo);
begin
  Info.ResultAsFloat := ParamAsVector4(Info, 0).Length;
end;

procedure TdwsFastMath.DoVector4LengthSquared(Info: TProgramInfo);
begin
  Info.ResultAsFloat := ParamAsVector4(Info, 0).LengthSquared;
end;

procedure TdwsFastMath.DoVector4Distance(Info: TProgramInfo);
begin
  Info.ResultAsFloat := ParamAsVector4(Info, 0).Distance(ParamAsVector4(Info, 1));
end;

procedure TdwsFastMath.DoVector4DistanceSquared(Info: TProgramInfo);
begin
  Info.ResultAsFloat := ParamAsVector4(Info, 0).DistanceSquared(ParamAsVector4(Info, 1));
end;

procedure TdwsFastMath.DoVector4Lerp(Info: TProgramInfo);
begin
  SetResultVector4(Info, ParamAsVector4(Info, 0).Lerp(ParamAsVector4(Info, 1), Info.ParamAsFloat[2]));
end;

procedure TdwsFastMath.DoVector4Equals(Info: TProgramInfo);
var
  Tolerance: Single;
begin
  Tolerance := 0.000001;
  if Info.ParamCount > 2 then
    Tolerance := Info.ParamAsFloat[2];

  Info.ResultAsBoolean := ParamAsVector4(Info, 0).Equals(ParamAsVector4(Info, 1), Tolerance);
end;

procedure TdwsFastMath.DoVector4ToString(Info: TProgramInfo);
var
  V: TVector4;
begin
  V := ParamAsVector4(Info, 0);
  Info.ResultAsString := Format('(%g, %g, %g, %g)', [V.X, V.Y, V.Z, V.W]);
end;

procedure TdwsFastMath.DoGlobalMatrix2Identity(Info: TProgramInfo);
begin
  SetResultMatrix2(Info, Matrix2);
end;

procedure TdwsFastMath.DoGlobalMatrix2Diagonal(Info: TProgramInfo);
begin
  SetResultMatrix2(Info, Matrix2(Info.ParamAsFloat[0]));
end;

procedure TdwsFastMath.DoGlobalMatrix2Rows(Info: TProgramInfo);
begin
  SetResultMatrix2(Info, Matrix2(ParamAsVector2(Info, 0), ParamAsVector2(Info, 1)));
end;

procedure TdwsFastMath.DoGlobalMatrix2Values(Info: TProgramInfo);
begin
  SetResultMatrix2(Info, Matrix2(Info.ParamAsFloat[0], Info.ParamAsFloat[1],
    Info.ParamAsFloat[2], Info.ParamAsFloat[3]));
end;

procedure TdwsFastMath.DoMatrix2Add(Info: TProgramInfo);
begin
  SetResultMatrix2(Info, ParamAsMatrix2(Info, 0) + ParamAsMatrix2(Info, 1));
end;

procedure TdwsFastMath.DoMatrix2Subtract(Info: TProgramInfo);
begin
  SetResultMatrix2(Info, ParamAsMatrix2(Info, 0) - ParamAsMatrix2(Info, 1));
end;

procedure TdwsFastMath.DoMatrix2Multiply(Info: TProgramInfo);
begin
  SetResultMatrix2(Info, ParamAsMatrix2(Info, 0) * ParamAsMatrix2(Info, 1));
end;

procedure TdwsFastMath.DoMatrix2Divide(Info: TProgramInfo);
begin
  SetResultMatrix2(Info, ParamAsMatrix2(Info, 0) / ParamAsMatrix2(Info, 1));
end;

procedure TdwsFastMath.DoMatrix2MultiplyMatrixFloat(Info: TProgramInfo);
begin
  SetResultMatrix2(Info, ParamAsMatrix2(Info, 0) * Info.ParamAsFloat[1]);
end;

procedure TdwsFastMath.DoMatrix2MultiplyFloatMatrix(Info: TProgramInfo);
begin
  SetResultMatrix2(Info, Info.ParamAsFloat[0] * ParamAsMatrix2(Info, 1));
end;

procedure TdwsFastMath.DoMatrix2DivideMatrixFloat(Info: TProgramInfo);
begin
  SetResultMatrix2(Info, ParamAsMatrix2(Info, 0) / Info.ParamAsFloat[1]);
end;

procedure TdwsFastMath.DoMatrix2MultiplyMatrixVector(Info: TProgramInfo);
begin
  SetResultVector2(Info, ParamAsMatrix2(Info, 0) * ParamAsVector2(Info, 1));
end;

procedure TdwsFastMath.DoMatrix2MultiplyVectorMatrix(Info: TProgramInfo);
begin
  SetResultVector2(Info, ParamAsVector2(Info, 0) * ParamAsMatrix2(Info, 1));
end;

procedure TdwsFastMath.DoMatrix2Transpose(Info: TProgramInfo);
begin
  SetResultMatrix2(Info, ParamAsMatrix2(Info, 0).Transpose);
end;

procedure TdwsFastMath.DoMatrix2Inverse(Info: TProgramInfo);
begin
  SetResultMatrix2(Info, ParamAsMatrix2(Info, 0).Inverse);
end;

procedure TdwsFastMath.DoMatrix2Determinant(Info: TProgramInfo);
begin
  Info.ResultAsFloat := ParamAsMatrix2(Info, 0).Determinant;
end;

procedure TdwsFastMath.DoMatrix2CompMult(Info: TProgramInfo);
begin
  SetResultMatrix2(Info, ParamAsMatrix2(Info, 0).CompMult(ParamAsMatrix2(Info, 1)));
end;

procedure TdwsFastMath.DoMatrix2Equals(Info: TProgramInfo);
begin
  Info.ResultAsBoolean := ParamAsMatrix2(Info, 0) = ParamAsMatrix2(Info, 1);
end;

procedure TdwsFastMath.DoMatrix2ToString(Info: TProgramInfo);
var
  M: TMatrix2;
begin
  M := ParamAsMatrix2(Info, 0);
  Info.ResultAsString := Format('[(%g, %g), (%g, %g)]', [M.m11, M.m12, M.m21, M.m22]);
end;

procedure TdwsFastMath.DoGlobalMatrix3Identity(Info: TProgramInfo);
begin
  SetResultMatrix3(Info, Matrix3);
end;

procedure TdwsFastMath.DoGlobalMatrix3Diagonal(Info: TProgramInfo);
begin
  SetResultMatrix3(Info, Matrix3(Info.ParamAsFloat[0]));
end;

procedure TdwsFastMath.DoGlobalMatrix3Rows(Info: TProgramInfo);
begin
  SetResultMatrix3(Info, Matrix3(ParamAsVector3(Info, 0), ParamAsVector3(Info, 1),
    ParamAsVector3(Info, 2)));
end;

procedure TdwsFastMath.DoGlobalMatrix3Values(Info: TProgramInfo);
begin
  SetResultMatrix3(Info, Matrix3(
    Info.ParamAsFloat[0], Info.ParamAsFloat[1], Info.ParamAsFloat[2],
    Info.ParamAsFloat[3], Info.ParamAsFloat[4], Info.ParamAsFloat[5],
    Info.ParamAsFloat[6], Info.ParamAsFloat[7], Info.ParamAsFloat[8]));
end;

procedure TdwsFastMath.DoMatrix3ScalingXY(Info: TProgramInfo);
var
  M: TMatrix3;
begin
  M.InitScaling(Info.ParamAsFloat[0], Info.ParamAsFloat[1]);
  SetResultMatrix3(Info, M);
end;

procedure TdwsFastMath.DoMatrix3ScalingVector(Info: TProgramInfo);
var
  M: TMatrix3;
begin
  M.InitScaling(ParamAsVector2(Info, 0));
  SetResultMatrix3(Info, M);
end;

procedure TdwsFastMath.DoMatrix3TranslationXY(Info: TProgramInfo);
var
  M: TMatrix3;
begin
  M.InitTranslation(Info.ParamAsFloat[0], Info.ParamAsFloat[1]);
  SetResultMatrix3(Info, M);
end;

procedure TdwsFastMath.DoMatrix3TranslationVector(Info: TProgramInfo);
var
  M: TMatrix3;
begin
  M.InitTranslation(ParamAsVector2(Info, 0));
  SetResultMatrix3(Info, M);
end;

procedure TdwsFastMath.DoMatrix3Rotation(Info: TProgramInfo);
var
  M: TMatrix3;
begin
  M.InitRotation(Info.ParamAsFloat[0]);
  SetResultMatrix3(Info, M);
end;

procedure TdwsFastMath.DoMatrix3Add(Info: TProgramInfo);
begin
  SetResultMatrix3(Info, ParamAsMatrix3(Info, 0) + ParamAsMatrix3(Info, 1));
end;

procedure TdwsFastMath.DoMatrix3Subtract(Info: TProgramInfo);
begin
  SetResultMatrix3(Info, ParamAsMatrix3(Info, 0) - ParamAsMatrix3(Info, 1));
end;

procedure TdwsFastMath.DoMatrix3Multiply(Info: TProgramInfo);
begin
  SetResultMatrix3(Info, ParamAsMatrix3(Info, 0) * ParamAsMatrix3(Info, 1));
end;

procedure TdwsFastMath.DoMatrix3Divide(Info: TProgramInfo);
begin
  SetResultMatrix3(Info, ParamAsMatrix3(Info, 0) / ParamAsMatrix3(Info, 1));
end;

procedure TdwsFastMath.DoMatrix3MultiplyMatrixFloat(Info: TProgramInfo);
begin
  SetResultMatrix3(Info, ParamAsMatrix3(Info, 0) * Info.ParamAsFloat[1]);
end;

procedure TdwsFastMath.DoMatrix3MultiplyFloatMatrix(Info: TProgramInfo);
begin
  SetResultMatrix3(Info, Info.ParamAsFloat[0] * ParamAsMatrix3(Info, 1));
end;

procedure TdwsFastMath.DoMatrix3DivideMatrixFloat(Info: TProgramInfo);
begin
  SetResultMatrix3(Info, ParamAsMatrix3(Info, 0) / Info.ParamAsFloat[1]);
end;

procedure TdwsFastMath.DoMatrix3MultiplyMatrixVector(Info: TProgramInfo);
begin
  SetResultVector3(Info, ParamAsMatrix3(Info, 0) * ParamAsVector3(Info, 1));
end;

procedure TdwsFastMath.DoMatrix3MultiplyVectorMatrix(Info: TProgramInfo);
begin
  SetResultVector3(Info, ParamAsVector3(Info, 0) * ParamAsMatrix3(Info, 1));
end;

procedure TdwsFastMath.DoMatrix3Transpose(Info: TProgramInfo);
begin
  SetResultMatrix3(Info, ParamAsMatrix3(Info, 0).Transpose);
end;

procedure TdwsFastMath.DoMatrix3Inverse(Info: TProgramInfo);
begin
  SetResultMatrix3(Info, ParamAsMatrix3(Info, 0).Inverse);
end;

procedure TdwsFastMath.DoMatrix3Determinant(Info: TProgramInfo);
begin
  Info.ResultAsFloat := ParamAsMatrix3(Info, 0).Determinant;
end;

procedure TdwsFastMath.DoMatrix3CompMult(Info: TProgramInfo);
begin
  SetResultMatrix3(Info, ParamAsMatrix3(Info, 0).CompMult(ParamAsMatrix3(Info, 1)));
end;

procedure TdwsFastMath.DoMatrix3Equals(Info: TProgramInfo);
begin
  Info.ResultAsBoolean := ParamAsMatrix3(Info, 0) = ParamAsMatrix3(Info, 1);
end;

procedure TdwsFastMath.DoMatrix3ToString(Info: TProgramInfo);
var
  M: TMatrix3;
begin
  M := ParamAsMatrix3(Info, 0);
  Info.ResultAsString := Format('[(%g, %g, %g), (%g, %g, %g), (%g, %g, %g)]',
    [M.m11, M.m12, M.m13, M.m21, M.m22, M.m23, M.m31, M.m32, M.m33]);
end;

procedure TdwsFastMath.DoGlobalMatrix4Identity(Info: TProgramInfo);
begin
  SetResultMatrix4(Info, Matrix4);
end;

procedure TdwsFastMath.DoGlobalMatrix4Diagonal(Info: TProgramInfo);
begin
  SetResultMatrix4(Info, Matrix4(Info.ParamAsFloat[0]));
end;

procedure TdwsFastMath.DoGlobalMatrix4Rows(Info: TProgramInfo);
begin
  SetResultMatrix4(Info, Matrix4(ParamAsVector4(Info, 0), ParamAsVector4(Info, 1),
    ParamAsVector4(Info, 2), ParamAsVector4(Info, 3)));
end;

procedure TdwsFastMath.DoGlobalMatrix4Values(Info: TProgramInfo);
begin
  SetResultMatrix4(Info, Matrix4(
    Info.ParamAsFloat[0], Info.ParamAsFloat[1], Info.ParamAsFloat[2], Info.ParamAsFloat[3],
    Info.ParamAsFloat[4], Info.ParamAsFloat[5], Info.ParamAsFloat[6], Info.ParamAsFloat[7],
    Info.ParamAsFloat[8], Info.ParamAsFloat[9], Info.ParamAsFloat[10], Info.ParamAsFloat[11],
    Info.ParamAsFloat[12], Info.ParamAsFloat[13], Info.ParamAsFloat[14], Info.ParamAsFloat[15]));
end;

procedure TdwsFastMath.DoMatrix4ScalingXYZ(Info: TProgramInfo);
var
  M: TMatrix4;
begin
  M.InitScaling(Info.ParamAsFloat[0], Info.ParamAsFloat[1], Info.ParamAsFloat[2]);
  SetResultMatrix4(Info, M);
end;

procedure TdwsFastMath.DoMatrix4ScalingVector(Info: TProgramInfo);
var
  M: TMatrix4;
begin
  M.InitScaling(ParamAsVector3(Info, 0));
  SetResultMatrix4(Info, M);
end;

procedure TdwsFastMath.DoMatrix4TranslationXYZ(Info: TProgramInfo);
var
  M: TMatrix4;
begin
  M.InitTranslation(Info.ParamAsFloat[0], Info.ParamAsFloat[1], Info.ParamAsFloat[2]);
  SetResultMatrix4(Info, M);
end;

procedure TdwsFastMath.DoMatrix4TranslationVector(Info: TProgramInfo);
var
  M: TMatrix4;
begin
  M.InitTranslation(ParamAsVector3(Info, 0));
  SetResultMatrix4(Info, M);
end;

procedure TdwsFastMath.DoMatrix4RotationX(Info: TProgramInfo);
var
  M: TMatrix4;
begin
  M.InitRotationX(Info.ParamAsFloat[0]);
  SetResultMatrix4(Info, M);
end;

procedure TdwsFastMath.DoMatrix4RotationY(Info: TProgramInfo);
var
  M: TMatrix4;
begin
  M.InitRotationY(Info.ParamAsFloat[0]);
  SetResultMatrix4(Info, M);
end;

procedure TdwsFastMath.DoMatrix4RotationZ(Info: TProgramInfo);
var
  M: TMatrix4;
begin
  M.InitRotationZ(Info.ParamAsFloat[0]);
  SetResultMatrix4(Info, M);
end;

procedure TdwsFastMath.DoMatrix4RotationAxis(Info: TProgramInfo);
var
  M: TMatrix4;
begin
  M.InitRotation(ParamAsVector3(Info, 0), Info.ParamAsFloat[1]);
  SetResultMatrix4(Info, M);
end;

procedure TdwsFastMath.DoMatrix4RotationYawPitchRoll(Info: TProgramInfo);
var
  M: TMatrix4;
begin
  M.InitRotationYawPitchRoll(Info.ParamAsFloat[0], Info.ParamAsFloat[1], Info.ParamAsFloat[2]);
  SetResultMatrix4(Info, M);
end;

procedure TdwsFastMath.DoMatrix4LookAtLH(Info: TProgramInfo);
var
  M: TMatrix4;
begin
  M.InitLookAtLH(ParamAsVector3(Info, 0), ParamAsVector3(Info, 1), ParamAsVector3(Info, 2));
  SetResultMatrix4(Info, M);
end;

procedure TdwsFastMath.DoMatrix4LookAtRH(Info: TProgramInfo);
var
  M: TMatrix4;
begin
  M.InitLookAtRH(ParamAsVector3(Info, 0), ParamAsVector3(Info, 1), ParamAsVector3(Info, 2));
  SetResultMatrix4(Info, M);
end;

procedure TdwsFastMath.DoMatrix4PerspectiveFovLH(Info: TProgramInfo);
var
  M: TMatrix4;
begin
  if Info.ParamCount > 4 then
    M.InitPerspectiveFovLH(Info.ParamAsFloat[0], Info.ParamAsFloat[1],
      Info.ParamAsFloat[2], Info.ParamAsFloat[3], Info.ParamAsBoolean[4])
  else
    M.InitPerspectiveFovLH(Info.ParamAsFloat[0], Info.ParamAsFloat[1],
      Info.ParamAsFloat[2], Info.ParamAsFloat[3]);
  SetResultMatrix4(Info, M);
end;

procedure TdwsFastMath.DoMatrix4PerspectiveFovRH(Info: TProgramInfo);
var
  M: TMatrix4;
begin
  if Info.ParamCount > 4 then
    M.InitPerspectiveFovRH(Info.ParamAsFloat[0], Info.ParamAsFloat[1],
      Info.ParamAsFloat[2], Info.ParamAsFloat[3], Info.ParamAsBoolean[4])
  else
    M.InitPerspectiveFovRH(Info.ParamAsFloat[0], Info.ParamAsFloat[1],
      Info.ParamAsFloat[2], Info.ParamAsFloat[3]);
  SetResultMatrix4(Info, M);
end;

procedure TdwsFastMath.DoMatrix4Add(Info: TProgramInfo);
begin
  SetResultMatrix4(Info, ParamAsMatrix4(Info, 0) + ParamAsMatrix4(Info, 1));
end;

procedure TdwsFastMath.DoMatrix4Subtract(Info: TProgramInfo);
begin
  SetResultMatrix4(Info, ParamAsMatrix4(Info, 0) - ParamAsMatrix4(Info, 1));
end;

procedure TdwsFastMath.DoMatrix4Multiply(Info: TProgramInfo);
begin
  SetResultMatrix4(Info, ParamAsMatrix4(Info, 0) * ParamAsMatrix4(Info, 1));
end;

procedure TdwsFastMath.DoMatrix4Divide(Info: TProgramInfo);
begin
  SetResultMatrix4(Info, ParamAsMatrix4(Info, 0) / ParamAsMatrix4(Info, 1));
end;

procedure TdwsFastMath.DoMatrix4MultiplyMatrixFloat(Info: TProgramInfo);
begin
  SetResultMatrix4(Info, ParamAsMatrix4(Info, 0) * Info.ParamAsFloat[1]);
end;

procedure TdwsFastMath.DoMatrix4MultiplyFloatMatrix(Info: TProgramInfo);
begin
  SetResultMatrix4(Info, Info.ParamAsFloat[0] * ParamAsMatrix4(Info, 1));
end;

procedure TdwsFastMath.DoMatrix4DivideMatrixFloat(Info: TProgramInfo);
begin
  SetResultMatrix4(Info, ParamAsMatrix4(Info, 0) / Info.ParamAsFloat[1]);
end;

procedure TdwsFastMath.DoMatrix4MultiplyMatrixVector(Info: TProgramInfo);
begin
  SetResultVector4(Info, ParamAsMatrix4(Info, 0) * ParamAsVector4(Info, 1));
end;

procedure TdwsFastMath.DoMatrix4MultiplyVectorMatrix(Info: TProgramInfo);
begin
  SetResultVector4(Info, ParamAsVector4(Info, 0) * ParamAsMatrix4(Info, 1));
end;

procedure TdwsFastMath.DoMatrix4Transpose(Info: TProgramInfo);
begin
  SetResultMatrix4(Info, ParamAsMatrix4(Info, 0).Transpose);
end;

procedure TdwsFastMath.DoMatrix4Inverse(Info: TProgramInfo);
begin
  SetResultMatrix4(Info, ParamAsMatrix4(Info, 0).Inverse);
end;

procedure TdwsFastMath.DoMatrix4Determinant(Info: TProgramInfo);
begin
  Info.ResultAsFloat := ParamAsMatrix4(Info, 0).Determinant;
end;

procedure TdwsFastMath.DoMatrix4CompMult(Info: TProgramInfo);
begin
  SetResultMatrix4(Info, ParamAsMatrix4(Info, 0).CompMult(ParamAsMatrix4(Info, 1)));
end;

procedure TdwsFastMath.DoMatrix4Equals(Info: TProgramInfo);
begin
  Info.ResultAsBoolean := ParamAsMatrix4(Info, 0) = ParamAsMatrix4(Info, 1);
end;

procedure TdwsFastMath.DoMatrix4ToString(Info: TProgramInfo);
var
  M: TMatrix4;
begin
  M := ParamAsMatrix4(Info, 0);
  Info.ResultAsString := Format(
    '[(%g, %g, %g, %g), (%g, %g, %g, %g), (%g, %g, %g, %g), (%g, %g, %g, %g)]',
    [M.m11, M.m12, M.m13, M.m14, M.m21, M.m22, M.m23, M.m24,
     M.m31, M.m32, M.m33, M.m34, M.m41, M.m42, M.m43, M.m44]);
end;

procedure TdwsFastMath.DoGlobalQuaternionIdentity(Info: TProgramInfo);
begin
  SetResultQuaternion(Info, Quaternion);
end;

procedure TdwsFastMath.DoGlobalQuaternionXYZW(Info: TProgramInfo);
begin
  SetResultQuaternion(Info, Quaternion(Info.ParamAsFloat[0], Info.ParamAsFloat[1],
    Info.ParamAsFloat[2], Info.ParamAsFloat[3]));
end;

procedure TdwsFastMath.DoGlobalQuaternionAxisAngle(Info: TProgramInfo);
begin
  SetResultQuaternion(Info, Quaternion(ParamAsVector3(Info, 0), Info.ParamAsFloat[1]));
end;

procedure TdwsFastMath.DoQuaternionYawPitchRoll(Info: TProgramInfo);
var
  Q: TQuaternion;
begin
  Q.Init(Info.ParamAsFloat[0], Info.ParamAsFloat[1], Info.ParamAsFloat[2]);
  SetResultQuaternion(Info, Q);
end;

procedure TdwsFastMath.DoQuaternionFromMatrix4(Info: TProgramInfo);
var
  Q: TQuaternion;
begin
  Q.Init(ParamAsMatrix4(Info, 0));
  SetResultQuaternion(Info, Q);
end;

procedure TdwsFastMath.DoQuaternionAdd(Info: TProgramInfo);
begin
  SetResultQuaternion(Info, ParamAsQuaternion(Info, 0) + ParamAsQuaternion(Info, 1));
end;

procedure TdwsFastMath.DoQuaternionMultiply(Info: TProgramInfo);
begin
  SetResultQuaternion(Info, ParamAsQuaternion(Info, 0) * ParamAsQuaternion(Info, 1));
end;

procedure TdwsFastMath.DoQuaternionMultiplyQuaternionFloat(Info: TProgramInfo);
begin
  SetResultQuaternion(Info, ParamAsQuaternion(Info, 0) * Info.ParamAsFloat[1]);
end;

procedure TdwsFastMath.DoQuaternionMultiplyFloatQuaternion(Info: TProgramInfo);
begin
  SetResultQuaternion(Info, Info.ParamAsFloat[0] * ParamAsQuaternion(Info, 1));
end;

procedure TdwsFastMath.DoQuaternionNormalize(Info: TProgramInfo);
begin
  SetResultQuaternion(Info, ParamAsQuaternion(Info, 0).Normalize);
end;

procedure TdwsFastMath.DoQuaternionNormalizeFast(Info: TProgramInfo);
begin
  SetResultQuaternion(Info, ParamAsQuaternion(Info, 0).NormalizeFast);
end;

procedure TdwsFastMath.DoQuaternionConjugate(Info: TProgramInfo);
begin
  SetResultQuaternion(Info, ParamAsQuaternion(Info, 0).Conjugate);
end;

procedure TdwsFastMath.DoQuaternionToMatrix4(Info: TProgramInfo);
begin
  SetResultMatrix4(Info, ParamAsQuaternion(Info, 0).ToMatrix);
end;

procedure TdwsFastMath.DoQuaternionLength(Info: TProgramInfo);
begin
  Info.ResultAsFloat := ParamAsQuaternion(Info, 0).Length;
end;

procedure TdwsFastMath.DoQuaternionLengthSquared(Info: TProgramInfo);
begin
  Info.ResultAsFloat := ParamAsQuaternion(Info, 0).LengthSquared;
end;

procedure TdwsFastMath.DoQuaternionIsIdentity(Info: TProgramInfo);
begin
  if Info.ParamCount > 1 then
    Info.ResultAsBoolean := ParamAsQuaternion(Info, 0).IsIdentity(Info.ParamAsFloat[1])
  else
    Info.ResultAsBoolean := ParamAsQuaternion(Info, 0).IsIdentity;
end;

procedure TdwsFastMath.DoQuaternionToString(Info: TProgramInfo);
var
  Q: TQuaternion;
begin
  Q := ParamAsQuaternion(Info, 0);
  Info.ResultAsString := Format('(%g, %g, %g, %g)', [Q.X, Q.Y, Q.Z, Q.W]);
end;

procedure TdwsFastMath.DoGlobalIVector2(Info: TProgramInfo);
begin
  case Info.ParamCount of
    0: SetResultIVector2(Info, IVector2);
    1: SetResultIVector2(Info, IVector2(Info.ParamAsInteger[0]));
  else
    SetResultIVector2(Info, IVector2(Info.ParamAsInteger[0], Info.ParamAsInteger[1]));
  end;
end;

procedure TdwsFastMath.DoGlobalIVector3(Info: TProgramInfo);
begin
  case Info.ParamCount of
    0: SetResultIVector3(Info, IVector3);
    1: SetResultIVector3(Info, IVector3(Info.ParamAsInteger[0]));
  else
    SetResultIVector3(Info, IVector3(Info.ParamAsInteger[0], Info.ParamAsInteger[1],
      Info.ParamAsInteger[2]));
  end;
end;

procedure TdwsFastMath.DoGlobalIVector4(Info: TProgramInfo);
begin
  case Info.ParamCount of
    0: SetResultIVector4(Info, IVector4);
    1: SetResultIVector4(Info, IVector4(Info.ParamAsInteger[0]));
  else
    SetResultIVector4(Info, IVector4(Info.ParamAsInteger[0], Info.ParamAsInteger[1],
      Info.ParamAsInteger[2], Info.ParamAsInteger[3]));
  end;
end;

procedure TdwsFastMath.DoIVectorIsZero(Info: TProgramInfo);
begin
  if SameText(Info.FuncSym.Params[0].Typ.Name, 'TIVector2') then
    Info.ResultAsBoolean := ParamAsIVector2(Info, 0).IsZero
  else if SameText(Info.FuncSym.Params[0].Typ.Name, 'TIVector3') then
    Info.ResultAsBoolean := ParamAsIVector3(Info, 0).IsZero
  else
    Info.ResultAsBoolean := ParamAsIVector4(Info, 0).IsZero;
end;

procedure TdwsFastMath.DoIVectorToVector(Info: TProgramInfo);
begin
  if SameText(Info.FuncSym.Params[0].Typ.Name, 'TIVector2') then
    SetResultVector2(Info, ParamAsIVector2(Info, 0).ToVector2)
  else if SameText(Info.FuncSym.Params[0].Typ.Name, 'TIVector3') then
    SetResultVector3(Info, ParamAsIVector3(Info, 0).ToVector3)
  else
    SetResultVector4(Info, ParamAsIVector4(Info, 0).ToVector4);
end;

procedure TdwsFastMath.DoIVectorToString(Info: TProgramInfo);
var
  V2: TIVector2;
  V3: TIVector3;
  V4: TIVector4;
begin
  if SameText(Info.FuncSym.Params[0].Typ.Name, 'TIVector2') then
  begin
    V2 := ParamAsIVector2(Info, 0);
    Info.ResultAsString := Format('(%d, %d)', [V2.X, V2.Y]);
  end
  else if SameText(Info.FuncSym.Params[0].Typ.Name, 'TIVector3') then
  begin
    V3 := ParamAsIVector3(Info, 0);
    Info.ResultAsString := Format('(%d, %d, %d)', [V3.X, V3.Y, V3.Z]);
  end
  else
  begin
    V4 := ParamAsIVector4(Info, 0);
    Info.ResultAsString := Format('(%d, %d, %d, %d)', [V4.X, V4.Y, V4.Z, V4.W]);
  end;
end;

procedure TdwsFastMath.DoFloatClamp(Info: TProgramInfo);
begin
  Info.ResultAsFloat := FastMathClampSingle(Info.ParamAsFloat[0], Info.ParamAsFloat[1],
    Info.ParamAsFloat[2]);
end;

procedure TdwsFastMath.DoFloatLerp(Info: TProgramInfo);
begin
  Info.ResultAsFloat := Info.ParamAsFloat[0] +
    ((Info.ParamAsFloat[1] - Info.ParamAsFloat[0]) * Info.ParamAsFloat[2]);
end;

procedure TdwsFastMath.DoFloatSmoothStep(Info: TProgramInfo);
var
  Edge0, Edge1, X, T: Single;
begin
  Edge0 := Info.ParamAsFloat[0];
  Edge1 := Info.ParamAsFloat[1];
  X := Info.ParamAsFloat[2];
  if SameValue(Edge0, Edge1) then
    T := 0
  else
    T := FastMathClampSingle((X - Edge0) / (Edge1 - Edge0), 0.0, 1.0);
  Info.ResultAsFloat := T * T * (3.0 - (2.0 * T));
end;

procedure TdwsFastMath.DoRadians(Info: TProgramInfo);
begin
  Info.ResultAsFloat := DegToRad(Info.ParamAsFloat[0]);
end;

procedure TdwsFastMath.DoDegrees(Info: TProgramInfo);
begin
  Info.ResultAsFloat := RadToDeg(Info.ParamAsFloat[0]);
end;

procedure TdwsFastMath.DoVector2Min(Info: TProgramInfo);
var
  A, B: TVector2;
begin
  A := ParamAsVector2(Info, 0);
  B := ParamAsVector2(Info, 1);
  SetResultVector2(Info, Vector2(FastMathMinSingle(A.X, B.X), FastMathMinSingle(A.Y, B.Y)));
end;

procedure TdwsFastMath.DoVector2Max(Info: TProgramInfo);
var
  A, B: TVector2;
begin
  A := ParamAsVector2(Info, 0);
  B := ParamAsVector2(Info, 1);
  SetResultVector2(Info, Vector2(FastMathMaxSingle(A.X, B.X), FastMathMaxSingle(A.Y, B.Y)));
end;

procedure TdwsFastMath.DoVector2Clamp(Info: TProgramInfo);
var
  V, MinV, MaxV: TVector2;
begin
  V := ParamAsVector2(Info, 0);
  MinV := ParamAsVector2(Info, 1);
  MaxV := ParamAsVector2(Info, 2);
  SetResultVector2(Info, Vector2(FastMathClampSingle(V.X, MinV.X, MaxV.X),
    FastMathClampSingle(V.Y, MinV.Y, MaxV.Y)));
end;

procedure TdwsFastMath.DoVector3Min(Info: TProgramInfo);
var
  A, B: TVector3;
begin
  A := ParamAsVector3(Info, 0);
  B := ParamAsVector3(Info, 1);
  SetResultVector3(Info, Vector3(FastMathMinSingle(A.X, B.X),
    FastMathMinSingle(A.Y, B.Y), FastMathMinSingle(A.Z, B.Z)));
end;

procedure TdwsFastMath.DoVector3Max(Info: TProgramInfo);
var
  A, B: TVector3;
begin
  A := ParamAsVector3(Info, 0);
  B := ParamAsVector3(Info, 1);
  SetResultVector3(Info, Vector3(FastMathMaxSingle(A.X, B.X),
    FastMathMaxSingle(A.Y, B.Y), FastMathMaxSingle(A.Z, B.Z)));
end;

procedure TdwsFastMath.DoVector3Clamp(Info: TProgramInfo);
var
  V, MinV, MaxV: TVector3;
begin
  V := ParamAsVector3(Info, 0);
  MinV := ParamAsVector3(Info, 1);
  MaxV := ParamAsVector3(Info, 2);
  SetResultVector3(Info, Vector3(FastMathClampSingle(V.X, MinV.X, MaxV.X),
    FastMathClampSingle(V.Y, MinV.Y, MaxV.Y), FastMathClampSingle(V.Z, MinV.Z, MaxV.Z)));
end;

procedure TdwsFastMath.DoVector3Reflect(Info: TProgramInfo);
var
  V, N: TVector3;
begin
  V := ParamAsVector3(Info, 0);
  N := ParamAsVector3(Info, 1).Normalize;
  SetResultVector3(Info, V - (N * (2.0 * V.Dot(N))));
end;

procedure TdwsFastMath.DoVector3Project(Info: TProgramInfo);
var
  A, B: TVector3;
  Denom: Single;
begin
  A := ParamAsVector3(Info, 0);
  B := ParamAsVector3(Info, 1);
  Denom := B.Dot(B);
  if SameValue(Denom, 0.0) then
    SetResultVector3(Info, Vector3)
  else
    SetResultVector3(Info, B * (A.Dot(B) / Denom));
end;

procedure TdwsFastMath.DoVector4Min(Info: TProgramInfo);
var
  A, B: TVector4;
begin
  A := ParamAsVector4(Info, 0);
  B := ParamAsVector4(Info, 1);
  SetResultVector4(Info, Vector4(FastMathMinSingle(A.X, B.X),
    FastMathMinSingle(A.Y, B.Y), FastMathMinSingle(A.Z, B.Z),
    FastMathMinSingle(A.W, B.W)));
end;

procedure TdwsFastMath.DoVector4Max(Info: TProgramInfo);
var
  A, B: TVector4;
begin
  A := ParamAsVector4(Info, 0);
  B := ParamAsVector4(Info, 1);
  SetResultVector4(Info, Vector4(FastMathMaxSingle(A.X, B.X),
    FastMathMaxSingle(A.Y, B.Y), FastMathMaxSingle(A.Z, B.Z),
    FastMathMaxSingle(A.W, B.W)));
end;

procedure TdwsFastMath.DoVector4Clamp(Info: TProgramInfo);
var
  V, MinV, MaxV: TVector4;
begin
  V := ParamAsVector4(Info, 0);
  MinV := ParamAsVector4(Info, 1);
  MaxV := ParamAsVector4(Info, 2);
  SetResultVector4(Info, Vector4(FastMathClampSingle(V.X, MinV.X, MaxV.X),
    FastMathClampSingle(V.Y, MinV.Y, MaxV.Y), FastMathClampSingle(V.Z, MinV.Z, MaxV.Z),
    FastMathClampSingle(V.W, MinV.W, MaxV.W)));
end;

procedure TdwsFastMath.DoShowMessage(Info: TProgramInfo);
begin
  ShowMessage(Info.ParamAsString[0]);
end;

constructor TdwsFastMath.RegisterFastMath(AOwner: TComponent; AScript: TDelphiWebScript);
begin
  inherited Create(AOwner);

  UnitName := 'FastMath';
  Script := AScript;
  ImplicitUse := True;

  RegisterRecordType('TVector2', 'Float', ['X', 'Y']);
  RegisterRecordType('TVector3', 'Float', ['X', 'Y', 'Z']);
  RegisterRecordType('TVector4', 'Float', ['X', 'Y', 'Z', 'W']);
  RegisterRecordType('TQuaternion', 'Float', ['X', 'Y', 'Z', 'W']);
  RegisterRecordType('TMatrix2', 'Float', ['M11', 'M12', 'M21', 'M22']);
  RegisterRecordType('TMatrix3', 'Float', ['M11', 'M12', 'M13', 'M21', 'M22', 'M23', 'M31', 'M32', 'M33']);
  RegisterRecordType('TMatrix4', 'Float', ['M11', 'M12', 'M13', 'M14', 'M21', 'M22', 'M23', 'M24',
    'M31', 'M32', 'M33', 'M34', 'M41', 'M42', 'M43', 'M44']);
  RegisterRecordType('TIVector2', 'Integer', ['X', 'Y']);
  RegisterRecordType('TIVector3', 'Integer', ['X', 'Y', 'Z']);
  RegisterRecordType('TIVector4', 'Integer', ['X', 'Y', 'Z', 'W']);

  RegisterFastMathFunction('Clamp', 'Float', ['Value', 'MinValue', 'MaxValue'], ['Float', 'Float', 'Float'], DoFloatClamp, True);
  RegisterFastMathFunction('Lerp', 'Float', ['A', 'B', 'Alpha'], ['Float', 'Float', 'Float'], DoFloatLerp, True);
  RegisterFastMathFunction('SmoothStep', 'Float', ['Edge0', 'Edge1', 'X'], ['Float', 'Float', 'Float'], DoFloatSmoothStep);
  RegisterFastMathFunction('Radians', 'Float', ['Degrees'], ['Float'], DoRadians);
  RegisterFastMathFunction('Degrees', 'Float', ['Radians'], ['Float'], DoDegrees);

  RegisterFastMathFunction('Vector2', 'TVector2', [], [], DoGlobalVector2Zero, True);
  RegisterFastMathFunction('Vector2', 'TVector2', ['AValue'], ['Float'], DoGlobalVector2Val, True);
  RegisterFastMathFunction('Vector2', 'TVector2', ['X', 'Y'], ['Float', 'Float'], DoGlobalVector2XY, True);
  RegisterFastMathFunction('Vector2Add', 'TVector2', ['A', 'B'], ['TVector2', 'TVector2'], DoVector2Add);
  RegisterFastMathFunction('Vector2AddFloatVector2', 'TVector2', ['AValue', 'B'], ['Float', 'TVector2'], DoVector2AddFloatVector2);
  RegisterFastMathFunction('Vector2AddVector2Float', 'TVector2', ['A', 'BValue'], ['TVector2', 'Float'], DoVector2AddVector2Float);
  RegisterFastMathFunction('Vector2Subtract', 'TVector2', ['A', 'B'], ['TVector2', 'TVector2'], DoVector2Subtract);
  RegisterFastMathFunction('Vector2SubtractFloatVector2', 'TVector2', ['AValue', 'B'], ['Float', 'TVector2'], DoVector2SubtractFloatVector2);
  RegisterFastMathFunction('Vector2SubtractVector2Float', 'TVector2', ['A', 'BValue'], ['TVector2', 'Float'], DoVector2SubtractVector2Float);
  RegisterFastMathFunction('Vector2Multiply', 'TVector2', ['A', 'B'], ['TVector2', 'TVector2'], DoVector2Multiply, True);
  RegisterFastMathFunction('Vector2Multiply', 'TVector2', ['A', 'BValue'], ['TVector2', 'Float'], DoVector2MultiplyVector2Float, True);
  RegisterFastMathFunction('Vector2MultiplyFloatVector2', 'TVector2', ['AValue', 'B'], ['Float', 'TVector2'], DoVector2MultiplyFloatVector2);
  RegisterFastMathFunction('Vector2MultiplyVector2Float', 'TVector2', ['A', 'BValue'], ['TVector2', 'Float'], DoVector2MultiplyVector2Float);
  RegisterFastMathFunction('Vector2Divide', 'TVector2', ['A', 'B'], ['TVector2', 'TVector2'], DoVector2Divide, True);
  RegisterFastMathFunction('Vector2Divide', 'TVector2', ['A', 'BValue'], ['TVector2', 'Float'], DoVector2DivideVector2Float, True);
  RegisterFastMathFunction('Vector2DivideFloatVector2', 'TVector2', ['AValue', 'B'], ['Float', 'TVector2'], DoVector2DivideFloatVector2);
  RegisterFastMathFunction('Vector2DivideVector2Float', 'TVector2', ['A', 'BValue'], ['TVector2', 'Float'], DoVector2DivideVector2Float);
  RegisterFastMathFunction('Vector2Dot', 'Float', ['A', 'B'], ['TVector2', 'TVector2'], DoVector2Dot);
  RegisterFastMathFunction('Vector2Cross', 'Float', ['A', 'B'], ['TVector2', 'TVector2'], DoVector2Cross);
  RegisterFastMathFunction('Vector2Normalize', 'TVector2', ['A'], ['TVector2'], DoVector2Normalize);
  RegisterFastMathFunction('Vector2NormalizeFast', 'TVector2', ['A'], ['TVector2'], DoVector2NormalizeFast);
  RegisterFastMathFunction('Vector2Length', 'Float', ['A'], ['TVector2'], DoVector2Length);
  RegisterFastMathFunction('Vector2LengthSquared', 'Float', ['A'], ['TVector2'], DoVector2LengthSquared);
  RegisterFastMathFunction('Vector2Distance', 'Float', ['A', 'B'], ['TVector2', 'TVector2'], DoVector2Distance);
  RegisterFastMathFunction('Vector2DistanceSquared', 'Float', ['A', 'B'], ['TVector2', 'TVector2'], DoVector2DistanceSquared);
  RegisterFastMathFunction('Vector2Lerp', 'TVector2', ['A', 'B', 'Alpha'], ['TVector2', 'TVector2', 'Float'], DoVector2Lerp);
  RegisterFastMathFunction('Vector2Min', 'TVector2', ['A', 'B'], ['TVector2', 'TVector2'], DoVector2Min);
  RegisterFastMathFunction('Vector2Max', 'TVector2', ['A', 'B'], ['TVector2', 'TVector2'], DoVector2Max);
  RegisterFastMathFunction('Vector2Clamp', 'TVector2', ['Value', 'MinValue', 'MaxValue'], ['TVector2', 'TVector2', 'TVector2'], DoVector2Clamp);
  RegisterFastMathFunction('Vector2Equals', 'Boolean', ['A', 'B'], ['TVector2', 'TVector2'], DoVector2Equals, True);
  RegisterFastMathFunction('Vector2Equals', 'Boolean', ['A', 'B', 'Tolerance'], ['TVector2', 'TVector2', 'Float'], DoVector2Equals, True);
  RegisterFastMathFunction('Vector2ToString', 'String', ['A'], ['TVector2'], DoVector2ToString);

  RegisterFastMathFunction('Vector3', 'TVector3', [], [], DoGlobalVector3Zero, True);
  RegisterFastMathFunction('Vector3', 'TVector3', ['AValue'], ['Float'], DoGlobalVector3Val, True);
  RegisterFastMathFunction('Vector3', 'TVector3', ['X', 'Y', 'Z'], ['Float', 'Float', 'Float'], DoGlobalVector3XYZ, True);
  RegisterFastMathFunction('Vector3', 'TVector3', ['XY', 'Z'], ['TVector2', 'Float'], DoGlobalVector3Vector2Float, True);
  RegisterFastMathFunction('Vector3', 'TVector3', ['X', 'YZ'], ['Float', 'TVector2'], DoGlobalVector3FloatVector2, True);
  RegisterFastMathFunction('Vector3Add', 'TVector3', ['A', 'B'], ['TVector3', 'TVector3'], DoVector3Add);
  RegisterFastMathFunction('Vector3AddFloatVector3', 'TVector3', ['AValue', 'B'], ['Float', 'TVector3'], DoVector3AddFloatVector3);
  RegisterFastMathFunction('Vector3AddVector3Float', 'TVector3', ['A', 'BValue'], ['TVector3', 'Float'], DoVector3AddVector3Float);
  RegisterFastMathFunction('Vector3Subtract', 'TVector3', ['A', 'B'], ['TVector3', 'TVector3'], DoVector3Subtract);
  RegisterFastMathFunction('Vector3SubtractFloatVector3', 'TVector3', ['AValue', 'B'], ['Float', 'TVector3'], DoVector3SubtractFloatVector3);
  RegisterFastMathFunction('Vector3SubtractVector3Float', 'TVector3', ['A', 'BValue'], ['TVector3', 'Float'], DoVector3SubtractVector3Float);
  RegisterFastMathFunction('Vector3Multiply', 'TVector3', ['A', 'B'], ['TVector3', 'TVector3'], DoVector3Multiply, True);
  RegisterFastMathFunction('Vector3Multiply', 'TVector3', ['A', 'BValue'], ['TVector3', 'Float'], DoVector3MultiplyVector3Float, True);
  RegisterFastMathFunction('Vector3MultiplyFloatVector3', 'TVector3', ['AValue', 'B'], ['Float', 'TVector3'], DoVector3MultiplyFloatVector3);
  RegisterFastMathFunction('Vector3MultiplyVector3Float', 'TVector3', ['A', 'BValue'], ['TVector3', 'Float'], DoVector3MultiplyVector3Float);
  RegisterFastMathFunction('Vector3Divide', 'TVector3', ['A', 'B'], ['TVector3', 'TVector3'], DoVector3Divide, True);
  RegisterFastMathFunction('Vector3Divide', 'TVector3', ['A', 'BValue'], ['TVector3', 'Float'], DoVector3DivideVector3Float, True);
  RegisterFastMathFunction('Vector3DivideFloatVector3', 'TVector3', ['AValue', 'B'], ['Float', 'TVector3'], DoVector3DivideFloatVector3);
  RegisterFastMathFunction('Vector3DivideVector3Float', 'TVector3', ['A', 'BValue'], ['TVector3', 'Float'], DoVector3DivideVector3Float);
  RegisterFastMathFunction('Vector3Dot', 'Float', ['A', 'B'], ['TVector3', 'TVector3'], DoVector3Dot);
  RegisterFastMathFunction('Vector3Cross', 'TVector3', ['A', 'B'], ['TVector3', 'TVector3'], DoVector3Cross);
  RegisterFastMathFunction('Vector3Normalize', 'TVector3', ['A'], ['TVector3'], DoVector3Normalize);
  RegisterFastMathFunction('Vector3NormalizeFast', 'TVector3', ['A'], ['TVector3'], DoVector3NormalizeFast);
  RegisterFastMathFunction('Vector3Length', 'Float', ['A'], ['TVector3'], DoVector3Length);
  RegisterFastMathFunction('Vector3LengthSquared', 'Float', ['A'], ['TVector3'], DoVector3LengthSquared);
  RegisterFastMathFunction('Vector3Distance', 'Float', ['A', 'B'], ['TVector3', 'TVector3'], DoVector3Distance);
  RegisterFastMathFunction('Vector3DistanceSquared', 'Float', ['A', 'B'], ['TVector3', 'TVector3'], DoVector3DistanceSquared);
  RegisterFastMathFunction('Vector3Lerp', 'TVector3', ['A', 'B', 'Alpha'], ['TVector3', 'TVector3', 'Float'], DoVector3Lerp);
  RegisterFastMathFunction('Vector3Min', 'TVector3', ['A', 'B'], ['TVector3', 'TVector3'], DoVector3Min);
  RegisterFastMathFunction('Vector3Max', 'TVector3', ['A', 'B'], ['TVector3', 'TVector3'], DoVector3Max);
  RegisterFastMathFunction('Vector3Clamp', 'TVector3', ['Value', 'MinValue', 'MaxValue'], ['TVector3', 'TVector3', 'TVector3'], DoVector3Clamp);
  RegisterFastMathFunction('Vector3Reflect', 'TVector3', ['Vector', 'Normal'], ['TVector3', 'TVector3'], DoVector3Reflect);
  RegisterFastMathFunction('Vector3Project', 'TVector3', ['Vector', 'Onto'], ['TVector3', 'TVector3'], DoVector3Project);
  RegisterFastMathFunction('Vector3Equals', 'Boolean', ['A', 'B'], ['TVector3', 'TVector3'], DoVector3Equals, True);
  RegisterFastMathFunction('Vector3Equals', 'Boolean', ['A', 'B', 'Tolerance'], ['TVector3', 'TVector3', 'Float'], DoVector3Equals, True);
  RegisterFastMathFunction('Vector3ToString', 'String', ['A'], ['TVector3'], DoVector3ToString);

  RegisterFastMathFunction('Vector4', 'TVector4', [], [], DoGlobalVector4Zero, True);
  RegisterFastMathFunction('Vector4', 'TVector4', ['AValue'], ['Float'], DoGlobalVector4Val, True);
  RegisterFastMathFunction('Vector4', 'TVector4', ['X', 'Y', 'Z', 'W'], ['Float', 'Float', 'Float', 'Float'], DoGlobalVector4XYZW, True);
  RegisterFastMathFunction('Vector4', 'TVector4', ['XYZ', 'W'], ['TVector3', 'Float'], DoGlobalVector4Vector3Float, True);
  RegisterFastMathFunction('Vector4', 'TVector4', ['X', 'YZW'], ['Float', 'TVector3'], DoGlobalVector4FloatVector3, True);
  RegisterFastMathFunction('Vector4Add', 'TVector4', ['A', 'B'], ['TVector4', 'TVector4'], DoVector4Add);
  RegisterFastMathFunction('Vector4AddFloatVector4', 'TVector4', ['AValue', 'B'], ['Float', 'TVector4'], DoVector4AddFloatVector4);
  RegisterFastMathFunction('Vector4AddVector4Float', 'TVector4', ['A', 'BValue'], ['TVector4', 'Float'], DoVector4AddVector4Float);
  RegisterFastMathFunction('Vector4Subtract', 'TVector4', ['A', 'B'], ['TVector4', 'TVector4'], DoVector4Subtract);
  RegisterFastMathFunction('Vector4SubtractFloatVector4', 'TVector4', ['AValue', 'B'], ['Float', 'TVector4'], DoVector4SubtractFloatVector4);
  RegisterFastMathFunction('Vector4SubtractVector4Float', 'TVector4', ['A', 'BValue'], ['TVector4', 'Float'], DoVector4SubtractVector4Float);
  RegisterFastMathFunction('Vector4Multiply', 'TVector4', ['A', 'B'], ['TVector4', 'TVector4'], DoVector4Multiply, True);
  RegisterFastMathFunction('Vector4Multiply', 'TVector4', ['A', 'BValue'], ['TVector4', 'Float'], DoVector4MultiplyVector4Float, True);
  RegisterFastMathFunction('Vector4MultiplyFloatVector4', 'TVector4', ['AValue', 'B'], ['Float', 'TVector4'], DoVector4MultiplyFloatVector4);
  RegisterFastMathFunction('Vector4MultiplyVector4Float', 'TVector4', ['A', 'BValue'], ['TVector4', 'Float'], DoVector4MultiplyVector4Float);
  RegisterFastMathFunction('Vector4Divide', 'TVector4', ['A', 'B'], ['TVector4', 'TVector4'], DoVector4Divide, True);
  RegisterFastMathFunction('Vector4Divide', 'TVector4', ['A', 'BValue'], ['TVector4', 'Float'], DoVector4DivideVector4Float, True);
  RegisterFastMathFunction('Vector4DivideFloatVector4', 'TVector4', ['AValue', 'B'], ['Float', 'TVector4'], DoVector4DivideFloatVector4);
  RegisterFastMathFunction('Vector4DivideVector4Float', 'TVector4', ['A', 'BValue'], ['TVector4', 'Float'], DoVector4DivideVector4Float);
  RegisterFastMathFunction('Vector4Dot', 'Float', ['A', 'B'], ['TVector4', 'TVector4'], DoVector4Dot);
  RegisterFastMathFunction('Vector4Normalize', 'TVector4', ['A'], ['TVector4'], DoVector4Normalize);
  RegisterFastMathFunction('Vector4NormalizeFast', 'TVector4', ['A'], ['TVector4'], DoVector4NormalizeFast);
  RegisterFastMathFunction('Vector4Length', 'Float', ['A'], ['TVector4'], DoVector4Length);
  RegisterFastMathFunction('Vector4LengthSquared', 'Float', ['A'], ['TVector4'], DoVector4LengthSquared);
  RegisterFastMathFunction('Vector4Distance', 'Float', ['A', 'B'], ['TVector4', 'TVector4'], DoVector4Distance);
  RegisterFastMathFunction('Vector4DistanceSquared', 'Float', ['A', 'B'], ['TVector4', 'TVector4'], DoVector4DistanceSquared);
  RegisterFastMathFunction('Vector4Lerp', 'TVector4', ['A', 'B', 'Alpha'], ['TVector4', 'TVector4', 'Float'], DoVector4Lerp);
  RegisterFastMathFunction('Vector4Min', 'TVector4', ['A', 'B'], ['TVector4', 'TVector4'], DoVector4Min);
  RegisterFastMathFunction('Vector4Max', 'TVector4', ['A', 'B'], ['TVector4', 'TVector4'], DoVector4Max);
  RegisterFastMathFunction('Vector4Clamp', 'TVector4', ['Value', 'MinValue', 'MaxValue'], ['TVector4', 'TVector4', 'TVector4'], DoVector4Clamp);
  RegisterFastMathFunction('Vector4Equals', 'Boolean', ['A', 'B'], ['TVector4', 'TVector4'], DoVector4Equals, True);
  RegisterFastMathFunction('Vector4Equals', 'Boolean', ['A', 'B', 'Tolerance'], ['TVector4', 'TVector4', 'Float'], DoVector4Equals, True);
  RegisterFastMathFunction('Vector4ToString', 'String', ['A'], ['TVector4'], DoVector4ToString);

  RegisterFastMathFunction('Matrix2', 'TMatrix2', [], [], DoGlobalMatrix2Identity, True);
  RegisterFastMathFunction('Matrix2', 'TMatrix2', ['Diagonal'], ['Float'], DoGlobalMatrix2Diagonal, True);
  RegisterFastMathFunction('Matrix2', 'TMatrix2', ['Row0', 'Row1'], ['TVector2', 'TVector2'], DoGlobalMatrix2Rows, True);
  RegisterFastMathFunction('Matrix2', 'TMatrix2', ['M11', 'M12', 'M21', 'M22'], ['Float', 'Float', 'Float', 'Float'], DoGlobalMatrix2Values, True);
  RegisterFastMathFunction('Matrix2Add', 'TMatrix2', ['A', 'B'], ['TMatrix2', 'TMatrix2'], DoMatrix2Add);
  RegisterFastMathFunction('Matrix2Subtract', 'TMatrix2', ['A', 'B'], ['TMatrix2', 'TMatrix2'], DoMatrix2Subtract);
  RegisterFastMathFunction('Matrix2Multiply', 'TMatrix2', ['A', 'B'], ['TMatrix2', 'TMatrix2'], DoMatrix2Multiply, True);
  RegisterFastMathFunction('Matrix2Multiply', 'TMatrix2', ['A', 'BValue'], ['TMatrix2', 'Float'], DoMatrix2MultiplyMatrixFloat, True);
  RegisterFastMathFunction('Matrix2MultiplyMatrixFloat', 'TMatrix2', ['A', 'BValue'], ['TMatrix2', 'Float'], DoMatrix2MultiplyMatrixFloat);
  RegisterFastMathFunction('Matrix2MultiplyFloatMatrix', 'TMatrix2', ['AValue', 'B'], ['Float', 'TMatrix2'], DoMatrix2MultiplyFloatMatrix);
  RegisterFastMathFunction('Matrix2MultiplyMatrixVector', 'TVector2', ['A', 'B'], ['TMatrix2', 'TVector2'], DoMatrix2MultiplyMatrixVector);
  RegisterFastMathFunction('Matrix2MultiplyVectorMatrix', 'TVector2', ['A', 'B'], ['TVector2', 'TMatrix2'], DoMatrix2MultiplyVectorMatrix);
  RegisterFastMathFunction('Matrix2Divide', 'TMatrix2', ['A', 'B'], ['TMatrix2', 'TMatrix2'], DoMatrix2Divide, True);
  RegisterFastMathFunction('Matrix2Divide', 'TMatrix2', ['A', 'BValue'], ['TMatrix2', 'Float'], DoMatrix2DivideMatrixFloat, True);
  RegisterFastMathFunction('Matrix2DivideMatrixFloat', 'TMatrix2', ['A', 'BValue'], ['TMatrix2', 'Float'], DoMatrix2DivideMatrixFloat);
  RegisterFastMathFunction('Matrix2Transpose', 'TMatrix2', ['A'], ['TMatrix2'], DoMatrix2Transpose);
  RegisterFastMathFunction('Matrix2Inverse', 'TMatrix2', ['A'], ['TMatrix2'], DoMatrix2Inverse);
  RegisterFastMathFunction('Matrix2Determinant', 'Float', ['A'], ['TMatrix2'], DoMatrix2Determinant);
  RegisterFastMathFunction('Matrix2CompMult', 'TMatrix2', ['A', 'B'], ['TMatrix2', 'TMatrix2'], DoMatrix2CompMult);
  RegisterFastMathFunction('Matrix2Equals', 'Boolean', ['A', 'B'], ['TMatrix2', 'TMatrix2'], DoMatrix2Equals);
  RegisterFastMathFunction('Matrix2ToString', 'String', ['A'], ['TMatrix2'], DoMatrix2ToString);

  RegisterFastMathFunction('Matrix3', 'TMatrix3', [], [], DoGlobalMatrix3Identity, True);
  RegisterFastMathFunction('Matrix3', 'TMatrix3', ['Diagonal'], ['Float'], DoGlobalMatrix3Diagonal, True);
  RegisterFastMathFunction('Matrix3', 'TMatrix3', ['Row0', 'Row1', 'Row2'], ['TVector3', 'TVector3', 'TVector3'], DoGlobalMatrix3Rows, True);
  RegisterFastMathFunction('Matrix3', 'TMatrix3', ['M11', 'M12', 'M13', 'M21', 'M22', 'M23', 'M31', 'M32', 'M33'], ['Float', 'Float', 'Float', 'Float', 'Float', 'Float', 'Float', 'Float', 'Float'], DoGlobalMatrix3Values, True);
  RegisterFastMathFunction('Matrix3Scaling', 'TMatrix3', ['ScaleX', 'ScaleY'], ['Float', 'Float'], DoMatrix3ScalingXY, True);
  RegisterFastMathFunction('Matrix3Scaling', 'TMatrix3', ['Scale'], ['TVector2'], DoMatrix3ScalingVector, True);
  RegisterFastMathFunction('Matrix3Translation', 'TMatrix3', ['DeltaX', 'DeltaY'], ['Float', 'Float'], DoMatrix3TranslationXY, True);
  RegisterFastMathFunction('Matrix3Translation', 'TMatrix3', ['Delta'], ['TVector2'], DoMatrix3TranslationVector, True);
  RegisterFastMathFunction('Matrix3Rotation', 'TMatrix3', ['Angle'], ['Float'], DoMatrix3Rotation);
  RegisterFastMathFunction('Matrix3Add', 'TMatrix3', ['A', 'B'], ['TMatrix3', 'TMatrix3'], DoMatrix3Add);
  RegisterFastMathFunction('Matrix3Subtract', 'TMatrix3', ['A', 'B'], ['TMatrix3', 'TMatrix3'], DoMatrix3Subtract);
  RegisterFastMathFunction('Matrix3Multiply', 'TMatrix3', ['A', 'B'], ['TMatrix3', 'TMatrix3'], DoMatrix3Multiply, True);
  RegisterFastMathFunction('Matrix3Multiply', 'TMatrix3', ['A', 'BValue'], ['TMatrix3', 'Float'], DoMatrix3MultiplyMatrixFloat, True);
  RegisterFastMathFunction('Matrix3MultiplyMatrixFloat', 'TMatrix3', ['A', 'BValue'], ['TMatrix3', 'Float'], DoMatrix3MultiplyMatrixFloat);
  RegisterFastMathFunction('Matrix3MultiplyFloatMatrix', 'TMatrix3', ['AValue', 'B'], ['Float', 'TMatrix3'], DoMatrix3MultiplyFloatMatrix);
  RegisterFastMathFunction('Matrix3MultiplyMatrixVector', 'TVector3', ['A', 'B'], ['TMatrix3', 'TVector3'], DoMatrix3MultiplyMatrixVector);
  RegisterFastMathFunction('Matrix3MultiplyVectorMatrix', 'TVector3', ['A', 'B'], ['TVector3', 'TMatrix3'], DoMatrix3MultiplyVectorMatrix);
  RegisterFastMathFunction('Matrix3Divide', 'TMatrix3', ['A', 'B'], ['TMatrix3', 'TMatrix3'], DoMatrix3Divide, True);
  RegisterFastMathFunction('Matrix3Divide', 'TMatrix3', ['A', 'BValue'], ['TMatrix3', 'Float'], DoMatrix3DivideMatrixFloat, True);
  RegisterFastMathFunction('Matrix3DivideMatrixFloat', 'TMatrix3', ['A', 'BValue'], ['TMatrix3', 'Float'], DoMatrix3DivideMatrixFloat);
  RegisterFastMathFunction('Matrix3Transpose', 'TMatrix3', ['A'], ['TMatrix3'], DoMatrix3Transpose);
  RegisterFastMathFunction('Matrix3Inverse', 'TMatrix3', ['A'], ['TMatrix3'], DoMatrix3Inverse);
  RegisterFastMathFunction('Matrix3Determinant', 'Float', ['A'], ['TMatrix3'], DoMatrix3Determinant);
  RegisterFastMathFunction('Matrix3CompMult', 'TMatrix3', ['A', 'B'], ['TMatrix3', 'TMatrix3'], DoMatrix3CompMult);
  RegisterFastMathFunction('Matrix3Equals', 'Boolean', ['A', 'B'], ['TMatrix3', 'TMatrix3'], DoMatrix3Equals);
  RegisterFastMathFunction('Matrix3ToString', 'String', ['A'], ['TMatrix3'], DoMatrix3ToString);

  RegisterFastMathFunction('Matrix4', 'TMatrix4', [], [], DoGlobalMatrix4Identity, True);
  RegisterFastMathFunction('Matrix4', 'TMatrix4', ['Diagonal'], ['Float'], DoGlobalMatrix4Diagonal, True);
  RegisterFastMathFunction('Matrix4', 'TMatrix4', ['Row0', 'Row1', 'Row2', 'Row3'], ['TVector4', 'TVector4', 'TVector4', 'TVector4'], DoGlobalMatrix4Rows, True);
  RegisterFastMathFunction('Matrix4', 'TMatrix4', ['M11', 'M12', 'M13', 'M14', 'M21', 'M22', 'M23', 'M24', 'M31', 'M32', 'M33', 'M34', 'M41', 'M42', 'M43', 'M44'], ['Float', 'Float', 'Float', 'Float', 'Float', 'Float', 'Float', 'Float', 'Float', 'Float', 'Float', 'Float', 'Float', 'Float', 'Float', 'Float'], DoGlobalMatrix4Values, True);
  RegisterFastMathFunction('Matrix4Scaling', 'TMatrix4', ['ScaleX', 'ScaleY', 'ScaleZ'], ['Float', 'Float', 'Float'], DoMatrix4ScalingXYZ, True);
  RegisterFastMathFunction('Matrix4Scaling', 'TMatrix4', ['Scale'], ['TVector3'], DoMatrix4ScalingVector, True);
  RegisterFastMathFunction('Matrix4Translation', 'TMatrix4', ['DeltaX', 'DeltaY', 'DeltaZ'], ['Float', 'Float', 'Float'], DoMatrix4TranslationXYZ, True);
  RegisterFastMathFunction('Matrix4Translation', 'TMatrix4', ['Delta'], ['TVector3'], DoMatrix4TranslationVector, True);
  RegisterFastMathFunction('Matrix4RotationX', 'TMatrix4', ['Angle'], ['Float'], DoMatrix4RotationX);
  RegisterFastMathFunction('Matrix4RotationY', 'TMatrix4', ['Angle'], ['Float'], DoMatrix4RotationY);
  RegisterFastMathFunction('Matrix4RotationZ', 'TMatrix4', ['Angle'], ['Float'], DoMatrix4RotationZ);
  RegisterFastMathFunction('Matrix4RotationAxis', 'TMatrix4', ['Axis', 'Angle'], ['TVector3', 'Float'], DoMatrix4RotationAxis);
  RegisterFastMathFunction('Matrix4RotationYawPitchRoll', 'TMatrix4', ['Yaw', 'Pitch', 'Roll'], ['Float', 'Float', 'Float'], DoMatrix4RotationYawPitchRoll);
  RegisterFastMathFunction('Matrix4LookAtLH', 'TMatrix4', ['CameraPosition', 'CameraTarget', 'CameraUp'], ['TVector3', 'TVector3', 'TVector3'], DoMatrix4LookAtLH);
  RegisterFastMathFunction('Matrix4LookAtRH', 'TMatrix4', ['CameraPosition', 'CameraTarget', 'CameraUp'], ['TVector3', 'TVector3', 'TVector3'], DoMatrix4LookAtRH);
  RegisterFastMathFunction('Matrix4PerspectiveFovLH', 'TMatrix4', ['FieldOfView', 'AspectRatio', 'NearPlaneDistance', 'FarPlaneDistance'], ['Float', 'Float', 'Float', 'Float'], DoMatrix4PerspectiveFovLH, True);
  RegisterFastMathFunction('Matrix4PerspectiveFovLH', 'TMatrix4', ['FieldOfView', 'AspectRatio', 'NearPlaneDistance', 'FarPlaneDistance', 'HorizontalFOV'], ['Float', 'Float', 'Float', 'Float', 'Boolean'], DoMatrix4PerspectiveFovLH, True);
  RegisterFastMathFunction('Matrix4PerspectiveFovRH', 'TMatrix4', ['FieldOfView', 'AspectRatio', 'NearPlaneDistance', 'FarPlaneDistance'], ['Float', 'Float', 'Float', 'Float'], DoMatrix4PerspectiveFovRH, True);
  RegisterFastMathFunction('Matrix4PerspectiveFovRH', 'TMatrix4', ['FieldOfView', 'AspectRatio', 'NearPlaneDistance', 'FarPlaneDistance', 'HorizontalFOV'], ['Float', 'Float', 'Float', 'Float', 'Boolean'], DoMatrix4PerspectiveFovRH, True);
  RegisterFastMathFunction('Matrix4Add', 'TMatrix4', ['A', 'B'], ['TMatrix4', 'TMatrix4'], DoMatrix4Add);
  RegisterFastMathFunction('Matrix4Subtract', 'TMatrix4', ['A', 'B'], ['TMatrix4', 'TMatrix4'], DoMatrix4Subtract);
  RegisterFastMathFunction('Matrix4Multiply', 'TMatrix4', ['A', 'B'], ['TMatrix4', 'TMatrix4'], DoMatrix4Multiply, True);
  RegisterFastMathFunction('Matrix4Multiply', 'TMatrix4', ['A', 'BValue'], ['TMatrix4', 'Float'], DoMatrix4MultiplyMatrixFloat, True);
  RegisterFastMathFunction('Matrix4MultiplyMatrixFloat', 'TMatrix4', ['A', 'BValue'], ['TMatrix4', 'Float'], DoMatrix4MultiplyMatrixFloat);
  RegisterFastMathFunction('Matrix4MultiplyFloatMatrix', 'TMatrix4', ['AValue', 'B'], ['Float', 'TMatrix4'], DoMatrix4MultiplyFloatMatrix);
  RegisterFastMathFunction('Matrix4MultiplyMatrixVector', 'TVector4', ['A', 'B'], ['TMatrix4', 'TVector4'], DoMatrix4MultiplyMatrixVector);
  RegisterFastMathFunction('Matrix4MultiplyVectorMatrix', 'TVector4', ['A', 'B'], ['TVector4', 'TMatrix4'], DoMatrix4MultiplyVectorMatrix);
  RegisterFastMathFunction('Matrix4Divide', 'TMatrix4', ['A', 'B'], ['TMatrix4', 'TMatrix4'], DoMatrix4Divide, True);
  RegisterFastMathFunction('Matrix4Divide', 'TMatrix4', ['A', 'BValue'], ['TMatrix4', 'Float'], DoMatrix4DivideMatrixFloat, True);
  RegisterFastMathFunction('Matrix4DivideMatrixFloat', 'TMatrix4', ['A', 'BValue'], ['TMatrix4', 'Float'], DoMatrix4DivideMatrixFloat);
  RegisterFastMathFunction('Matrix4Transpose', 'TMatrix4', ['A'], ['TMatrix4'], DoMatrix4Transpose);
  RegisterFastMathFunction('Matrix4Inverse', 'TMatrix4', ['A'], ['TMatrix4'], DoMatrix4Inverse);
  RegisterFastMathFunction('Matrix4Determinant', 'Float', ['A'], ['TMatrix4'], DoMatrix4Determinant);
  RegisterFastMathFunction('Matrix4CompMult', 'TMatrix4', ['A', 'B'], ['TMatrix4', 'TMatrix4'], DoMatrix4CompMult);
  RegisterFastMathFunction('Matrix4Equals', 'Boolean', ['A', 'B'], ['TMatrix4', 'TMatrix4'], DoMatrix4Equals);
  RegisterFastMathFunction('Matrix4ToString', 'String', ['A'], ['TMatrix4'], DoMatrix4ToString);

  RegisterFastMathFunction('Quaternion', 'TQuaternion', [], [], DoGlobalQuaternionIdentity, True);
  RegisterFastMathFunction('Quaternion', 'TQuaternion', ['X', 'Y', 'Z', 'W'], ['Float', 'Float', 'Float', 'Float'], DoGlobalQuaternionXYZW, True);
  RegisterFastMathFunction('Quaternion', 'TQuaternion', ['Axis', 'Angle'], ['TVector3', 'Float'], DoGlobalQuaternionAxisAngle, True);
  RegisterFastMathFunction('QuaternionYawPitchRoll', 'TQuaternion', ['Yaw', 'Pitch', 'Roll'], ['Float', 'Float', 'Float'], DoQuaternionYawPitchRoll);
  RegisterFastMathFunction('QuaternionFromMatrix4', 'TQuaternion', ['Matrix'], ['TMatrix4'], DoQuaternionFromMatrix4);
  RegisterFastMathFunction('QuaternionAdd', 'TQuaternion', ['A', 'B'], ['TQuaternion', 'TQuaternion'], DoQuaternionAdd);
  RegisterFastMathFunction('QuaternionMultiply', 'TQuaternion', ['A', 'B'], ['TQuaternion', 'TQuaternion'], DoQuaternionMultiply, True);
  RegisterFastMathFunction('QuaternionMultiply', 'TQuaternion', ['A', 'BValue'], ['TQuaternion', 'Float'], DoQuaternionMultiplyQuaternionFloat, True);
  RegisterFastMathFunction('QuaternionMultiplyQuaternionFloat', 'TQuaternion', ['A', 'BValue'], ['TQuaternion', 'Float'], DoQuaternionMultiplyQuaternionFloat);
  RegisterFastMathFunction('QuaternionMultiplyFloatQuaternion', 'TQuaternion', ['AValue', 'B'], ['Float', 'TQuaternion'], DoQuaternionMultiplyFloatQuaternion);
  RegisterFastMathFunction('QuaternionNormalize', 'TQuaternion', ['A'], ['TQuaternion'], DoQuaternionNormalize);
  RegisterFastMathFunction('QuaternionNormalizeFast', 'TQuaternion', ['A'], ['TQuaternion'], DoQuaternionNormalizeFast);
  RegisterFastMathFunction('QuaternionConjugate', 'TQuaternion', ['A'], ['TQuaternion'], DoQuaternionConjugate);
  RegisterFastMathFunction('QuaternionToMatrix4', 'TMatrix4', ['A'], ['TQuaternion'], DoQuaternionToMatrix4);
  RegisterFastMathFunction('QuaternionLength', 'Float', ['A'], ['TQuaternion'], DoQuaternionLength);
  RegisterFastMathFunction('QuaternionLengthSquared', 'Float', ['A'], ['TQuaternion'], DoQuaternionLengthSquared);
  RegisterFastMathFunction('QuaternionIsIdentity', 'Boolean', ['A'], ['TQuaternion'], DoQuaternionIsIdentity, True);
  RegisterFastMathFunction('QuaternionIsIdentity', 'Boolean', ['A', 'ErrorMargin'], ['TQuaternion', 'Float'], DoQuaternionIsIdentity, True);
  RegisterFastMathFunction('QuaternionToString', 'String', ['A'], ['TQuaternion'], DoQuaternionToString);

  RegisterFastMathFunction('IVector2', 'TIVector2', [], [], DoGlobalIVector2, True);
  RegisterFastMathFunction('IVector2', 'TIVector2', ['AValue'], ['Integer'], DoGlobalIVector2, True);
  RegisterFastMathFunction('IVector2', 'TIVector2', ['X', 'Y'], ['Integer', 'Integer'], DoGlobalIVector2, True);
  RegisterFastMathFunction('IVector3', 'TIVector3', [], [], DoGlobalIVector3, True);
  RegisterFastMathFunction('IVector3', 'TIVector3', ['AValue'], ['Integer'], DoGlobalIVector3, True);
  RegisterFastMathFunction('IVector3', 'TIVector3', ['X', 'Y', 'Z'], ['Integer', 'Integer', 'Integer'], DoGlobalIVector3, True);
  RegisterFastMathFunction('IVector4', 'TIVector4', [], [], DoGlobalIVector4, True);
  RegisterFastMathFunction('IVector4', 'TIVector4', ['AValue'], ['Integer'], DoGlobalIVector4, True);
  RegisterFastMathFunction('IVector4', 'TIVector4', ['X', 'Y', 'Z', 'W'], ['Integer', 'Integer', 'Integer', 'Integer'], DoGlobalIVector4, True);
  RegisterFastMathFunction('IVector2IsZero', 'Boolean', ['A'], ['TIVector2'], DoIVectorIsZero);
  RegisterFastMathFunction('IVector3IsZero', 'Boolean', ['A'], ['TIVector3'], DoIVectorIsZero);
  RegisterFastMathFunction('IVector4IsZero', 'Boolean', ['A'], ['TIVector4'], DoIVectorIsZero);
  RegisterFastMathFunction('IVector2ToVector2', 'TVector2', ['A'], ['TIVector2'], DoIVectorToVector);
  RegisterFastMathFunction('IVector3ToVector3', 'TVector3', ['A'], ['TIVector3'], DoIVectorToVector);
  RegisterFastMathFunction('IVector4ToVector4', 'TVector4', ['A'], ['TIVector4'], DoIVectorToVector);
  RegisterFastMathFunction('IVector2ToString', 'String', ['A'], ['TIVector2'], DoIVectorToString);
  RegisterFastMathFunction('IVector3ToString', 'String', ['A'], ['TIVector3'], DoIVectorToString);
  RegisterFastMathFunction('IVector4ToString', 'String', ['A'], ['TIVector4'], DoIVectorToString);

  RegisterBinaryOperator('Vector2AddOperator', ttPLUS, 'TVector2', 'TVector2', 'TVector2', 'Vector2Add');
  RegisterBinaryOperator('Vector2AddFloatVector2Operator', ttPLUS, 'Float', 'TVector2', 'TVector2', 'Vector2AddFloatVector2');
  RegisterBinaryOperator('Vector2AddVector2FloatOperator', ttPLUS, 'TVector2', 'Float', 'TVector2', 'Vector2AddVector2Float');
  RegisterBinaryOperator('Vector2SubtractOperator', ttMINUS, 'TVector2', 'TVector2', 'TVector2', 'Vector2Subtract');
  RegisterBinaryOperator('Vector2SubtractFloatVector2Operator', ttMINUS, 'Float', 'TVector2', 'TVector2', 'Vector2SubtractFloatVector2');
  RegisterBinaryOperator('Vector2SubtractVector2FloatOperator', ttMINUS, 'TVector2', 'Float', 'TVector2', 'Vector2SubtractVector2Float');
  RegisterBinaryOperator('Vector2MultiplyOperator', ttTIMES, 'TVector2', 'TVector2', 'TVector2', 'Vector2Multiply');
  RegisterBinaryOperator('Vector2MultiplyFloatVector2Operator', ttTIMES, 'Float', 'TVector2', 'TVector2', 'Vector2MultiplyFloatVector2');
  RegisterBinaryOperator('Vector2MultiplyVector2FloatOperator', ttTIMES, 'TVector2', 'Float', 'TVector2', 'Vector2MultiplyVector2Float');
  RegisterBinaryOperator('Vector2DivideOperator', ttDIVIDE, 'TVector2', 'TVector2', 'TVector2', 'Vector2Divide');
  RegisterBinaryOperator('Vector2DivideFloatVector2Operator', ttDIVIDE, 'Float', 'TVector2', 'TVector2', 'Vector2DivideFloatVector2');
  RegisterBinaryOperator('Vector2DivideVector2FloatOperator', ttDIVIDE, 'TVector2', 'Float', 'TVector2', 'Vector2DivideVector2Float');

  RegisterBinaryOperator('Vector3AddOperator', ttPLUS, 'TVector3', 'TVector3', 'TVector3', 'Vector3Add');
  RegisterBinaryOperator('Vector3AddFloatVector3Operator', ttPLUS, 'Float', 'TVector3', 'TVector3', 'Vector3AddFloatVector3');
  RegisterBinaryOperator('Vector3AddVector3FloatOperator', ttPLUS, 'TVector3', 'Float', 'TVector3', 'Vector3AddVector3Float');
  RegisterBinaryOperator('Vector3SubtractOperator', ttMINUS, 'TVector3', 'TVector3', 'TVector3', 'Vector3Subtract');
  RegisterBinaryOperator('Vector3SubtractFloatVector3Operator', ttMINUS, 'Float', 'TVector3', 'TVector3', 'Vector3SubtractFloatVector3');
  RegisterBinaryOperator('Vector3SubtractVector3FloatOperator', ttMINUS, 'TVector3', 'Float', 'TVector3', 'Vector3SubtractVector3Float');
  RegisterBinaryOperator('Vector3MultiplyOperator', ttTIMES, 'TVector3', 'TVector3', 'TVector3', 'Vector3Multiply');
  RegisterBinaryOperator('Vector3MultiplyFloatVector3Operator', ttTIMES, 'Float', 'TVector3', 'TVector3', 'Vector3MultiplyFloatVector3');
  RegisterBinaryOperator('Vector3MultiplyVector3FloatOperator', ttTIMES, 'TVector3', 'Float', 'TVector3', 'Vector3MultiplyVector3Float');
  RegisterBinaryOperator('Vector3DivideOperator', ttDIVIDE, 'TVector3', 'TVector3', 'TVector3', 'Vector3Divide');
  RegisterBinaryOperator('Vector3DivideFloatVector3Operator', ttDIVIDE, 'Float', 'TVector3', 'TVector3', 'Vector3DivideFloatVector3');
  RegisterBinaryOperator('Vector3DivideVector3FloatOperator', ttDIVIDE, 'TVector3', 'Float', 'TVector3', 'Vector3DivideVector3Float');

  RegisterBinaryOperator('Vector4AddOperator', ttPLUS, 'TVector4', 'TVector4', 'TVector4', 'Vector4Add');
  RegisterBinaryOperator('Vector4AddFloatVector4Operator', ttPLUS, 'Float', 'TVector4', 'TVector4', 'Vector4AddFloatVector4');
  RegisterBinaryOperator('Vector4AddVector4FloatOperator', ttPLUS, 'TVector4', 'Float', 'TVector4', 'Vector4AddVector4Float');
  RegisterBinaryOperator('Vector4SubtractOperator', ttMINUS, 'TVector4', 'TVector4', 'TVector4', 'Vector4Subtract');
  RegisterBinaryOperator('Vector4SubtractFloatVector4Operator', ttMINUS, 'Float', 'TVector4', 'TVector4', 'Vector4SubtractFloatVector4');
  RegisterBinaryOperator('Vector4SubtractVector4FloatOperator', ttMINUS, 'TVector4', 'Float', 'TVector4', 'Vector4SubtractVector4Float');
  RegisterBinaryOperator('Vector4MultiplyOperator', ttTIMES, 'TVector4', 'TVector4', 'TVector4', 'Vector4Multiply');
  RegisterBinaryOperator('Vector4MultiplyFloatVector4Operator', ttTIMES, 'Float', 'TVector4', 'TVector4', 'Vector4MultiplyFloatVector4');
  RegisterBinaryOperator('Vector4MultiplyVector4FloatOperator', ttTIMES, 'TVector4', 'Float', 'TVector4', 'Vector4MultiplyVector4Float');
  RegisterBinaryOperator('Vector4DivideOperator', ttDIVIDE, 'TVector4', 'TVector4', 'TVector4', 'Vector4Divide');
  RegisterBinaryOperator('Vector4DivideFloatVector4Operator', ttDIVIDE, 'Float', 'TVector4', 'TVector4', 'Vector4DivideFloatVector4');
  RegisterBinaryOperator('Vector4DivideVector4FloatOperator', ttDIVIDE, 'TVector4', 'Float', 'TVector4', 'Vector4DivideVector4Float');

  RegisterBinaryOperator('Matrix2AddOperator', ttPLUS, 'TMatrix2', 'TMatrix2', 'TMatrix2', 'Matrix2Add');
  RegisterBinaryOperator('Matrix2SubtractOperator', ttMINUS, 'TMatrix2', 'TMatrix2', 'TMatrix2', 'Matrix2Subtract');
  RegisterBinaryOperator('Matrix2MultiplyOperator', ttTIMES, 'TMatrix2', 'TMatrix2', 'TMatrix2', 'Matrix2Multiply');
  RegisterBinaryOperator('Matrix2MultiplyMatrixFloatOperator', ttTIMES, 'TMatrix2', 'Float', 'TMatrix2', 'Matrix2MultiplyMatrixFloat');
  RegisterBinaryOperator('Matrix2MultiplyFloatMatrixOperator', ttTIMES, 'Float', 'TMatrix2', 'TMatrix2', 'Matrix2MultiplyFloatMatrix');
  RegisterBinaryOperator('Matrix2MultiplyMatrixVectorOperator', ttTIMES, 'TMatrix2', 'TVector2', 'TVector2', 'Matrix2MultiplyMatrixVector');
  RegisterBinaryOperator('Matrix2MultiplyVectorMatrixOperator', ttTIMES, 'TVector2', 'TMatrix2', 'TVector2', 'Matrix2MultiplyVectorMatrix');
  RegisterBinaryOperator('Matrix2DivideOperator', ttDIVIDE, 'TMatrix2', 'TMatrix2', 'TMatrix2', 'Matrix2Divide');
  RegisterBinaryOperator('Matrix2DivideMatrixFloatOperator', ttDIVIDE, 'TMatrix2', 'Float', 'TMatrix2', 'Matrix2DivideMatrixFloat');

  RegisterBinaryOperator('Matrix3AddOperator', ttPLUS, 'TMatrix3', 'TMatrix3', 'TMatrix3', 'Matrix3Add');
  RegisterBinaryOperator('Matrix3SubtractOperator', ttMINUS, 'TMatrix3', 'TMatrix3', 'TMatrix3', 'Matrix3Subtract');
  RegisterBinaryOperator('Matrix3MultiplyOperator', ttTIMES, 'TMatrix3', 'TMatrix3', 'TMatrix3', 'Matrix3Multiply');
  RegisterBinaryOperator('Matrix3MultiplyMatrixFloatOperator', ttTIMES, 'TMatrix3', 'Float', 'TMatrix3', 'Matrix3MultiplyMatrixFloat');
  RegisterBinaryOperator('Matrix3MultiplyFloatMatrixOperator', ttTIMES, 'Float', 'TMatrix3', 'TMatrix3', 'Matrix3MultiplyFloatMatrix');
  RegisterBinaryOperator('Matrix3MultiplyMatrixVectorOperator', ttTIMES, 'TMatrix3', 'TVector3', 'TVector3', 'Matrix3MultiplyMatrixVector');
  RegisterBinaryOperator('Matrix3MultiplyVectorMatrixOperator', ttTIMES, 'TVector3', 'TMatrix3', 'TVector3', 'Matrix3MultiplyVectorMatrix');
  RegisterBinaryOperator('Matrix3DivideOperator', ttDIVIDE, 'TMatrix3', 'TMatrix3', 'TMatrix3', 'Matrix3Divide');
  RegisterBinaryOperator('Matrix3DivideMatrixFloatOperator', ttDIVIDE, 'TMatrix3', 'Float', 'TMatrix3', 'Matrix3DivideMatrixFloat');

  RegisterBinaryOperator('Matrix4AddOperator', ttPLUS, 'TMatrix4', 'TMatrix4', 'TMatrix4', 'Matrix4Add');
  RegisterBinaryOperator('Matrix4SubtractOperator', ttMINUS, 'TMatrix4', 'TMatrix4', 'TMatrix4', 'Matrix4Subtract');
  RegisterBinaryOperator('Matrix4MultiplyOperator', ttTIMES, 'TMatrix4', 'TMatrix4', 'TMatrix4', 'Matrix4Multiply');
  RegisterBinaryOperator('Matrix4MultiplyMatrixFloatOperator', ttTIMES, 'TMatrix4', 'Float', 'TMatrix4', 'Matrix4MultiplyMatrixFloat');
  RegisterBinaryOperator('Matrix4MultiplyFloatMatrixOperator', ttTIMES, 'Float', 'TMatrix4', 'TMatrix4', 'Matrix4MultiplyFloatMatrix');
  RegisterBinaryOperator('Matrix4MultiplyMatrixVectorOperator', ttTIMES, 'TMatrix4', 'TVector4', 'TVector4', 'Matrix4MultiplyMatrixVector');
  RegisterBinaryOperator('Matrix4MultiplyVectorMatrixOperator', ttTIMES, 'TVector4', 'TMatrix4', 'TVector4', 'Matrix4MultiplyVectorMatrix');
  RegisterBinaryOperator('Matrix4DivideOperator', ttDIVIDE, 'TMatrix4', 'TMatrix4', 'TMatrix4', 'Matrix4Divide');
  RegisterBinaryOperator('Matrix4DivideMatrixFloatOperator', ttDIVIDE, 'TMatrix4', 'Float', 'TMatrix4', 'Matrix4DivideMatrixFloat');

  RegisterBinaryOperator('QuaternionAddOperator', ttPLUS, 'TQuaternion', 'TQuaternion', 'TQuaternion', 'QuaternionAdd');
  RegisterBinaryOperator('QuaternionMultiplyOperator', ttTIMES, 'TQuaternion', 'TQuaternion', 'TQuaternion', 'QuaternionMultiply');
  RegisterBinaryOperator('QuaternionMultiplyQuaternionFloatOperator', ttTIMES, 'TQuaternion', 'Float', 'TQuaternion', 'QuaternionMultiplyQuaternionFloat');
  RegisterBinaryOperator('QuaternionMultiplyFloatQuaternionOperator', ttTIMES, 'Float', 'TQuaternion', 'TQuaternion', 'QuaternionMultiplyFloatQuaternion');

  RegisterFastMathFunction('ShowMessage', '', ['Msg'], ['String'], DoShowMessage);
end;

end.
